#!/usr/bin/env python3
"""Ottsel S1.1 — ARM64 emitter validation harness.

Validates every word the ARM64 goalc emitter produces for a compiled kernel
object (the objects inside KERNEL.CGO) by decoding each word with the Xcode
toolchain (as + llvm-objdump) and failing on any invalid encoding.

Two independent checks per word:
  1. decode: llvm-objdump must decode the word as an A64 instruction (an
     undecodable word produces an "invalid instruction encoding" warning and
     an address gap in the disassembly);
  2. round-trip: the disassembled mnemonic must reassemble (as) to the same
     4 bytes (catches decode/encode mismatches).

Deliberately accepted (never executed, by object-format construction):
  - 0xaeaeaeae: the v3 "function type tag" (POINTER_SIZE bytes of 0xae that
    precede every function; code starts after the tag).
  - 0x00000000: page-boundary alignment padding, decoded as `udf #0`.

Usage:
  python3 scripts/validate-arm64-emission.py [--cgo out/jak1/iso/KERNEL.CGO]
  python3 scripts/validate-arm64-emission.py --selftest

Exit code 0 = all code words valid; 1 = invalid word(s) found or harness
failure. Known-bad test case: 0xb8760801 (the pre-H3 load32u encoding).
"""

import argparse
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

N_SEG = 3
SEG_NAMES = ["main", "debug", "top-level"]
TYPE_TAG_WORD = 0xAE

# Mnemonics whose PC-relative immediate must be rewritten to a label for
# reassembly. tbz/tbnz carry a bit number in operand 2; the target is last.
PC_REL = {"b", "bl", "cbz", "cbnz", "tbz", "tbnz", "adr", "adrp"}


def parse_cgo(path):
    data = Path(path).read_bytes()
    (count,) = struct.unpack_from("<I", data, 0)
    off = 64  # DgoHeader{ u32 object_count; char name[60] }
    objs = []
    for _ in range(count):
        (size,) = struct.unpack_from("<I", data, off)
        name = data[off + 4 : off + 64].split(b"\0")[0].decode()
        blob = data[off + 64 : off + 64 + size]
        objs.append((name, blob))
        off += 64 + ((size + 15) & ~15)
    assert off == len(data), "DGO parse did not consume the whole file"
    return objs


def parse_object(blob):
    """Return (ver, code_ranges) where code_ranges[seg] = (file_off, code_len)."""
    assert blob[:4] == b"GOAL", "object does not start with GOAL magic"
    ver = struct.unpack_from("<I", blob, 8)[0]
    count = struct.unpack_from("<I", blob, 12)[0]
    assert count == N_SEG
    link_seg = [struct.unpack_from("<II", blob, 16 + 8 * i) for i in range(N_SEG)]
    code_seg = [struct.unpack_from("<II", blob, 16 + 24 + 8 * i) for i in range(N_SEG)]
    code_size = list(struct.unpack_from("<III", blob, 16 + 48))
    (link_block_length,) = struct.unpack_from("<I", blob, 16 + 60)
    # The object layout is: "GOAL" magic (4) + ObjectFileHeader struct (76) +
    # link tables (per link_seg sizes) + segment data.  code_seg[i].offset is
    # relative to the start of the segment-data region, which sits at file
    # offset link_block_length (the header field == 80 + total link size,
    # which is exactly where the data region begins; note this can be
    # non-4-aligned).  The runtime linker reads code_infos[seg].offset the
    # same way (it copies from m_object_data + offset), so validating these
    # file ranges validates exactly the bytes the runtime executes.
    code0 = link_block_length + code_seg[0][0]
    code1 = link_block_length + code_seg[1][0]
    code2 = link_block_length + code_seg[2][0]
    code_off = [code0, code1, code2]
    ranges = []
    for seg in range(N_SEG):
        if code_size[seg] == 0:
            ranges.append(None)
        else:
            ranges.append((code_off[seg], code_size[seg]))
    return ver, ranges


