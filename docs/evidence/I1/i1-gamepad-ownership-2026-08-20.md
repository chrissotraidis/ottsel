# I1 — selected SDL gamepad ownership boundary — 2026-08-20

## Result

**OPEN — the mobile shell now owns one selected SDL gamepad for pad 0, but
physical-controller acceptance remains unverified.**

## Source/build identity

- Outer Ottsel checkout: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Fresh iOS Simulator executable SHA-256:
  `46aea3d32b08806957d3b9147f011a7a80e38d64a7563bb926628b6e830cd008`.

## Before failure

`src/shell/main.cpp` initialized SDL gamepad events but did not enumerate,
open, retain, or identify a selected controller. Button and axis events were
therefore accepted without proving which device owned pad 0, and a removed
device had no explicit neutralization path.

## Change

The shell now enumerates `SDL_GetGamepads`, opens the first available device
with `SDL_OpenGamepad`, retains its `SDL_JoystickID`, filters button/axis
events to that owner, handles `SDL_EVENT_GAMEPAD_ADDED` and
`SDL_EVENT_GAMEPAD_REMOVED`, closes the selected device, publishes canonical
neutral state on disconnect, and selects an already-present replacement.

## Focused proof

```text
out/jak-project/build/h1/goalc-test --gtest_filter='PlatformInput.*'
[  PASSED  ] 2 tests.
```

The iOS build completed, strict codesign verification passed, and
`git diff --check` plus the upstream worktree diff check passed.

## Live proof and fault scan

No physical controller was available for this run. Therefore no active
controller, disconnect, or reconnect acceptance is claimed. The next live
experiment is one supported controller through add/open → input → remove →
neutral → reconnect, with the same `scePadRead` samples recorded at each
boundary.

## Verdict / next gate

**OPEN.** Continue I1 with a real controller replay when hardware is available;
touch customization and the remaining renderer/audio gates stay open.

## Follow-up touch-state correction

The same source audit found that the touch bridge used finger ID `0` as its
unassigned sentinel. The bridge now keeps explicit active flags for the left
stick, camera gesture, and action finger, so a valid zero-valued SDL finger ID
cannot be mistaken for an unowned region. Motion, release, cancellation, and
whole-state neutralization preserve the prior mappings. This is a source-level
correction; a fresh multitouch Simulator trace remains required before T1 can
advance.

Foreground resume also re-enumerates SDL gamepads, covering a replacement that
was connected while the app was backgrounded. This remains source/build proof;
hardware reconnect acceptance is still open.
