# M1 title-logo forensics — 2026-08-17

## Scope

This is an M1 investigation record, not a playability pass. The target is the
macOS arm64 `gk` runtime at outer-repository commit `6ef5c77`; all game data,
logs, captures, and generated textures remain local.

## Visible evidence

The user supplied a current macOS title-screen capture on 2026-08-17. It
shows the title background, `the Precursor Legacy` subtitle, and `PRESS START`,
but the large `Jak and Daxter` logo is severely warped/fragmented with
incorrect red/orange/black regions. This establishes that the screen renders,
not that title rendering is correct.

The bare SDL `gk` executable was not enumerated by the available Computer Use
provider. A local, ignored `OttselDebug.app` wrapper now launches the exact
checked-out `gk` binary under bundle id `local.ottsel.debug`; Computer Use
captured the actual game title window after launch. M0 is therefore satisfied
as an observability harness, not as a visual-correctness pass.

## macOS audio/TCC containment

The current repair harness exports `OTTSEL_DISABLE_AUDIO=1`. The maintained
sound player logs `OTTSEL AUDIO: playback disabled ... no CoreAudio device
opened`, and `lsof` for that fresh game PID had no CoreAudio/AudioUnit handle.
The same Computer Use launch reached the title screen without a microphone
dialog. This is a deliberate temporary silence mode for graphics and ABI
debugging; it does not validate host audio and M1's audible-output requirement
remains open.

## New-game autosave regression — 2026-08-17

The former deterministic New Game → empty save-slot fault was reproduced with
`pc=0`, `lr=0`, and a native stack pointer 0x30 bytes beyond the auto-save
thread's recorded stack top. The bounded crash dump recorded the only
recognizable synthetic continuation 0x40 bytes below that faulting pointer.

`gstate.gc` had one ARM64-specific gap: its state-entry tail jump pushed
`return-from-thread-dead` but did not seed `x30`. The same required handoff
already existed in `reset-and-call` and `set-to-run-bootstrap`. The repaired
state path now sets `x30` to the pushed trampoline before the tail jump.

Validation was a full 546-target `goalc --isa arm64 ... (mi)` rebuild followed
by the same Computer Use-driven retail sequence. The `gk` process remained
live with no `OTTSEL CRASH` record and streamed from the title/save flow into
Village1 and Misty. This closes the single-reproduction PC=0 regression, not
the broader ten-minute retail stability gate.

## Bounded runtime instrumentation

The maintained source delta now accepts local, three-frame trigger files:

```sh
touch /tmp/ottsel-trace-buckets
touch /tmp/ottsel-trace-merc2
touch /tmp/ottsel-trace-sprite3
touch /tmp/ottsel-trace-tfrag
```

- Bucket trace records the exact Jak 1 bucket renderer and DMA span.
- Merc trace records raw DMA name, resolved model, matrix-slot endpoints,
  material contract, bound GL texture, and draw mode.
- Sprite trace records source texture/GS state and can dump the first-frame
  source texture to local `/tmp/` PPM.
- Tfrag trace records the copied PC-port camera packet without treating its
  fixed/GS-domain values as an error.

`ninja -C out/jak-project/build/h1 gk` and `git -C out/jak-project diff --check`
passed after these changes (only pre-existing compiler warnings were emitted).

## Fresh results

With every trigger armed before a fresh launch:

```sh
cd out/jak-project
touch /tmp/ottsel-trace-buckets /tmp/ottsel-trace-merc2 \
      /tmp/ottsel-trace-sprite3 /tmp/ottsel-trace-tfrag
./build/h1/game/gk -v --game jak1 -- -boot -fakeiso \
  > /tmp/ottsel-title-first-frame.log 2>&1
```

- The log reached `Displaying level title [display]` and `GAMEPLAY: enter
  title`.
- The first three observed dispatches contained only 16-byte bucket spans;
  Merc2 and Sprite3 submitted no models, draws, or sprites. Therefore this
  capture did not observe the producer event that generated the corrupted
  title image.
- Tfrag's later initialized title packet was captured. Its `hvdf.z` value is
  expected to be in the 8,388,608 fixed/GS domain, so the numerically large
  values are not corruption evidence by themselves.
- Earlier Sprite3 texture dumps captured a 64x64 flare and a near-white 32x32
  texture, not the title logo. Sprite3 is not yet an attributed cause.

## Follow-up runtime loop — title, input, and stack capacity