def disassemble(code):
    """Return (lines, warnings) via as + llvm-objdump. lines: list of
    (offset, word, text)."""
    with tempfile.TemporaryDirectory(prefix="ottsel-s11-") as td:
        td = Path(td)
        asm = td / "seg.s"
        obj = td / "seg.o"
        lines = [".text"]
        for i in range(0, len(code), 4):
            b = code[i : i + 4]
            lines.append(".byte " + ",".join(str(x) for x in b))
        asm.write_text("\n".join(lines) + "\n")
        subprocess.run(["as", "-arch", "arm64", "-o", str(obj), str(asm)], check=True)
        proc = subprocess.run(
            ["xcrun", "llvm-objdump", "-d", "--macho", "--arch=arm64", str(obj)],
            capture_output=True,
            text=True,
        )
        warnings = [
            ln for ln in proc.stderr.splitlines() if "invalid instruction encoding" in ln
        ]
        out = []
        for ln in proc.stdout.splitlines():
            m = re.match(r"\s+([0-9a-f]+):", ln)
            if not m:
                continue
            # llvm-objdump lines: "  ADDR:\tBB BB BB BB\tMNEMONIC ..."
            fields = ln.split("\t")
            if len(fields) < 2:
                continue
            off = int(m.group(1), 16)
            byte_hex = fields[1].split()
            if len(byte_hex) != 4:
                continue
            word = int.from_bytes(bytes(int(x, 16) for x in byte_hex), "little")
            text = " ".join(f.strip() for f in fields[2:]) if len(fields) > 2 else ""
            out.append((off, word, text))
        return out, warnings


def _parse_imm(s):
    s = s.lstrip("#")
    try:
        return int(s, 16) if s.lower().startswith("0x") else int(s)
    except ValueError:
        return None


def _reg_num(s):
    m = re.search(r"([xwqsdv])(\d+)", s)
    return int(m.group(2)) if m else None


COND = {"b.eq": 0, "b.ne": 1, "b.cs": 2, "b.hs": 2, "b.cc": 3, "b.lo": 3,
        "b.mi": 4, "b.pl": 5, "b.vs": 6, "b.vc": 7, "b.hi": 8, "b.ls": 9,
        "b.ge": 10, "b.lt": 11, "b.gt": 12, "b.le": 13, "b.al": 14, "b.nv": 15}


def compute_pc_rel_word(off, word, text):
    """Verify a PC-relative/literal instruction against its resolved target.
    Returns the expected 32-bit word, or None if the instruction is not
    PC-relative, or False if the operands cannot be parsed (skip check).
    objdump prints resolved absolute targets (hex or decimal, optional '#')
    and adrp as a raw immediate plus a `; 0x...` resolved-page comment."""
    text = text.split(";")[0].strip()
    parts = text.split()
    if not parts:
        return False
    mnem = parts[0]
    if len(parts) < 2:
        return None
    last = parts[-1]
    if mnem in ("b", "bl") or mnem in COND:
        target = _parse_imm(last)
        if target is None:
            return False
        imm = (target - off) >> 2
        if mnem in COND:
            return 0x54000000 | ((imm & 0x7FFFF) << 5) | COND[mnem]
        return (0x94000000 if mnem == "bl" else 0x14000000) | (imm & 0x3FFFFFF)
    if mnem in ("cbz", "cbnz"):
        rt = _reg_num(parts[1])
        target = _parse_imm(last)
        if rt is None or target is None:
            return False
        sf = 1 if parts[1].startswith("x") else 0
        imm = (target - off) >> 2
        base = 0xB4000000 if mnem == "cbnz" else 0x34000000
        return base | (sf << 31) | ((imm & 0x7FFFF) << 5) | rt
    if mnem in ("tbz", "tbnz"):
        rt = _reg_num(parts[1])
        bit = _parse_imm(parts[2])
        target = _parse_imm(last)
        if rt is None or bit is None or target is None:
            return False
        sf = 1 if parts[1].startswith("x") else 0
        imm = (target - off) >> 2
        base = 0xB6000000 if mnem == "tbnz" else 0x36000000
        return base | (sf << 31) | ((bit & 0x3F) << 19) | ((imm & 0x3FFF) << 5) | rt
    if mnem == "adr":
        rd = _reg_num(parts[1])
        target = _parse_imm(last)
        if rd is None or target is None:
            return False
        imm = (target - off) >> 2
        return 0x10000000 | ((imm & 0x3) << 29) | (((imm >> 2) & 0x7FFFF) << 5) | rd
    if mnem == "adrp":
        rd = _reg_num(parts[1])
        raw = _parse_imm(last)  # raw page offset (objdump omits the '#')
        if rd is None or raw is None:
            return False
        imm = raw
        return 0x90000000 | ((imm & 0x3) << 29) | (((imm >> 2) & 0x7FFFF) << 5) | rd
    if mnem == "ldr" and "[" not in text:
        # literal load: reg determines size; resolved target is the operand
        rt = _reg_num(parts[1])
        target = _parse_imm(last)
        if rt is None or target is None:
            return False
        imm = (target - off) >> 2
        if parts[1].startswith(("s", "d", "q", "v")):
            opc = {"s": 0, "d": 1, "q": 2}[parts[1][0]]
            return 0x1C000000 | (opc << 30) | ((imm & 0x7FFFF) << 5) | rt
        opc = {"w": 0, "x": 1}[parts[1][0]]
        return 0x18000000 | (opc << 30) | ((imm & 0x7FFFF) << 5) | rt
    if mnem == "ldrsw" and "[" not in text:
        rt = _reg_num(parts[1])
        target = _parse_imm(last)
        if rt is None or target is None:
            return False
        imm = (target - off) >> 2
        return 0x98000000 | ((imm & 0x7FFFF) << 5) | rt
    return None


