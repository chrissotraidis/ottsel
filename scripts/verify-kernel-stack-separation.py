#!/usr/bin/env python3
"""A1.14 guard: kernel/activation stack separation (patch a11-kernel-stack-separation.patch).

The kernel runs on a stack anchored at the top of EE memory, and every C->GOAL activation
(`call_goal_on_stack`: kboot, klink's link_and_exec, the signed loader) anchors at the same
address.  A deep activation running while the kernel was suspended overwrote the kernel's live
frames; the suspend side then popped the clobbered slots and jumped into the stack (A1.13 fault:
pc = the kernel stack top, SIGBUS, right after `served obj 1 (oracle)`).  A1.14 keeps the kernel
64 KiB below the top so activations own the top of EE memory.

Checks the nested kboot.cpp for the reserve constant and the goal_stack expression, confirms the
activation call sites still anchor at the top, and that the overlay reverse-applies and restores
the unreserved expression.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
KBOOT = ROOT / "out/jak-project/game/kernel/jak1/kboot.cpp"
SIGNED = ROOT / "out/jak-project/game/kernel/common/ottsel_signed_gstate.cpp"
KLINK = ROOT / "out/jak-project/game/kernel/jak1/klink.cpp"
PATCH = ROOT / "patches/a11-kernel-stack-separation.patch"

if not KBOOT.exists():
    print("A1.14 kernel-stack-separation guard: SKIP (no nested kboot.cpp)")
    sys.exit(0)

failures = []
text = KBOOT.read_text()
if "constexpr u64 kActivationStackReserve = 0x10000;" not in text:
    failures.append("kboot.cpp is missing the 64 KiB activation stack reservation")
if "u64 goal_stack = u64(g_ee_main_mem) + EE_MAIN_MEM_SIZE - kActivationStackReserve -" not in text:
    failures.append("kboot.cpp goal_stack does not subtract the reservation")
if len(re.findall(r"kActivationStackReserve", text)) != 2:
    failures.append("expected exactly one declaration and one use of kActivationStackReserve")
# Numeric form of the invariant: the kernel anchor must sit far enough below the activation anchor
# (EE_MAIN_MEM_SIZE - 16) that no activation depth we can plausibly need reaches the kernel's
# frames.  The measured offender is ~0x1e0 bytes of frames; require 16 KiB of separation and
# 16-byte alignment for the ARM64 spills the code relies on.
reserve_match = re.search(r"kActivationStackReserve = (0x[0-9a-fA-F]+)", text)
reserve = int(reserve_match.group(1), 16) if reserve_match else 0
if reserve < 0x4000:
    failures.append("activation reserve is only 0x%x bytes; the kernel/activation separation "
                    "invariant needs at least 16 KiB" % reserve)
if reserve % 16:
    failures.append("activation reserve 0x%x breaks the 16-byte SP alignment goal_stack needs" % reserve)
# The activations must keep the top of EE memory (they are the party A1.14 moved the kernel away
# from); if one of them moved too, the separation argument no longer holds.
if SIGNED.exists() and "EE_MAIN_MEM_SIZE - 16" not in SIGNED.read_text():
    failures.append("the signed loader no longer anchors its activation at the top of EE memory")
if KLINK.exists() and not re.search(r"goal_stack = u64\(g_ee_main_mem\) \+ EE_MAIN_MEM_SIZE -",
                                   KLINK.read_text()):
    failures.append("klink link_and_exec no longer anchors its activation at the top of EE memory")

with tempfile.TemporaryDirectory(prefix="a114-") as directory:
    temporary = pathlib.Path(directory)
    target = temporary / "game/kernel/jak1/kboot.cpp"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(KBOOT, target)
    res = subprocess.run(["git", "apply", "--reverse", str(PATCH)], cwd=directory,
                         capture_output=True, text=True)
    if res.returncode != 0:
        failures.append("overlay does not reverse-apply: " + (res.stderr or "").strip()[:200])
    else:
        before = target.read_text()
        if "A1.14" in before or "kActivationStackReserve" in before:
            failures.append("reverse-applied kboot.cpp still contains the A1.14 reservation")
        if not re.search(r"u64 goal_stack = u64\(g_ee_main_mem\) \+ EE_MAIN_MEM_SIZE -\n", before):
            failures.append("reverse-applied kboot.cpp is missing the original goal_stack expression")

if failures:
    print("A1.14 kernel-stack-separation guard: FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("A1.14 kernel-stack-separation guard: PASS (kernel 64 KiB below the top, activations keep "
      "the top, overlay reconstructs)")
