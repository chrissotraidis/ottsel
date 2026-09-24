#!/usr/bin/env python3
"""A1.15 guard: the host reference lane can link the ARM64 GOAL<->C++ trampolines.

`game/kernel/asm_funcs_arm64.s` writes eight `ottsel_cbridge_*` diagnostics, which the iOS product
shell (`src/shell/ios_boot.cpp`) and the assembly-only test harness define.  Nothing defined them for
the macOS `gk` reference lane, so `ninja -C out/jak-project/build/h1 gk` failed at link time and the
reference lane could not be rebuilt from source at all.  The inner runtime now defines them for every
non-iOS build (`game/kernel/jak1/kscheme.cpp`, `#ifndef OTTSEL_IOS`).

Checks the definition/guard, that every counter the assembly writes is defined, that the iOS shell
still supplies its own copy (no duplicate symbol on iOS), and that the overlay reverse-applies.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEME = ROOT / "out/jak-project/game/kernel/jak1/kscheme.cpp"
ASM = ROOT / "out/jak-project/game/kernel/asm_funcs_arm64.s"
SHELL = ROOT / "src/shell/ios_boot.cpp"
PATCH = ROOT / "patches/a11-host-cbridge-counters.patch"
COUNTERS = [
    "ottsel_cbridge_calls",
    "ottsel_cbridge_in",
    "ottsel_cbridge_out",
    "ottsel_cbridge_target",
    "ottsel_cbridge_leaks",
    "ottsel_cbridge_leak_in",
    "ottsel_cbridge_leak_out",
    "ottsel_cbridge_leak_target",
]

if not SCHEME.exists():
    print("A1.15 host-cbridge-counters guard: SKIP (no nested checkout)")
    sys.exit(0)

failures = []
text = SCHEME.read_text()
guarded = re.search(r"#ifndef OTTSEL_IOS\n(?P<body>extern \"C\" \{.*?\}\n)#endif", text,
                    re.DOTALL)
if not guarded:
    failures.append("kscheme.cpp has no `#ifndef OTTSEL_IOS` extern-C block for the counters")
else:
    body = guarded.group("body")
    for counter in COUNTERS:
        if not re.search(r"unsigned long long %s;" % counter, body):
            failures.append("kscheme.cpp does not define %s for non-iOS builds" % counter)
if ASM.exists():
    asm = ASM.read_text()
    for counter in COUNTERS:
        if "_%s@" % counter not in asm:
            failures.append("asm_funcs_arm64.s no longer references %s (update this guard)" % counter)
else:
    failures.append("missing asm_funcs_arm64.s")
if SHELL.exists():
    shell = SHELL.read_text()
    for counter in COUNTERS:
        if not re.search(r"unsigned long long %s;" % counter, shell):
            failures.append("the iOS shell no longer defines %s (duplicate-symbol risk on iOS)"
                            % counter)

with tempfile.TemporaryDirectory(prefix="a115-") as directory:
    temporary = pathlib.Path(directory)
    target = temporary / "game/kernel/jak1/kscheme.cpp"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SCHEME, target)
    res = subprocess.run(["git", "apply", "--reverse", str(PATCH)], cwd=directory,
                         capture_output=True, text=True)
    if res.returncode != 0:
        failures.append("overlay does not reverse-apply: " + (res.stderr or "").strip()[:200])
    else:
        before = target.read_text()
        if "ottosel_cbridge" in before:
            failures.append("reverse-applied kscheme.cpp still defines the host counters")

if failures:
    print("A1.15 host-cbridge-counters guard: FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("A1.15 host-cbridge-counters guard: PASS (8 counters defined for non-iOS builds, iOS shell "
      "keeps its own copy, overlay reconstructs)")
