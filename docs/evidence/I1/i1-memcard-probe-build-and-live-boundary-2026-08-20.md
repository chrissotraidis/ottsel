# I1 memory-card probe: build and live boundary — 2026-08-20

## Result

This slice does not pass the mobile playable gate. It confirms that the
progress/memory-card method is active in the signed normal-Metal Simulator
runtime, but the first numeric probe is not yet a usable discriminator because
GOAL's `~D` formatter writes blank fields for these values.

## Build and source checks

- Re-read the fixed objective before continuing: 416 lines, 20,446 bytes.
- Rebuilt the GOAL image successfully: `Successfully built all 546 targets in
  8.943s`.
- Built and signed the iOS app with `scripts/build-ios.sh`.
- App executable SHA-256:
  The first probe build was `a376dd1ec71b6c393d512c04ee2eaf30838423a62258e71d92e3fd3efccfdbb5`.
- Focused regressions: 18/18 passed across DirectFixture, Sprite3Native,
  PlatformInput, and ARM64EmitterFloatMath.
- `codesign --verify --deep --strict` passed.
- Product source scan for `MAP_JIT|PROT_EXEC|pthread_jit_write|vm_protect`:
  zero matches.
- `git diff --check` passed.

## One-runtime Simulator observation

On the single iPad Pro 11-inch (M4) Simulator, the signed app launched with
the validated local user-data pack and stayed alive. Runtime evidence included
the normal level-loader path and repeated `Displaying level village1
[display-self]` records. The progress method then emitted repeated lines such
as:

```text
OTTSEL MEMCARD: requested= resolved= state= index= handle=
```

This proves the method is running, not what screen/card state it selected. No
visual or audio acceptance is claimed: this Simulator remains blank and
non-audible. The Simulator was shut down after the bounded observation.

## Next falsifiable slice

Replace the unsupported numeric formatting with a representation already known
to serialize in this GOAL build (or emit one field per supported `~A`/symbol
value), rebuild, and repeat one clean Start/Cross/Down route. The target is to
identify whether the normal-Metal path resolves `save-game-title` to a
memcard error state or reaches the option-4 continue-without-saving branch.
Do not expand Sprite3 batching or call this a playability pass until that route
and the native composition are independently proven.

## Literal-branch follow-up

The probe was then rebuilt with literal messages for the expected
`memcard-removed`, `memcard-not-inserted`, `memcard-format`, `memcard-no-space`,
`memcard-no-data`, `memcard-insert`, `save-game-title`, and `load-game` enum
values. The second signed app executable was
`c701a265d1c067658d9db7007c29023095663b6091815cee142323c9fd6d0a7b`, and the
same 18 focused tests, strict signing check, executable-marker scan, and diff
check passed. The bounded replay again loaded Village1 and emitted the blank
numeric probe, but none of those literal branch labels appeared. The next
probe must add an explicit default label and/or log the caller before the case;
the current evidence does not justify guessing which menu branch is active.

## Route discriminator follow-up

The enum-string probe then established the actual route: after Start and Cross,
the app repeatedly logged
`requested="save-game-title" resolved="save-game-title" state="save-game-title"`.
The card-info object was present, so this is not a missing memory-card pointer;
the app is parked in the New Game save-options screen. A Down trigger reached
the raw EE pad snapshot as `button0=0x40`; after the synthetic-edge seam fix,
the diagnostic reported `prior-rel=0x40`, but the GOAL progress consumer still
did not emit a Down navigation/accept edge in the bounded replay. The menu
consumer/input-history boundary is therefore the first open dependency, not
the renderer.

The synthetic seam change is intentionally narrow: while a headless diagnostic
press is active, `scePadRead` also exposes its button in the EE absolute/edge
history, and neutral reads remain unchanged. No game-specific route or
renderer shortcut was added.

The final cleanup rebuild then succeeded with all 546 GOAL targets, 18/18
focused regressions, strict codesign, zero product executable-page markers, and
clean diffs. The final signed executable SHA-256 was
`133f01d3b95f5d3a2df4bcc53cd69197d80dbddffaf9590bdeae7c35943f22fd`.

## Canonical-latch route pass

The file-trigger seam was then corrected to use the same canonical
`ShellPadInput::keyboard` press/release path as a real keyboard/touch action;
that path already latches brief digital taps across asynchronous pad reads.
The raw `scePadRead` history mutation was not retained.

With the signed normal-Metal app, one bounded replay produced keyboard-latched
Start, Cross, four Down edges, and a final Cross accept. Runtime evidence then
recorded `GAMEPLAY: enter village1`, continued Village1 `FR3` camera records,
and a live process during the follow-up window. The app remained blank and
non-audible in Simulator, and `ottsel-fault.log` remained 0 bytes. This is an
I1 route/liveness increment, not a visual playability or audio pass.

The final aligned signed build after removing the diagnostic raw-history
mutation passed the same checks; its executable SHA-256 was
`2460f9b20a133e3ce5e296d5d6da450b2cd384c3f02f179511b2837b2717f566`.
