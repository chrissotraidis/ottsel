# Crash boundary gate — 2026-08-22

| Gate | Result |
|---|---|
| `presentRGBA:` upload | Guard added before `MTLSimTexture replaceRegion`: null, non-positive, and dimensions above 4096 are rejected. The 06:07 report additionally showed an open render encoder unwinding through `presentRGBA:`; `RenderEncoderEndGuard` now closes it during exception unwinding and normal completion. |
| Jak 1 linker | `jak1::link_begin` now rejects null args/data/name and non-positive object size before `jak1_jak2_begin`; the existing `link_and_exec` zero-size guard remains. |
| New pasted report | Not the original encoder assertion: PID 92785 terminated with `METAL Code 102` after `SimMetalHost` XPC interruption at `appendSpriteMeshNow:newBufferWithLength:`. This followed the prior forced SimRender shutdown and is recorded as host teardown, not an encoder fix. |
| Fresh regression | Rebuilt and strictly signed app launched as PID 97598 on the same booted iPad Pro Simulator. It remained alive through a 30-second window plus a 10-second capture; fault log was 0 B and unified-log scan found no encoder/Metal command-buffer failure. |
| Visual evidence | `/tmp/ottsel-video/encoder-guard-post-30s.jpeg` shows live textured geometry but detached/partial composition. This is not playability proof. |
| Video evidence | `/tmp/ottsel-video/encoder-guard-10s.mov` is 27 MB, bounded to 10 seconds with SIGINT, and post-check reported `no live recording`. |

The two supplied crash signatures are source-traced. The encoder fix now has a
fresh signed live regression without recurrence, but this remains a bounded
non-reproduction rather than proof of all Metal exception paths; keep the
crash gate under observation while resuming only the next source-defined
composition experiment.

## Audio/bootstrap regression

The first cold run with the Jak boundary trace hung before title: the UI thread
waited in `Player::InitOutput` while the SDL callback held the audio mutex and
logged through the shared logger during the link flood. PCM window publication
is now atomic and callback logging moved to `snd_PumpAudioInit`. Two fresh cold
launches reached title/bootstrap with output-only SDL playback and callback
telemetry; the fault log remained 0 bytes. Full audible AU1 proof remains OPEN.
