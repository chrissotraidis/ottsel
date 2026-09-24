#!/usr/bin/env python3
"""Census the whole genuine Jak 1 code corpus against the A1.1 signed-module
emitter, without a compiler, a build, or extra disk headroom.

This is a faithful pure-Python port of
out/jak-project/tools/ottsel_a1_1/a11_module_emitter.h::parse_signed_module
(the accept/reject decision only; no code is emitted). It walks every
*.CGO/*.DGO container in out/jak1/iso, maps each member body by SHA-256 to a
loose out/jak1/obj/*.o (code) or *.go (art) file, and reports which code
members the current emitter accepts.

Read-only: nothing is written except the report.

Usage:
  python3 scripts/a11-corpus-census.py            # summary
  python3 scripts/a11-corpus-census.py --json     # full per-member detail
  python3 scripts/a11-corpus-census.py --prefix GAME.CGO=60
"""

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import struct
import sys
from collections import Counter, defaultdict

FUNCTION_TYPE = 0x1BFEC4
TYPE_WHITELIST = {"function", "string", "kernel-context", "state"}
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OBJDIR = os.path.join(REPO, "out", "jak-project", "out", "jak1", "obj")
ISODIR = os.path.join(REPO, "out", "jak-project", "out", "jak1", "iso")
# Mirrors scripts/emit-signed-module-arena.py ARENA_SIZE and goal_constants.h
# EE_MAIN_MEM_SIZE. MEMORY_LAYOUT is where the loader's heap constants live.
ARENA_SIZE = 128 * 1024 * 1024
MEMORY_LAYOUT = os.path.join(REPO, "out", "jak-project", "game", "kernel",
                             "common", "memory_layout.h")


class EmitError(Exception):
    def __init__(self, msg, **detail):
        super().__init__(msg)
        self.detail = detail


def fits(p, n, end):
    return p <= end and n <= end - p


def u32(b, p):
    if not fits(p, 4, len(b)):
        raise EmitError("truncated object word")
    return struct.unpack_from("<I", b, p)[0]


def parse_signed_module(b, function_type=FUNCTION_TYPE, release_no_debug=None,
                        enforce_type_whitelist=True, allow_ldr_q=False,
                        enforce_methods=True, allow_data_only_main=False,
                        allow_code_pointer=False):
    """Port of parse_signed_module. Raises EmitError exactly where C++ throws."""
    if not function_type or (function_type & 3):
        raise EmitError("invalid function Type identity")
    if len(b) > 0xFFFFFFFF:
        raise EmitError("object exceeds v3 size range")
    if len(b) < 80:
        raise EmitError("truncated header")
    if release_no_debug is None:
        release_no_debug = u32(b, 52) != 0
    if u32(b, 4) != 1 or u32(b, 8) != 3 or u32(b, 12) != 3:
        raise EmitError("unsupported object version/segments")
    link_end = u32(b, 76)
    if link_end < 80 or link_end > len(b):
        raise EmitError("invalid link block")
    segs = []   # (base, size, text, loaded)
    links = []  # (begin, end)
    for s in range(3):
        base = link_end + u32(b, 40 + s * 8)
        size = u32(b, 44 + s * 8)
        text = u32(b, 64 + s * 4)
        begin = 4 + u32(b, 16 + s * 8)
        length = u32(b, 20 + s * 8)
        if (begin < 80 or not length or not fits(begin, length, link_end)
                or not fits(base, size, len(b)) or base > 0xFFFFFFFF
                or text > size or text % 4):
            raise EmitError("invalid segment bounds/layout")
        for t in range(s):
            ob, ob_len = links[t]
            if begin < ob + ob_len and ob < begin + length:
                raise EmitError("overlapping link tables")
            o_base, o_size, _, _ = segs[t]
            if size and o_size and base < o_base + o_size and o_base < base + size:
                raise EmitError("overlapping segments")
        segs.append((base, size, text, True))
        links.append((begin, begin + length))
    if not release_no_debug and segs[1][1]:
        raise EmitError("unsupported nonempty debug segment")
    if release_no_debug:
        segs[1] = (segs[1][0], segs[1][1], segs[1][2], False)
    # A data-only main segment is a declaration-only object's static-data area.
    # It is accepted only as a loaded template: an unloaded one would drop the
    # data its own code addresses, so that stays rejected with the guard off.
    if (not allow_data_only_main and segs[0][1] and not segs[0][2]
            and segs[0][3]):
        raise EmitError("unsupported data-only main segment")
    if segs[2][2] < 8:
        raise EmitError("missing top-level code")

    top_tag = False
    for s in range(3):
        base, size, text, loaded = segs[s]
        p, end = links[s]
        occupied = []

        def claim(patch, width, size=size):
            if patch % 4 or not fits(patch, width, size):
                raise EmitError("invalid patch bounds/alignment")
            for a, bnd in occupied:
                if patch < bnd and a < patch + width:
                    raise EmitError("overlapping relocations")
            occupied.append((patch, patch + width))

        terminated = False
        while p < end:
            kind = b[p]
            p += 1
            if not kind:
                if p != end:
                    raise EmitError("trailing link bytes")
                terminated = True
                break
            if kind in (1, 2):
                start = p
                while p < end and b[p]:
                    p += 1
                if p == end or p == start or p - start >= 256:
                    raise EmitError("invalid symbol/type name")
                name_bytes = b[start:p]
                p += 1
                if any(c >= 127 for c in name_bytes):
                    raise EmitError("unsupported non-ASCII symbol/type name")
                name = name_bytes.decode("ascii")
                methods = 0
                if kind == 2:
                    if p == end:
                        raise EmitError("truncated method count")
                    methods = b[p]
                    p += 1
                    if ((enforce_methods and methods != 9)
                            or (enforce_type_whitelist and name not in TYPE_WHITELIST)):
                        raise EmitError("unsupported type/method count: " + name,
                                        type_name=name, methods=methods)
                if not fits(p, 4, end):
                    raise EmitError("truncated slot count")
                count = u32(b, p)
                p += 4
                if count > (end - p) // 4:
                    raise EmitError("truncated slots/count overflow")
                for _ in range(count):
                    patch = u32(b, p)
                    p += 4
                    claim(patch, 4)
                    if kind == 1:
                        if patch < text:
                            raise EmitError("symbol relocation in signed text")
                    elif patch < text:
                        if name != "function" or patch + 4 >= text:
                            raise EmitError("non-function type in signed text",
                                            type_name=name)
                        if patch == 0 and s == 2:
                            top_tag = True
            elif kind == 4:
                # A distance record rewrites an ADRP/consumer instruction pair,
                # so it can only live in a segment that carries signed text.
                if not text:
                    raise EmitError("distance record in textless segment")
                if not fits(p, 13, end):
                    raise EmitError("truncated distance32 record")
                target_seg = b[p]
                current = u32(b, p + 1)
                target = u32(b, p + 5)
                patch = u32(b, p + 9)
                p += 13
                if (target_seg >= 3 or not segs[target_seg][1]
                        or target >= segs[target_seg][1] or current != patch
                        or not fits(patch, 8, text)):
                    raise EmitError("invalid distance32 offsets/target")
                claim(patch, 8)
                adrp = u32(b, base + patch)
                add = u32(b, base + patch + 4)
                address = (add & 0xFFC00000) == 0x91000000
                scalar_float = (add & 0xFFC00000) == 0xBD400000
                # size=00/opc=11 is a 128-bit LDR Q whose imm12 is scaled by
                # sixteen, not the eight-byte LDR D class.
                ldr_q = allow_ldr_q and (add & 0xFFC00000) == 0x3DC00000
                if ((adrp & 0x9F000000) != 0x90000000
                        or not (address or scalar_float or ldr_q)
                        or ((add >> 5) & 31) != (adrp & 31) or (adrp & 31) == 31
                        or (address and (add & 31) == 31)):
                    raise EmitError("unsupported distance32 instruction pair",
                                    addr_op=add & 0xFFC00000, adrp=adrp, add=add)
                d_base, d_size, d_text, d_loaded = segs[target_seg]
                if loaded and not d_loaded and scalar_float:
                    raise EmitError("unsupported scalar load from omitted debug segment")
                if scalar_float and ((target & 3) or target < d_text
                                     or not fits(target, 4, d_size)):
                    raise EmitError("invalid scalar LDR target")
                if ldr_q and (target < d_text or ((target - d_text) & 15)
                              or not fits(target, 16, d_size)):
                    raise EmitError("invalid LDR Q target")
            elif kind == 5:
                if not fits(p, 8, end):
                    raise EmitError("truncated pointer record")
                patch = u32(b, p)
                target = u32(b, p + 4)
                p += 8
                claim(patch, 4)
                if patch < text:
                    raise EmitError("pointer patch in signed text")
                if (target >= size if allow_code_pointer
                        else target < text or target >= size):
                    raise EmitError("pointer target outside static data")
            else:
                raise EmitError("unsupported relocation kind %d" % kind)
        if not terminated:
            raise EmitError("missing link terminator")
    if not top_tag:
        raise EmitError("missing top-level function tag")


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def scan_distance32(b):
    """Tolerant walker: tally every distance32 ADRP consumer class in an object,
    including records in modules the strict parser rejects before reaching them.
    Returns (consumer_opcode_counts, issue_counts)."""
    counts, issues = Counter(), Counter()
    if len(b) < 80:
        return counts, issues
    try:
        link_end = u32(b, 76)
    except EmitError:
        return counts, issues
    if link_end < 80 or link_end > len(b):
        return counts, issues
    for s in range(3):
        try:
            seg_base = link_end + u32(b, 40 + s * 8)
            text = u32(b, 64 + s * 4)
            p = 4 + u32(b, 16 + s * 8)
            end = p + u32(b, 20 + s * 8)
        except EmitError:
            issues["bad segment header"] += 1
            continue
        if not (80 <= p <= end <= link_end):
            issues["bad link table"] += 1
            continue
        while p < end:
            kind = b[p]
            p += 1
            if not kind:
                break
            if kind in (1, 2):
                q = p
                while q < end and b[q]:
                    q += 1
                if q == end:
                    issues["unterminated name"] += 1
                    break
                p = q + 1
                if kind == 2:
                    p += 1
                if p + 4 > end:
                    issues["truncated slot count"] += 1
                    break
                p += 4 + 4 * u32(b, p)
            elif kind == 4:
                if p + 13 > end:
                    issues["truncated distance32"] += 1
                    break
                patch = u32(b, p + 9)
                if fits(patch, 8, text):
                    adrp = u32(b, seg_base + patch)
                    add = u32(b, seg_base + patch + 4)
                    counts[add & 0xFFC00000] += 1
                    if (adrp & 0x9F000000) != 0x90000000:
                        issues["non-ADRP first instruction"] += 1
                else:
                    issues["distance32 patch outside text"] += 1
                p += 13
            elif kind == 5:
                if p + 8 > end:
                    issues["truncated pointer"] += 1
                    break
                p += 8
            else:
                issues["unsupported kind %d" % kind] += 1
                break
    return counts, issues


