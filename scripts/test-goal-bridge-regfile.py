#!/usr/bin/env python3

"""Ottsel A1.7 regression: the C->GOAL bridges must preserve GOAL's register file.

GOAL's register file is x19-x28 plus v8-v15 (RegisterInfo::make_register_info_arm64;
_call_goal_on_stack_asm_arm64 documents the reason).  A bridge that saves only
x20-x22 leaves the caller's live x19/x23-x28 to the GOAL callee, which uses them as
general purpose registers.  Measured on the strict signed-GAME lane, that destroyed
display-loop's `disp` (held in x19): its frame-buffer chain then read a foreign object
and handed draw-string a null dma-buffer, whose first store SIGBUSed at font seg0
0x6864.  This test pins the invariant in the source.

Usage: python3 scripts/test-goal-bridge-regfile.py [asm_path]
"""
import re
import sys

DEFAULT = "out/jak-project/game/kernel/asm_funcs_arm64.s"
# C->GOAL bridges also park pp/st/off (x20/x21/x22) for the GOAL callee.
BRIDGES = ("_call_goal_asm_arm64", "_call_goal8_asm_arm64")
BRIDGE_SETUP = ["stp x20, x21", "str x22"]
BRIDGE_SETUP_POPS = ["ldr x22", "ldp x20, x21"]
# Every GOAL<->C++ boundary must leave GOAL's register file intact.
TRAMPOLINES = ("_arg_call_arm64", "_stack_call_arm64")
# _mips2c_call_arm64 also preserves GOAL's register file and additionally uses x19 as its own
# stack-size scratch, so it gets the offset simulation even though its pairs differ from the
# REG_FILE shape above (x19,x20 / x21,x22 / ... rather than x19,x23 / x24,x25 / ...).
SIM_ONLY = ("_mips2c_call_arm64",)
REG_FILE = ["stp x19, x23", "stp x24, x25", "stp x26, x27", "str x28"]
REG_FILE_POPS = ["ldr x28", "ldp x26, x27", "ldp x24, x25", "ldp x19, x23"]
# The vector half may be paired either way; only its presence is required.
VECTORS = ["q%d" % i for i in range(8, 16)]

# Stack-slot simulation.  A presence-only check missed a real defect: the A1.7c GPR
# saves were appended after the vector saves in _stack_call_arm64's prologue while
# its epilogue still popped the vectors first, so every GOAL->C call through that
# trampoline restored x19-x28 from the vector save area (measured: signed rpc-h
# `call` ran with x19 = 0 after the rpc-call and stored through a null
# rpc-buffer-pair at ee+0xC) and v8-v15 from the GPR slots.  Each pop must read the
# exact slot its matching push wrote.
PUSH = re.compile(r"^(stp|str)\s+(.+?)\s*,\s*\[sp, #-(\w+)\]!$")
POP = re.compile(r"^(ldp|ldr)\s+(.+?)\s*,\s*\[sp\], #(\w+)$")
DISCARD = re.compile(r"^add\s+sp,\s*sp, #(\w+)$")
RESERVE = re.compile(r"^sub\s+sp,\s*sp, #(\w+)$")
# _arg_call_arm64/_stack_call_arm64 are entered with the C target already pushed on
# the stack by the export-bank stub; their last `ldp x29, x30, [sp], #32` takes it.
# _mips2c_call_arm64 consumes the export-bank stub's two 16-byte slots ([stack_size], [exec]).
ENTRY_SLACK = {"_arg_call_arm64": 16, "_stack_call_arm64": 16, "_mips2c_call_arm64": 32}


def stack_slot_failures(seq, label):
    problems = []
    sp, slots = 0, {}
    for line in seq:
        match = PUSH.match(line)
        if match:
            names = [name.strip() for name in match.group(2).split(",")]
            sp -= int(match.group(3), 0)
            cursor = sp
            for name in names:
                slots[cursor] = name
                cursor += 16 if name.startswith("q") else 8
            continue
        match = POP.match(line)
        if match:
            names = [name.strip() for name in match.group(2).split(",")]
            cursor = sp
            for name in names:
                found = slots.get(cursor)
                if found != name:
                    problems.append("%s: %s restored from the slot that saved %s"
                                    % (label, name, found or "nothing"))
                cursor += 16 if name.startswith("q") else 8
            sp += int(match.group(3), 0)
            continue
        match = DISCARD.match(line)
        if match:
            sp += int(match.group(1), 0)
            continue
        match = RESERVE.match(line)
        if match:
            # A fixed-size scratch region (the mips2c ExecutionContext) sits between the
            # register saves and the restore block; it is released again before the pops, so
            # the sim only needs to move sp by it symmetrically.
            sp -= int(match.group(1), 0)
            continue
    if sp != ENTRY_SLACK.get(label, 0):
        problems.append("%s: unbalanced stack (%d bytes left, expected %d)"
                        % (label, sp, ENTRY_SLACK.get(label, 0)))
    return problems


def bridge_body(text, label):
    body, inside = [], False
    for line in text.splitlines():
        if re.match(r"\s*%s:" % re.escape(label), line):
            inside = True
            continue
        if inside and line.startswith(".global"):
            break
        if inside:
            body.append(line.split(";")[0].strip())
    return [b for b in body if b and not b.startswith("//")]


def first_index(seq, pat, after):
    for i, line in enumerate(seq):
        if i > after and line.startswith(pat):
            return i
    return -1


def check(path):
    text = open(path).read()
    failures = []
    targets = ([(l, BRIDGE_SETUP + REG_FILE, REG_FILE_POPS + BRIDGE_SETUP_POPS) for l in BRIDGES]
               + [(l, REG_FILE, REG_FILE_POPS) for l in TRAMPOLINES])
    for label, pushes, pops in targets:
        seq = bridge_body(text, label)
        if not seq:
            failures.append("%s: not found in %s" % (label, path))
            continue
        positions = []
        last = -1
        for pat in pushes + pops:
            i = first_index(seq, pat, last)
            positions.append(i)
            last = i
        if -1 in positions:
            missing = [p for p, i in zip(pushes + pops, positions) if i < 0]
            failures.append("%s: missing in order: %s" % (label, missing))
            continue
        push_last = positions[len(pushes) - 1]
        pop_first = positions[len(pushes)]
        if not push_last < pop_first:
            failures.append("%s: restores are not LIFO vs pushes (last push at %d, "
                            "first pop at %d)" % (label, push_last, pop_first))
        for vec in VECTORS:
            if not any(l.startswith("stp q") and vec in l for l in seq):
                failures.append("%s: vector %s is not saved" % (label, vec))
            if not any(l.startswith("ldp q") and vec in l for l in seq):
                failures.append("%s: vector %s is not restored" % (label, vec))
        failures.extend(stack_slot_failures(seq, label))
    for label in SIM_ONLY:
        seq = bridge_body(text, label)
        if not seq:
            failures.append("%s: not found in %s" % (label, path))
            continue
        failures.extend(stack_slot_failures(seq, label))
        if not any(l.startswith("stp x19, x20") for l in seq):
            failures.append("%s: x19/x20 pair is not saved" % label)
        if not any(l.startswith("ldp x19, x20") for l in seq):
            failures.append("%s: x19/x20 pair is not restored" % label)
    return failures


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    failures = check(path)
    if failures:
        print("FAIL: a C->GOAL bridge does not preserve the GOAL register file")
        for f in failures:
            print("  " + f)
        return 1
    print("PASS: every GOAL<->C++ trampoline preserves x19-x28 and v8-v15 "
          "(LIFO, balanced, pop order matches push order)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