A later fresh macOS run (the local `OttselDebug.app` wrapper, with its child
`gk` process) materially improved the visible title: repeated Computer Use
captures showed an intact orange `Jak and Daxter` logo, subtitle, and
`PRESS START`, then a coherent New Game and save-file UI. This supersedes the
initial claim that the logo itself remained warped. It is **not** a visual
pass: the 3D title backdrop still fluctuates between very dark/black and deep
blue regions, so it needs a producer-side diagnosis rather than a blind
OpenGL blend change.

The three-frame Sprite3 trace during that observed title submitted 34 world
blocks / about 1,600 sprites per frame with stable texture IDs and stable GS
draw modes. TFR3 also reported rendering `title`, then `village1`. That proves
both paths are active but does not identify the source of the dark backdrop.

The new-game regression also exposed a second ARM64 capacity failure:
`sequenceB` attempted to suspend at 560 bytes on a 512-byte taskable process
stack. The maintained `process-taskable` allocation is now 640 bytes, matching
the arm64 16-byte saved-register slots. A full ARM64 `(mi)` rebuild passed and
the first subsequent title run showed no `ERROR: suspend`; this remains below
the required five-minute stability gate.

For input, the active user profile explicitly had `keyboard_enabled: false`.
The ignored local harness now sets `OTTSEL_ENABLE_KEYBOARD=1`; a bounded,
environment-gated log confirmed both that process-local enablement and native
SDL Return key-down/key-up delivery. Computer Use produces that pair too
quickly for SDL's held-key polling to turn it into a game action, so its
one-shot key press is not a physical-keyboard regression proof. Do not persist
the override or call keyboard control verified until a held physical/control
path visibly moves Jak and returns neutral.

The harness now also has a bounded, port-0-only left-stick diagnostic. In a
retail loaded `training` level, a 360-read hold moved the target from roughly
`(-5.393m, 28k, 4.364m)` to `(-5.352m, 30k, 4.398m)` and the logged release
returned it to neutral. This establishes game-level motion, but the current
Computer Use frame for the same real level is still almost entirely dark blue.
The level transition and TFR3 packet are live (`Displaying level training`,
`TFRAG TRACE ... level=training`), so the next experiment must inspect the
active TFR3 material/color producer; do not dismiss the frame as an unloaded
level, a title overlay, or an input failure.

## Next discriminating experiment

M0 must first make the running window observable. Then record a short video
from launch through the first stable corrupted title and arm the Merc, Sprite,
and bucket triggers immediately before the visual change. If a nonempty Merc
packet is seen, compare its matrices and material/GL state with the resolved
title asset; otherwise add one bounded probe to the active nonempty bucket,
not a renderer workaround. Do not change blending, texture conversion, or
GOAL title source until that producer path is identified.

## ARM64 `.ppach` time-of-day repair — 2026-08-17

The dark-blue Training capture had a producer-side cause before OpenGL.
`update-mood-itimes` builds the tfrag palette weights with four `.ppach`
operations. The ARM64 compiler lowered each underlying `VPSHUFLW/HW 0x88` as
if its selectors formed an in-place permutation. They do not: mask `0x88`
selects `[0, 2, 0, 2]`. The former cycle rewrite produced `[w0, w2, w1, w3]`,
corrupting the duplicated channels.

The correction in `goalc/compiler/IR.cpp` saves source halfwords 0 and 2 to
the reserved scratch registers, then writes the required duplicated lanes.
`tools/ottsel_a1/semantic_regressions.cpp` now guards that explicit lowering,
and `ottsel-a1-sem` passed. A full ARM64 `(mi)` rebuild was required before
launching the actual host game.

Live retail Training proof before the change was a three-frame TFRAG palette
capture with `rgba-avg=(0,0,97,128)`: red and green were identically zero.
After the rebuilt game reached `Displaying level training [display]`, the
same bounded capture reported tree averages `(110,110,114,128)` and
`(138,141,123,128)`, with nonzero red, green, and blue ranges. Computer Use
also captured an intact orange/green title backdrop, replacing the earlier
blue-only appearance.

This does **not** pass M1. In the loaded Training save, Computer Use still
shows a close-up of world geometry, even though the bounded port-0 stick
probe moves Jak and the camera. Treat the next issue as camera/transform or
save-spawn state; do not regress the palette fix or alter blending merely to
hide the viewpoint.

## Viewpoint control split — 2026-08-17

The macOS harness now also accepts a local `/tmp/ottsel-hold-right-stick`
file using the existing `x y port0-reads` bounded format. It applies only to
pad 0, returns neutral after the requested number of reads, and logs both
acceptance and release. A 720-read right-stick pulse changed the live
math-camera position and the Computer Use frame, proving that the view path
is responsive.

