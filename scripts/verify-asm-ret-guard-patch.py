#!/usr/bin/env python3
"""Verify the a11-asm-ret-fail-safe overlay reproduces the maintained IR.cpp.

Usage: python3 scripts/verify-asm-ret-guard-patch.py [--source out/jak-project]
Only a temporary directory is written; neither checkout nor Git index is changed.
The h1/h2/h3 compiler overlays each apply to the pin alone but do not compose in
any tested order for goalc/compiler/IR.cpp, so a11-asm-ret-fail-safe.patch is a
pin-to-current snapshot that supersedes their hunks for that file; this check
proves pin + that one overlay reproduces the maintained file byte for byte.
"""

import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIN = "641fb572e876750d8618434d9f7c1a531b43b366"
FILES = ("goalc/compiler/IR.cpp",)
PATCHES = ("a11-asm-ret-fail-safe.patch",)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "out/jak-project")
    source = parser.parse_args().source.resolve()
    with tempfile.TemporaryDirectory(prefix="ottsel-ir-patch-") as directory:
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
    print("PASS: pin + a11-asm-ret-fail-safe.patch match the maintained compiler source")


if __name__ == "__main__":
    main()