def walk_kind5(b):
    """kind-5 pointer records as (segment, text, size, patch, target)."""
    return [(s, text, size, r[0], r[1])
            for (s, k, text, size, r) in walk_link_records(b) if k == 5]


def walk_link_records(b):
    """Tolerant walk of all three link tables, in record order.

    Unlike parse_signed_module this never rejects a record it can size, so it
    reaches records sitting after an earlier complaint. Yields
    (segment, kind, text, size, payload): payload is (name, methods, patches)
    for kinds 1/2, (target_seg, current, target, patch) for kind 4, and
    (patch, target) for kind 5. A segment stops at the first record it cannot
    size; the walk returns [] when the header itself is unreadable.
    """
    out = []
    if len(b) < 80:
        return out
    try:
        link_end = u32(b, 76)
    except EmitError:
        return out
    if link_end < 80 or link_end > len(b):
        return out
    for s in range(3):
        try:
            size = u32(b, 44 + s * 8)
            text = u32(b, 64 + s * 4)
            p = 4 + u32(b, 16 + s * 8)
            end = p + u32(b, 20 + s * 8)
        except EmitError:
            continue
        if not (80 <= p <= end <= link_end):
            continue
        while p < end:
            kind = b[p]
            p += 1
            if not kind:
                break
            if kind in (1, 2):
                q = p
                while q < end and b[q]:
                    q += 1
                if q == end:
                    break
                name = b[p:q].decode("latin1")
                p = q + 1
                methods = None
                if kind == 2:
                    if p == end:
                        break
                    methods = b[p]
                    p += 1
                if p + 4 > end:
                    break
                count = u32(b, p)
                p += 4
                if count > (end - p) // 4:
                    break
                patches = [u32(b, p + 4 * i) for i in range(count)]
                p += 4 * count
                out.append((s, kind, text, size, (name, methods, patches)))
            elif kind == 4:
                if p + 13 > end:
                    break
                out.append((s, 4, text, size,
                            (b[p], u32(b, p + 1), u32(b, p + 5), u32(b, p + 9))))
                p += 13
            elif kind == 5:
                if p + 8 > end:
                    break
                out.append((s, 5, text, size, (u32(b, p), u32(b, p + 4))))
                p += 8
            else:
                break
    return out


CODE_TARGET_INVARIANTS = (
    ("inside_code_region",
     "every rejected target is inside the code region"),
    ("four_aligned",
     "target and text are 4-aligned (implied by entry_convention)"),
    ("entry_convention",
     "target is 8k+4 and text is 8-aligned (entry convention)"),
    ("writable_slot",
     "every rejected slot is a 4-aligned data slot"))


def code_target_violations(text, size, patch, target):
    """The facts a widened data->code pointer path relies on, for one kind-5
    record the narrow emitter rejects: a target outside [text, size).

    `four_aligned` is implied by `entry_convention` -- an unaligned target or
    text can never satisfy target%8==4 and text%8==0 -- so it is the coarser
    guard and cannot fail on its own. links_selftest() proves that by
    exhaustion over every (target%8, text%8) pair.
    """
    if not (target < text or target >= size):
        raise ValueError("target in static data is not a rejected record")
    bad = set()
    if not target < text:
        bad.add("inside_code_region")
    if target % 4 or text % 4:
        bad.add("four_aligned")
    if target % 8 != 4 or text % 8:
        bad.add("entry_convention")
    if patch % 4 or patch < text:
        bad.add("writable_slot")
    return bad