The non-writing `(bg 'village1)` route deliberately selects the first
`village1-hut` continue point. Its configured target position
`(-638860.06, 139319.7, 769990.6)` matched the live target immediately after
the route. Therefore its foliage/roof close-up is an expected consequence of
that debug continue point, not evidence that the repaired renderer embeds the
camera. It remains unsuitable as a final gameplay visual gate; the retail
Training save and a validated open-space continue point still need an
unobstructed, interactive macOS capture.

## Training camera handoff — 2026-08-17

The actual saved-game route reached `Displaying level training [display]` and
reproduced the close-up in Computer Use. This is not a bad saved coordinate:
the live target matched the configured `game-start`/`training-start`
positions in `level-info.gc`.

An exact GOAL-side probe in `target-continue` logged both the continue-point
row and the camera-combiner row immediately after assignment:

```
OTTSEL CAMERA START: cp "game-start" expected-r0=(-0.3536,0.0000,-0.9352)
OTTSEL CAMERA START: stored-r0=(-0.3536,0.0000,-0.9352)
```

The later live math-camera row is instead near identity. The handoff stores
therefore work; the subsequent `cam-fixed`/`cam-string` state path replaces
the intended orientation. The next probe must identify that state-path
producer or its ARM64 lowering. Do not modify continue-point data or tfrag
rendering to conceal it.

## Camera handoff narrowing — 2026-08-17

The bounded trace now covers the entire retail Training handoff. The saved
game reaches `Displaying level training [display]`; Computer Use still shows
the camera embedded in a brown terrain surface. This is repeatable after the
time-of-day repair.

The camera source math is correct. At initial string setup it produces the
expected target-relative forward row:

```
OTTSEL CAMERA COMBINER: result-r2=(0.9622,-0.1165,-0.2460)
OTTSEL CAMERA FRUSTUM: pitch-corrected-r2=(0.9677,-0.0469,-0.2475)
```

But the caller's tracker row becomes approximately positive Z before the
math-camera copy:

```
OTTSEL CAMERA ROTATE: pre-remove-r2=(0.0088,0.0742,1.0027)
OTTSEL CAMERA UPDATE: math-inv-r2=(0.0088,0.0742,1.0027)
```

`mat-remove-z-rot` preserves its input, so it is not the corruptor. The
frustum pitch matrix and the vector application also remain plausible. A
direct four-row copy in `slave-set-rotation!` was tested and did **not**
change the bad post-return row, ruling out that obvious temporary-copy form.

Current root boundary: an ARM64 GOAL vector/matrix state handoff around
`vector-into-frustum-nosmooth!` returns correct local data but the caller
observes the wrong matrix row on the next frame. Keep the four-frame
`OTTSEL CAMERA` traces while reducing this to one emitted register/memory
regression. Do not disable frustum clamping or hard-code a continue-point
orientation; those would conceal the compatibility defect rather than repair
it. M1 remains open.

## Camera basis and quaternion repair — 2026-08-17

The handoff was narrowed further with an A/B runtime probe: the no-blend
copy branch preserved the correct Training forward row and produced a clear
interactive scene, while the ordinary blend branch immediately collapsed to
positive Z. The blend inputs exposed the cause. Their rows were reflected:
the cross-product-generated right/up/forward basis had negative determinant,
so `matrix->quaternion` legitimately lost the missing rotation component and
the blend converged toward identity.

The ARM64 culprit was `IR_SwizzleVF::do_codegen_arm64` in
`goalc/compiler/IR.cpp`. It used an in-place cycle algorithm for every
swizzle; the outer-product/cross-product lowering uses duplicate selector
masks (`0x09` and `0x12`), not permutations. The emitted program therefore
overwrote source lanes before later lanes were read, reversing cross-product
orientation. The repair snapshots duplicate-selector sources in unallocated
`V31` before inserting result lanes. This is the same class of semantic error
as the previously repaired `.ppach 0x88` lowering, but affects 32-bit vector
lanes and camera geometry.

Verification after rebuilding goalc, all 546 GOAL targets, and `gk`:

- `ottsel-a1-sem` passed, including a focused duplicate-`IR_SwizzleVF`
  regression that requires the V31 immutable-source snapshot before the
  outer-product lane writes.
- Live Training blend quaternions became normalized with a nonzero Y
  component (`old-q=(0.0277,0.8391,-0.0429,0.5414)`), and its output forward
  rows remained plausible (`(0.9042,-0.1226,-0.4090)`), rather than collapsing
  to `(0,0,1)`.
- Computer Use captured a clear Training scene with Jak, terrain, foliage,
  and interactables; a bounded right-stick/left-stick pulse changed both the
  live camera/Jak positions and the visible scene without a fault.

