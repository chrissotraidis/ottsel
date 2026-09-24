# BOT46 - the progress menu renders text on iPad (Gate G1 partly refuted)

Proven live on iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`.

## Question

BOT44's STATUS says the progress screen loads but "only its text and logo fail
to draw", and BOT45 carried Gate G1 as "make the title prompt and the menu
draw". Does the title menu draw text at all?

## Build under test

`goal_src/jak1/levels/title/title-obs.gc` restored to upstream Start behaviour
(immediate `activate-progress`) plus two diagnostic `format` lines.
TIT.DGO `7421fc02714448e47c30995878f03449b5138025a40c4983ebc69a2a385b0588`,
GAME.CGO `4bcdacefe1b2c71c93876e57fb36219f187aaf2763f27da5793de504a96937fc`
(unchanged). Signed and `simctl install`ed.

## Result

Screenshots in `/tmp/b47/060500/` (`sips -r 270`):

- `00_title_wait`, before Start: "PRESS START" is drawn on the title prompt.
- `03_plus15` and `04_plus30`, after Start: "OPTIONS" is drawn as a menu entry.

The press route also completes: `OTTSEL PROGRESS: normal screen=27 state=27
in-out=0` (`screen=27` is `progress-screen title`). Glyph rendering reaches the
iPad screen, so "the menu draws no text" is refuted.

## What is still wrong

- Only 1 of the 4 `*title*` entries renders. The list is
  `NEW GAME / LOAD GAME / OPTIONS / BACK` (`engine/ui/progress/progress-static.gc:54`);
  only `OPTIONS` is legible. The other three are absent, not dimmed.
- No menu backdrop/panel: the live Village1 frame shows through undimmed.
- `loader stall on art`=66 during the press, `link finish: logo-loop`=0,
  `link finish: logo-intro-2`=2 (the spool never completes once the menu opens).
  Fault log 0 bytes, no crash.

## BOT45 Gate V2 is withdrawn

Deferring Start until `(-> *art-control* active-stream)` is `#f` can never fire.
The title logo spools ~54 s by design: 15 parts at ~4 s each in the clean run
(`/tmp/ottsel-clean2.log` 42:37-43:36) and identically in the Mac reference
(`/tmp/ottsel-mac-ref3.log` 33:28-34:22). The loader is busy for the whole intro,
so the guard would silently drop the Start press instead of repairing it. The
earlier "309 stalls vs 0" contrast measured the menu being open, not a wedge.

## Next

Gate G1 becomes "why do 3 of the 4 menu entries not draw", not "no text".
See `docs/BOT46_PROMPT.md`.
