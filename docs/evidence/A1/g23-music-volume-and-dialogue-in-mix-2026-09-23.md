# G2.3 audibility: a real music volume, and the dialogue measured in the mix - 2026-09-23

Gate item: G2.3.  Two results, and the second is the one the dialogue thread has been chasing.

## The AUDIO setting is a music control now, not a master mute

The port's own `SetMusicVol()` (`game/overlord/jak1/ssound.cpp:189`) drives **groups 1 and 2** for music, while
group 16 is the synth master (`Player::SetMasterVolume` also calls `mSynth.SetMasterVol` only for 16).  The shell
was driving 16, which is why setting it to 0 silenced everything.  `apply_music_volume` now scales groups 1 and 2.

Measured with the row at 0, on the route to Training:

    before (group 16)   120.00 s captured, peak=0     rms=0     non-silent 0/120
    before (group 16)   115.00 s captured, peak=0     rms=0     non-silent 0/115
    now    (groups 1,2)  90.00 s captured, peak=16383 rms=951   non-silent 79/90

so the music is gone and the world's ambience stays.  `scene-level='training'`, 0-byte fault log.  The row is
labelled `MUSIC VOLUME` again; it was briefly `MASTER VOLUME` while it still drove the master, which was honest
for that behaviour but is no longer what it does.

## The dialogue reaches the mix (measured, music muted)

Muting the music is what made this measurable.  Driving Jak into the training level's hint volumes and reading
the captured mix per second:

    hints      SAGEVB38 at second 28 (its VAG is 153632 bytes ~ 5.6 s), ASSTVB40 at second 33 (~6 s)
    rms        ... 363, 6179, 4731, 2629, 2495, 1856, 1976, 1694, 1275, 1663, 2603, 2003, 2111, 365, 481 ...
    baseline   ~200-800 before and after

The mix's energy rises roughly eight to ten times at the exact second each line starts and stays elevated for
about the length of that line, then returns to the ambience baseline.  So the narration contributes signal to the
output - the claim the earlier rounds could only make as "the engine accepted the voice".

## Boundary

This measures the mix's energy, not a human hearing it - the listening check is still the gate's last piece.  The
lines measured are the training hints, which get no stop command and therefore play in full; the cutscene lines
are still stopped in the same second they start by the game itself, which remains its own open question.
