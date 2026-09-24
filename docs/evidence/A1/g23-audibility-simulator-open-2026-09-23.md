# G2.3: the Simulator's audio device now opens, and the sound is tied to game events - 2026-09-23

Gate item: G2.3 audibility - "is real game output audible on a supported surface with the correct event
association", exit "ambient/effects, music and dialogue heard ... plus interruption and held-input
cancellation".

## A correction on record

`i2-audio-pcm-measured-device-open-blocks-2026-09-22.md` recorded that a default run's opener **hangs
forever** in `SDL_OpenAudioDeviceStream -> COREAUDIO_OpenDevice -> HAL_HardwarePlugIn_ObjectHasProperty`, so
nothing was audible on the Simulator and the work moved to "a Simulator-side workaround or the device lane".
**That does not reproduce today.**  In two consecutive runs (a plain launch, and a launch with the PCM capture
armed) the same build logs the success path:

    OTTSEL AUDIO: opening SDL output-only playback asynchronously selector=''
    OTTSEL AUDIO: SDL output-only playback stream opened device=21 paused=false
    OTTSEL AUDIO: opened playback route='System audio playback device'
    OTTSEL AUDIO: output callback observed after 1024 frames

No `SDL_AUDIO_DRIVER` was set, so this is the real CoreAudio device, not the `dummy` driver the earlier
evidence had to use.  What changed in the host is not established; the claim is only that the blocker is gone.

## Measured: the audio the device is handed

Route: title -> New Game -> Training, then a stick hold, then a background/foreground round trip.  PCM captured
by the `OTTSEL_AUDIO_DUMP=45` instrument to `ottsel-audio-dump.wav` and read back with `wave` and `numpy`:

    channels=2 sampwidth=2 rate=48000 frames=2160640 seconds=45.01 overall peak=32768 rms=4913
    per-second peak: 0-6 silent (boot/title) | 7-9 signal | 10 silent (level load) | 11-20 signal
                     21-22 SILENT (background pause) | 23-44 signal, peaks 32728-32768, rms to 14485

Ten of 45 seconds are silent and each is accounted for: boot, the level-load gap, and the two seconds the app
was backgrounded.

## Measured: the events the audio is tied to

Nineteen distinct sounds played, each the game's own PLAYER RPC for a named event, not a synthetic tone:

    frontend   cursor-up-down, select-menu, select-option, menu-close   (the driven route's own edges)
    movement   walk-grass1, walk-grass2, land-grass                     (the stick hold)
    swimming   swim-kick-surf, swim-idle1, swim-idle2, swim-stroke, breath-in-loud, breath-out-loud
    water      water-drop, water-lap-cls
    ambience   training-amb, bird-2, fly7
    event      warpgate-tele
    music      `Load music village1` (the level's bank), sustained rms 8.8k-14.5k in-level

Interruption, seen in the PCM and not only in the log: `OTTSEL LIFECYCLE: background input neutralized and
audio paused` at the two silent seconds, then `foreground controller rechecked and audio resumed` with signal
returning at second 23.  Four dangling references remain (`fly7` 2, `training-amb` 2, `water-lap-cls` 2,
`starts-options` 1) plus the carried `fire-pop` - the same data-reference class as before, not a pack defect.

Lane health: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`, `scene-level='training'`.

## Boundary

Proven: the audio substrate opens on the real device and is handed non-silent PCM reaching full scale; the
sound is tied to named game events including the frontend, movement, swimming, water, level ambience and a
level event; music loads; interruption silences and resume restores it.  **Not proven**: dialogue (no NPC
conversation on this route), and a human listening check - the measurement is that the real output device
receives the signal, not that an ear confirmed it.
