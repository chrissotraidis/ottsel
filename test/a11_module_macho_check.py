"""Check linked actual emission without executing any emitted GOAL code."""
import json
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1])
allocator = json.loads((root / 'allocator-reservation.json').read_text())
# The expected RW template span per module. A data-only main segment is a
# declaration-only object's static data; its span is its own data alone.
expected_data = {"gstate": 320, "gstate_unaligned": 320, "gstring": 528,
                 "gstring_quad": 528, "merc-vu1": 20, "ocean-vu0": 280}
for name in ("gstate", "gstate_unaligned", "gstring", "gstring_quad",
             "merc-vu1", "ocean-vu0"):
    manifest = json.loads((root / (name + ".json")).read_text())
    source = (root / (name + ".source.o")).read_bytes()
    binary = (root / (name + "-linked")).read_bytes()
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
            segments[segname] = (vmaddr, vmsize, initprot)
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
        assert (root / f'{name}-s{sid}-data.bin').read_bytes() == source[base + seg['text_size']:base + seg['size']]
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
                # unscaled. Emitting LDR D for an LDR Q word would change the
                # operation bits asserted below and resolve a 16x-short address.
                op = add & 0xFFC00000
                scale = 4 if op == 0xBD400000 else 16 if op == 0x3DC00000 else 1
                resolved = ((code + off) & ~4095) + (imm << 12) + (((add >> 10) & 4095) * scale)
                target = manifest["segments"][ref["target_segment"]]
                is_data = ref["target"] >= target["text_size"]
                expected = symbols[target["data_label"] if is_data else target["code_label"]]
                expected += ref["target"] - (target["text_size"] if is_data else 0)
                assert resolved == expected, (name, sid, off, resolved, expected)
                # Linker may change immediate fields, not operation or registers.
                assert (actual & 0x9F00001F) == (word(source, base + off) & 0x9F00001F)
                assert (add & ~(4095 << 10)) == (word(source, base + off + 4) & ~(4095 << 10))
                off += 8
            else:
                expected = manifest["required_function_type"] if off in tags else word(source, base + off)
                assert actual == expected, (name, sid, off, actual, expected)
                off += 4
    assert segments['__ARENA'][2] == 3 and segments['__GOAL'][2] == 5
    if name in ("merc-vu1", "ocean-vu0"):
        # A declaration-only object's main segment has no signed text, so it can
        # carry no tag, no instruction-pair distance and no code pointer; every
        # record it does keep is data-side.
        main = manifest["segments"][0]
        assert main["source_text_size"] == 0 and main["text_size"] == 0
        assert not main["distances"] and not main["pointers"]
        assert not [s for s in main["slots"] if s["kind"] == "immutable_function_tag"]
    assert manifest['data_size'] == expected_data[name]
    assert manifest['data_reservation_offset'] == allocator['required_new_heap_end']
    assert allocator['heap_start'] < allocator['required_new_heap_end']
    assert allocator['required_new_heap_end'] + manifest['data_size'] <= allocator['old_heap_end']
    print(f"PASS {name}: linked all{sum(len(s["distances"]) for s in manifest["segments"])} targets/codewords; RX GOAL after arena, reserved RW data inside128MiB")
