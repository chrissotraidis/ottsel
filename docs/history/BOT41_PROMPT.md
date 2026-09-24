# BOT41 — iPad playability: make Jak visible, then settle the sky

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. It
supersedes `docs/BOT40_PROMPT.md` as the active queue and keeps the same gate
contract (I1-I3, P1, D1). Read `AGENTS.md` first, then this file, then
`docs/BOT40_PROMPT.md`, `docs/BOT39_PROMPT.md`, `docs/BOT38_PROMPT.md` for the
still-valid defect inventory, `docs/STATUS.md` (tail), and `docs/evidence/I1/`.

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

## Why BOT41 exists

BOT40 measured the scene correctly but spent its budget on the sky, which is
cosmetic. The PRD's own playability definition turns on **Jak visible and
controllable**, and that is currently failing: Village1 renders well (huts,
roof tiles, palms, terraces, water) but no Jak is on screen, while BOT40
finding 5 records every one of the 9942 Village1 Eichar vertices as
`visible=0`. BOT41 makes the character lane primary and keeps the sky as a
parallel lane.

## Platform order (unchanged)

1. macOS stays frozen as the accepted behavioral/visual reference.
2. The active queue is the iPad Simulator (Gate I1).
3. iPhone parity (P1) and physical-device readiness (D1) stay behind a coherent
   iPad route.

Frozen until I1 closes: camera matrix math (`set_mobile_tie_camera`),
TBP/lookup, strip-restart, the touch frontend, and all iPhone work. The sky
source address is frozen except inside lane L2.

## Disk precondition — user override in force

