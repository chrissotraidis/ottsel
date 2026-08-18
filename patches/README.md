# Patches — canonical list

Target tree: `open-goal/jak-project` pinned at
`641fb572e876750d8618434d9f7c1a531b43b366`.

## Canonical patch (apply this one)

- **`h3-jak1-host-boot.patch`** — the full Ottsel diff vs the pin: ARM64
  goalc codegen (H1), no-emit runtime (H2), packaging shim (H2.5), and the
  Jak 1 host AOT boot to the GOAL kernel dispatcher loop (H3), plus the
  subsequent signed-native and S2.1 integration work, plus bounded macOS
  title-renderer forensics. 60 files.
  Verified: applies clean to a fresh pin worktree and reverse-applies
  cleanly against the working worktree (`git apply --check --reverse`).

## Superseded / historical (do not apply)

- `h1-arm64-goal-function-codegen.patch` — H1 slice only (subset of the
  canonical patch).
- `h2-noemit-runtime-host.patch` — H2 slice only (superset of H1; subset
  of the canonical patch).
- `h3-jak1-kernel-arm64-compile.patch` — H3 compile slice only (superset
  of H1/H2; subset of the canonical patch).

Apply only `h3-jak1-host-boot.patch`. The others are kept for bisection.

## Regenerating

From inside the pinned worktree with all local changes applied:

    git diff <pin> > ../patches/h3-jak1-host-boot.patch

Then verify on a fresh pin worktree with `git apply --check`.
