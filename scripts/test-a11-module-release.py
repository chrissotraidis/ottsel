#!/usr/bin/env python3
"""Fresh release-debug emitter/standalone/aggregate link proof, without GOAL execution.
Usage: python3 scripts/test-a11-module-release.py NEW_OUTPUT_DIRECTORY
"""
import json
import pathlib
import subprocess
import sys
repo=pathlib.Path(__file__).resolve().parents[1]
source=repo/'out/jak-project'
output=pathlib.Path(sys.argv[1]).resolve()
output.mkdir(parents=True,exist_ok=False)
commands=[]
def run(args):
    args=list(map(str,args));commands.append(args)
    (output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    with (output/'proof.log').open('a') as log:
        subprocess.run(args,cwd=repo,check=True,timeout=60,stdout=log,stderr=subprocess.STDOUT)
# Existing regression obtains actual memory_layout constants and freshly emits
# ordinary Gstate/Gstring; don't trust stale or hand-edited generated assembly.
run(['bash',repo/'scripts/test-a11-module.sh',output/'ordinary'])
allocator=json.loads((output/'ordinary/allocator-reservation.json').read_text())
(output/'cli.cpp').write_text('#include "a11_module_emitter.h"\n#include <iostream>\nint main(int n,char**v) try{return ottsel::a11::signed_module_cli(n,v);}catch(const std::exception&e){std::cerr<<e.what()<<"\\n";return 1;}\n')
run(['xcrun','--sdk','macosx','clang++','-std=c++20','-Wno-deprecated-declarations',
     '-I'+str(source/'tools/ottsel_a1_1'),output/'cli.cpp','-o',output/'cli'])
run(['python3',repo/'test/a11_module_release_test.py',output/'cli',source/'out/jak1/obj/gcommon.o',output/'fixture'])
release=output/'fixture/release'
run(['python3',repo/'test/a11_release_manifest_test.py',release])
manifest=json.loads((release/'gcommon.json').read_text())
(release/'aggregate.json').write_text(json.dumps(dict(modules=['gcommon'],reservation_begin=manifest['data_reservation_offset'],
    heap_start=allocator['heap_start'],original_heap_end=allocator['old_heap_end'])))
inputs=[release/'gcommon.json',output/'ordinary/gstate.json',output/'ordinary/gstring.json']
span=sum((json.loads(p.read_text())['data_size']+15)&~15 for p in inputs)
run(['python3',repo/'scripts/emit-signed-module-arena.py','--heap-start',allocator['heap_start'],
     '--heap-end',allocator['old_heap_end'],'--reservation-begin',(allocator['old_heap_end']-span)&~16383,
     '--output',output/'aggregate',*inputs])
(output/'link-only.cpp').write_text('int main(){return 0;}\n')
for directory,names,arena in [(release,['gcommon'],'gcommon-arena-layout.s'),
                            (output/'aggregate',['gcommon','gstate','gstring'],'aggregate-arena-layout.s')]:
    executable=directory/'aggregate-linked'
    run(['xcrun','--sdk','macosx','clang++','-arch','arm64',output/'link-only.cpp',directory/arena,
         *[directory/(name+'.s') for name in names],'-Wl,-segprot,__ARENA,rw,rw','-Wl,-segprot,__GOAL,rx,rx','-o',executable])
    if executable.stat().st_size>=100_000_000:raise RuntimeError('fixture too large')
    run(['codesign','--force','--sign','-',executable])
    run(['codesign','--verify','--strict',executable])
    run(['python3',repo/'test/a11_aggregate_macho_check.py',directory])
print('PASS release-debug source policy, standalone tail and aggregate linked text/targets; no GOAL executed:',output/'proof.log')
