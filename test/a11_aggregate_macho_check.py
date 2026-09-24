"""Compare aggregate linked text/relocations/templates to genuine emitted objects."""
import json
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1])
aggregate = json.loads((root / 'aggregate.json').read_text()); allocator = dict(required_new_heap_end=aggregate['reservation_begin'], heap_start=aggregate['heap_start'], old_heap_end=aggregate['original_heap_end'])
for name in aggregate["modules"]:
    manifest = json.loads((root / (name + ".json")).read_text())
    source = (root / (name + ".source.o")).read_bytes()
    binary = (root / "aggregate-linked").read_bytes()
    assert struct.unpack_from("<I", binary)[0] == 0xFEEDFACF
    word = lambda b, p: struct.unpack_from("<I", b, p)[0]
    pos = 32
    sections = []
    symbols = {}
    segments = {}
    for _ in range(word(binary, 16)):
        command, size = struct.unpack_from("<II", binary, pos)
        if command == 0x19:
            segname = binary[pos + 8:pos + 24].split(b'\0')[0].decode()
            vmaddr, vmsize, fileoff, filesize, maxprot, initprot = struct.unpack_from('<QQQQII', binary, pos + 24)
            assert segname not in segments, 'duplicate Mach-O segment'
            segments[segname] = (vmaddr, vmsize, initprot, maxprot, filesize)
            for i in range(word(binary, pos + 64)):
                sec = pos + 72 + 80 * i
                address, length, offset = struct.unpack_from("<QQI", binary, sec + 32)
                sections.append((address, length, offset))
        elif command == 2:
            symoff, count, stroff, strsize = struct.unpack_from("<IIII", binary, pos + 8)
            for i in range(count):
                strx, typ, section, desc, value = struct.unpack_from("<IBBHQ", binary, symoff + 16 * i)
                end = binary.index(0, stroff + strx)
                symbols[binary[stroff + strx:end].decode()] = value
        pos += size

    def at(address, size):
        for base, length, offset in sections:
            if base <= address and address + size <= base + length:
                return binary[offset + address - base:offset + address - base + size]
        raise AssertionError(f"address outside sections: {address:x}")

    for seg in manifest["segments"]:
        sid = seg["id"]
        base = word(source, 76) + word(source, 40 + 8 * sid)
        code = symbols[seg["code_label"]]
        data = symbols[seg["data_label"]]
        arena = symbols[manifest['arena_symbol']]
        assert data - arena == seg['data_arena_offset']
        assert manifest['data_reservation_offset'] <= data - arena
        assert data - arena + seg['size'] - seg['text_size'] <= manifest['arena_size']
        assert (root / f'{name}-s{sid}-data.bin').read_bytes() == (source[base + seg['text_size']:base + seg['size']] if seg.get('loaded', True) else b'')
        if seg['text_size']:
            assert manifest['arena_size'] <= code - arena < 2**32
            assert code + seg['text_size'] - arena <= 2**32
            goal = segments['__GOAL']
            assert goal[0] <= code and code + seg['text_size'] <= goal[0] + goal[1]
        tags = {slot["offset"] for slot in seg["slots"] if slot["kind"] == "immutable_function_tag"}
        distances = {r["patch"]: r for r in seg["distances"]}
        off = 0
        while off < seg["text_size"]:
            actual = word(at(code + off, 4), 0)
            if off in distances:
                ref = distances[off]
                add = word(at(code + off + 4, 4), 0)
                imm = ((actual >> 29) & 3) | (((actual >> 5) & 0x7FFFF) << 2)
                if imm & (1 << 20):
                    imm -= 1 << 21
                # LDR S scales imm12 by four, LDR Q by sixteen; ADD leaves it
                # unscaled.
                op = add & 0xFFC00000
                scale = 4 if op == 0xBD400000 else 16 if op == 0x3DC00000 else 1
                resolved = ((code + off) & ~4095) + (imm << 12) + (((add >> 10) & 4095) * scale)
                target = manifest["segments"][ref["target_segment"]]
                is_data = ref["target"] >= target["text_size"]
                expected = symbols[target["data_label"] if is_data else target["code_label"]]
                expected += ref["target"] - (target["text_size"] if is_data else 0)
                if ref.get('target_policy') == 'goal-zero':
                    assert manifest['schema'] == 2 and manifest['debug_policy'] == 'release-omit'
                    assert ref['target_segment'] == 1 and not target['loaded']
                    expected = arena  # Source target offset must be discarded.
                assert resolved == expected, (name, sid, off, resolved, expected)
                # Linker may change immediate fields, not operation or registers.
                assert (actual & 0x9F00001F) == (word(source, base + off) & 0x9F00001F)
                assert (add & ~(4095 << 10)) == (word(source, base + off + 4) & ~(4095 << 10))
                off += 8
            else:
                expected = manifest["required_function_type"] if off in tags else word(source, base + off)
                assert actual == expected, (name, sid, off, actual, expected)
                off += 4
    assert segments['__ARENA'][1:] == (134217728, 3, 3, 0)
    assert segments['__GOAL'][2:4] == (5, 5)
    assert manifest['data_size'] == max(s['data_arena_offset']+s['size']-s['text_size'] for s in manifest['segments'])-manifest['data_reservation_offset']
    assert manifest['data_reservation_offset'] >= allocator['required_new_heap_end']
    assert allocator['heap_start'] < allocator['required_new_heap_end']
    assert allocator['required_new_heap_end'] + manifest['data_size'] <= allocator['old_heap_end']
    print(f"PASS {name}: linked all{sum(len(s["distances"]) for s in manifest["segments"])} targets/codewords; RX GOAL after arena, reserved RW data inside128MiB")