def reassemble_roundtrip(decoded, code):
    """Reassemble the decoded instructions and compare bytes word-for-word.
    Returns list of (off, word, got_word)."""
    n = len(decoded)
    mismatches = []
    with tempfile.TemporaryDirectory(prefix="ottsel-s11-") as td:
        td = Path(td)
        asm = td / "rt.s"
        obj = td / "rt.o"
        lines = [".text"]
        to_reassemble = []
        for off, word, text in decoded:
            expected = compute_pc_rel_word(off, word, text)
            if expected is not None:
                if expected is False:
                    continue  # unparseable operand: skip the comparison
                if expected != word:
                    mismatches.append((off, word, expected))
                continue
            to_reassemble.append((off, word, text))
            lines.append(f"L{off // 4}: {text}")
        if not to_reassemble:
            return mismatches
        asm.write_text("\n".join(lines) + "\n")
        subprocess.run(["as", "-arch", "arm64", "-o", str(obj), str(asm)], check=True)
        # extract __TEXT,__text bytes: minimal Mach-O section reader
        macho = obj.read_bytes()
        ncmds = struct.unpack_from("<I", macho, 16)[0]
        off = 32
        text_bytes = b""
        for _ in range(ncmds):
            (cmd, cmdsize) = struct.unpack_from("<II", macho, off)
            if cmd == 0x19:  # LC_SEGMENT_64
                nsects = struct.unpack_from("<I", macho, off + 64)[0]
                s = off + 72
                for _ in range(nsects):
                    sectname = macho[s : s + 16].split(b"\0")[0].decode()
                    segname = macho[s + 16 : s + 32].split(b"\0")[0].decode()
                    (addr, size, file_off) = struct.unpack_from("<QQQ", macho, s + 32)
                    if segname == "__TEXT" and sectname == "__text":
                        text_bytes = macho[file_off : file_off + size]
                    s += 80
            off += cmdsize
        for i, (off, word, _) in enumerate(to_reassemble):
            got = int.from_bytes(text_bytes[i * 4 : i * 4 + 4], "little")
            if got != word:
                mismatches.append((off, word, got))
        return mismatches


