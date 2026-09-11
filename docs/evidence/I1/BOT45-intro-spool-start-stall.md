# BOT45 - the intro stall is Start arriving while the title spool is in flight

Round BOT45, 2026-09-11. iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, `com.ottsel.shell`.

## Correction to the carried framing

The carried note said "the Mac reference gets past the intro, the iPad stalls".
That comparison was confounded. `/tmp/ottsel-mac-ref3.log` never pressed
Start; the iPad run `/tmp/ottsel-ipad-clean.log` had Start injected
mid-intro. The difference was the injected input, not the platform and not the
loader.

## The experiment

Two launches, same build, same device, same pack, no Mac `gk` running.

- Clean, no injected input (`/tmp/ottsel-clean2.log`): all 15 `LOI2.STR`
  parts load in order, `logo-loop` reached once, `loader stall on art` = 0,
  `loader stall on lock` = 0.
- Start injected at `title-wait-ready` (`/tmp/ottsel-ipad-clean.log`, driver
  `/tmp/b43_route3.sh`): `loader stall on art logo-intro-2 12` = 309,
  `logo-loop` = 0, and the intro spool never finishes.

## Mechanism

`logo-init-by-other` (`goal_src/jak1/levels/title/title-obs.gc:421`) sets
`next-anim = logo-intro`. `logo` `startup` spools it, then sends `'wait` to
its parent, which enters `target-title-wait` (`title-obs.gc:633`), and only
then spools `logo-intro-2` (15 parts) followed by `logo-loop` - so Start
lands while a long title spool is already in flight.

`ja-play-spooled-anim` holds an `external-art-control` buffer across its wait

    (while (!= (file-status *art-control* (-> arg0 name) spool-part) 'active) ...)

(`engine/load/loader.gc:692`). `external-art-control` has exactly two
buffers (`loader-h.gc:136-145`). Start at `target-title-wait` calls
`activate-progress` -> `progress-screen title`, whose menu/level-art
reservation takes those buffers, so the wait can never satisfy. Part 12 does
link; the loop spins on the `seconds 4` abort timeout, which is also the source
of the ~4 s per-part cadence - identical on Mac and iPad, so there is no
disk-speed defect.

`loader stall on lock` = 0, so `*master-mode*` is `'game` and the spool lock
is free; the wedge is purely the art reservation.

## Consequence

Start is not lost: the same run reaches `master=progress` and the menu screen
enters `normal`. What never happens is `logo-loop`, and the loader burns its
timeout loop instead. The remaining user-visible defect after Start is that the
menu draws no text and no logo.
