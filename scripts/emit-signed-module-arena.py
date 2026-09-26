#!/usr/bin/env python3
"""Aggregate validated v3 module emissions; this does not activate a runtime loader.

Inputs are emitter JSON files next to their .s, .source.o and data templates.
Output is a NEW directory containing one arena layout, adjusted per-module
manifests and byte-identical code/templates. Never link input *-arena-layout.s.
The runtime must reserve aggregate.json reservation_begin before allocation.
Prerequisite: inputs were produced by the maintained validated emitter. This
layout tool verifies source/templates and metadata bounds; it does not decode
assembly or prove that an arbitrary .s corresponds to the source object. Run
test-a11-aggregate-arena.py to freshly emit, link and compare every codeword.
Relocation targets remain unchanged; supported kinds remain the emitter policy.
"""
import argparse
import copy
import hashlib
import json
import pathlib
import re
import struct

ARENA_SIZE = 128 * 1024 * 1024

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def uint(value):
    require(type(value) is int and 0 <= value <= 0xffffffff, 'invalid u32')
    return value

def aligned(value):
    return (value + 15) & ~15

def load(path):
    m = json.loads(path.read_text())
    name = m['module']
    require(type(name) is str and re.fullmatch(r'[A-Za-z0-9_-]+', name), 'invalid module name')
    require(m['schema'] in (1, 2) and m['arena_symbol'] == '_ottsel_module_arena' and
            m['arena_size'] == ARENA_SIZE and m['entry'] == {'segment': 2, 'offset': 4},
            'unsupported module schema/arena/entry')
    release = m['schema'] == 2
    require(m.get('debug_policy', 'reject-nonempty') == ('release-omit' if release else 'reject-nonempty'),
            'unsupported debug load policy')
    label_name = name.replace('-', '_')
    identity = uint(m['required_function_type'])
    require(identity and not identity & 3, 'invalid function Type')
    files = {}
    for filename in [name + '.s', name + '.source.o'] + [f'{name}-s{i}-data.bin' for i in range(3)]:
        content = (path.parent / filename).read_bytes()
        require(len(content) < 100 * 1024 * 1024, 'artifact too large')
        files[filename] = content
    source = files[name + '.source.o']
    require(len(source) == uint(m['source_bytes']) and
            hashlib.sha256(source).hexdigest() == m['source_sha256'], 'source hash/size mismatch')
    require(len(source) >= 80, 'short source')
    word = lambda p: struct.unpack_from('<I', source, p)[0]
    require((word(4), word(8), word(12)) == (1, 3, 3), 'unsupported source version')
    require(len(m['segments']) == 3, 'invalid segment count')
    previous = uint(m['data_reservation_offset'])
    limit = previous + uint(m['data_size'])
    require(previous and previous % 16 == 0 and limit <= ARENA_SIZE, 'invalid input reservation')
    for i, s in enumerate(m['segments']):
        require(s['id'] == i, 'invalid segment ordering')
        size, text = uint(s['size']), uint(s['text_size'])
        require(text <= size and text % 4 == 0, 'invalid text size')
        source_size = uint(s.get('source_size', size))
        source_text = uint(s.get('source_text_size', text))
        require(source_size == word(44 + i * 8) and source_text == word(64 + i * 4) and
                source_text <= source_size and source_text % 4 == 0, 'source segment mismatch')
        omitted = release and i == 1
        require(type(s.get('loaded', True)) is bool and s.get('loaded', True) == (not omitted),
                'incorrect loaded segment policy')
        require((size, text) == ((0, 0) if omitted else (source_size, source_text)),
                'loaded segment differs without exact omitted-debug policy')
        if omitted:
            require(not s['slots'] and not s['distances'] and not s.get('pointers', []), 'omitted debug still has loaded relocations')
        base = word(76) + word(40 + i * 8)
        require(base + source_size <= len(source), 'source segment overflow')
        data = files[f'{name}-s{i}-data.bin']
        require(data == (b'' if omitted else source[base + source_text:base + source_size]), 'data template mismatch')
        offset = uint(s['data_arena_offset'])
        require(offset % 16 == 0 and offset >= previous and offset + len(data) <= limit,
                'overlapping/unaligned input data')
        previous = offset + len(data)
        for field, suffix in [('code_label', 'code'), ('data_label', 'data')]:
            require(s[field] == f'_ottsel_module_{label_name}_s{i}_{suffix}', 'invalid symbol label')
        occupied = set()
        for slot in s['slots']:
            off = uint(slot['offset'])
            require(off % 4 == 0 and off not in occupied and off + 4 <= size, 'invalid/duplicate slot')
            occupied.add(off)
            require(type(slot['name']) is str and slot['name'] and '\0' not in slot['name'], 'invalid slot name')
            if slot['kind'] == 'immutable_function_tag':
                require(off + 8 <= text and slot['name'] == 'function' and slot['methods'] == 9,
                        'invalid immutable function tag')
            else:
                require(off >= text and slot['kind'] in ('symbol_offset', 'symbol_address', 'type_pointer'),
                        'writable slot in text/unknown slot')
                if slot['kind'] == 'type_pointer':
                    # A Type slot is interned by (name, methods) at load time,
                    # so a writable record carries the object's own count. The
                    # three bootstrap types the runtime registers at exactly
                    # nine methods stay pinned.
                    require(not (slot['name'] in ('string', 'kernel-context', 'state') and slot['methods'] != 9),
                            'unsupported bootstrap writable type')
        for r in s['distances']:
            patch, target, sid = uint(r['patch']), uint(r['target']), uint(r['target_segment'])
            require(sid < 3 and target < m['segments'][sid].get('source_size', m['segments'][sid]['size']), 'invalid relocation target')
            absent = release and sid == 1
            require(r.get('target_policy', 'segment') == ('goal-zero' if absent else 'segment'),
                    'incorrect absent segment target policy')
            require(patch % 4 == 0 and patch + 8 <= text and
                    patch not in occupied and patch + 4 not in occupied, 'overlapping relocation')
            if absent:
                require((word(base + patch + 4) & 0xffc00000) == 0x91000000,
                        'only address materialization may target omitted debug')
            occupied.update((patch, patch + 4))
            # Target low bits are representation data, not layout alignment.
            # Keep the complete target unchanged (ADRP+ADD may address tagged data).
        for pointer in s.get('pointers', []):
            patch, target = uint(pointer['patch']), uint(pointer['target'])
            require(patch % 4 == 0 and text <= patch and patch + 4 <= size and patch not in occupied,
                    'invalid/overlapping writable pointer patch')
            if pointer.get('kind', 'data') == 'code':
                # The code base is a link-time symbol difference no static
                # initializer can hold, so the record carries the raw target.
                require(set(pointer) == {'patch', 'target', 'kind', 'target_offset'} and
                        uint(pointer['target_offset']) == target and target % 4 == 0 and
                        target + 4 <= source_text, 'invalid code-target pointer record')
            else:
                # A data target is written from the reserved arena span, so its
                # complete value is the recorded offset and must reproduce the
                # source target exactly, low tag bits included.
                require(set(pointer) == {'patch', 'target', 'kind', 'goal_offset'}, 'invalid data pointer record')
                goal_offset = uint(pointer['goal_offset'])
                require(goal_offset < ARENA_SIZE and goal_offset >= offset and
                        goal_offset - offset + text == target and source_text <= target < source_size,
                        'pointer value does not preserve source target offset/tag')
            occupied.add(patch)
        if i == 2:
            require(any(v['kind'] == 'immutable_function_tag' and v['offset'] == 0 for v in s['slots']),
                    'missing entry function tag')
    require(previous == limit, 'incorrect module data span')
    return m, files

