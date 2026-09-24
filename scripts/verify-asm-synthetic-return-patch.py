#!/usr/bin/env python3
"""Verify pin + h3 + vector-preservation + bridge overlays reproduce the maintained asm.

Usage: python3 scripts/verify-asm-synthetic-return-patch.py [--source out/jak-project]
Only a temporary directory is written; neither checkout nor Git index is changed.
This checks patch reconstruction of game/kernel/asm_funcs_arm64.s, which the
A1.1 C->GOAL synthetic-return fix changes.
"""

import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIN = "641fb572e876750d8618434d9f7c1a531b43b366"
FILES = ("game/kernel/asm_funcs_arm64.s",)
PATCHES = (
    "h3-jak1-host-boot.patch",
    "arm64-goal-vector-preservation.patch",
    # applied last: adds the synthetic return slot the GOAL asm-funcs read
    "a11-call-goal-synthetic-return.patch",
    # applied last: both remaining C->GOAL bridges preserve GOAL's register file
    # (x19-x28 + v8-v15), which the A1.7 fault probe showed were being destroyed
    "a11-goal-bridge-regfile.patch",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "out/jak-project")
    source = parser.parse_args().source.resolve()
    with tempfile.TemporaryDirectory(prefix="ottsel-asm-patch-") as directory:
        temporary = Path(directory)
        for name in FILES:
            target = temporary / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(subprocess.check_output(
                ["git", "-C", str(source), "show", f"{PIN}:{name}"]))
        for patch in PATCHES:
            arguments = ["git", "apply", *[f"--include={name}" for name in FILES],
                         str(ROOT / "patches" / patch)]
            subprocess.run(arguments, cwd=temporary, check=True)
        for name in FILES:
            reconstructed = (temporary / name).read_bytes()
            if reconstructed != (source / name).read_bytes():
                raise SystemExit(f"FAIL: reconstructed file differs: {name}")
            print(f"PASS {name} sha256={hashlib.sha256(reconstructed).hexdigest()}")
    print("PASS: pin + h3 + vector + bridge overlays match the maintained asm")


if __name__ == "__main__":
    main()