def kind5_report(index):
    """Report the kind-5 pointer records the narrow Gkernel-scoped emitter
    path rejects: a target below `text`, i.e. inside the code region of the
    module itself rather than in its static data. Fails closed on the
    structural facts a widened code-target path depends on."""
    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    tot = Counter()
    per_member = Counter()
    residual = defaultdict(list)
    checks = Counter()
    invariants = CODE_TARGET_INVARIANTS
    for cname in conts:
        data, members, _ = read_container(os.path.join(ISODIR, cname))
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            if len(body) < 80 or u32(body, 4) != 1:
                continue
            if not pick_member(index.get(sha256_bytes(body), []), ".o", m["name"]):
                continue
            recs = walk_kind5(body)
            if not recs:
                continue
            tot["members_with_kind5"] += 1
            for (_, text, size, patch, target) in recs:
                tot["records"] += 1
                if target < text or target >= size:
                    tot["target_outside_static_data"] += 1
                    tot["tagged_target_low_bits_%d" % (target & 7)] += 1
                    if target < text:
                        tot["target_in_code_region"] += 1
                    else:
                        tot["target_at_or_past_size"] += 1
                    if patch >= text:
                        tot["patch_in_static_data"] += 1
                    per_member[m["name"]] += 1
                    for key in code_target_violations(text, size, patch, target):
                        checks[key] += 1
                else:
                    tot["target_in_static_data"] += 1
                    tot["untagged_target_low_bits_%d" % (target & 7)] += 1
            policy = u32(body, 52) != 0
            try:
                parse_signed_module(body, release_no_debug=policy,
                                    enforce_type_whitelist=False,
                                    enforce_methods=False, allow_ldr_q=True)
            except EmitError as e:
                if str(e).startswith("pointer"):
                    residual[m["name"]].append(cname)
    print("kind-5 pointer records over every container code member:")
    for key in sorted(tot):
        print("  %-32s %d" % (key, tot[key]))
    n_res = sum(len(v) for v in residual.values())
    print("members left failing only on the pointer path (after authenticated "
          "types + LDR Q): %d" % n_res)
    for name in sorted(residual):
        print("  %-22s %s" % (name, sorted(residual[name])))
    print("members carrying a rejected data->code pointer record:")
    for name in sorted(per_member, key=lambda n: (-per_member[n], n)):
        print("  %-22s %d" % (name, per_member[name]))
    print("code-target invariants (fail closed; exit 1 on any violation):")
    for key, label in invariants:
        print("  %s %s" % ("FAIL" if checks[key] else "PASS", label))
    return 1 if any(checks[key] for key, _ in invariants) else 0


def links_selftest(index):
    """Negative control for the code-target invariants in kind5_report.

    Unit level: one synthetic rejected record per isolable invariant, the
    four_aligned/entry_convention implication, an exhaustive 8x8 residue
    sweep, and both boundaries of the inside_code_region test. End to end:
    rewrite one genuine rejected record in the real corpus to violate a chosen
    invariant and require kind5_report to name that invariant and exit 1.
    Without this the PASS block above is an unfalsified claim.
    """
    bad = 0
    reached = set()
    print("code-target invariants: single-violation control")
    cases = (("clean rejected code target", 0x1000, 0x2000, 0x1000, 0x0ff4,
              set()),
             ("target past module end", 0x1000, 0x2000, 0x1000, 0x2004,
              {"inside_code_region"}),
             ("target off the entry convention", 0x1000, 0x2000, 0x1000,
              0x0ff0, {"entry_convention"}),
             ("patch is not a data slot", 0x1000, 0x2000, 0x0800, 0x0ff4,
              {"writable_slot"}),
             ("target and text unaligned", 0x1002, 0x2000, 0x1004, 0x0ff2,
              {"four_aligned", "entry_convention"}))
    for label, text, size, patch, target, want_set in cases:
        got = code_target_violations(text, size, patch, target)
        ok = got == want_set
        bad += 0 if ok else 1
        reached |= got
        print("  %s %-32s -> %s" % ("ok  " if ok else "FAIL", label,
                                    ",".join(sorted(got)) or "clean"))
    missing = {k for k, _ in CODE_TARGET_INVARIANTS} - reached
    bad += 0 if not missing else 1
    print("  %s every invariant reached by the unit cases%s" % (
        "ok  " if not missing else "FAIL",
        "" if not missing else " (missing " + ",".join(sorted(missing)) + ")"))
    print("code-target invariants: 8x8 (target%8, text%8) residue sweep")
    sweep_bad = 0
    for t8 in range(8):
        for x8 in range(8):
            text = 0x1000 + x8
            target = 0x0ff0 + t8
            got = code_target_violations(text, 0x2000, 0x1008, target)
            want = set()
            if t8 % 4 or x8 % 4:
                want.add("four_aligned")
            if t8 != 4 or x8:
                want.add("entry_convention")
            if got != want or ("four_aligned" in got
                               and "entry_convention" not in got):
                sweep_bad += 1
    bad += 0 if not sweep_bad else 1
    print("  %s 64 residue pairs; four_aligned never fails without "
          "entry_convention" % ("ok  " if not sweep_bad else "FAIL"))
    print("code-target invariants: inside_code_region boundaries")
    edges = ((0x1000, 0x2000, 0x0ffc, False), (0x1000, 0x2000, 0x2000, True),
             (0x1000, 0x2000, 0x2004, True))
    edge_bad = 0
    for text, size, target, expect in edges:
        got = code_target_violations(text, size, 0x1000, target)
        if ("inside_code_region" in got) != expect:
            edge_bad += 1
    try:
        code_target_violations(0x1000, 0x2000, 0x1000, 0x1ffc)
    except ValueError:
        pass
    else:
        edge_bad += 1           # an in-static-data record is out of contract
    bad += 0 if not edge_bad else 1
    print("  %s just below text clean; at/past size flagged; in-data "
          "out of contract%s" % ("ok  " if not edge_bad else "FAIL",
                                 "" if not edge_bad else " (mismatch)"))
    print("code-target invariants: end-to-end injection into the real corpus")
    real = walk_kind5
    labels = dict(CODE_TARGET_INVARIANTS)
    for key, text, size, patch, target in (
            ("inside_code_region", 0x1000, 0x2000, 0x1000, 0x2004),
            ("entry_convention", 0x1000, 0x2000, 0x1000, 0x0ff0),
            ("writable_slot", 0x1000, 0x2000, 0x0800, 0x0ff4)):
        state = {"done": False}
        def wrapped(b, _real=real, _s=state,
                    _r=(text, size, patch, target)):
            recs = _real(b)
            if not _s["done"]:
                for i, (s, t, z, p, g) in enumerate(recs):
                    if g < t and p % 4 == 0 and p >= t:
                        recs[i] = (s, _r[0], _r[1], _r[2], _r[3])
                        _s["done"] = True
                        break
            return recs
        globals()["walk_kind5"] = wrapped
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                code = kind5_report(index)
        finally:
            globals()["walk_kind5"] = real
        out = buf.getvalue()
        named = ("FAIL " + labels[key]) in out
        only = out.count("  FAIL ") == 1
        ok = code == 1 and named and only
        bad += 0 if ok else 1
        print("  %s injected %-22s exit=%d names=%s alone=%s" % (
            "ok  " if ok else "FAIL", key, code,
            "yes" if named else "no", "yes" if only else "no"))
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = kind5_report(index)
    baseline_ok = code == 0 and "\n  FAIL " not in buf.getvalue()
    bad += 0 if baseline_ok else 1
    print("  %s unmodified real corpus exit=%d (all PASS)" % (
        "ok  " if baseline_ok else "FAIL", code))
    print("code-target invariants: SELFTEST %s" % ("PASS" if not bad else "FAIL"))
    return 1 if bad else 0


