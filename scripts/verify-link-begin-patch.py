#!/usr/bin/env python3
"""Verify pin + h3 + linker overlay reproduce the three maintained source files.

Usage: python3 scripts/verify-link-begin-patch.py [--source out/jak-project]
Only a temporary directory is written; neither checkout nor Git index is changed.
This checks patch reconstruction, not execution of the C++ regression test.
"""

import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PIN = "641fb572e876750d8618434d9f7c1a531b43b366"
FILES = (
    "game/kernel/jak1/klink.cpp",
    "game/kernel/jak1/klink.h",
    "test/test_kernel_jak1.cpp",
)
PATCHES = (
    "h3-jak1-host-boot.patch",
    "jak1-link-begin-argument-regression.patch",
    # a11-signed-gstate-loader.patch also edits klink.cpp (signed-gstate include,
    # the link_and_exec signed hook, strict RX-flip aborts), so it belongs to the
    # reconstruction of these files; without it this check reports a false drift.
    "a11-signed-gstate-loader.patch",
    # a11-streamed-link-begin.patch adds the streamed `link-begin` signed-first
    # attempt in the same function, so it applies after the loader overlay.
    "a11-streamed-link-begin.patch",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "out/jak-project")
    source = parser.parse_args().source.resolve()
    with tempfile.TemporaryDirectory(prefix="ottsel-link-patch-") as directory:
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
    print("PASS: pin + h3 + linker + signed-gstate overlays match all three current source files")


if __name__ == "__main__":
    main()