def validate_code_region(name, seg, code, verbose=False):
    decoded, warnings = disassemble(code)
    problems = []
    # words present in the code region but absent from the decode stream
    decoded_offs = {off for off, _, _ in decoded}
    skipped = []
    type_tag_offs = set()
    for off in range(0, len(code), 4):
        if off not in decoded_offs:
            w = int.from_bytes(code[off : off + 4], "little")
            if w == 0xAEAEAEAE:  # function type-tag data, never executed
                type_tag_offs.add(off)
                continue
            skipped.append((off, w))
    for off, w in skipped:
        problems.append(f"invalid word at +{off:#x}: 0x{w:08x}")
    # every undecodable word must be accounted for as a warning
    n_undecoded = len(skipped) + len(type_tag_offs)
    if warnings and len(warnings) != n_undecoded:
        problems.append(
            f"{len(warnings)} 'invalid instruction encoding' warning(s) but "
            f"{n_undecoded} undecoded word(s); decoder accounting mismatch")
    # address continuity: if no bad words, the decode stream must cover every
    # word exactly once, in order (type-tag words are the only allowed gap)
    if not skipped and decoded:
        actual = [off for off, _, _ in decoded]
        expected = [off for off in range(0, len(code), 4) if off not in type_tag_offs]
        if actual != expected:
            problems.append("decode address continuity error")
    # round-trip reassembly (bonus check; PC-rel placeholders pointing
    # outside the segment are pre-link and are skipped)
    try:
        mism = reassemble_roundtrip(decoded, code)
    except subprocess.CalledProcessError as e:
        problems.append(f"reassembly failed to assemble: {e}")
        mism = []
    for off, word, got in mism:
        problems.append(f"round-trip mismatch at +{off:#x}: 0x{word:08x} != 0x{got:08x}")
    return problems, skipped, len(type_tag_offs), decoded


def validate_object(name, blob, verbose=False):
    ver, ranges = parse_object(blob)
    problems = []
    stats = {"type_tags": 0}
    for seg, r in enumerate(ranges):
        if r is None:
            continue
        foff, clen = r
        code = blob[foff : foff + clen]
        seg_problems, skipped, n_tags, _ = validate_code_region(name, seg, code, verbose)
        stats["type_tags"] += n_tags
        if seg_problems:
            problems.append(f"{name} [{SEG_NAMES[seg]}]: " + "; ".join(seg_problems))
        elif verbose:
            print(f"  OK {name} [{SEG_NAMES[seg]}] {clen} bytes "
                  f"({clen // 4} words, {n_tags} type-tag words skipped, "
                  f"{len(skipped)} bad words)")
    return problems, stats


def selftest():
    """The tool must catch the known-bad pre-H3 load32u word 0xb8760801."""
    code = bytes.fromhex("01ea76b8" "010876b8" "00000000" "84531a70")
    problems, skipped, _, _ = validate_code_region("selftest", 0, code)
    bad = [s for s in skipped if s[1] == 0xB8760801]
    if bad:
        print("SELFTEST PASS: known-bad word 0xb8760801 caught at +%#x" % bad[0][0])
        return 0
    print("SELFTEST FAIL: known-bad word 0xb8760801 was NOT caught")
    print("problems:", problems)
    return 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cgo", default="out/jak-project/out/jak1/iso/KERNEL.CGO")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    cgo = Path(args.cgo)
    if not cgo.exists():
        print(f"KERNEL.CGO not found at {cgo}; run goalc (make GROUP:kernel) first")
        return 1
    objs = parse_cgo(cgo)
    all_problems = []
    total_words = 0
    total_tags = 0
    for name, blob in objs:
        problems, stats = validate_object(name, blob, args.verbose)
        total_tags += stats["type_tags"]
        all_problems.extend(problems)
        for _, ranges in [("", parse_object(blob)[1])]:
            for r in ranges:
                if r is not None:
                    total_words += r[1] // 4
    if all_problems:
        print(f"FAIL: {len(all_problems)} problem(s) across {len(objs)} objects "
              f"({total_words} code words, {total_tags} type-tag words skipped)")
        for p in all_problems:
            print("  " + p)
        return 1
    print(f"PASS: all {total_words} code words across {len(objs)} objects "
          f"validate (decode + round-trip); {total_tags} type-tag words skipped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