The temporary no-blend containment was removed before this verification.
M1 is materially advanced but still open: retain short stability, real-audio,
and normal input coverage before declaring macOS playable, then add a focused
duplicate-swizzle regression and reduce the temporary camera trace volume.

## Fresh macOS Training retest — 2026-08-17

After restoring the source-level tracker copy and rebuilding the full GAME
group, a fresh wrapper launch again reached `Displaying level training
[display]`. Computer Use showed the intact Training scene, Jak, trees,
terrain, and collectibles. A bounded left-stick pulse changed the measured
Jak position from `(-5394922.5,28234.4,4358073.0)` to
`(-5319524.5,31168.0,4298097.0)` and the subsequent screenshot showed him in
a different location among the rock/chest cluster. The same process remained
alive for an additional 25 seconds with no `OTTSEL CRASH`, fatal, signal, or
exception marker.

The audio implementation is output-only: `Player` passes null input device
and input parameters to Cubeb. This establishes that the game does not ask
Cubeb to create a microphone stream. It does not establish audible playback
or a user-facing TCC dialog result; the debug wrapper therefore continues to
disable audio until that macOS route is validated without accepting
microphone access.

## Isolated New Game/autosave path — 2026-08-17

The earlier autosave/return-path failure was exercised without touching the
user's saves. The local wrapper temporarily used `--config-path` with a new
`/tmp/ottsel-newgame-config.*` directory, producing four empty save slots.
Selecting the first slot ran the real New Game flow through the autosave
symbols and progressed title → `village1` → `misty`; the live log includes
`GAMEPLAY: enter village1` and `Displaying level misty [display]`, with no
`pc=0` or crash marker. Computer Use captured the rendered opening misty
scene with Jak and Daxter. The wrapper was restored to the normal user save
path immediately after the test.

## macOS audio containment and provenance — 2026-08-17

The previous wording that implied a completed Cubeb start was stale and has
been corrected above. A fresh audio-enabled process reached `cubeb_stream_init`
and remained black at `OTTSEL AUDIO: creating output stream`. Its two-second
macOS sample is saved at `/tmp/ottsel-audio-hang.sample`; the IOP thread is
blocked in `AudioComponentInstanceNew` while CoreAudio creates the default
output I/O procedure, before Cubeb's buffer-size setup is reached. A narrow
buffer-size bypass was built and tested, then reverted because it could not
affect that earlier block.

The normal debug wrapper now explicitly sets `OTTSEL_DISABLE_AUDIO=1` again.
A fresh Computer Use launch reached the repaired, rendered title screen and
displayed no microphone permission prompt. This is temporary output-audio
containment, not a claim that Mac audio works. The next audio test must focus
on why `AudioComponentInstanceNew` blocks on this host; do not accept a
microphone permission dialog as a workaround. macOS still needs a real-audio
playback gate before it can pass.

## Explicit-output audio probe — 2026-08-17

`system_profiler` showed that the machine's default output is a virtual Jump
Desktop device while its default *system* output is the built-in MacBook Air
Speakers. Normal `afplay` output remained live. To separate that configuration
from the game, `Player` now has an opt-in `OTTSEL_AUDIO_OUTPUT_DEVICE`
substring selector: it logs the Cubeb output collection and passes the
matching device ID to `cubeb_stream_init`; no global macOS audio preference is
changed.

The selector found all six advertised outputs and selected `MacBook Air
Speakers` (two channels at 48 kHz), but the game again stopped at stream
creation. A second two-second sample at
`/tmp/ottsel-audio-speakers-hang.sample` is the same as the default-device
sample: `AudioComponentInstanceNew` blocks in CoreAudio while creating its I/O
procedure. Therefore neither the virtual default output nor Cubeb's device
selection is the direct cause. The selector is retained as bounded diagnostic
support; the normal wrapper is restored to `OTTSEL_DISABLE_AUDIO=1` and was
visually revalidated at the title screen without a TCC prompt.

## Native title, New Game, and opening gameplay — 2026-08-17

The earlier assertion that fake-ISO had no title VIS/STR data was false. A
fresh isolated run loaded `NDINTRO.STR`, `LOINTRO.STR`, and `VI1.VIS`; the
loader reported both `title` and `village1` loaded. The apparent failed Start
tests had happened before the title animation sent its `wait` event. Two
one-shot GOAL logs now mark that state handoff and an accepted Start edge.

