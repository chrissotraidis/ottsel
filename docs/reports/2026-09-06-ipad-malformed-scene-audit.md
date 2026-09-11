# iPad malformed-scene audit — 2026-09-06 (read-only, no source changes)
Scope: review prompt `docs/BOT36_OTTSel_REVIEW_PROMPT.md`, prior audit
`docs/reports/2026-09-03-ipad-village1-render-audit.md`, current diff
(`metal_shell.mm`, `metal_gfx.mm`, `mobile_*_policy.h`, `build-ios.sh`,
`ios_boot.cpp`), I1/I2 evidence 2026-09-03, upstream `tfrag3.vert`,
`merc2.vert`, `tie_wind.vert`. Disk gate FAILS: `Avail 4.0Gi` (<40GB),
so no build/boot/record was run; static + retained-evidence audit only.
No playability claimed.
## Confirmed (code + logged evidence)
- Depth fix matches upstream (`glClearDepth(0)`+GEQUAL; `metal_shell.mm`
  clear 0 + GreaterEqual, `kOttselMobileDepth*`): correct, but
  `scene-no-depth` probe stays black/sparse — depth is not the sole cause.
- Level latch fixed: packet-level owner logs `title`→`village1`
  (`i1-level-ownership`); prior misty-latch falsified. Route still malformed.
- Merc raw-perspective fix matches `merc2.vert` (`perspective*skin`, not
  `pc_camera`): giant panels gone. `eichar-lod0` IS captured (chain 311,
  1712B, 2253 tris) — capture-coverage hypothesis refuted.
- TFRAG/TIE share one `tie_vs`, but upstream splits: `tfrag3.vert` has no
  Q/HVDF block, `tie_wind.vert` always applies it. Native gates it on
  `camera_sign<0` — wrong family contract; falsify by paired TFRAG-only vs
  TIE-only frames at same packet.
- Black regions are structural: sky/ocean/TIE TRANS+WATER/envmap/shrub and
  Direct/HUD product paths unimplemented or trigger-gated; Sprite3
  Village1 bucket-67 yields only 48-sprite MSCAL-3, no HUD/3D, with
  implausible camera-t — producer/2D-camera contract, not consumer drop.
- Audio structural fix partial: `jak1/srpc.cpp` compiled, PLAYER→
  `RPC_Player` yields `pcm-peak` to 15476; audible/interrupt/resume open.
- Pacing I/O gated (`OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`, container stable
  1601200 KiB): correct. Chain-rate variance (0.13/s vs 38/s) unexplained.
- Blocker unchanged: title `enter-state` SIGSEGV (`x20=0`, fault `0x140`)
  recurs; R-round rule bars new R-round until it + encoder crash regressed.
## Hypotheses (unproven, with falsifier)
- H1 Eichar behind near plane (clip-z −1.05, visible=0 across 32 packets):
  CPU skin sign/layout or perspective row/col vs `emerc.vert`. Falsify with
  one-vertex identity-bone projection regression + live clip-visible>0.
- H2 TFRAG NDC extremes (−422..438, −851..1606; 996/4129 visible): domain
  or frustum/bucket ownership, not pipeline loss (finite 4097, no index
  mismatch). Falsify by macOS-vs-native same-packet vertex correlation.
- H3 Cross-chain Merc loss (5-draw batch replaces 13-draw Eichar owner):
  missing game-frame boundary. Falsify with owner-tagged drain ledger.
- H4 Aspect stretch (~9% wide: 512/448 y-scale on full 2420x1668): needs
  upstream letterbox (`SCISSOR_ADJUST*HEIGHT_SCALE`). Falsify by letterbox
  frame vs macOS reference.
## Concrete next tests (regression-first, one change each)
1. Merc skinning audit vs `emerc.vert` + one-vertex projection test; capture
   clip-visible count and Village1 no-TIE/no-TFRAG Merc-only frame.
2. Split TFRAG/TIE vertex paths to upstream contracts; paired isolations.
3. Same-packet macOS/native TFRAG vertex correlation before domain edits.
4. Letterbox + depth-mode mapping review (NEVER/ALWAYS/GEQUAL/GREATER only).
5. Root-cause `enter-state` null process/state before any renderer change.
## Continue prompt for primary agent
Continue from this report + `2026-09-03-ipad-village1-render-audit.md`. Do
not touch camera math, TBP/lookup, strip-restart, touch, or iPhone. Smallest
next change: H1 Merc skinning/matrix comparison with before-failing
one-vertex `merc2.vert` regression. Evidence: clip-visible>0 ledger,
Merc-only Village1 frame, 0-byte fault log, chain≥30/s, `pcm-peak` noted.
