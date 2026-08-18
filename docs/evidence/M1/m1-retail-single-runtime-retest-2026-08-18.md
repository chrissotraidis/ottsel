# macOS retail single-runtime retest — 2026-08-18

## Scope

One Windowed macOS game process only:

```text
./build/h1/game/gk -v --game jak1 --config-path /tmp/ottsel-newgame-config.KmBHyH -- -boot -fakeiso -nosound
```

The temporary config directory created four empty slots, so the New Game
autosave test did not touch user saves. The wrapper was restored to its normal
launcher behavior before this record was written. No iPad Simulator was booted
or launched during this run.

## Verified live route

Computer Use captured the real title, New Game screen, four empty save slots,
Naughty Dog intro, Misty cutscene, and playable Training scene. The concise
runtime milestones were:

```text
GAMEPLAY: enter title
OTTSEL TITLE: title-play received wait; entering title-wait
OTTSEL TITLE: start edge in title-wait abs=8 rel=8 progress=#f
GAMEPLAY: enter village1
OTTSEL SPOOL: start name="sage-intro-sequence-a"
OTTSEL SPOOL: start name="sidekick-human-intro-sequence-b"
GAMEPLAY: enter misty
OTTSEL SPOOL: start name="sidekick-human-intro-sequence-c"
OTTSEL SPOOL: start name="sage-intro-sequence-d1"
OTTSEL SPOOL: start name="sage-intro-sequence-d2"
Displaying level training [display]
GAMEPLAY: enter training
```

This includes the formerly fragile autosave/process-spawn and B-intro
boundaries. No `pc=0`, `OTTSEL CRASH`, fault, assertion, or fatal marker
appeared through the five-minute Training soak.

## Input proof

A bounded pad-0 stick hold (`x=128 y=0`, 180 reads) was accepted at 09:00 and
returned to neutral at 09:03. The trace recorded Jak moving from
`(-5366969.5, 27571.9, 4336418.5)` to
`(-5319285.5, 30924.0, 4299180.5)`, where the subsequent sample remained
stable. Computer Use's before/after Training captures show the corresponding
camera/player relocation. A Cross (`0x4000`) action pulse was also delivered
to pad 0; its brief animation was not claimed as a still-frame action proof.

### Corrected action-state proof

A second fresh, isolated run used
`/tmp/ottsel-newgame-config.2N3LPX`, again with one macOS game window and no
booted Simulator. It completed the canonical title/New Game/A/B/C/D1/D2 route
to Training. The `-nosound` VAG timing bridge selected and advanced the fake
clock for the readable A-sequence stream:

```text
OTTSEL VAG CLOCK: id=66059 fd=open nosound=true selected=fake
GAMEPLAY: enter training
```

The action probe originally read the process transition-hook and heap-base
fields as state values. It now reads the actual `process.state` and
`process.next-state` fields (+52 and +72 after the process-tree header). The
same bounded three-read pad-0 inputs then proved the complete action path:

```text
Cross  (0x4000): current=target-jump   pending=target-jump
Circle (0x2000): current=target-attack pending=target-attack
```

The visible Training frame remained coherent after both actions. This is live
GOAL state-transition evidence, not an inference from raw controller bytes.

## Sky-chain visual repair

The open Training capture's black upper background was a real ARM64 graphics
defect. A bounded `SkyRenderer` trace first established that both title and
Training received the complete 64-byte setup plus three GIF packets; the live
VU1 mask also has the sky bit. Replacing the `sky-direct` base-0 fallback would
therefore have been a wrong consumer-side fix.

The next bounded probe found the actual producer failure. `SkyBlendCPU` saw
real copy work (`sky=1/1`, `cloud=1/0`), but its output buffers were all zero.
Both blend routines were enclosed in `#ifndef __arm64__`, leaving them no-ops
on the native macOS build. They now use portable byte-wise intensity scaling
and saturating accumulation on ARM64. The new focused regression
`SkyBlendCPU.ScaledCopyAndSaturatingAccumulate` passes.

Fresh live verification on the single macOS process produced nonzero output:

```text
title sky avg:    (81,155,236,128), cloud avg: (119,119,119,128)
Training sky avg: (126,148,207,128), cloud avg: (119,119,119,128)
```

Computer Use then captured a repaired blue/purple title sky, an intro with
blue stars, and Training with blue sky above the foliage. The canonical retail
route still reached Training, and Cross/Circle again reached `target-jump` and
`target-attack`.

The legacy per-draw MIPS2C TFRAG dump was also made opt-in with
`/tmp/ottsel-trace-tfasm`; one trigger captured exactly three complete
assembler calls rather than continuously writing the runtime log.

## PC big-memory particle queue repair

A later single-runtime Training soak exposed a real but bounded gameplay
compatibility defect: after the Training handoff, the live log emitted
`sp-launch-particles called during processing, and queue is full`. The queue
is used while the particle update holds its launcher lock, then drained by
`sp-clear-queue` at the end of that update.

