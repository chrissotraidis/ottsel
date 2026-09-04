# I1 selected TFRAG slot guard — 2026-09-03

Status: OPEN. This is renderer-fault evidence, not playability acceptance.

Question: does indexing the selected TFRAG LOD with no trees cause the title
route's `fault addr=0x140`?

Evidence:

- Disk gate before build: 84 GiB available; outer and nested temporary-pack
  counts 0.
- Before-failing regression: `MobileSceneSkipsMissingTfragGeometrySlot`
  failed to compile because the new contract was absent.
- After the smallest guard, the focused six-test scene/pointer/depth/TOD suite
  passed 6/6.
- Signed app: `out/jak-project/out/ios/app/OttselShell.app` assembled at
  2026-09-03 07:22.
- Fresh cold run used one iPad Pro 11-inch M4 Simulator
  `08636791-2675-4675-8335-EF72EF954DCF` for 25 seconds.
- The route reached `GAMEPLAY: enter title`, logged the title TFRAG snapshot
  (`geos=3`, one visible tree, four vertices, two triangles), and then still
  gated with signal 11 at `fault addr=0x140`.
- Audio opened and loaded COMMON (461) and VILLAGE1 (43), but `pcm-peak=0`.

Conclusion: the selected-empty TFRAG access was guarded and regression covered,
but was not the active title crash. The remaining `0x140` fault was an
unguarded selected-slot access in the post-camera diagnostic clip summary.
The same range contract now guards that consumer. No camera matrix,
TBP/lookup, strip-restart, touch, iPhone, or playability claim is authorized.

Follow-up range-validity regression passed; the next signed route reached
`after camera`, `after tfrag colors`, and `after tie colors` with no fresh fault.
The camera wrapper/method both entered and exited; prior route PCM reached 7146.
Renderer, controls, lifecycle, and playability gates remain OPEN.

Fresh post-fault frame `/tmp/ottsel-video/bot36-postfault-2026-09-03.png`
(SHA-256 `736eddfaea91832fa871be782bec00f08b7b4af84f56617e74da54707ed68078`)
and pre-armed no-MERC/no-TIE frames remained black/sparse with debug rectangles,
not Jak gameplay. The runtime reached Village1 and nonzero PCM without a fresh
fault, but those isolation frames did not identify Merc versus TIE as the cause.
The pre-armed no-depth probe reached Village1 without a fault, but remained
sparse/malformed, so depth is not the sole visual cause. The category
regression passes; envmap intervals remain excluded because ETIE inputs are
absent. The bounded clip-input probe recorded native TIE `x=68.374,w=35.547`
versus reference `x=-0.012,w=35.547`; camera math remains frozen by the goal.

Index-ledger retest: signed app rebuilt at 08:26 and ran 25 seconds. Fresh
frame `/tmp/ottsel-video/bot36-index-ledger-measured-2026-09-03.png` (SHA-256
`3fbe1caf5be7201f62adaba242880488fade4c00449409731288ff51515d2129`) remains
black/sparse with debug rectangles. Runtime emitted TFRAG 76,264/62,504 and
TIE 511,138/359,812 vertices/triangles; sampled strip counts matched, with no triangle-mismatch log. VU1STAT reached chain 810 (~38/s), PCM peaked at 4105,
fault log stayed 0 B, and local.ottsel grew 0 KiB (1601200 -> 1601200).
Index flattening has no observed count mismatch; visual/playability remains OPEN.

Reference-projection probe changed a few particles but remained malformed:
`/tmp/ottsel-video/bot36-tie-reference-projection-2026-09-03.png` (SHA-256
`8df2d8165369f2eeb3a18c0d382f0516304a849aaffdb2d5eaee08ae02413b68`). The
no-CPU-frame probe also remained malformed, proving the CPU base is not the sole
cause; both reached chain 810, PCM 3743, and zero fault bytes. Production remains OPEN.
