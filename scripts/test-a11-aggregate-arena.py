#!/usr/bin/env python3
"""Fresh emitter -> aggregate -> signed host Mach-O -> VM/real allocator proof.
No app, Simulator, GOAL execution or product source/output modification.
Usage: python3 scripts/test-a11-aggregate-arena.py NEW_OUTPUT_DIRECTORY
"""
import json
import pathlib
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parents[1]
source = repo/'out/jak-project'
output = pathlib.Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=False)
commands = []

def run(args):
    args = list(map(str,args))
    commands.append(args)
    (output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    with (output/'proof.log').open('a') as log:
        subprocess.run(args,cwd=repo,check=True,timeout=60,stdout=log,stderr=subprocess.STDOUT)

fresh = output/'fresh'
run(['bash',repo/'scripts/test-a11-module.sh',fresh])
run(['python3',repo/'test/a11_aggregate_arena_test.py',fresh])
allocator = json.loads((fresh/'allocator-reservation.json').read_text())
# Actual current emitter data sizes, not inferred unused heap space.
span = sum((json.loads((fresh/(n+'.json')).read_text())['data_size']+15)&~15 for n in ('gstate','gstring'))
begin = (allocator['old_heap_end']-span)&~16383
linked = output/'linked'
run(['python3',repo/'scripts/emit-signed-module-arena.py','--heap-start',allocator['heap_start'],
     '--heap-end',allocator['old_heap_end'],'--reservation-begin',begin,'--output',linked,
     fresh/'gstate.json',fresh/'gstring.json'])
a = json.loads((linked/'aggregate.json').read_text())
lines = [f'constexpr u32 kReservation={a["reservation_begin"]}, kDataSpan={a["data_span_size"]}, kFunctionType={a["required_function_type"]};']
segments,tags = [],[]
for name in a['modules']:
    m = json.loads((linked/(name+'.json')).read_text())
    for s in m['segments']:
        code,data = s['code_label'][1:],s['data_label'][1:]
        lines.append(f'extern "C" u8 {code}[], {data}[];')
        segments.append('{'+f'{code},{data},{s["text_size"]},{s["data_arena_offset"]}'+'}')
        tags += [f'{code}+{v["offset"]}' for v in s['slots'] if v['kind']=='immutable_function_tag']
lines += ['struct Segment {u8* code;u8* data;u32 text_size;u32 offset;};',
          'const Segment kSegments[]={'+','.join(segments)+'};','u8* const kTags[]={'+','.join(tags)+'};']
(linked/'aggregate_fixture.inc').write_text('\n'.join(lines)+'\n')
executable = linked/'aggregate-linked'
run(['xcrun','--sdk','macosx','clang++','-arch','arm64','-std=c++20','-O2',
     '-I'+str(source),'-I'+str(source/'third-party/fmt/include'),'-I'+str(linked),
     repo/'test/a11_aggregate_vm_test.cpp',source/'game/kernel/common/kmalloc.cpp',
     linked/'aggregate-arena-layout.s',linked/'gstate.s',linked/'gstring.s',
     '-Wl,-segprot,__ARENA,rw,rw','-Wl,-segprot,__GOAL,rx,rx','-o',executable])
if executable.stat().st_size>=100_000_000:
    raise SystemExit('host fixture too large')
run(['codesign','--force','--sign','-',executable])
run(['codesign','--verify','--strict',executable])
run(['python3',repo/'test/a11_aggregate_macho_check.py',linked])
run([executable])
print('PASS aggregate signed layout and actual allocator; no GOAL executed. Evidence:',output/'proof.log')
