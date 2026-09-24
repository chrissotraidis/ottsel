# L5: the route is drivable - holds move the frontend, the menu order is what is stale - 2026-09-22

Gate: L5 (route/input).  Question: now that the lane boots clean and the pad provably samples injected
keys, does driving the frontend work?

**Press semantics were the blocker, not the input path.**  The driver used `ottsel-press-*`, which is one
frame of button state; at this lane's 5-8 fps the frontend never saw it.  Switched to
`ottsel-hold-*` (which `src/shell/main.cpp` documents as what the game actually reads), the frontend
moves:

- title (`PRESS START`, screenshot `/tmp/ottsel-routeB-02-after-cross.png`) -> hold START 3 s -> **main
  menu** - the wooden wheel UI over the village1 background (`/tmp/ottsel-routeA-final.png` and
  `/tmp/ottsel-routeB-01-menu.png`), with `scene-level='village1'` and `merc-submits` climbing in the same
  log.
- continuing the sequence (cross, then four downs, then cross) returned the frontend to the *title*
  (`/tmp/ottsel-routeB-03-final.png`), i.e. the press at the wheel selected an item that leaves the menu.

Pad trace from the same runs (launched with `OTTSEL_TRACE_INPUT=1`): `buttons=0x8` (START) is always
delivered, and the later holds register as `0x40`, `0x4000` and `0x4040`, so every injected hold reaches
GOAL's pad.  `ottsel-fault.log` stayed 0 bytes in every run, and the lane boots in under 20 s
(346 modules) with the pack staged.

**What is stale is the route's menu model, not its plumbing.**  The August route expected
`title-wait -> Start -> Cross (accept screen=27 index=0) -> Down x4 -> Cross (Continue Without Saving)`,
and on the current build `Cross` at the wheel does not lead to the save menu.  The next step is bounded
and empirical: at the wheel, press Down first and screenshot, then Cross, screenshot, until the frame
shows the save menu and then the intro - and only then rewrite the driver's expected edges around what
the frames and `OTTSEL PROGRESS` lines actually show.

State: the lane is healthy (346 modules, title, 0-byte fault log), the driver presses with holds, and its
expected edges are marked stale in the loop.  Not claimed: no New Game/Village1 route proof yet, no
playability, audio or lifecycle acceptance.
