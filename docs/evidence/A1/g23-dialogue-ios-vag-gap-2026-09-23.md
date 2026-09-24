# G2.3 dialogue: the iOS path has no VAG dialogue player - 2026-09-23

Gate item: G2.3's dialogue leg.  The training level turns out to **have** dialogue, so the leg is reachable; it
is silent for a port reason, not a data one.

## Dialogue is reachable

My earlier note that the training level defines no `level-hint-spawn` was wrong - the grep was truncated by
`head`.  `training-obs.gc:109-129` defines seven hint volumes (`asstvb41`, `asstvb42`, `sagevb22`, `sagevb24`,
`asstvb48`, `sagevb21`, `sagevb27`), each `(level-hint-spawn ...)` gated on `(-> *setting-control* current
play-hints)` and fired by `process-release? *target*`.  Driving Jak forward from the start produced hint
activity in the log within one leg.

## Why it is silent, named

A voicebox plays its line as a sound named `spool-<name>` (`ambient.gc:287/329/335`).  The port has **two**
`RPC_Player` implementations in `game/overlord/jak1/srpc.cpp`:

    srpc.cpp:313  the desktop handler strips the `spool-` prefix, uppercases the name, `FindVAGFile` and
                 `PlayVAGStream` - dialogue implemented
    srpc.cpp:104  the `#ifdef OTTSEL_IOS` handler has no such branch, so a `spool-` name falls through to
                 `LookupSoundIndex` and is dropped

Measured on the lane: `OTTSEL AUDIO: PLAYER RPC sound missing name=spool-sagevb38 id=65782` and
`spool-asstvb40 id=65819`.  The cutscene path is silent for the same class of reason: `ja-play-spooled-anim`
(`loader.gc:734`) calls `str-play-async`, whose consumer is the PLAY-STR RPC (`stream.cpp` `RPC_PLAY`,
registered through the PS2 SIF), and the lane logs `OTTSEL SPOOL: start name=sage-intro-sequence-a ...
initial-pos=-1` - `current-str-pos` never leaves -1, i.e. no stream is playing.

## It is not a bank or pack defect

The voice lines are VAG entries, not bank sounds: `sagevb38`, `asstvb40`, `asstvb41` and `sagevb22` are absent
from all 24 `SBK` files, and the dialogue data is `VAG/VAGDIR.AYB` + `VAG/VAGWAD.ENG`.  The building blocks to
play them already exist: the shell reads VAGDIR/VAGWAD and starts a voice with `snd_StartVAGProbeShared` behind
the opt-in `OTTSEL_AUDIO_VAG_PROBE` (`src/shell/ios_boot.cpp:428-545`), and the sound engine has `VagVoice`.

## Next

Give the iOS path a VAG dialogue player: a `spool-` branch in the mobile `RPC_Player` that resolves the name in
VAGDIR.AYB and plays it.  The reader cannot reuse the fake-ISO root, which the banks own, so the VAG service
belongs on the shell side behind a bridge (the probe is already most of it).  That is a feature, not a tweak,
so it is left for its own round rather than half-wired here.

## Boundary

Proven: dialogue is reachable in the training level; the iOS path drops `spool-` names and never starts a
stream; the voice data is VAG, not bank.  Not proven: any dialogue is audible - it is not, on this path.  Lane
health during the drive: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`,
`scene-level='training'`.
