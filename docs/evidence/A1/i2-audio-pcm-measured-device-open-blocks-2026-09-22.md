# Audio: the pipeline produces real PCM; the Simulator's device open never returns - 2026-09-22

Gate: I2 (audio).  Question: is the lane's audio merely *requested* by the game, or does the substrate
actually produce signal - and if it does, why is nothing audible?

**Instrument (opt-in, one overlay).**  `patches/i2-audio-pcm-capture.patch` adds a bounded capture to the
Apple playback callback in `game/sound/989snd/player.cpp`: with `OTTSEL_AUDIO_DUMP=<seconds>` the PCM the
callback hands to the SDL stream is written to `<writable>ottsel-audio-dump.wav` in the stream's own
format (S16, stereo, 48 kHz) and one peak/RMS line is logged per second of captured audio.  Without the
variable nothing is opened, written or logged.  The overlay reverse-applies, `pre + overlay` reconstructs
the file byte-for-byte, and the Stage 0 coverage guard still passes.

**The pipeline works - measured, not inferred.**  The capture only starts if the stream opens, so the same
run was repeated with `SDL_AUDIO_DRIVER=dummy` (which opens immediately):

```
OTTSEL AUDIO: SDL output-only playback stream opened device=21 paused=false
OTTSEL AUDIO PCM: second=1..9 peak=0 rms=0            (boot/title: silence)
OTTSEL AUDIO PCM: second=10 peak=6101 rms=589         (signal starts)
                  second=11 peak=8215 rms=1386
                  second=15 peak=9733 rms=699   second=17 peak=10003 rms=612
                  second=19 peak=10299 rms=674
OTTSEL AUDIO PCM: dump complete frames=960512 bytes=3842048
```

An independent read of the WAV (`python3 -c wave`) confirms 2 channels, 48000 Hz, 16-bit, 960512 frames
(20.01 s), overall peak 10299 of 32767 (~31% full scale), overall RMS 446, and **11 of 20 seconds carrying
signal**.  So the bank loads, the PLAYER RPC resolution, the voices and the mix all produce real audio; the
silence before second 10 is boot/title, exactly where the game has not started level audio yet.

**Why nothing is audible: the device open blocks forever.**  In a default run (no dummy driver) the opener
logs only `opening SDL output-only playback asynchronously` - never the success line
(`... stream opened device=... paused=...`), never any of the three failure lines.  A 3 s `sample` of that
process shows the opener thread at **1591 of 1591 samples** in:

```
std::__thread_proxy<snd::Player::InitOutput()::$_0>
  SDL_OpenAudioDeviceStream -> SDL_OpenAudioDevice -> OpenPhysicalAudioDevice
  -> COREAUDIO_OpenDevice -> SDL_WaitSemaphoreTimeoutNS -> _pthread_cond_wait
```

with the CoreAudio side parked in `AudioObjectGetPropertyData -> HAL_HardwarePlugIn_ObjectHasProperty ->
HALC_ProxyObject::HasProperty` and an `AudioQueueXPC_Server::Start`.  The host does have a working default
output device (`system_profiler`: "MacBook Air Speakers", 48000 Hz, default) and also a virtual
`Microsoft Teams Audio` device, so this is the Simulator's HAL property query hanging, not a missing
device - and the port's design already contains the hang (the game thread never stalls; the lane simply
stays silent).

Not claimed: **audibility is still not proven**, on this Simulator or on a device.  What is proven is the
producer side and the exact blocking call, which moves the remaining work to either a Simulator-side
driver/host workaround or the device lane (P1/D1), not to the game's sound code.
