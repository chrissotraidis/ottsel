#!/usr/bin/env python3
"""Fresh all-KERNEL emission/link plus actual kind5 linker oracle; no GOAL execution.
Usage: python3 scripts/test-a11-kernel-emission.py NEW_OUTPUT_DIRECTORY
"""
import hashlib,json,pathlib,re,struct,subprocess,sys
repo=pathlib.Path(__file__).resolve().parents[1];source=repo/'out/jak-project'
output=pathlib.Path(sys.argv[1]).resolve();output.mkdir(parents=True,exist_ok=False)
order=re.findall(r'"([^"]+)\.o"',(source/'goal_src/jak1/dgos/kernel.gd').read_text())
assert order==['gcommon','gstring-h','gkernel-h','gkernel','pskernel','gstring','dgo-h','gstate']
commands=[]
def run(args):
 args=list(map(str,args));commands.append(args);(output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 with (output/'proof.log').open('a') as log:subprocess.run(args,cwd=repo,check=True,timeout=60,stdout=log,stderr=subprocess.STDOUT)
# Reuse the focused regression's actual memory constants and actual emitter CLI.
run(['bash',repo/'scripts/test-a11-module.sh',output/'ordinary'])
allocator=json.loads((output/'ordinary/allocator-reservation.json').read_text())
cli=output/'ordinary/module_cli';inputs=[];hashes={}
for name in order:
 obj=source/f'out/jak1/obj/{name}.o';raw=obj.read_bytes();hashes[name]=hashlib.sha256(raw).hexdigest()
 debug=struct.unpack_from('<I',raw,52)[0]!=0
 run([cli,'--module',obj,name,output/'modules','0x1bfec4',str((allocator['old_heap_end']-16384)&~16383)]+
     (['--release-no-debug'] if debug else []))
 inputs.append(output/f'modules/{name}.json')
(output/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
run(['python3',repo/'test/a11_top_only_test.py',cli,source/'out/jak1/obj/gstring-h.o',output/'top-only',repo/'scripts/emit-signed-module-arena.py'])
run(['python3',repo/'test/a11_kernel_pointer_test.py',cli,source/'out/jak1/obj/gkernel.o',output/'pointer-controls',repo/'scripts/emit-signed-module-arena.py'])
span=sum((json.loads(p.read_text())['data_size']+15)&~15 for p in inputs)
run(['python3',repo/'scripts/emit-signed-module-arena.py','--heap-start',allocator['heap_start'],'--heap-end',allocator['old_heap_end'],
     '--reservation-begin',(allocator['old_heap_end']-span)&~16383,'--output',output/'aggregate',*inputs])
a=output/'aggregate';(output/'link-only.cpp').write_text('int main(){return 0;}\n')
executable=a/'aggregate-linked'
run(['xcrun','--sdk','macosx','clang++','-arch','arm64',output/'link-only.cpp',a/'aggregate-arena-layout.s',
     *[a/(name+'.s') for name in order],'-Wl,-segprot,__ARENA,rw,rw','-Wl,-segprot,__GOAL,rx,rx','-o',executable])
if executable.stat().st_size>=100_000_000:raise RuntimeError('fixture too large')
run(['codesign','--force','--sign','-',executable]);run(['codesign','--verify','--strict',executable])
run(['python3',repo/'test/a11_aggregate_macho_check.py',a])
# The oracle is unmodified source, using real Ptr and ObjectFileHeader types.
# For data-only pointers, virtual contiguous base = final RW label - source text
# exactly translates original segment-relative records into split signed layout.
linker=source/'game/kernel/jak1/klink.cpp';text=linker.read_text();start=text.index('uint32_t ptr_link_v3(');end=text.index('\n}',start)+2
(output/'actual-ptr-link.inc').write_text(text[start:end]+'\n')
(output/'oracle-source-sha256.txt').write_text(hashlib.sha256(linker.read_bytes()).hexdigest()+'\n')
m=json.loads((a/'gkernel.json').read_text());records=[]
for s in m['segments']:
 for p in s.get('pointers',[]):
  assert p['kind']=='data'
  records.append(f'data {s["data_arena_offset"]-s["text_size"]} {p["patch"]} {p["target"]} {p["goal_offset"]}')
# No genuine KERNEL member carries a code target, so the oracle's code branch runs
# on a synthetic record over the first genuine slot/target window: base is the
# module's signed code label (outside the arena) and the value is base+target.
code_base=112*1024*1024;first=m['segments'][0]['pointers'][0]
code_target=m['segments'][0]['source_text_size']-4
records.append(f'code {code_base} {first["patch"]} {code_target} {code_base+code_target}')
(output/'pointer-records.txt').write_text('\n'.join(records)+'\n')
run(['xcrun','--sdk','macosx','clang++','-std=c++20','-I'+str(source),'-I'+str(output),
     repo/'test/a11_kernel_pointer_oracle.cpp','-o',output/'pointer-oracle'])
run([output/'pointer-oracle',output/'pointer-records.txt'])
for name in order:
 assert hashes[name]==hashlib.sha256((source/f'out/jak1/obj/{name}.o').read_bytes()).hexdigest()
 manifest=json.loads((a/(name+'.json')).read_text());assert manifest['source_sha256']==hashes[name]
print('PASS all-eight signed emission/layout + independent six-pointer oracle; no GOAL executed:',output/'proof.log')