On the fresh run, `OTTSEL TITLE: title-play received wait` appeared before the
host Start injection, followed by `OTTSEL TITLE: start edge in title-wait
abs=8 rel=8 progress=#f`. Computer Use then captured the normal New Game / Load
Game / Options menu. Selecting New Game and the first empty isolated save slot
used the normal save UI (four empty slots), not the `bg 'village1` diagnostic
bypass. The log progressed through `GAMEPLAY: enter village1`, `Displaying
level misty [display]`, and `Blackout loads done. Current status: misty is
loaded.` The initial black screen was the ordinary level-load blackout; a
subsequent Computer Use capture showed the opening misty scene with Jak and
Daxter.

A bounded left-stick input in that live New Game process changed Jak's logged
position from `(164305.7,15126.4,3390593.5)` to `(156920.6,13815.7,3459987.5)`
and the later screenshot showed a distinct misty camera/player position. No
crash, signal, or exception marker occurred. This proves the title, menu,
autosave slot selection, opening level transition, and basic movement route
on macOS; it does not yet prove a completed game playthrough or real audio.

The same run did report a nonfatal cutscene fidelity issue: fake-ISO requested
`SAISB.STR` for `sage-intro-sequence-b`, but the installed STR set has
`SAISA`, `SAISD1`, `SAISD2`, and `SAISE`, not `SAISB`. The source documents an
alternate spool name as known to crash, so no speculative alias or source
rewrite was made. The misty scene nevertheless completed loading and accepted
movement. Keep this as an explicit cutscene/content compatibility gate.

## Trace hygiene and native CoreAudio control — 2026-08-17

`TFragment` previously used a single `last_level` string for its level trace.
Because concurrently loaded `village1` and `misty` buckets alternate, that
logged almost every renderer invocation. It now retains a set of already
logged level names, producing one durable `OTTSEL TFR3: rendering level` line
per level. A rebuilt title run emitted only `title` and `village1`, with no
new crash marker.

The CoreAudio failure is not caused by running `Player` on Ottsel's IOP/libco
coroutine. The repository's `game/sound/sndplay` target constructs the same
Player directly from native `main`; an audio-enabled, bounded run still hung
after `cubeb_stream_init` at `AudioComponentInstanceNew`. Its sample at
`/tmp/ottsel-sndplay.sample` matches the game sample: CoreAudio blocks while
creating an I/O procedure. Therefore do not move sound initialization to a
different Ottsel thread as a speculative fix. Keep `OTTSEL_DISABLE_AUDIO=1`
in the local wrapper, retain the optional device-selection diagnostic, and
treat real playback as an external CoreAudio compatibility gate rather than a
microphone permission requirement.

The local debug wrapper now uses the game-native `-nosound` boot argument.
That route skips `InitSound_Overlord` before a Player or CoreAudio unit is
created, rather than depending on an in-Player escape hatch. A fresh normal
save-path launch logged `dkernel: no sound mode`, contained no Cubeb/AudioUnit
startup record, and Computer Use captured the intact title screen without a
microphone dialog. This is the default safe macOS launch while the independent
real-audio host gate remains open.

## Reproducible intro and purple-frame investigation — 2026-08-17

The host-only synthetic pad probe had been decrementing its shared button
duration once for each of four pad ports.  It now delivers and decrements
synthetic buttons only for pad 0, while keeping real controller input
unchanged.  This made the normal title route deterministic in a fresh run:
title wait, New Game, four Down edges to `Continue Without Saving`, then X.
Computer Use captured each menu state and the resulting purple gameplay frame.

The missing `SAISB.STR` request was replaced experimentally with the
project-mapped `sidekick-human-intro-sequence-b` / `SIHISB.STR` request.
The next real New Game run opened and streamed `SIHISB.STR`, proving the name
and asset mapping are correct.  It did **not** complete the cutscene: loading
still stalls on `sage-intro-sequence-a+0` because its
`sidekick-human-sage-intro-sequence-a` animation cannot find a master art
slot.  This source change must therefore remain an experiment until the
master-slot failure is fixed and B advances to C without a stall or crash.

During the visible purple frame, a one-shot three-frame TFragment trace saw
the village1 PC packet and 1,024 interpolated colors with nonzero RGB ranges
and a stable average near `(50,57,79,128)`.  The renderer is therefore
receiving a valid initialized background packet; this is not a generic empty
TFragment call.  The packet's enormous `fog.w` value is expected uninitialized
padding: GOAL writes only x/y/z, and the TFragment/Tie paths consume only those
three values.  It is not a candidate tint fix.  The remaining visual probe is
to attribute the bad frame to sky/direct composition or to a master-slot/scene
state after the A sequence is unblocked.
