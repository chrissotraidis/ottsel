#!/usr/bin/env python3
"""A1.10/A1.11/A1.13 guard: the kernel continuation slot (patch a11-kernel-continuation-slot.patch).

thread-resume and reset-and-call stash their incoming x30 as the first kernel-stack slot, so
[*kernel-sp* + 0x50] - the slot the suspend-side guard reads - holds the kernel continuation
instead of whatever frame data happened to be there (A1.10).  A1.11 tightened the guard window to
the module block.  A1.13 made the balance exact: the suspend side pops that sixth slot too, so sp
returns to the caller resume point.  Five pops left sp 0x10 low, and every suspend/resume then
resumed the kernel 0x10 lower, which shifted the kernel frames into each other slots (measured:
the argument group handed to execute-process-tree recursion rotated after a few dispatches).

Checks the nested gkernel.gc for the stash edits, for the sixth pop in all three suspend-side
asm-funcs, for the absence of the abandoned unguarded (.jr lr) variant, that the overlay
reverse-applies and restores the pre-change text, and - when the objects exist - that exactly
three of the emitted gkernel guarded .ret sites are preceded by the sixth pop (ldr x30, [sp], #16).
"""
import pathlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILE = ROOT / "out/jak-project/goal_src/jak1/kernel/gkernel.gc"
PATCH = ROOT / "patches/a11-kernel-continuation-slot.patch"
OBJECT = ROOT / "out/jak-project/out/jak1/obj/gkernel.o"

POSITIVE = [
    ("stash push (reset-and-call + thread-resume)",
     r"\(\.push :color #f lr\) ;; A1\.10: the kernel continuation the \.ret must land on", 2),
    ("x30 binding (three suspend-side asm-funcs + two stashers + set-to-run)",
     r"\(lr :reg x30 :type uint\)", 6),
    ("sixth pop reclaiming the stash in all three suspend-side tails",
     r"\(\.pop :color #f lr\)[^\n]*\n(?:    ;; [^\n]*\n)*    \(\.ret\)", 3),
]
NEGATIVE = [
    ("abandoned unguarded jr", r"\(\.jr lr\)"),
]

if not FILE.exists():
    print("A1.10/A1.11/A1.13 kernel-continuation-slot guard: SKIP (no nested gkernel.gc)")
    sys.exit(0)

failures = []
text = FILE.read_text()
if not re.search(r"\(\.pop :color #f s0\)\n", text):
    failures.append("suspend-side five-pop block is missing")
if len(re.findall(r"\(\.pop :color #f s0\)\n(?:    ;; [^\n]*\n)*    \(\.pop :color #f lr\)",
                  text)) != 3:
    failures.append("not all three suspend-side tails pop the sixth slot after the five s-pops")
for name, pattern, want in POSITIVE:
    got = len(re.findall(pattern, text))
    if got != want:
        failures.append("%s: expected %d occurrence(s), found %d" % (name, want, got))
for name, pattern in NEGATIVE:
    if re.search(pattern, text):
        failures.append("%s still present (the suspend side must use the guarded .ret)" % name)

with tempfile.TemporaryDirectory(prefix="a110-") as directory:
    temporary = pathlib.Path(directory)
    target = temporary / "goal_src/jak1/kernel/gkernel.gc"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(FILE, target)
    res = subprocess.run(["git", "apply", "--reverse", str(PATCH)], cwd=directory,
                         capture_output=True, text=True)
    if res.returncode != 0:
        failures.append("overlay does not reverse-apply: " + (res.stderr or "").strip()[:200])
    else:
        before = target.read_text()
        for marker in ("A1.10", "A1.13"):
            if marker in before:
                failures.append("reverse-applied file still contains %s markers" % marker)
        if not re.search(r"\(\.pop :color #f s0\)\n    ;; return to the kernel", before):
            failures.append("reverse-applied file is missing the original .pop s0 / .ret tail")

# Emitted-code half of the contract: at each guarded .ret site the guard loads the slot into x30
# (mov x16, x30 ; ldr x30, [sp]); the three suspend-side tails must load x30 with the sixth pop
# (ldr x30, [sp], #16) immediately before it.
MOV_X16_X30 = b"\xf0\x03\x1e\xaa"
LDR_X30_SP = b"\xfe\x03\x40\xf9"
POP_X30 = 0xF84107FE
if OBJECT.exists():
    data = OBJECT.read_bytes()
    guarded = tail_with_pop = 0
    offset = 0
    while True:
        offset = data.find(MOV_X16_X30, offset)
        if offset < 0:
            break
        if data[offset + 4:offset + 8] == LDR_X30_SP:
            guarded += 1
            if struct.unpack("<I", data[offset - 4:offset])[0] == POP_X30:
                tail_with_pop += 1
        offset += 4
    if guarded == 0:
        print("INFO: no guarded .ret site in the emitted gkernel.o (object not regenerated)")
    elif tail_with_pop != 3:
        failures.append("emitted gkernel.o: expected 3 suspend-side guarded .ret sites preceded by "
                        "the sixth pop, found %d of %d" % (tail_with_pop, guarded))
    else:
        print("emitted gkernel.o: %d guarded .ret site(s), %d carry the sixth pop" % (guarded, tail_with_pop))
else:
    print("INFO: no emitted gkernel.o present (regenerate the objects to check the epilogue)")

if failures:
    print("A1.10/A1.11/A1.13 kernel-continuation-slot guard: FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("A1.10/A1.11/A1.13 kernel-continuation-slot guard: PASS (stash + sixth pop in 3 tails, "
      "overlay reconstructs)")
