#!/usr/bin/env python3
"""Hunk-level validity of the documented overlay stack against the working tree.

The path-level coverage guard (scripts/verify-overlay-coverage.py) proves every changed
nested file is *named* by some overlay.  This asks the other half: does a patch's own text
still match the tree, i.e. does it reverse-apply?  Read the verdict carefully - the stack
is layered, so a patch that does NOT reverse-apply may simply have been edited by a later
layer (the canonical base patch cannot reverse-apply as a whole for exactly that reason),
not be stale.  What is actionable is a file no later patch touches whose only overlay no
longer matches; `--file PATH` names which patch actually reproduces a file.

Usage: python3 scripts/verify-overlay-hunks.py [--verbose] [--file PATH]
Exit status is non-zero only for the actionable class: a live-listed patch whose body is not
a valid unified diff at all (git reports `corrupt patch` / `only garbage`).  The README's own
health scan calls that group the only real defect, and it is how a11-loader-fail-closed.patch
was found.
"""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NESTED = ROOT / "out" / "jak-project"
README = ROOT / "patches" / "README.md"

DO_NOT_APPLY = ("Superseded / historical (do not apply)",
                "Malformed patch-file records (do not apply)")
OUTER_PREFIXES = ("src/", "scripts/", "config/", "test/", "docs/", "patches/")
MALFORMED_MARKERS = ("corrupt patch", "only garbage", "unrecognized input",
                     "patch fragment without header")


def documented_do_not_apply():
    """Patch names under a README section that says not to apply it."""
    if not README.exists():
        return set()
    names, inside = set(), False
    for line in README.read_text().splitlines():
        if line.startswith("#"):
            inside = any(marker in line for marker in DO_NOT_APPLY)
            continue
        if inside:
            names.update(re.findall(r"([A-Za-z0-9_.\-]+\.patch)", line))
    return names


def patch_paths(patch):
    paths = []
    for line in patch.read_text(errors="replace").splitlines():
        if line.startswith("+++ b/") or line.startswith("--- a/"):
            paths.append(line[6:])
    return sorted(set(paths))


def groups_by_root(paths):
    outer = [p for p in paths if p.startswith(OUTER_PREFIXES)]
    nested = [p for p in paths if p not in outer]
    out = []
    if outer:
        out.append((ROOT, "outer", outer))
    if nested:
        out.append((NESTED, "nested", nested))
    return out


def check(root, paths, patch):
    cmd = ["git", "-C", str(root), "apply", "--check", "--reverse"]
    for path in paths:
        cmd += ["--include", path]
    cmd.append(str(patch))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        return True, ""
    first = (result.stderr or result.stdout).strip().splitlines()
    return False, first[0] if first else "reverse-apply failed"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--file", metavar="PATH", help="name the patch that reproduces one path")
    args = parser.parse_args()

    if args.file:
        root = ROOT if args.file.startswith(OUTER_PREFIXES) else NESTED
        print(f"{args.file}: root={root.name}")
        for patch in sorted((ROOT / "patches").glob("*.patch")):
            if args.file not in patch.read_text(errors="replace"):
                continue
            ok, _why = check(root, [args.file], patch)
            print(f"  {'reproduces current content' if ok else 'does not match      '}  {patch.name}")
        return 0

    skip = documented_do_not_apply()
    patches = sorted((ROOT / "patches").glob("*.patch"))
    clean, stale, skipped, malformed = [], [], [], []
    touched = {}
    for patch in patches:
        paths = patch_paths(patch)
        touched[patch.name] = paths
        if patch.name in skip:
            skipped.append(patch.name)
            continue
        for root, kind, group in groups_by_root(paths):
            ok, why = check(root, group, patch)
            if ok:
                clean.append((patch.name, kind))
            elif any(marker in why for marker in MALFORMED_MARKERS):
                malformed.append((patch.name, kind, why))
            else:
                stale.append((patch.name, kind, why))

    print(f"overlay patches: {len(patches)}  documented do-not-apply: {len(skipped)}")
    print(f"whole-patch reverse-apply: {len(clean)} clean, {len(stale)} superseded by a later layer")
    print(f"malformed bodies (actionable): {len(malformed)}")
    for name, kind, why in malformed:
        print(f"  MALFORMED [{kind:6}] {name}: {why[:110]}")
    if args.verbose:
        for name, kind in clean:
            print(f"  reproduces [{kind:6}] {name}")
    for name, kind, why in stale:
        files = set(touched.get(name, []))
        others = [o for o in touched if o != name and o not in skip and files & set(touched[o])]
        note = (f"{len(others)} later patch(es) touch these files" if others
                else "no other patch touches these files - check with --file")
        print(f"  no      [{kind:6}] {name}: {why[:100]} ({note})")
    return 1 if malformed else 0


if __name__ == "__main__":
    raise SystemExit(main())
