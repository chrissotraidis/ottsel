# R1 shared route-state marker — 2026-08-21

## Gate

Record the target-level New Game→Village1 transition state before comparing the
first Sprite3 producer group on macOS and mobile.

## Change

Added two bounded diagnostic `format` lines at the existing Jak 1 GOAL
`target-generic-event-handler` `level-enter` boundary in
`out/jak-project/goal_src/jak1/engine/target/target-handler.gc`:

```text
OTTSEL ROUTE MARKER: level=... trans=(x,y,z,w)
OTTSEL ROUTE MARKER: quat=(x,y,z,w) time=...
```

The change preserves game behavior and uses two calls because the GOAL format
function accepts at most eight parameters. It is carried by
`patches/r1-route-state-marker.patch` (SHA-256
`6bab40f30ff15f284ef997289634aaf9533dd98eba2c23497cc6a1aa37286244`).

## Focused proof

- First attempt with the default REPL ISA failed before the edited object:
  `Could not parse x30 as a register name` in the pre-existing ARM64 GOAL
  source. This was a wrong invocation, not a marker failure.
- Correct invocation: `./build/h1/goalc/goalc --user-auto --game jak1 --isa
  arm64`, then `(mi)`.
- After splitting the marker into two legal calls, `(mi)` rebuilt 292 targets
  successfully in 6.843 seconds.
- `git apply --check --reverse patches/r1-route-state-marker.patch` passed.
- `goalc-test --gtest_filter='Sprite3Native.*'` passed 12/12.

## Live proof and verdict

OPEN. The source change is compiler-proven but has not yet been rebuilt into a
fresh macOS and iPad app/runtime pair or captured live on both platforms. The
next experiment is to use this marker at the exact New Game→Village1 boundary,
then capture the first Sprite3 group and compare route position/quaternion,
frame setup, and resource tuple. No parity or playability claim follows yet.