def types_report(index):
    """The complete kind-2 type table over every container code member.

    The emitter must authenticate each type pointer by (name, methods) and the
    runtime guard must allow it, but the strict parser reports only whichever
    pair fails first in a member, so its histogram undercounts pairs and cannot
    say whether the patch word lies in signed code or in static data. Code-side
    patches are the binding constraint: genuine linking writes every one of
    them as the single immutable function Type, while data-side patches resolve
    per name through intern_type_from_c.

    It also proves the relaxed data-side guard needs no link-order coordination:
    since every type name is requested at a single methods count, the runtime's
    "more methods than the existing type" assert cannot fire, in any order.
    """
    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    records = Counter()
    members = defaultdict(set)
    region = defaultdict(Counter)
    code_records = Counter()
    code_members = defaultdict(set)
    with_types = with_relax = 0
    for cname in conts:
        data, cont_members, _ = read_container(os.path.join(ISODIR, cname))
        for m in cont_members:
            body = data[m["off"]:m["off"] + m["size"]]
            if len(body) < 80 or u32(body, 4) != 1:
                continue
            if not pick_member(index.get(sha256_bytes(body), []), ".o", m["name"]):
                continue
            seen = Counter()
            relax = False
            for (_, kind, text, _, payload) in walk_link_records(body):
                if kind != 2:
                    continue
                name, methods, patches = payload
                key = (name, methods)
                seen[key] += len(patches)
                if name not in TYPE_WHITELIST or methods != 9:
                    relax = True
                for patch in patches:
                    if patch < text:
                        region[key]["code"] += 1
                        code_records[key] += 1
                        code_members[key].add(m["name"])
                    else:
                        region[key]["data"] += 1
            if seen:
                with_types += 1
            if relax:
                with_relax += 1
            for key, n in seen.items():
                records[key] += n
                members[key].add(m["name"])
    print("kind-2 type records over every container code member "
          "(tolerant whole-member walk):")
    print("  %-46s %d" % ("members carrying type records", with_types))
    print("  %-46s %d" % ("type records", sum(records.values())))
    print("  %-46s %d" % ("distinct (name, methods) pairs", len(records)))
    print("  %-46s %d" % ("members needing the type guard relaxed", with_relax))
    print()
    print("  %-32s %7s %6s %6s %7s" %
          ("(name, methods)", "records", "code", "data", "members"))
    for key, n in sorted(records.items(), key=lambda kv: (-kv[1], kv[0])):
        print("  %-32s %7d %6d %6d %7d" %
              ("%s/%d" % key, n, region[key]["code"], region[key]["data"],
               len(members[key])))
    print()
    print("pairs with a patch word inside signed code, which genuine linking "
          "writes only as the immutable function Type:")
    if not code_records:
        print("  none")
    for key, n in sorted(code_records.items(), key=lambda kv: (-kv[1], kv[0])):
        print("  %-32s %7d records  %d members  e.g. %s" %
              ("%s/%d" % key, n, len(code_members[key]),
               sorted(code_members[key])[:6]))
    # The kind-2 relaxation takes each object's own methods byte for every pair
    # except the four pinned bootstrap types, so the only way it can break
    # intern_type_from_c (klink.cpp:216 -> kscheme.cpp:1176, which asserts when
    # size_of_type(existing) < size_of_type(requested)) is if one type name is
    # requested at two different method counts in two modules. So the name, not
    # the (name, methods) pair, has to be measured as a primary key for its count.
    methods_by_name = defaultdict(set)
    for name, methods in records:
        methods_by_name[name].add(methods)
    multi = {n: sorted(v) for n, v in methods_by_name.items() if len(v) > 1}
    distribution = Counter(methods for _, methods in records)
    print()
    print("methods byte per type name (the relaxation's ordering safety):")
    print("  %-46s %d" % ("distinct type names", len(methods_by_name)))
    print("  %-46s %s" % ("methods value -> #names",
                           dict(sorted(distribution.items()))))
    print("  %-46s %s" % ("pinned four measured at",
                           {n: sorted(methods_by_name[n])
                            for n in sorted(TYPE_WHITELIST) if n in methods_by_name}))
    print("  %-46s %s" % ("names requested at >1 methods count", multi or "none"))
    checks = [("type name is a primary key for its count (no ordering hazard)",
               not multi),
              ("every pair carries a concrete count (no 0/1 fallback)",
               not (set(distribution) & {0, 1})),
              ("the pinned four bootstrap types each measure at 9",
               all(methods_by_name.get(n) == {9} for n in TYPE_WHITELIST))]
    for label, ok in checks:
        print("  %-4s %s" % ("PASS" if ok else "FAIL", label))
    return 0 if all(ok for _, ok in checks) else 1


def relax_report(index):
    """Accept count under the maintained emitter policy. All four
    generalizations are now implemented in the working tree: authenticated type
    identity, the validated 16-byte SIMD LDR Q consumer, the loaded data-only
    main segment, and kind-5 pointer targets in the code region. This is still
    a static port of the emitter, so nothing is compiled."""
    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    code = ok = 0
    hist = Counter()
    names = defaultdict(set)
    for cname in conts:
        data, members, _ = read_container(os.path.join(ISODIR, cname))
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            if len(body) < 80 or u32(body, 4) != 1:
                continue
            if not pick_member(index.get(sha256_bytes(body), []), ".o", m["name"]):
                continue
            code += 1
            try:
                parse_signed_module(body, release_no_debug=u32(body, 52) != 0,
                                    enforce_type_whitelist=False,
                                    enforce_methods=False, allow_ldr_q=True,
                                    allow_data_only_main=True,
                                    allow_code_pointer=True)
                ok += 1
            except EmitError as e:
                hist[str(e)] += 1
                names[str(e)].add(m["name"])
    print("PORT OF THE MAINTAINED EMITTER (not compiled): all four "
          "generalizations applied")
    print("  %d/%d code members would emit; residual %d" % (ok, code, code - ok))
    for msg, n in hist.most_common():
        print("  %5d  %s" % (n, msg))
        print("         %s" % sorted(names[msg]))


ATTRIBUTION = (
    ("type", dict(enforce_type_whitelist=False, enforce_methods=False)),
    ("ldr_q", dict(allow_ldr_q=True)),
    ("seg0", dict(allow_data_only_main=True)),
    ("pointer", dict(allow_code_pointer=True)),
)


def shape(bits):
    return "+".join(n for i, (n, _) in enumerate(ATTRIBUTION) if bits >> i & 1) or "none"


