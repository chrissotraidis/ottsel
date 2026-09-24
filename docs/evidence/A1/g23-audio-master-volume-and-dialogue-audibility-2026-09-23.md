# G2.3 audibility: "MUSIC VOLUME" is a master volume, and dialogue audibility is still open - 2026-09-23

Gate item: G2.3 audibility.  Two findings, one a correction to an earlier round's evidence and one an honest
statement of what is still unproven.

## The AUDIO setting is a master volume, not a music volume

The I3 round added an AUDIO row labelled `MUSIC VOLUME` and measured it in the lane's PCM (0 -> peak=0/rms=0,
100 -> real signal), reading that as the music group.  It drives `snd_SetMasterVolume(16, ...)`, and group 16 is
the synth master, so what that measurement actually showed is a **master** mute.  Measured directly: two runs
with the row set to 0 - one of which reached Training with its own level ambience - produced

    run A  120.00 s captured, peak=0 rms=0, non-silent 0/120
    run B  115.00 s captured, peak=0 rms=0, non-silent 0/115   (scene-level='training', fault 0)

Both were silent, level ambience included, so the control mutes everything.  A player setting "music" to 0 and
losing all sound is a defect, so the row is now labelled **MASTER VOLUME** - verified end to end by driving the
settings screen: `OTTSEL SETTINGS: changed section=AUDIO row=MASTER VOLUME value=90%` with `settings-tablet.cfg`
reading `1 0 90 0 100 0 100`.  A true music-only volume would need the music handler's own group, which is not
established yet.

## Dialogue audibility is still unproven

The A/B this was meant to be - suppress the VAG player with the new `ottsel-trace-vag-off` diagnostic and compare
the cutscene's audio - is confounded by the finding above: with the master muted, the suppressed run and the
normal run are both silent, so the comparison proves nothing.  What is proven about the dialogue remains exactly
what was claimed: the lines resolve, and the engine accepts and submits the voice (`started=1`).  It is **not**
yet shown that the narration contributes signal to the mix.

What would settle it, in order: a per-call version of the off-switch plus an aligned cutscene-window comparison at
full volume, or a voice-level meter in the shim that reports the mixed peak with and without the VAG voice.

## Two dead ends, recorded so they are not repeated

- `OTTSEL_AUDIO_VAG_PROBE=1 OTTSEL_AUDIO_VAG_REFILL_PROBE=1` produced no probe lines on this run, so the probe
  path did not fire and could not be used as the isolated voice test.
- One analysis read a dump left over from the previous run because the new run had not written one yet; delete
  `<writable>/ottsel-audio-dump.wav` before each capture.

Lane health throughout: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`.
