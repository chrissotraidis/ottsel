#!/usr/bin/env python3
"""Read-only aggregate regression against genuine emitted Gstate/Gstring modules.
Usage: python3 test/a11_aggregate_arena_test.py EMISSION_DIRECTORY [GENERATOR]
No compiler, runtime launch or product output writes.
"""
import copy
import importlib.util
import json
import pathlib
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('aggregate', pathlib.Path(sys.argv[2]) if len(sys.argv)>2 else root/'scripts/emit-signed-module-arena.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
inputs = pathlib.Path(sys.argv[1])
allocator = json.loads((inputs/'allocator-reservation.json').read_text())
heap_start, heap_end = allocator['heap_start'], allocator['old_heap_end']
begin = (heap_end - 320 - 528) & ~16383
paths = [inputs/'gstate.json', inputs/'gstring.json']
checks = 0

def check(ok, label):
    global checks
    assert ok, label
    checks += 1
    print('PASS', label)

def reject(fn, label):
    try:
        fn()
    except ValueError:
        check(True, label)
        return
    raise AssertionError(label)

result = a.aggregate(paths, heap_start, heap_end, begin)
meta = json.loads(result['aggregate.json'])
check(meta['data_span_size']==848 and begin==0x3eb4000, 'actual 848-byte aggregate fits newly reserved tail')
assembly = result['aggregate-arena-layout.s'].decode()
check(assembly.count('.zerofill __ARENA,__zero,_ottsel_module_arena,')==1 and
      assembly.count('.zerofill __ARENA,__zero,_ottsel_module_arena_tail,')==1,
      'one arena and one tail; no standalone layouts copied')
end = begin
for name in ('gstate','gstring'):
    old = json.loads((inputs/(name+'.json')).read_text())
    new = json.loads(result[name+'.json'])
    check(result[name+'.s']==(inputs/(name+'.s')).read_bytes(), name+' immutable assembly unchanged')
    for s, previous in zip(new['segments'], old['segments']):
        check(s['slots']==previous['slots'] and s['distances']==previous['distances'],
              f'{name} segment{s["id"]} tags and complete relocation target offsets preserved')
        check(s['data_arena_offset']>=end and s['data_arena_offset']%16==0, name+' aligned disjoint data')
        end = s['data_arena_offset']+s['size']-s['text_size']
        check(result[f'{name}-s{s["id"]}-data.bin']==(inputs/f'{name}-s{s["id"]}-data.bin').read_bytes(),
              name+' exact template preserved')
reject(lambda:a.aggregate(paths,heap_start,heap_end,0x3eb8000),'old 736-byte tail rejects aggregate')
reject(lambda:a.aggregate(paths+paths[:1],heap_start,heap_end,begin),'duplicate module rejects')
reject(lambda:a.aggregate(paths,heap_start,heap_end,begin+16),'page-unaligned reservation rejects')

with tempfile.TemporaryDirectory(prefix='ottsel-aggregate-') as tmp:
    tmp = pathlib.Path(tmp)
    original = json.loads(paths[1].read_text())
    for f in ('gstring.s','gstring.source.o','gstring-s0-data.bin','gstring-s1-data.bin','gstring-s2-data.bin'):
        (tmp/f).write_bytes((inputs/f).read_bytes())
    def malformed(change, label):
        m=copy.deepcopy(original)
        change(m)
        p=tmp/'gstring.json'
        p.write_text(json.dumps(m))
        reject(lambda:a.aggregate([paths[0],p],heap_start,heap_end,begin),label)
    malformed(lambda m:m.update(required_function_type=m['required_function_type']+16),'different bootstrap Type rejects')
    malformed(lambda m:m.update(source_sha256='0'*64),'changed source hash rejects')
    malformed(lambda m:m['segments'][2].update(data_arena_offset=m['segments'][0]['data_arena_offset']), 'overlapping input data rejects')
    malformed(lambda m:m['segments'][2]['slots'].append(copy.deepcopy(m['segments'][2]['slots'][0])), 'duplicate function tag rejects')
    malformed(lambda m:next(s for s in m['segments'][2]['slots'] if s['kind']=='immutable_function_tag').update(name='string'), 'wrong immutable tag type rejects')
    p=tmp/'gstring.json'
    p.write_text(json.dumps(original))
    data=tmp/'gstring-s0-data.bin'
    data.write_bytes(b'x'+data.read_bytes()[1:])
    reject(lambda:a.aggregate([paths[0],p],heap_start,heap_end,begin),'modified data template rejects')
print(f'{checks} checks PASS; no linked Mach-O or runtime assertion made')