def attribution_report(index):
    """Per-restriction attribution across the 16-subset relaxation lattice.

    Every relaxation only disables a guard, so acceptance is monotone by
    construction and the whole corpus reaches 872/872 at the full set. That
    joint count cannot localize an overlay mistake, so this reports two
    separable predictions: the cumulative accept count at each subset, which
    is checkable one fix at a time, and each failing member's minimal
    accepting set, which names exactly which members one fix must flip and
    which members it must leave alone. Pure prediction: nothing is compiled.
    """
    def verdict(body, bits):
        flags = dict(release_no_debug=u32(body, 52) != 0)
        for i, (_, extra) in enumerate(ATTRIBUTION):
            if bits >> i & 1:
                flags.update(extra)
        try:
            parse_signed_module(body, **flags)
            return None
        except EmitError as e:
            return str(e)

    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    bodies = []
    for cname in conts:
        data, members, _ = read_container(os.path.join(ISODIR, cname))
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            if len(body) < 80 or u32(body, 4) != 1:
                continue
            if not pick_member(index.get(sha256_bytes(body), []), ".o", m["name"]):
                continue
            bodies.append((cname[:-4], m["name"], body))
    bits_all = list(range(16))
    accept_total = Counter()
    minimal = Counter()
    members_of = defaultdict(list)
    base_hist = Counter()
    monotone = closure = True
    multi_minimal = []
    for cname, name, body in bodies:
        base = verdict(body, 0)
        if base is None:
            for bits in bits_all:
                accept_total[bits] += 1
            continue
        base_hist[base] += 1
        table = {0: base}
        for bits in bits_all[1:]:
            table[bits] = verdict(body, bits)
        for bits in bits_all:
            if table[bits] is None:
                accept_total[bits] += 1
        accepting = {b for b in bits_all if table[b] is None}
        minimal_sets = [b for b in accepting
                        if not any(o != b and o & b == o for o in accepting)]
        for bits in bits_all:
            supersets = [o for o in bits_all if o & bits == bits]
            if table[bits] is None and any(table[o] is not None for o in supersets):
                monotone = False
            if (table[bits] is None) != any(o & bits == o for o in minimal_sets):
                closure = False
        if not minimal_sets:
            closure = False
        if len(minimal_sets) > 1:
            multi_minimal.append((name, sorted(shape(b) for b in minimal_sets)))
        for bits in minimal_sets:
            minimal[bits] += 1
            members_of[bits].append(cname + "/" + name)
    print("PREDICTION (not compiled): per-restriction attribution over 16 subsets")
    print("  %-46s %d" % ("code members", len(bodies)))
    print("  %-46s %s" % ("restriction bit order", shape(15)))
    print("  %-46s %d" % ("accept with no relaxation (pre-generalization "
                          "emitter baseline)",
                          accept_total[0]))
    print("  %-46s %d" % ("accept with all four (must equal --relax-all)",
                          accept_total[15]))
    print()
    print("  %-46s %6s %6s" % ("subset (cumulative)", "accept", "newly"))
    for bits in sorted(bits_all, key=lambda v: (bin(v).count("1"), v)):
        print("  %-46s %6d %6d" % (shape(bits), accept_total[bits],
                                   accept_total[bits] - accept_total[0]))
    print()
    print("minimal accepting set per failing member (causal attribution):")
    for bits in sorted(minimal, key=lambda v: (bin(v).count("1"), v)):
        print("  %-46s %6d" % (shape(bits), minimal[bits]))
        print("         %s" % sorted(members_of[bits])[:8])
    print("  %-46s %s" % ("members with more than one minimal set",
                          multi_minimal[:4] or "none"))
    print()
    print("first rejection with no relaxation (which guard fires on the corpus):")
    for msg, n in base_hist.most_common():
        print("  %5d  %s" % (n, msg))
    checks = [("all four relaxations accept the whole corpus (agrees with "
               "--relax-all)", accept_total[15] == len(bodies)),
              ("accepting a member implies any superset accepts it (monotone)",
               monotone),
              ("every failing member's verdict is exactly the upward closure "
               "of its minimal sets", closure)]
    for label, ok in checks:
        print("  %-4s %s" % ("PASS" if ok else "FAIL", label))
    return 0 if all(ok for _, ok in checks) else 1


def aligned16(value):
    return (value + 15) & ~15


class LayoutExpression:
    """Recursive-descent evaluator for the restricted memory_layout.h subset.

    Grammar, lowest precedence first: C ternary (`c ? a : b`), then + -, then
    * /, then parenthesised integer literals. This replaces eval so the header
    text is parsed, never executed.
    """

    def __init__(self, text):
        self.text = text
        self.pos = 0

    def parse(self):
        value = self.ternary()
        self.space()
        if self.pos != len(self.text):
            raise ValueError("trailing layout expression " + self.text)
        return value

    def space(self):
        while self.pos < len(self.text) and self.text[self.pos] == " ":
            self.pos += 1

    def take(self, char):
        self.space()
        if self.text.startswith(char, self.pos):
            self.pos += len(char)
            return True
        return False

    def ternary(self):
        value = self.additive()
        if self.take("?"):
            taken = self.ternary()
            if not self.take(":"):
                raise ValueError("layout ternary missing ':' in " + self.text)
            other = self.ternary()
            return taken if value else other
        return value

    def additive(self):
        value = self.multiplicative()
        while True:
            if self.take("+"):
                value += self.multiplicative()
            elif self.take("-"):
                value -= self.multiplicative()
            else:
                return value

    def multiplicative(self):
        value = self.primary()
        while True:
            if self.take("*"):
                value *= self.primary()
            elif self.take("/"):
                divisor = self.primary()
                if not divisor:
                    raise ValueError("layout division by zero in " + self.text)
                value //= divisor
            else:
                return value

    def primary(self):
        self.space()
        if self.take("("):
            value = self.ternary()
            if not self.take(")"):
                raise ValueError("unbalanced layout parentheses in " + self.text)
            return value
        start = self.pos
        while self.pos < len(self.text) and self.text[self.pos].isdigit():
            self.pos += 1
        if start == self.pos:
            raise ValueError("unexpected layout token in " + self.text)
        return int(self.text[start:self.pos])


def layout_constants(text):
    """Read the allocator constants from memory_layout.h without a compiler.

    Restricted subset: `constexpr bool NAME = true|false;` and
    `constexpr u32 NAME = <hex/decimal, + - * ( ) ? :>;`. Names resolve against
    earlier constants; any other identifier, call or attribute is rejected
    before evaluation, so the header is never executed as code.
    """
    boolean = {n: v == "true" for n, v in
               re.findall(r"constexpr\s+bool\s+(\w+)\s*=\s*(true|false)\s*;", text)}
    exprs = dict(re.findall(r"constexpr\s+u32\s+(\w+)\s*=\s*([^;]+);", text))
    values = {}

    def resolve(expr, depth=0):
        if depth > 16:
            raise ValueError("recursive layout constant")
        expr = re.sub(r"0[xX][0-9a-fA-F]+", lambda m: str(int(m.group(0), 16)), expr)

        def substitute(match):
            name = match.group(0)
            if name in values:
                return str(values[name])
            if name in boolean:
                return "1" if boolean[name] else "0"
            if name in exprs:
                return str(resolve(exprs[name], depth + 1))
            raise ValueError("unsupported layout constant " + name)

        expr = re.sub(r"[A-Za-z_]\w*", substitute, expr)
        if not re.fullmatch(r"[0-9()+\-*/?: ]+", expr):
            raise ValueError("unsupported layout expression " + expr)
        return LayoutExpression(expr).parse()

    for name in exprs:
        values[name] = resolve(exprs[name])
    return values