AGENTS.md rule 2 sets a 40 GB floor. The user has explicitly overridden it and
re-stated the override on 2026-09-11 ("theres space to work, just keep
working"). BOT41 runs under that authorization. Measured at BOT41 start:
`df -h /` Avail **14Gi**, `tmp_pack_*` **0**. Still run `df -h / | tail -1`
and count `.git/objects/pack/tmp_pack_*` before every build; keep every
worktree file below 100 MB; never `git add -A`. The override covers working,
not cleanup — no deletion of user files.

## AGENTS.md rule 3 — both preconditions are already satisfied

Rule 3 bars a new round until the `presentRGBA:`/`_MTLCommandEncoder` crash and
the Jak 1 linker SIGABRT are each root-caused and covered by a regression.
Both are: the crash report aborts in `link_control::jak1_jak2_begin` on a
zero-length GOAL object header (`docs/STATUS.md:2879`,
`docs/STATUS.md:1782`), the guard is in `link_and_exec` plus the GOAL
`link-begin` wrapper, and the focused suite passes 21/21 (`docs/STATUS.md:2892`).
Both reports are older app UUIDs than current builds. BOT41 may therefore open
a new round; re-derive this if either reappears in a fresh fault log.

## Verified starting state (measured 2026-09-11)

- HEAD `a1101c0`. Four `src/shell/*` files are modified and uncommitted
  (1268 insertions) and **contain the landed I1.1f registry fix**, so the
  working tree, not HEAD, is the current product candidate.
- Fresh frame `/tmp/ottsel-video/f.png` SHA-256
  `d5a954e629b84ebd3dccaa9c6f7f7c45d0b3eb564030350dc8af8ecbbd9411e8`,
  `nonblack(mx>40)=0.3182` — against 0.5603 for the same binary at `t=02:32`,
  which re-confirms BOT40 finding 2 (the camera is live; single-frame A/Bs are
  inside the noise floor).
- Sky: `SKYBOUNDFRAME n=40`; the 64x64 horizon fans sit at
  `y in [-0.009, 0.214]`, the 32x32 fans tile `|x| <= 4`; all report
  `a=0.502` or `a=0.000` with real UVs. The sky region still shows the
  `(0.03,0.04,0.07)` clear colour.
- `OTTSEL SKY REGISTRY` now reports `key-present=1` and
  **`meta-same-dest=1` for all three sky tbps (0x10/0x14/0x20)**. That
  refutes I1.1f's named next suspect: the sky dests do **not** alias, so the
  "give metadata provenance" fix is not the sky blocker.
- The decoded sky source is a grey mottle with rainbow CLUT speckles in both
  the registry path and the raw-VRAM path, and all four candidate CLUT windows
  (0x30/0x40/0x4c/0x50) produce the same rainbow. The sky source address is
  therefore still unexplained, not merely mis-palettised.
- The bright flat rectangles are the PS2 touch overlay
  (`src/shell/main.cpp:626-632`), confirmed independently.

## Gate I1 — scene correctness (ACTIVE)

### Lane L0 — camera-free comparison harness (first, blocking)

Single-screenshot A/Bs are void (BOT40 finding 2). Build the harness before
any further probe: from **one** launch, capture N screenshots across a fixed
wall-clock window per condition, and compare **distributions** — non-background
fraction, per-pixel difference against a same-condition baseline, and sky-region
fraction — instead of one frame. Land it as a repo tool with a fixed, documented
window and N. Every later PASS/FAIL in BOT41 cites this harness, not a lone PNG.

### Lane L1 — Jak visible and controllable (primary)

One falsifiable question: **which term puts the Village1 Eichar clip-z at
(-1.0543,-1.0405) when correct geometry must satisfy z >= -1?**

`clip_z = (cz*q + hvdf_off[2]) / 8388608 - 1`. A value whose maximum is
`-1.0405` is roughly 4% of the full range below the near plane, and the same
bundle spans ~1.06 NDC in y — about twice the frame height — so this reads as a
projection/scale outlier, not a skinning failure. Record, for the same frame:
the `perspective` matrix actually in force at the Merc draw, `hvdf_off`,
`fog[0]`, and `cw`; then decide whether the fault is in `q = fog[0]/cw`, the
`hvdf_off[2]` term, or the `/8388608 - 1` scale. Do not change
`set_mobile_tie_camera`; if the matrix is the fault, stop and write the
finding instead of remapping it.

Controls: the paired `scene-no-merc` / `scene-no-tie` triggers, a 0-byte
fault log, and a fresh `VU1STAT` chain rate.

### Lane L2 — sky compositing (parallel)

Unchanged question: **what texture is actually resident at the ADGIF's sky
tbp, and why does it decode to mottle rather than a gradient?** Given
`meta-same-dest=1`, pursue *address provenance* (which upload last wrote that
VRAM range and with which tbp) rather than CLUT choice or blend math, both of
which are already refuted. Compare against
`docs/evidence/M1/artifacts-2026-08-21-macos-stability-gate/11-post-soak-neutral.png`
(blue-to-purple gradient, pink horizon haze). Never synthesise a sky texture,
gradient, or placeholder.

Also still open here: the `SKYENDREDRAW` one-shot guard fires on pass 0 before
batches exist.

### I1.2 - I1.5

Unchanged from `docs/BOT40_PROMPT.md`: TFRAG vs TIE vertex contracts, aspect/
TOD/pacing, and the title `enter-state` fault. The Merc identity-bone lane is
promoted into L1.

Every I1 change needs a focused regression, a fresh inspected iPad frame with
its SHA-256 from the L0 harness, the paired controls, a chain rate from
`VU1STAT`, a 0-byte fault log, and one <=60-line evidence doc.

## Gate I2 — audio and lifecycle

Carried forward from BOT40: nonzero game PCM is measured
(`pcm-peak=9413`, `mixed 48000 frames`); what remains is *acceptance* —
audible confirmation on the accepted route, interruption, background/foreground
recovery, neutral input on focus loss or controller disconnect, save
persistence, and termination/relaunch. A peak counter alone is not acceptance.
Gate I2 opens only after L1 passes.

## Gate I3 — PS2 touch/controller frontend

Unchanged from BOT40: `ref/sunpad` is an interaction/menu/persistence reference
only; both sticks, D-pad, four face buttons, L1/L2/R1/R2, L3/R3, Start, Select,
multitouch, pressed/held/neutral feedback, editable normalized layouts,
controller handoff, safe areas, separate iPad/iPhone defaults, and the
persistent three-dot frontend. The overlay rectangles currently visible in
Village1 are this gate's placeholder, not a sky defect. Capture three visual
directions before implementing one.

## Gate P1 — iPhone parity

Run the accepted iPad route on one iPhone Simulator after shutting the iPad one
down. Rework, not merely shrink, the layout for phone reachability and safe
areas.

## Gate D1 — physical-device readiness

Verify signing/provisioning, legal user-data import, save persistence, install,
launch, input, audio, interruption, background/resume, and relaunch on a
physical iPad and iPhone. Simulator evidence alone never closes this gate.

## Operating loop

For each experiment: state the current evidence, ask one falsifiable question,
make the smallest change, add the before-failing regression, run one visible
route, inspect the screen, and record PASS or OPEN honestly. Stop at the first
failed gate instead of switching platforms as a workaround. Three repeated runs
against the same root blocker require a dated stop report, then an independent
gate.

Housekeeping owed before any product commit: revert the accumulated
diagnostic scaffolding (the four modified `src/shell/*` files carry 1268
insertions of probes alongside the I1.1f fix), commit the product change with
explicit paths, and never `git add -A`. Do not push without asking.

## Evidence budget (AGENTS.md rule 3)

One <=60-line doc per proven gate, at most eight appended STATUS lines. Stop
appending new dated STATUS sections: replace the stale top board with current
truth instead of growing the file.
