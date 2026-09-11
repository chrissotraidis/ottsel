# BOT43 — The camera is live; the sprite layer is the visible defect

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT42_PROMPT.md` as the active queue and keeps the same gate
contract (I2, I3, P1, D1). Read `AGENTS.md` first, then this file, then
`docs/BOT42_PROMPT.md` (defect inventory), `docs/STATUS.md` (tail), and
`docs/evidence/`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with **Jak visible and
controllable under real input**, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO or
extracted game data in Git, no RWX/`MAP_JIT`/trampoline code in the product
path, users supply their own legal data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Why BOT43 exists — the BOT42 framing is refuted

BOT42 concluded the app was "parked in the intro", that input never reached the
shell, and that the player mesh stops being submitted. Direct measurement on
2026-09-11 (iPad Pro 11-inch M4, UDID `08636791-2675-4675-8335-EF72EF954DCF`,
`com.ottsel.shell`, binary `756bbd1a35e5`) refutes all three:

1. **The camera is live, and the scene is live behind it.** Holding START then
   Cross through `target-title-wait` produced four consecutive screenshots
   showing four different world views (island overview, village hut exterior,
   interior plaza, grass slope). `OTTSEL SUBMITSTAT` shows
   `cam-accepted` rising 1:1 with `chain` and `merc-submits` rising ~90 per 90
   chains, i.e. one Merc submission per frame. The scene is not deduplicated
   and not latched.
2. **The overlay is the visible defect.** With
   `ottsel-trace-metal-scene-no-sprite` armed, every flat axis-aligned
   rectangle disappears and the frame becomes a correct, fully textured,
   correctly lit village (cliff rock, grass, palms, thatched huts, stone
   walls, wooden walkways, barrels). The rectangles are Sprite3 submissions,
   not scene geometry and not the sky.
3. **Two concrete sprite data defects are measured, not inferred.**
   `OTTSEL SPRITE IDENTITY` reports the 64x64 PSM19 texture at `tbp=0x24f2`
   decoding to `alpha-max=0 nonzero-alpha=0` (fully transparent), and
   `OTTSEL SPRITE ZERO TEX PRODUCT` reports Sprite3 groups arriving with
   `tex0=0x0000000000000000` (no texture register at all). Those zero-tex0
   groups are silently dropped by the native gate at
   `src/shell/metal_gfx.mm:4824` (`!adgifs[0].tex0_data`), which is why the
   rectangles cannot be attributed to them without a counter.

## Platform order (unchanged)

1. macOS stays frozen as the accepted behavioral/visual reference.
2. The active queue is the iPad Simulator (Gate I1).
3. iPhone parity (P1) and physical-device readiness (D1) stay behind a coherent
   iPad route.

Frozen until Gate C passes: camera matrix math (`set_mobile_tie_camera`),
TBP/lookup, strip-restart, the touch frontend, and all iPhone work. If the
camera matrix turns out to be the fault, write the finding instead of
remapping it.

## Disk precondition — user override in force

AGENTS.md rule 2 sets a 40 GB floor. The user overrode it and re-stated the
override on 2026-09-11 ("theres space to work, just keep working"). BOT43 runs
under that authorization. Measured at BOT43 start: `df -h /` Avail **14Gi**,
`tmp_pack_*` **0**. Still run `df -h / | tail -1` and count
`.git/objects/pack/tmp_pack_*` before every build; keep every worktree file
below 100 MB; never `git add -A`. The override covers working, not cleanup — no
deletion of user files.

## AGENTS.md rule 3 — both preconditions remain satisfied

The `presentRGBA:`/`_MTLCommandEncoder` crash and the Jak 1 linker SIGABRT were
both root-caused and covered (`docs/STATUS.md`; guard in `link_and_exec` plus
the GOAL `link-begin` wrapper; `ottsel-fault.log` measured 0 bytes across every
BOT43 launch). BOT43 may open a new round; re-derive if either reappears.

## Gate S1 — make the sprite layer correct or provably inert (blocking, new)

The sprite layer currently paints flat rectangles over a correct scene. Either
fix it or prove it cannot be fixed without the frozen surfaces.

- Attribute every visible rectangle to a specific Sprite3 group: extend the
  bounded counters so each natively drawn sprite group logs its `count`,
  `tex0`, decoded-texture alpha statistics, and clip-space bounds. No
  speculation: a rectangle must map to a group id or the layer is mis-modeled.
- Resolve the `tex0 == 0` Sprite3 groups. Decide from the desktop reference
  (`game/graphics/opengl_renderer/sprite3_3d.vert` plus
  `Sprite3.cpp`) whether a zero `tex0` is a legitimate colour-only draw
  (`sprite3_uses_texture` false, alpha forced to 1) or a parser defect. Do not
  invent a texture.
- Resolve `alpha-max=0` on `tbp=0x24f2` 64x64 PSM19. Compare against the same
  page decoded by the desktop renderer before touching any decode code.

Exit: the training-level village renders with whatever overlay the game
actually submits, and a fresh screenshot pair 8 s apart differs in the world
while the overlay either matches or is documented as inert.

## Gate S2 — route to New Game (blocking, new)

`target-title-wait` reacts to a real START edge
(`out/jak-project/goal_src/jak1/levels/title/title-obs.gc:665`) and loads
`progress` / `progress-draw` / `progress-pc`; `OTTSEL TITLE: start edge in
title-wait` fires, but `GAMEPLAY: enter village1` never follows.

- Drive the progress menu with the held-mask injector
  (`echo "<hex-mask> <reads>" > /tmp/ottsel-press-button`), which holds a real
  pad mask for N reads, instead of the same-frame keyboard tap used by
  `$W/ottsel-press-*` (press and release land in one frame and are flaky).
- Record which menu row is highlighted and which row confirms.

Exit: `GAMEPLAY: enter village1` followed by `enter training` in one launch,
reproduced twice, with the player mesh present in the frame.

## Gate A — loop health and observability (carried, hold)

The runtime log now grows ~2.15 KB/s (was ~58 KB/s) and `ottsel-fault.log` is
0 bytes. Keep the per-frame diagnostics trigger-gated and default-off.

Exit: log growth bounded by policy; a measured sustained frame rate is cited by
every later PASS/FAIL.

## Gate C / P1 / D1 (carried, blocked)

Camera-matrix remap, strip-restart, touch frontend, iPhone parity, and
physical-device readiness stay frozen until S1 and S2 pass.

## Next falsifiable experiment (do this first)

One launch, three arms, one screenshot each: (a) baseline, (b) `no-sprite`,
(c) `no-overlay`. For each arm capture the Sprite3 group ledger. Question: does
the rectangle set collapse to the groups whose decoded texture reports
`alpha-max=0`, or to the groups the native gate drops for `tex0 == 0`? Either
answer is decisive and both are cheap.