def layout_budget(index):
    """Predicted whole-corpus arena/address budget for the signed A1.1 path.

    Mirrors the real product layout: scripts/emit-signed-module-arena.py packs
    each loaded segment's static data as an aligned16 span inside one
    ARENA_SIZE reservation in reserved heap tail, while signed text lands in the
    u32 window above the arena (validate_module in
    game/kernel/common/ottsel_signed_gstate.cpp requires code >= arena_size).
    Read-only; nothing is compiled or emitted. This is a budget prediction over
    all code members, independent of the emitter accept/reject result.
    """
    try:
        with open(MEMORY_LAYOUT, encoding="utf-8") as header:
            const = layout_constants(header.read())
    except (OSError, ValueError) as error:
        print("cannot read memory layout: %s" % error, file=sys.stderr)
        return 3
    heap_start = const["HEAP_START"]
    heap_end = const["GLOBAL_HEAP_END"]
    low_end = 0x1FFC000                 # GLOBAL_HEAP_END with BIG_MEMORY == false
    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    per_container = Counter()
    member_size = {}                    # module name -> exact aggregate data_size
    member_where = {}                   # module name -> owning container
    named = set()                       # names already packed (aggregate keys by name)
    code = with_data = 0
    data_total = text_total = text_max = 0
    named_modules = named_text = named_span = 0
    packed = 0
    text_max_where = ""
    for cname in conts:
        data, members, _ = read_container(os.path.join(ISODIR, cname))
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            if len(body) < 80 or u32(body, 4) != 1:
                continue
            if not pick_member(index.get(sha256_bytes(body), []), ".o", m["name"]):
                continue
            code += 1
            release_no_debug = u32(body, 52) != 0
            member_data = member_text = 0
            spans = []                  # raw data bytes of each loaded segment
            for s in range(3):
                if release_no_debug and s == 1:
                    continue            # omitted debug segment: no data span
                size, text = u32(body, 44 + s * 8), u32(body, 64 + s * 4)
                member_data += aligned16(size - text)
                member_text += text
                spans.append(size - text)
            # Exact cursor as aggregate() walks it: align at the module start
            # and at every segment start, then add the raw span. A module's own
            # data_size is that end minus its aligned start.
            local = 0
            for raw in spans:
                local = aligned16(local) + raw
            packed = aligned16(packed)          # module start, as aggregate() aligns
            for raw in spans:
                packed = aligned16(packed) + raw
            if member_data:
                with_data += 1
                per_container[cname] += member_data
            data_total += member_data
            text_total += member_text
            if m["name"] not in member_size:
                member_size[m["name"]] = local
                member_where[m["name"]] = cname
            if m["name"] not in named:
                # The aggregate rejects a repeated module name, so a real
                # whole-corpus layout packs distinct names, not entries.
                named.add(m["name"])
                named_modules += 1
                named_text += member_text
                for raw in spans:
                    named_span = aligned16(named_span) + raw
            if member_text > text_max:
                text_max = member_text
                text_max_where = "%s %s" % (cname, m["name"])
    tail = heap_end - heap_start
    window = 0xFFFFFFFF - ARENA_SIZE + 1
    print("memory_layout.h: HEAP_START=0x%x GLOBAL_HEAP_END=0x%x (BIG_MEMORY=true)"
          % (heap_start, heap_end))
    print("%-26s %10d  (%.2f MiB)  == EE_MAIN_MEM_SIZE"
          % ("arena_size", ARENA_SIZE, ARENA_SIZE / 1048576.0))
    print("%-26s %10d  (%.2f MiB)  = GLOBAL_HEAP_END - HEAP_START"
          % ("heap tail budget", tail, tail / 1048576.0))
    print("%-26s %10d  (%.2f MiB)  = BIG_MEMORY=false floor"
          % ("  conservative", low_end - heap_start, (low_end - heap_start) / 1048576.0))
    print("%-26s %10d" % ("code members", code))
    print("%-26s %10d" % ("members carrying data", with_data))
    print("%-26s %10d  (%.2f MiB) = %.2f%% of tail budget"
          % ("total aligned static data", data_total, data_total / 1048576.0,
             100.0 * data_total / tail))
    print("%-26s %10d  (%.2f MiB) = exact aggregate cursor; above sum over by %d B"
          % ("  packed span", packed, packed / 1048576.0, data_total - packed))
    print("%-26s %10d  (%d distinct names)"
          % ("  name-keyed packed span", named_span, named_modules))
    print("%-26s %10d  (%.2f MiB)"
          % ("  name-keyed signed text", named_text, named_text / 1048576.0))
    print("%-26s %10d  (%.2f MiB) = %.2f%% of u32 window above arena"
          % ("total signed text", text_total, text_total / 1048576.0,
             100.0 * text_total / window))
    print("%-26s %10d  (%s)" % ("largest single signed text", text_max, text_max_where))
    print("%-26s %10d  (%.2f MiB)"
          % ("remaining tail headroom", tail - data_total,
             (tail - data_total) / 1048576.0))
    print("per-container aligned data bytes:")
    for cname, n in per_container.most_common():
        print("  %-12s %10d" % (cname, n))
    # Reproduce the shipped KERNEL reservation from scripts/build-ios.sh:342 so
    # the whole-corpus prediction stays anchored to a real product layout.
    print("KERNEL production reservation (build-ios.sh aggregate formula):")
    try:
        with open(os.path.join(REPO, "config", "signed-kernel-full.json"),
                  encoding="utf-8") as handle:
            kernel = json.load(handle)["modules"]
    except (OSError, ValueError, KeyError) as error:
        print("cannot read KERNEL module list: %s" % error, file=sys.stderr)
        return 3
    missing = [n for n in kernel if n not in member_size]
    if not kernel or missing:
        print("KERNEL members absent from corpus: %s" % missing, file=sys.stderr)
        return 3
    span = sum(aligned16(member_size[n]) for n in kernel)
    reservation = (heap_end - span) & ~0x3FFF       # build-ios.sh: span->begin
    slots = heap_end - reservation
    cursor = reservation
    for n in kernel:
        cursor = aligned16(cursor) + member_size[n]     # aggregate() data walk
    data_span = cursor - reservation
    print("  %-24s %10d  %s == documented 11104"
          % ("span sum aligned16(data_size)", span,
             "PASS" if span == 11104 else "FAIL"))
    print("  %-24s 0x%x  size %d  %s == documented 0x3eb4000"
          % ("reservation_begin", reservation, slots,
             "PASS" if reservation == 0x3EB4000 else "FAIL"))
    print("  %-24s %10d <= %d  %s data_span_size <= GLOBAL_HEAP_END - reservation_begin"
          % ("aggregate data_span_size", data_span, slots,
             "PASS" if data_span <= slots else "FAIL"))
    print("  %-24s 0x%x < 0x%x < 0x%x <= 0x%x  %s"
          % ("heap window", heap_start, reservation, heap_end, ARENA_SIZE,
             "PASS" if heap_start < reservation < heap_end <= ARENA_SIZE else "FAIL"))
    documented_ok = span == 11104 and reservation == 0x3EB4000
    structural_ok = (heap_start < reservation < heap_end <= ARENA_SIZE
                     and reservation % 16384 == 0 and data_span <= slots)
    return 0 if documented_ok and structural_ok else 1


