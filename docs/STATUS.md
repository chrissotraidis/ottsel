# STATUS - Ottsel

Authority: [GOAL_LOOP.md](GOAL_LOOP.md). The log below keeps its last eight lines.

## Board - 2026-10-12

Current gate: **G4 - a real playtest on the iPad** (G1 met in the Simulator; G2 and G3 met on a physical
iPad Pro 12.9-inch, M2).

- Device: iPadOS 27.0.1 at 2732x2048, 60 fps for 98.5% of a 29-minute session, by touch and with an Xbox
  Series X controller, 0 faults; PC saves load ([evidence](evidence/G2/g2-first-ipad-hardware-run-2026-10-10.md)).
  Open: iPhone hardware (G6), long sessions (heat, battery), a recorded full playtest (G4).
- Mac: the same app built with `OTTSEL_PLATFORM=macos`, menus in the menu bar; Geyser Rock 60 fps on an
  M3 Max. Open: uneven frame pacing seen in hand play, Developer ID signing and notarization.
- Play as Mario: Jak plays, libsm64's Mario is posed from Jak's state and drawn in his place; Mario's Moves
  adds triple jump and sideflip. Still being tuned on device.
- Delivery (G7): `padmint.json` + `scripts/build-personal.sh` build an unsigned IPA or a zipped Mac app
  and the game-data folder from the SCUS-97124 Black Label disc (other versions refused). PadMint 0.5.0's
  player check built the IPA from a fresh clone in 22 min; a Mac build plays the intro. PadMint lists
  Ottsel as not available yet until the repository is public with a release. Open: a sideloaded PadMint-built IPA on a device.
- Renderer: OpenGOAL's OpenGL renderer on OpenGL ES 3.0 from ANGLE on Metal; all 518 code modules signed,
  `OTTSEL_STRICT_EXEC` on for device and Mac builds.

## Log (last eight lines)

2026-09-26 Crash on quit fixed (audio pause after static teardown); iPhone 16 Pro Simulator boots to title with the full touch layout.
2026-09-26 Sprite/shadow buffers updated in place (no Metal buffer per flush). Sweep: 16 levels 47-59 fps, 0 faults.
2026-09-26 Audio dump clean (menu silence is the game pausing sound); TV cold/unplug/replug re-checked; README in the KartPad style with Discord.
2026-09-26 Sprites no longer stall on ANGLE restart scans; one 60 Hz pacer; palettes upload only when time of day moves. 12 of 16 levels at 60 fps; the rest are Simulator-GPU bound (51-57). 0 faults.
2026-10-10 First physical iPad run (iPad Pro 12.9 M2): intro, Geyser Rock, Sandover at 60 fps, 0 faults; controller hides/shows the touch controls; START drags in the editor; ••• menu in BlueWake order; new ottsel icon.
2026-10-11 Voice hints silenced all audio (heard on iPad): the iOS boot skipped goal_main's masterConfig.volume = 100, so scf-get-volume gave 0 and every hint ducked music, effects and dialogue to 0. Fixed in ios_boot.cpp; the same Geyser Rock hint now plays at full level (Simulator, per-second PCM peaks 4900-5700 vs 0).
2026-10-12 Play as Mario: Jak plays, Mario (libsm64, posed without his physics) is drawn in his place with a shadow; Mario's Moves adds triple jump and sideflip from Jak's flip jump; hat fixed. Mac app (OTTSEL_PLATFORM=macos): same app, menu bar, Geyser Rock 60 fps on M3 Max; quit no longer hangs.
2026-10-12 PadMint recipe: padmint.json + build-personal.sh; PadMint 0.5.0 player check passed from a fresh clone (IPA in 22 min); the zipped Mac app plays the intro; unsigned builds no longer carry an old provisioning profile; README gives the exact disc and ROM.
