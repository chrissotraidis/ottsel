# G2 - first physical iPad run (2026-10-10)

Result: Ottsel boots and plays Jak 1 on a physical iPad, by touch and with a controller.
One device, one session; iPhone hardware, heat, battery and long play are still open.

## Device and build

- iPad Pro 12.9-inch (6th generation, iPad14,5, M2), iPadOS 27.0.1, connected by cable.
- Fresh checkout of jak-project 641fb572 + patches/ottsel-jak-project.patch; NTSC-U disc (SCUS_971.24).
- `scripts/install-ios-device.sh /tmp/ottsel-pack`: strict signed build (config/signed-game-strict.json),
  team wildcard development profile, installed with devicectl, pack copied to Documents/OttselUserData.
- Fix needed on the way: a wildcard profile (TEAM.*) was copied into the signature verbatim;
  build-ios.sh now signs as TEAM.<bundle id> (checked: VKDH2T9UTF.com.ottsel.shell).

## What ran (ottsel-runtime.log, about 29 minutes)

- OTTSEL F1 imported the validated pack on first launch; every module loaded through
  SIGNED MODULE ENTER/RETURNED; ottsel-fault.log stayed empty; no abort, SIGABRT or presentRGBA fault.
- Intro cutscenes, Geyser Rock training, then Sandover (village1) and beach/jungle assets linked.
- OTTSEL PERF: 874 one-second samples at 2732x2048, median 60.0 fps, 98.5% at 59 or above; the one low
  sample (17 fps) is the second after returning to the foreground. HOSTFRAME 104700 frames / 1750 s = 59.8.
- Audio mixing reported throughout (pcm-peak about 3000).
- QuickTime mirror showed Jak and Daxter in Geyser Rock with the touch overlay (frame inspected).
- Logged [error] lines are files the retail disc or pack does not hold: SAISB.STR and SAGWAD.ENG
  (absent from the disc), SCREEN1.USA (PS2 boot image, not packed). Harmless.

## Controller

- `OTTSEL GAMEPAD: pad0 acquired id=3 name=Xbox Series X Controller`; the player moved Jak with it.
- Found: gamepad input never hid the touch controls (only keyboard and mouse did). Fixed in
  src/shell/main.cpp: a button press or a stick push past a quarter of its travel hides them; a touch
  on the game view or a controller disconnect shows them again (OTTSEL INPUT lines log both).
- Rebuilt and reinstalled on the iPad: the log shows pad0 acquired, then hidden (button), shown again
  (touch), hidden again; the player confirmed it. The disconnect path was not exercised in this log.

## Touch layout editor and menu

- Found: the editor's Done bar sat at bottom centre, over START, so START could not be dragged. The bar
  now takes the first of top, bottom or middle that covers no control, and moves after each drop.
- The ••• menu follows BlueWake's hierarchy: Display (resolution, FPS), Cheats, Touch Controls,
  Game Data, Help & Feedback (Report a Problem on GitHub with device/OS/fps prefilled, Share Logs,
  Discord, GitHub), Diagnostics (log overlay, Jump to Level).
- Reinstall over the running app kept the save (bank0.bin) and settings; both were backed up first.
- Player check on the iPad after the rebuild: START drags in the editor and the new menu works.
  Second session: 197 samples, median 60.0 fps, ottsel-fault.log empty.

## Logs

- Kept locally (not in the repo): /tmp/ottsel-device-logs/run1 and backup-before-reinstall.
- On device: Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log and
  ottsel-fault.log; ••• → Help & Feedback → Share Logs… exports both.