def aggregate(paths, heap_start, heap_end, reservation_begin):
    for v in (heap_start, heap_end, reservation_begin):
        uint(v)
    require(heap_start < reservation_begin < heap_end <= ARENA_SIZE and reservation_begin % 16384 == 0,
            'invalid aggregate heap reservation')
    require(paths, 'no modules')
    modules, files, names, labels = [], {}, set(), set()
    cursor = reservation_begin
    identity = None
    lines = ['.globl _ottsel_module_arena',
             f'.zerofill __ARENA,__zero,_ottsel_module_arena,{reservation_begin},14']
    for path in paths:
        m, artifacts = load(path)
        require(m['module'] not in names, 'duplicate module')
        names.add(m['module'])
        current_labels = {s[k] for s in m['segments'] for k in ('code_label', 'data_label')}
        require(not labels.intersection(current_labels), 'module names alias identical Mach-O symbols')
        labels.update(current_labels)
        if identity is None:
            identity = m['required_function_type']
        require(identity == m['required_function_type'], 'different bootstrap function Types')
        m = copy.deepcopy(m)
        begin = aligned(cursor)
        m['data_reservation_offset'] = begin
        for s in m['segments']:
            cursor = aligned(cursor)
            s['data_arena_offset'] = cursor
            for pointer in s.get('pointers', []):
                # A raw code target carries no arena base to rebase; the runtime
                # adds this module's signed code address at activation instead.
                if pointer.get('kind', 'data') == 'data':
                    pointer['goal_offset'] = cursor + pointer['target'] - s['text_size']
            size = s['size'] - s['text_size']
            require(size <= heap_end - cursor, 'aggregate exceeds reserved heap tail')
            cursor += size
            lines.extend([f'.globl {s["data_label"]}',
                          f'.zerofill __ARENA,__zero,{s["data_label"]},{size},4'])
        m['data_size'] = cursor - begin
        modules.append(m)
        files.update(artifacts)
    # Each .zerofill label is aligned16, including the tail. Count that padding
    # explicitly so a non16-aligned last template cannot grow __ARENA by a page.
    cursor = aligned(cursor)
    require(cursor <= heap_end, 'aggregate alignment exceeds heap tail')
    lines.append(f'.zerofill __ARENA,__zero,_ottsel_module_arena_tail,{ARENA_SIZE - cursor},4')
    manifest = dict(schema=1, arena_symbol='_ottsel_module_arena', arena_size=ARENA_SIZE,
                    required_function_type=identity, heap_start=heap_start,
                    original_heap_end=heap_end, reservation_begin=reservation_begin,
                    data_span_size=cursor-reservation_begin, modules=[m['module'] for m in modules])
    files['aggregate-arena-layout.s'] = ('\n'.join(lines)+'\n').encode()
    files['aggregate.json'] = (json.dumps(manifest, indent=2)+'\n').encode()
    for m in modules:
        files[m['module']+'.json'] = (json.dumps(m, indent=2)+'\n').encode()
    return files

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--heap-start', required=True, type=lambda v: int(v, 0))
    parser.add_argument('--heap-end', required=True, type=lambda v: int(v, 0))
    parser.add_argument('--reservation-begin', required=True, type=lambda v: int(v, 0))
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('manifests', nargs='+', type=pathlib.Path)
    args = parser.parse_args()
    artifacts = aggregate(args.manifests, args.heap_start, args.heap_end, args.reservation_begin)
    # All semantic validation precedes output; never overwrite a prior proof.
    args.output.mkdir(parents=True, exist_ok=False)
    for name, content in artifacts.items():
        (args.output / name).write_bytes(content)
    print(f'PASS aggregate {len(args.manifests)} modules; loader activation unchanged')

if __name__ == '__main__':
    main()
