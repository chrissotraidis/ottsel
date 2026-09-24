# G2.3 dialogue: the iOS path plays the VAG voice lines now - 2026-09-23

Gate item: G2.3's dialogue leg, which the previous round root-caused to a missing iOS VAG player.  This round
builds it.

## What landed

- **Nested** `game/overlord/jak1/srpc.cpp` (the `#ifdef OTTSEL_IOS` `RPC_Player`): a `spool-` branch that hands
  the line to the shell instead of falling through to the bank lookup, with the bridge declared at file scope
  exactly like `ottsel_ios_writable_dir`.
- **Shell** `src/shell/ios_boot.cpp`: `ottsel_ios_play_vag_dialogue(name8)`.  It parses `VAG/VAGDIR.AYB` once
  (807 entries: 8-character name + u32 offset **in 2048-byte sectors** - measured: `offset * 2048` lands on the
  `VAGp` header for every entry), uppercases and space-pads the name, reads the VAG from `VAG/VAGWAD.ENG`, takes
  the data size and 48 kHz rate from the header, sets the end-of-sample flag on the last ADPCM block exactly as
  the existing probe does, and starts it with the engine's own VAG voice (`snd_StartVAGProbeShared`).  The last
  four sample buffers are kept alive because the voice holds a raw pointer into them.

## Measured

Driving Jak forward from the training start fires the level's hint volumes, and each now resolves:

    OTTSEL AUDIO: VAG dialogue directory entries=807 wad=.../OttselUserData/VAG/VAGWAD.ENG
    OTTSEL AUDIO: VAG dialogue name='SAGEVB38' sector=62646 bytes=153632 rate=48000 started=1
    OTTSEL AUDIO: VAG dialogue name='ASSTVB40' sector=64563 bytes=163296 rate=48000 started=1

`started=1` is the engine's own return from submitting the voice, not an inference.  The two lines that were
dropped last round (`PLAYER RPC sound missing name=spool-sagevb38` / `spool-asstvb40`) now produce **zero**
`sound missing name=spool-` warnings, and the hint sequence completes - a second hint fires afterwards, so the
game does not stall waiting on a stream.

No regression: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`, `scene-level='training'`,
`Load music village1` still loads, and the lane's PCM dump is 120.00 s, peak 32768, rms 3793, non-silent
throughout gameplay (the same ten silent seconds as before: boot and the level-load gaps).

## What this covers, and what it does not

This is the path the level actually uses for dialogue - a voicebox hint plays `spool-<line>`.  The cutscene
path (`ja-play-spooled-anim` -> `str-play-async` -> the PLAY-STR RPC) is a different channel and is still not
wired on iOS, so cutscene narration remains silent; that is the next piece if it is wanted.  A human listening
check is also still outstanding: what is proven here is that the line resolves, the engine accepts and submits
the voice, and the mix stays non-silent.

## Verified on the phone lane too

The phone still had the pre-fix build, so the current one was installed there and driven the same way:

    OTTSEL AUDIO: VAG dialogue name='SAGEVB38' sector=62646 bytes=153632 rate=48000 started=1
    sound missing name=spool- warnings: 0     346 SIGNED MODULE ENTER = 346 RETURNED, fault 0,
    scene-level='training'
The voice-line path behaves identically on both classes.

## Disk: the build script leaks a generation per build

Measured, not guessed: `scripts/build-ios.sh:321` does `SIGNED_GENERATION="$(mktemp -d "$SIGNED_DIR/modules.XXXXXX")"`
and never removes it, so every build leaks a generation directory.  `out/jak-project/out/ios/app/signed-gstate`
holds 79 `modules.XXXXXX` plus 3 `aggregate.XXXXXX` directories totalling **13 GB** (largest 236 MB;
newest `modules.EQoUSg`, `modules.FoJD99`).  With the phone lane booted the volume read 38 GiB - below
40 GB floor - and returned to 45 GiB once it was shut down, so what breached the floor was the lane's own
container copy on top of the accumulated leak, not the product.  Reclaiming the leaked generations was put to
the user rather than done unilaterally, because deletion is gated in this workspace.