The PC configuration explicitly enables `PC_BIG_MEMORY`, and the surrounding
sprite allocations already scale for it. However,
`sparticle-launcher.gc` had its conditional disabled and permanently used the
console queue capacity of 32. The restored conditional uses 80 entries for
`PC_BIG_MEMORY` and preserves 32 for the console path. The focused
`SparticleQueueCapacity.UsesBigMemoryCapacityOnPc` test passes; it locks the
compiled-source contract to the exact `80 / 32` conditional. A full ARM64
`(mi)` rebuild then completed all 546 affected targets.

Post-fix, the only active macOS `gk` process (`94093`, isolated save config)
completed title → New Game → A/B/C/D1/D2 → Training. It reached
`Displaying level training [display]` and both `GAMEPLAY: enter training`
milestones, then ran for a further 25 seconds with zero queue-full, crash,
assertion, or fatal records. Computer Use captured the coherent Training
frame. No Simulator was booted during this retest.

The same patched process then completed a five-minute Training soak with flat
resident memory (about 795 MB after the level transition) and steady CPU
(about 31% of one core), still without queue-full, loader-stall, crash, fault,
or assertion markers. Its final bounded input trace again proved Cross in
`target-jump`, Circle in `target-attack`, and a neutral-returning stick hold
that moved Jak from `(-5393129.0, 28317.5, 4362849.5)` to
`(-5319244.5, 30902.9, 4299241.5)`. A final Computer Use capture shows the
rendered, playable Training scene after that input.

## Boundary retained

Audio remains intentionally disabled with `-nosound`. The current macOS host
blocks output-only Cubeb at `AudioComponentInstanceNew`; this is not a reason
to accept a microphone permission. Do not start iPadOS/iPhone testing while a
macOS game runtime is active.

### 2026-08-18 static-link discriminator

One direct, non-bundled `build/h1-static/game/gk` run linked SDL statically,
selected `MacBook Air Speakers`, created and started the output-only Cubeb
stream, observed an audio callback, and reached `target-title-wait`. It never
receives an input device or input parameters. The same static executable
launched through `OttselDebug.app` instead blocked immediately after
`OTTSEL AUDIO: opening output-only Cubeb stream`; it did not reach stream
creation. That proves the direct static success is not yet a bundled-product
audio pass. The regular bundled launcher remains `-nosound`, and no
microphone permission is to be accepted while this bundle/TCC boundary is
unresolved.

The runtime now enforces that containment for all ordinary macOS Jak 1
launches: `game/main.cpp` appends `-nosound` unless
`OTTSEL_ENABLE_HOST_AUDIO=1` is set. The focused
`MacHostAudioPolicy.RequiresExplicitOptInForJak1` regression passes. A fresh
bundled window launched with the wrapper deliberately omitting `-nosound`
logged the policy decision, received `arg 3 : -nosound` in the game runtime,
reached the Naughty Dog intro, and showed no microphone dialog. The absence of
audible sound in that run is intentional containment, not a successful audio
gate.

A second one-process bundled probe removed the explicit `MacBook Air
Speakers` selection, so Cubeb used its default output unit. With host audio
explicitly enabled, it still stopped at `OTTSEL AUDIO: creating output stream`
before graphics initialization. It did not enter any input path and no dialog
was accepted. This falsifies the explicit-speaker/HAL-output selection as the
cause; the unresolved boundary is bundled CoreAudio stream creation itself.
The process was terminated and the prompt-free `-nosound` launcher restored.

A final static-SDL control foreground-execed `build/h1-static/game/gk` from
the app launcher with explicit `MacBook Air Speakers` output. It likewise
stopped at `OTTSEL AUDIO: creating output stream`, before graphics or stream
creation. This falsifies both dynamic-SDL linkage and background-child
launching as sufficient explanations in the launched-app context. The direct
foreground terminal success remains a narrower host-control result, not a
product audio pass.

## 2026-08-18 TFRAG platform-boundary retest

The normal far-terrain call in `tfrag-methods.gc` was verified against the
retail reference and a fresh canonical title → New Game → A/B/C/D1/D2 →
Training replay. A one-shot Training trace observed populated far-TFRAG lists
of 1,332 and 28 entries, valid scratchpad transfers, and the PC-port Training
renderer drawing 12,764 and 1,732 terrain triangles in each of three frames.

The trace exposed a separate platform-boundary defect: the legacy iOS Metal
scratchpad bridge wrote its DMA chain/QWC into `tfrag-work`'s macOS
wait-statistics fields. It is now guarded by `OTTSEL_IOS`, with
`TfragPlatformBoundary.IosScratchpadStashIsNotActiveOnMac` locking that
contract. The rebuilt macOS replay repeated the populated trace and emitted
no `OTTSEL TFRAGSTASH` record. Cross and Circle again entered `target-jump`
and `target-attack`; a 180-read stick hold returned to neutral and the visible
Training scene remained coherent. No Simulator was booted.
