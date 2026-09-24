# G2.3 dialogue: the voice provably produces audio, and the stream stop is per-stream - 2026-09-23

Gate item: G2.3's dialogue.  Three results, in order of strength.

## 1. The VAG voice produces real audio (measured in isolation)

`OTTSEL_AUDIO_VAG_PROBE=1 OTTSEL_AUDIO_VAG_REFILL_PROBE=1` plays a VAG at boot, when nothing else is playing -
the clean isolation.  It produced

    OTTSEL AUDIO: VAG refill producer started entry=SA3INTRO initial-chunks=8 total-chunks=175 bytes=429809
    OTTSEL AUDIO: VAG refill producer finished entry=SA3INTRO chunks=175 bytes=4298096
    PCM: peak=30836, non-silent 7/9 seconds, per-second [0, 0, 684, 30736, 30836, 21282, 30684, 25518, 30788]

That is `snd_StartVAGProbeShared` - the same voice the dialogue player uses - so the voice path demonstrably
turns VAG data into output.  This is the substantive answer to "does the dialogue's voice work": yes.

## 2. The stream stop is per-stream now, and matches the desktop

The log showed plays and stops in the same second, and my stop was **global** - it would cut whichever line was
playing, not the one being stopped.  The PLAY-STR branch now resolves the same 8-character token for play and
stop (one shared `ottsel_play_token`), and the shell stops only the line the engine is actually playing:

    stopped name='NDINTRO '                       (only when it is the playing line)
    stop ignored name='NDINTRO ' playing=''       (otherwise)

This mirrors the desktop: its `StopVAG` does `snd_keyOffVoiceRaw`, so a stop there really does end the audio.

## 3. The game stops the cutscene lines immediately (observed, not root-caused)

Every cutscene line is played **and stopped in the same second** by the game's own commands - `NDINTRO` at 3366,
`LOINTRO` at 3367, `SAISA` at 3382 - while the training hints (`SAGEVB38`, `ASSTVB40`) get **no stop at all** and
therefore play in full.  So on this lane the cutscene narration is cut short by the game, and the tutorial hints
are the dialogue that plays completely.  Why the game stops those three immediately is not established: the log
has no spool abort or recover, only one `STALL-ART` line.  Recorded as its own open question.

## 4. Still open: the narration's share of the mix

At full volume the mix clips (peaks at 32768 in both the dialogue-on and dialogue-off runs), so peak cannot show
the narration, and the cross-run RMS comparison was lost because a reinstall rotated one dump away.  A same-run
measurement - a per-call off-switch and an aligned window, or a voice-level meter in the shim - is what would
close it.  The claim that stands is the one above: the lines resolve, the engine starts the voice, and that voice
provably produces audio.

Lane health throughout: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`,
`scene-level='training'`.
