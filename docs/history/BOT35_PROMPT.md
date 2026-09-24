# BOT35 — macOS-first Jak 1 playability, then mobile parity

> Historical: superseded by `docs/BOT36_PROMPT.md`. The user now accepts the
> current macOS build as the reference and makes iPadOS the active gate.

This is the active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`.

## Fixed product goal

Deliver an honestly playable native Ottsel Jak 1 build on macOS first, then
deliver the same goal on iPad, prove iPhone parity, and finish physical-device
readiness. Keep the product signed native code with no runtime executable-code
generation and keep the repository ROM-safe.

Do not redefine completion as a Mac boot, title screen, first frame, counter,
log, static build, blank/partial Simulator frame, or a technically valid
package. Playability requires a coherent visible game, real input, audio,
stability, lifecycle behavior, and fresh evidence.

## Mandatory platform order

1. Work on macOS only until the macOS stability/playability gate below is
   honestly closed.
2. Do not build, launch, replay, screenshot, or debug the iPad Simulator while
   macOS is still open or unproven. The iPad R1 experiment is paused.
3. After macOS passes, resume iPad source/resource parity and native visual
   composition, then iPhone parity, then physical-device gates.

Never run macOS `gk` and a Simulator at the same time. Use one runtime and at
most one booted Simulator. The Simulator must remain shut down during the
current macOS-only phase.

## Current verified state

- macOS is a bounded PARTIAL result: title → New Game → Village1 → Training,
  keyboard movement, interaction cycles, and a short coherent soak have been
  observed. It is not complete.
- Missing macOS proof includes a reproducible cold start with retained raw
  artifacts, explicit neutral/background/resume behavior, reliable audio and
  human audible acceptance, longer stability/controller evidence, and the
  complete native mouse+keyboard acceptance route.
- iPad is diagnostically bootable but visibly malformed/partial, has no Jak in
  the accepted frame, and has `pcm-peak=0`. It is not playable.
- R1 page-directory and aligned page/index lookup prefixes match macOS in the
  current source-side captures. The iPad first native 3D family still differs
  (`0x24d2` / `0x2004d2e59930a4d2`) from the macOS reference (`0x24f2` /
  `0x2004d1e59930a4f2`). No TBP remap, camera change, shader change, or Metal
  policy change is justified. Do not resume this trace until macOS passes.
- Crash boundaries have focused regressions: the SDL playback opener is
  joined and late streams are destroyed before teardown; platform input state
  has process lifetime; focused input is 5/5 and full `goalc-test` is 733/733.
  These are stability evidence, not playability proof.
- Native WASD and mouse input has reached the bridge in prior runs, but it must
  be accepted through the complete macOS route rather than inferred from logs.

Authoritative context is the current checkout, `docs/STATUS.md`,
`docs/13-current-state.md`, `docs/15-macos-to-mobile-goal-loop.md`, and the
latest dated evidence. Existing dirty changes, including the dirty
`out/jak-project` upstream worktree, are user-owned and must be preserved.

## First required work: close the macOS gate

Before any product action, audit:

- `git status --short` and the upstream worktree status/identity;
- `df -h / | tail -1`;
- `.git/objects/pack/tmp_pack_*` count and exact nested temp-pack paths;
- all `gk`, Ottsel, build, Simulator, and recording processes.

Then run one fresh Windowed native macOS `gk` from the current checkout. Retain
stdout, stderr, executable identity/hash, PID, timestamps, and fresh screenshots
outside giant worktree artifacts. Exercise, in one controlled run where
possible:

1. cold start → title → New Game → Village1 → Training;
2. native mouse and keyboard: W/A/S/D press and release, simultaneous movement
   plus action, mouse motion, primary/secondary button mapping, and focus loss;
3. explicit neutral input after every key/button release;
4. background/hide → resume/foreground, proving neutral input and resumed
   rendering without relaunch;
5. a bounded active soak long enough to expose the prior teardown/audio/linker
   faults;
6. audio output through the selected macOS route, with retained raw audio
   telemetry and a human audible acceptance when available.

If a clause fails, diagnose only that concrete macOS failure with the smallest
source-side change and a regression that fails before the fix. Do not switch to
iPad as a workaround. Do not call the Mac stable because the process remains
alive or because the title renders.

The macOS gate passes only when fresh evidence shows:

- coherent title, Village1, and Training frames;
- real mouse+keyboard gameplay controls, including release/neutral behavior;
- stable cold start and bounded active soak with no crash, assert, fault, or
  linker/encoder teardown marker;
- background/resume and focus-loss recovery with neutral input;
- audible playback or an explicitly documented external audio dependency;
- retained logs, screenshots, input transcript, lifecycle transcript, fault
  scan, and build identity.

If physical controller or human listening hardware is unavailable, mark only
that acceptance row externally blocked; do not promote the engineering gate or
silently substitute Simulator/iPad evidence.

## After macOS passes: resume the original queue

### R1 source/resource parity

Build the signed iPad app using the canonical
`patches/r1-texture-lookup-trace.patch`, one booted iPad Simulator, and one
runtime. Replay one fresh validated pack through:

`title-wait → Start → Cross → Down×4 → Cross`

Compare against the completed macOS run at the same phase:

- raw `OTTSEL TEX LOOKUP` page/index sequence;
- raw particle IDs;
- AdGif TEX0;
- native `first-tex0`/TBP;
- GOAL Sprite3 source immediately before DMA where needed.

If lookup differs, trace page-directory/FR3/DGO ordering and allocation. If
lookup matches, trace texture-object/data-family state, DMA ownership, and the
first native consumer divergence. Do not remap TBP or alter camera, shader, or
Metal policy without a falsifiable source-side result.

The Simulator’s blank/rotated/partial frame must remain explicitly labeled
non-playable until it becomes a coherent, controllable game scene. Capture
fresh screenshots and, only when necessary, bounded video under `/tmp/ottsel-video/`.

### Remaining gates

After R1, continue in order through native Direct/Sprite/material composition,
input/audio/lifecycle, legal user-data import and save persistence, iPhone
parity, and physical-device readiness. Do not import MAP_JIT, runtime
executable pages, dynamic trampolines, Jak 2 game changes, or an external Metal
shell.

## Evidence and disk rules

- One concise evidence document per proven gate, at most 60 lines, and at most
  eight appended STATUS lines. Do not create repetitive R-round paperwork.
- Never put a file larger than 100 MB in the worktree. Logs larger than that go
  to `/tmp` and are summarized. Never use `git add -A`.
- Add/keep `docs/evidence/**/*.mp4` and `*.mov` ignored; never store videos in
  `docs/evidence/`.
- The only permitted Simulator recording sequence is:

  `xcrun simctl io "$udid" recordVideo --codec=h264 "$out" & rec=$!`

  bounded sleep of at most 30 seconds, then `kill -INT "$rec"; wait "$rec"`,
  `ls -lh "$out"`, and an `lsof -c SimRender` check. Never use plain `kill`,
  `pkill`, SIGTERM, or `set -e` around a recorder. If SimRender still has a
  movie open, stop recording and report it before continuing.

## Operating loop

For every experiment: state the current evidence, one falsifiable question,
the smallest change, the before-failing regression, the exact live route, and
the exit bar. Inspect the actual runtime/screenshot, record PASS/OPEN/EXTERNAL
BLOCKED honestly, update one evidence note and STATUS only when the gate is
proven, then select the next missing clause. Keep this full goal active until
the iPad, iPhone, and physical-device completion definitions pass.
