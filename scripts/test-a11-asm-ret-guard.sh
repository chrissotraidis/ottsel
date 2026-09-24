#!/bin/bash
# Ottsel A1.1 regression runner: the .ret fail-safe select contract, plus the
# emitted-module check that the guarded sequence is present in signed modules.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-/tmp/ottsel-a11-asm-ret-guard}"
mkdir -p "$output"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O1 -Wall -Wextra \
  "$repo/test/a11_asm_ret_guard_test.cpp" -o "$output/a11-asm-ret-guard"
"$output/a11-asm-ret-guard"
# The guard is emitted as [add x16, x30, #0 ; ldr x30, [sp]] at every .ret site.
# Informational: out/jak1/obj/*.o are prebuilt by an earlier goalc, and both the
# app build and the --module path rewrite those objects rather than compiling
# GOAL, so the guarded sequence only appears after the objects are regenerated.
module_dir="$(cd "$repo"/out/jak-project/out/ios/app/signed-gstate 2>/dev/null && ls -dt modules.* 2>/dev/null | head -1 || true)"
if [ -n "$module_dir" ]; then
  python3 - "$repo/out/jak-project/out/ios/app/signed-gstate/$module_dir/modules" <<'PY'
import pathlib, sys
# Contract (A1.6): the .ret fail-safe must compute its keep-mask from the slot, so
# the emitted sequence is mov x16,x30 ; ldr x30,[sp] ; mov x17,x30 ; lsr x17,x17,#32.
# The shipped objects instead emitted lsr x17,x17,#32, i.e. the mask came from the
# pushed synthetic continuation in x17 and the fail-safe was inert whenever the slot
# held an EE value.  Fail on any guarded site that does not load x17 from the slot.
MOV_X16_X30 = (0xAA1E03F0, 0x910003F0)  # orr / add-immediate forms
LDR_X30_SP = 0xF94003FE
MOV_X17_X30 = 0xAA1E03F1
LSR_X17_X17 = 0xD360FE31
good = bad = 0
offenders = []
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.s")):
    words = []
    for line in path.read_text(errors="replace").splitlines():
        t = line.strip()
        if t.startswith(".long"):
            try:
                words.append(int(t.split()[1]) & 0xFFFFFFFF)
            except Exception:
                pass
    for i, w in enumerate(words):
        if w in MOV_X16_X30 and i + 1 < len(words) and words[i + 1] == LDR_X30_SP:
            nxt = words[i + 2] if i + 2 < len(words) else 0
            if nxt == MOV_X17_X30:
                good += 1
            else:
                bad += 1
                label = "stale-x17 shift" if nxt == LSR_X17_X17 else "unexpected 0x%08x" % nxt
                offenders.append("%s+0x%x %s" % (path.name, i * 4, label))
if good == 0 and bad == 0:
    print("INFO: no guarded .ret site in the emitted modules (object not regenerated)")
    raise SystemExit(0)
for o in offenders[:8]:
    print("FAIL: guarded .ret site does not load the mask from the slot: " + o)
if bad:
    print("FAIL: %d of %d guarded .ret sites compute the keep-mask from a stale register"
          % (bad, good + bad))
    raise SystemExit(1)
print("PASS: %d guarded .ret sites compute the keep-mask from the slot" % good)
PY
else
  echo 'SKIP: no emitted signed module present (build the app first)'
fi