def identity_report(index):
    """Whole-corpus code-member identity, the question that gates any GAME list.

    The signed aggregate keys each module by its GOAL name and rejects a
    repeated name, and the build profile maps a module name to one loose object
    by byte comparison. So the selection key has to be measured, not guessed:
    is the container member name usable as-is, or does the corpus need a
    payload/type identity scheme? This reports the invariants the GAME
    extension depends on and fails closed if any of them breaks.
    """
    conts = sorted(n for n in os.listdir(ISODIR)
                   if n.endswith(".CGO") or n.endswith(".DGO"))
    bodies = defaultdict(set)     # code name -> member body hashes seen
    owners = defaultdict(set)     # code name -> containers holding it
    stems = defaultdict(set)      # code name -> matching loose .o stems
    chosen = {}                   # code name -> the stem pick_member selects
    art_names = set()
    art_total = art_named = art_multi = 0
    code_members = 0
    local_dupes = Counter()
    for cname in conts:
        data, members, _ = read_container(os.path.join(ISODIR, cname))
        local = Counter()
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            matches = index.get(sha256_bytes(body), [])
            loose = pick_member(matches, ".o", m["name"])
            if loose:
                code_members += 1
                local[m["name"]] += 1
                bodies[m["name"]].add(sha256_bytes(body))
                owners[m["name"]].add(cname)
                stems[m["name"]].update(n for n in matches if n.endswith(".o"))
                chosen.setdefault(m["name"], loose)
            else:
                loose_art = pick_member(matches, ".go", m["name"])
                if loose_art:
                    art_names.add(m["name"])
                    art_total += 1
                    art_named += loose_art[:-3] == m["name"]
                    art_multi += len({n for n in matches if n.endswith(".go")}) > 1
        for name, n in local.items():
            if n > 1:
                local_dupes[cname + "/" + name] = n
    names = sorted(bodies)
    conflicts = [n for n in names if len(bodies[n]) > 1]
    repeated = [n for n in names if len(owners[n]) > 1]
    ambiguous = [n for n in names if len(stems[n]) > 1]
    labels = defaultdict(set)
    for n in names:
        labels[n.replace("-", "_")].add(n)
    collisions = {k: sorted(v) for k, v in labels.items() if len(v) > 1}
    loose = {n for n in os.listdir(OBJDIR) if n.endswith(".o")}
    selected = set(chosen.values())
    renamed = [n for n in names if chosen[n][:-2] != n]
    both = sorted(set(names) & art_names)
    print("code members            %6d  (container entries)" % code_members)
    print("distinct code names     %6d  (aggregate module count)" % len(names))
    print("distinct bodies         %6d" % len({s for v in bodies.values() for s in v}))
    print("loose .o files          %6d  selected %d  unselected %d"
          % (len(loose), len(selected & loose), len(loose - selected)))
    print("names repeated in >1 container %5d" % len(repeated))
    print("names whose bodies differ across containers %5d" % len(conflicts))
    print("names matching >1 loose .o stem %5d  (declaration-only group)"
          % len(ambiguous))
    print("names whose chosen stem != name %5d" % len(renamed))
    print("label collisions after -/_ fold %5d" % len(collisions))
    print("names that are code somewhere and art somewhere %5d" % len(both))
    print("art members resolved to a .go %6d  loose stem equal to name %d"
          % (art_total, art_named))
    print("art members matching >1 .go stem %5d" % art_multi)
    print("duplicate-module guard hits if members were keyed as-is %5d"
          % (code_members - len(names)))
    checks = [("name is a primary key (no cross-container body conflicts)", not conflicts),
              ("name is unambiguous as a Mach-O label", not collisions),
              ("art body hash identifies exactly one .go", not art_multi),
              ("chosen loose stem equals module name", not renamed),
              ("every loose .o is selected", not (loose - selected)),
              ("no container repeats a code name", not local_dupes)]
    for label, ok in checks:
        print("  %-4s %s" % ("PASS" if ok else "FAIL", label))
    return 0 if all(ok for _, ok in checks) else 1


def build_object_index():
    idx = defaultdict(list)
    for name in os.listdir(OBJDIR):
        if name.endswith(".o") or name.endswith(".go"):
            path = os.path.join(OBJDIR, name)
            with open(path, "rb") as f:
                idx[sha256_bytes(f.read())].append(name)
    return idx


def pick_member(matches, ext, name):
    """Prefer the loose file whose stem is the member's own name.

    Some declaration-only objects are byte-identical (e.g. gstring-h.o and
    pc-cheats.o), so a hash alone does not identify a single file; the
    container's own name is the better tiebreak.
    """
    cands = [m for m in matches if m.endswith(ext)]
    for c in cands:
        if c[: -len(ext)] == name:
            return c
    return cands[0] if cands else None


