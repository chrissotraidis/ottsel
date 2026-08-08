# S1.2 evidence — iOS Simulator app shell

Date: 2026-08-08 (Bot 4). Gate: **S1.2 PASS** (Simulator).

## What was built

- `src/shell/main.cpp` — SDL3 iOS app: video-only init (renderer stubbed,
  no OpenGL/GLES/Metal), a Windowed window (no fullscreen flag), a visible
  window-surface fill, lifecycle logging via `SDL_AddEventWatch` (iOS
  delivers background/foreground events only through the watch callback),
  and a log file in the app container. No listener/REPL exists in the shell.
- `src/shell/Info.plist` — bundle id `com.ottsel.shell`, min iOS 18.5,
  `UILaunchScreen` present.
- `scripts/build-ios-shell.sh` — idempotent build: SDL3 3.4.10 static for
  iphonesimulator arm64 (`-DCMAKE_SYSTEM_NAME=iOS -DSDL_STATIC=ON`), shell
  compile with `-target arm64-apple-ios18.5-simulator -mios-version-min=18.5`,
  bundle assembly + ad-hoc codesign. Output:
  `out/jak-project/out/ios/app/OttselShell.app`.

## Proof (all captured under `docs/evidence/S1/`)

Device: iPad Pro 11-inch (M4), UDID `08636791-...-EF72EF954DCF`, iOS 18.5
runtime, booted with `simctl boot`; the only booted simulator.

    xcrun simctl install <udid> OttselShell.app
    xcrun simctl launch <udid> com.ottsel.shell   -> "com.ottsel.shell: 53163"

- `s12-shell-launch.png` / `s12-shell-window.png` — the app window is
  visible on the Simulator (dark-blue filled surface, no renderer).
- `s12-shell-log.txt` — full lifecycle log:
  - `SDL_Init ok (video only; renderer stubbed)`
  - `window created (no renderer)`
  - `window surface filled (headless renderer stub)`
  - Background (launched Settings): `WILL_ENTER_BACKGROUND` →
    `DID_ENTER_BACKGROUND (still alive)`
  - Foreground (relaunched shell): `WILL_ENTER_FOREGROUND` →
    `DID_ENTER_FOREGROUND (still alive)`
  - Process stayed alive through the whole cycle (same PID 53163).

## Notes / honest boundaries

- The lifecycle events log twice each (SDL posts them via both the watch and
  the queue; the watch keeps them). Cosmetic.
- iOS has no separate "window" concept: the app view fills the device
  display by platform design. No `SDL_WINDOW_FULLSCREEN` is used; the
  operator's no-fullscreen rule (macOS host windows) is respected.
- Renderer, touch UI, icons, marketing: none — S1 is a headless shell.
- Simulator evidence is never device proof.
