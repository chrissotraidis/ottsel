#!/bin/bash
# Capture or verify the whole nested OpenGOAL delta as one patch.
#
#   scripts/snapshot-jak-project.sh write   # refresh patches/ottsel-jak-project.patch
#   scripts/snapshot-jak-project.sh verify  # pin + patch must equal the live nested tree
#
# Reconstruction is: git checkout <PIN>; git apply --binary patches/ottsel-jak-project.patch
# The live nested index and working tree are never modified (a temporary index is used).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NESTED="$ROOT/out/jak-project"
PIN=641fb572e876750d8618434d9f7c1a531b43b366
PATCH="$ROOT/patches/ottsel-jak-project.patch"
MODE="${1:-verify}"

live_tree() {
  # Tree id of the nested working tree (tracked changes + untracked, non-ignored files).
  local idx
  idx="$(mktemp -t ottsel-snap-idx)"
  (
    cd "$NESTED" || exit 1
    export GIT_INDEX_FILE="$idx"
    git read-tree HEAD
    git add -u
    git ls-files -z --others --exclude-standard | grep -zv '^--help/' | xargs -0 git add -- 2>/dev/null
    if [ "${1:-}" = "diff" ]; then
      git diff --cached --binary "$PIN"
    else
      git write-tree
    fi
  )
}

case "$MODE" in
  write)
    live_tree diff > "$PATCH" || exit 1
    echo "wrote $PATCH ($(wc -c < "$PATCH" | tr -d ' ') bytes)"
    exec "$0" verify
    ;;
  verify)
    want="$(live_tree)" || exit 1
    scratch="$(mktemp -d -t ottsel-recon)"
    git -C "$NESTED" worktree add --detach "$scratch/tree" "$PIN" >/dev/null 2>&1 || { echo "FAIL: worktree"; exit 1; }
    got="$(cd "$scratch/tree" && git apply --binary --whitespace=nowarn "$PATCH" && git add --all -- . && git write-tree)"
    git -C "$NESTED" worktree remove --force "$scratch/tree"
    git -C "$NESTED" worktree prune
    if [ "$got" = "$want" ]; then
      echo "PASS: pin + patch == live nested tree ($want)"
    else
      echo "FAIL: pin + patch gives ${got:-nothing}, live nested tree is $want"
      exit 1
    fi
    ;;
  *) echo "usage: $0 write|verify"; exit 2 ;;
esac