def read_container(path):
    with open(path, "rb") as f:
        data = f.read()
    count = struct.unpack_from("<I", data, 0)[0]
    off = 64
    members = []
    for _ in range(count):
        size = struct.unpack_from("<I", data, off)[0]
        raw = data[off + 4:off + 64].split(b"\x00")[0]
        members.append({"name": raw.decode("latin1"), "off": off + 64, "size": size})
        off += 64 + ((size + 15) // 16) * 16
    return data, members, off


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--simulate", action="store_true",
                    help="also apply the two proposed generalizations and report the "
                         "predicted accept count (pure prediction, nothing is compiled)")
    ap.add_argument("--prefix", default="GAME.CGO=60",
                    help="container=count member prefix to print")
    ap.add_argument("--links", action="store_true",
                    help="report kind-5 pointer records the narrow emitter path "
                         "rejects, the members left failing on that path, and the "
                         "code-target invariants (fail closed)")
    ap.add_argument("--relax-all", action="store_true",
                    help="accept count under the maintained emitter policy, where "
                         "all four generalizations are implemented (types, LDR Q, "
                         "loaded data-only seg0, pointer code targets)")
    ap.add_argument("--types", action="store_true",
                    help="complete kind-2 (name, methods) table over all code "
                         "members, split by code-region vs static-data patch")
    ap.add_argument("--links-selftest", action="store_true",
                    help="negative control for the --links code-target "
                         "invariants: one injection per invariant into the real "
                         "corpus plus a residue sweep and boundary check")
    ap.add_argument("--budget", action="store_true",
                    help="predicted arena/address budget for the whole signed code "
                         "corpus (aligned static data vs heap tail, text vs u32 window)")
    ap.add_argument("--attribution", action="store_true",
                    help="per-restriction attribution over the 16-subset relaxation "
                         "lattice: cumulative accepts per subset plus each failing "
                         "member's minimal accepting set (pure prediction)")
    ap.add_argument("--identity", action="store_true",
                    help="code-member identity across containers: is the module name a "
                         "usable aggregate/profile key, or is payload identity required")
    args = ap.parse_args()
    prefix_container, _, prefix_count = args.prefix.partition("=")
    prefix_count = int(prefix_count or "0")

    if not os.path.isdir(OBJDIR) or not os.path.isdir(ISODIR):
        print("missing build outputs under " + os.path.join(REPO, "out"), file=sys.stderr)
        return 2

    index = build_object_index()
    if args.attribution:
        return attribution_report(index)
    if args.budget:
        return layout_budget(index)
    if args.identity:
        return identity_report(index)
    if args.links_selftest:
        return links_selftest(index)
    if args.links:
        return kind5_report(index)
    if args.types:
        return types_report(index)
    if args.relax_all:
        relax_report(index)
        return 0
    containers = sorted(n for n in os.listdir(ISODIR)
                        if n.endswith(".CGO") or n.endswith(".DGO"))
    per_container = []
    fail_hist = Counter()
    addr_hist = Counter()
    scan_hist = Counter()
    scan_issues = Counter()
    sim_hist = Counter()
    sim_ok = 0
    sim_code = 0
    sim2_hist = Counter()
    sim2_ok = 0
    type_methods = defaultdict(Counter)
    type_hist = Counter()
    totals = Counter()
    all_members = []
    name_code = defaultdict(set)
    name_art = defaultdict(set)

    for cname in containers:
        data, members, end_off = read_container(os.path.join(ISODIR, cname))
        row = Counter(container=cname, members=len(members),
                      trailing=len(data) - end_off)
        prefix = []
        for m in members:
            body = data[m["off"]:m["off"] + m["size"]]
            matches = index.get(sha256_bytes(body), [])
            code = pick_member(matches, ".o", m["name"])
            art = pick_member(matches, ".go", m["name"])
            rec = {"container": cname, "member": m["name"], "size": m["size"],
                   "code": code, "art": art, "matches": matches}
            if code:
                rec["kind"] = "code"
                name_code[m["name"]].add(cname)
                policy = u32(body, 52) != 0
                rec["release_no_debug"] = policy
                try:
                    parse_signed_module(body, release_no_debug=policy)
                    rec["result"] = "OK"
                except EmitError as e:
                    rec["result"] = "FAIL"
                    rec["error"] = str(e)
                    fail_hist[str(e)] += 1
                    if e.detail.get("type_name"):
                        type_hist[e.detail["type_name"]] += 1
                        type_methods[e.detail["type_name"]][e.detail.get("methods")] += 1
                    if e.detail.get("addr_op") is not None:
                        addr_hist["0x%08x" % e.detail["addr_op"]] += 1
                sc, si = scan_distance32(body)
                scan_hist.update(sc)
                scan_issues.update(si)
                if args.simulate:
                    sim_code += 1
                    try:
                        parse_signed_module(body, release_no_debug=policy,
                                            enforce_type_whitelist=False, allow_ldr_q=True)
                        sim_ok += 1
                    except EmitError as e:
                        sim_hist[str(e)] += 1
                    try:
                        parse_signed_module(body, release_no_debug=policy, allow_ldr_q=True,
                                            enforce_type_whitelist=False, enforce_methods=False)
                        sim2_ok += 1
                    except EmitError as e:
                        sim2_hist[str(e)] += 1
            elif art:
                rec["kind"] = "art"
                name_art[m["name"]].add(cname)
            else:
                rec["kind"] = "unknown"
            row[rec["kind"]] = row.get(rec["kind"], 0) + 1
            if rec["kind"] == "code":
                key = "ok" if rec["result"] == "OK" else "fail"
                row[key] = row.get(key, 0) + 1
            totals[rec["kind"]] += 1
            if rec["kind"] == "code":
                totals["ok" if rec["result"] == "OK" else "fail"] += 1
            all_members.append(rec)
            if cname == prefix_container and len(prefix) < prefix_count:
                prefix.append(rec)
        per_container.append({"row": dict(row), "prefix": prefix,
                             "data_len": len(data), "end_off": end_off})

    dual = sorted(set(name_code) & set(name_art))
    unknown = [m for m in all_members if m["kind"] == "unknown"]

    if args.json:
        print(json.dumps({
            "totals": dict(totals),
            "per_container": [{"row": c["row"], "data_len": c["data_len"]}
                              for c in per_container],
            "fail_histogram": fail_hist.most_common(),
            "distance32_add_opcodes": addr_hist.most_common(),
            "distance32_consumer_classes": scan_hist.most_common(),
            "distance32_scan_issues": scan_issues.most_common(),
            "simulated": {"code": sim_code, "ok": sim_ok,
                          "fail_histogram": sim_hist.most_common()},
            "simulated_full_type_table": {"ok": sim2_ok,
                                          "fail_histogram": sim2_hist.most_common()},
            "observed_methods_per_type": {k: dict(v) for k, v in type_methods.items()},
            "type_name_histogram": type_hist.most_common(),
            "dual_named_code_and_art": dual,
            "unknown_members": unknown,
            "members": all_members,
        }, indent=1))
        return 0

    print("loose objects: %d distinct bodies -> %d files" % (len(index),
          sum(len(v) for v in index.values())))
    print("containers: %d" % len(containers))
    print("members: %d  code=%d (OK=%d FAIL=%d)  art=%d  unknown=%d"
          % (sum(v["row"]["members"] for v in per_container), totals["code"],
             totals["ok"], totals["fail"], totals["art"], totals["unknown"]))
    print()
    print("%-12s %6s %6s %6s %5s %5s %5s %5s" %
          ("container", "memb", "code", "ok", "fail", "art", "unk", "trail"))
    for c in per_container:
        r = c["row"]
        print("%-12s %6d %6d %6d %5d %5d %5d %5d" %
              (r["container"], r["members"], r.get("code", 0), r.get("ok", 0),
               r.get("fail", 0), r.get("art", 0), r.get("unknown", 0),
               c["data_len"] - c["end_off"]))
    print()
    print("failure histogram (emitter error string -> count):")
    for msg, n in fail_hist.most_common():
        print("  %5d  %s" % (n, msg))
    print()
    print("distance32 rejected ADRP-consumer opcodes (add & 0xffc00000):")
    for op, n in addr_hist.most_common():
        print("  %5d  %s" % (n, op))
    print()
    print("distance32 ADRP-consumer classes over the whole code corpus "
          "(tolerant scan, incl. modules that fail earlier):")
    for op, n in scan_hist.most_common():
        print("  %5d  0x%08x" % (n, op))
    if scan_issues:
        print("  scan issues: " + ", ".join("%s=%d" % kv for kv in scan_issues.most_common()))
    if args.simulate:
        print()
        print("PREDICTION (not compiled) A: type name whitelist relaxed, methods == 9 kept, "
              "plus the validated 16-byte SIMD LDR class:")
        print("  %d/%d code members would emit; residual %d failures"
              % (sim_ok, sim_code, sim_code - sim_ok))
        for msg, n in sim_hist.most_common():
            print("  %5d  %s" % (n, msg))
        print("PREDICTION (not compiled) B: full authenticated type table too "
              "(any name+methods pair) + LDR Q:")
        print("  %d/%d code members would emit; residual %d failures"
              % (sim2_ok, sim_code, sim_code - sim2_ok))
        for msg, n in sim2_hist.most_common():
            print("  %5d  %s" % (n, msg))
        print("observed methods byte per rejected type name "
              "(name -> {methods: modules}):")
        for name in sorted(type_methods):
            print("  %-32s %s" % (name, dict(type_methods[name])))
    print()
    print("dual-named types (code in one container, art in another): %d" % len(dual))
    for n in dual:
        print("  %-28s code=%s art=%s" % (n, sorted(name_code[n]), sorted(name_art[n])))
    if unknown:
        print()
        print("unmatched members: %d" % len(unknown))
        for m in unknown[:20]:
            print("  %-12s %-28s %d" % (m["container"], m["member"], m["size"]))
    for c in per_container:
        if c["prefix"]:
            r = c["row"]
            print()
            print("prefix: %s (first %d members, dependency order)"
                  % (r["container"], len(c["prefix"])))
            for m in c["prefix"]:
                if m["kind"] != "code":
                    print("  %-34s %-4s %s" % (m["member"], m["kind"], m.get("art") or ""))
                else:
                    print("  %-34s %-4s %s" % (m["member"], m["result"],
                                               m.get("error", "")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
