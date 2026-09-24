#!/usr/bin/env python3
"""Stage 0 reconciliation guard: every dirty nested delta is covered by a maintained overlay.

Stage 0 requires the dirty nested checkout to be reconstructible: each tracked modification or
untracked addition must appear in some `patches/*.patch`, or be an enumerated, unreferenced stray.
This walks `git -C out/jak-project status --porcelain`, collects the paths every overlay touches
(both `diff --git a/X b/Y` and `+++ b/X`, with directory entries matched by prefix) and fails when a
new uncovered delta appears.  The allowlist below is the documented stray set only: the accidental
`--help/` slice-output directory and the 0-byte, unreferenced `goal_src/jak1/kernel/aligner.gc`
(`game.gp` references `anim/aligner.gc`, not the kernel path).  Remove them, or overlay them, then
update this list.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
NESTED = ROOT / "out/jak-project"
PATCHES = ROOT / "patches"
STRAY_ALLOWLIST = {
    "--help/",
    "goal_src/jak1/kernel/aligner.gc",
}

if not NESTED.exists():
    print("Stage 0 overlay-coverage guard: SKIP (no nested checkout)")
    sys.exit(0)

status = subprocess.run(["git", "-C", str(NESTED), "status", "--porcelain"],
                        capture_output=True, text=True, check=True).stdout
dirty = [line.split(maxsplit=1)[1] for line in status.splitlines() if line.strip()]

covered_by = {}
for patch in sorted(PATCHES.glob("*.patch")):
    for line in patch.read_text(errors="replace").splitlines():
        m = re.match(r"^\+\+\+ b/(.+)$", line)
        if not m:
            m = re.match(r"^diff --git a/(.+?) b/", line)
        if m:
            covered_by.setdefault(m.group(1), patch.name)

covered, uncovered = [], []
for entry in dirty:
    if entry in covered_by:
        covered.append(entry)
        continue
    if any(path.startswith(entry) for path in covered_by):  # untracked directory entry
        covered.append(entry)
        continue
    uncovered.append(entry)

new_gaps = [u for u in uncovered if u not in STRAY_ALLOWLIST]
print("nested dirty entries: %d, overlay-covered: %d, uncovered strays: %d"
      % (len(dirty), len(covered), len(uncovered)))
for entry in sorted(uncovered):
    print("  %s %s" % ("ALLOWED STRAY" if entry in STRAY_ALLOWLIST else "GAP", entry))
if new_gaps:
    print("Stage 0 overlay-coverage guard: FAIL")
    for gap in new_gaps:
        print("  - add a narrowly scoped overlay (or document the stray) for:", gap)
    sys.exit(1)
print("Stage 0 overlay-coverage guard: PASS (every nested delta is overlaid or a documented stray)")
