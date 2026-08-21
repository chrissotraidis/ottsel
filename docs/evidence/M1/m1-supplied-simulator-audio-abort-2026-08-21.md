# M1 supplied Simulator audio abort attribution — 2026-08-21

## Gate

M1 audio/stability evidence only. This report is not a renderer or Sprite3
failure attribution.

## Supplied report identity

- Incident: `BFC94005-4B2F-4720-B685-FC2FAE80EEBA`.
- Capture: 2026-08-21 01:58:39 -0500.
- App UUID: `6c22f5bd-eb55-39f3-a42f-9d4d91550ad7`.
- Environment: iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`, hosted by arm64 macOS 26.5.2.

## Attribution

The process terminated with `EXC_CRASH (SIGABRT)`, but the triggered thread
was `10 SDLAudioP15`. Its native frames are:

```text
abort -> AudioQueueThreadEntry -> SDL_RunThread -> RunThread
```

The main thread was in UIKit scene invalidation, and the graphics worker was
still in `gfx_send_chain` while the process terminated. Separate BackBoard
threads show recursive `GameTextFontBank` destruction during process exit;
those frames are not the triggered thread and do not establish a renderer
use-after-free. No Metal, Sprite3, texture lookup, or native draw frame is on
the triggered stack.

## Verdict

OPEN. This is a real mobile audio/stability defect candidate: SDL's Apple
AudioQueue thread rethrew an Objective-C exception and aborted the process.
It does not change the current R1 resource/phase gate and does not justify
weakening the linker assertion, changing Sprite3 state, or claiming mobile
audio. The next audio slice must reproduce the abort with a bounded audio
enabled lifecycle route and capture the SDL/CoreAudio error or interruption
boundary before changing teardown.

