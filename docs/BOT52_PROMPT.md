# BOT52 — the camera packet is back; next is the player model and the frame budget

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT51_PROMPT.md`, whose N1-A framing ("the target is suspended") is **refuted**.
Read `AGENTS.md` first, then this file, then the tail of `docs/STATUS.md`.

## Product goal (unchanged, from the PRD and the gate loop)

Deliver an honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and controllable
under real input, a stable and correct camera, nonzero game PCM, clean lifecycle, and
sustained frame pacing. Signed-native and ROM-safe: no ISO or extracted game data in
Git, no RWX / `MAP_JIT` / trampoline code in the product path, users supply their own
data. Gates M0 / I0 / I1 / I2 / I3 / P1 / D1 are defined in
`docs/16-ipados-ios-goal-loop-2026-08-23.md` and are unchanged.

A build, a log, a counter, a first frame, a title screen, HUD text, or a
Simulator-only success is never playability proof. Gate N1 (training gameplay with a
visible, controllable Jak) is **not passed**.

## What this round inherited (all measured live, this session)

- Disk gate: `/dev/disk3s3s1 460Gi 12Gi 8.9Gi 57% /`, zero `.git/objects/pack/tmp_pack_*`.
  The operator explicitly authorized work below the repo's 40 GB rule; the hard stop
  remains any `tmp_pack_*` or below 5 GiB. Re-run `df -h / | tail -1` before every
  experiment.
- Device: `08636791-2675-4675-8335-EF72EF954DCF`, iPad Pro 11-inch (M4), iOS 18.5, booted.
- The presented frame is **live and animated**. Eight screenshots 1.5 s apart produced
  eight distinct md5s, and the status-bar clock tracks wall-clock. The earlier "frozen
  frame" and "blank frame" reads are both dead.
- `cam-entries` / `cam-accepted` climb monotonically with `cam-level-rejects=0`
  (604 -> 1414 -> 2175 -> 2947 -> 3721 -> 4441 -> 5203 -> 6013 -> ... -> 12941).
- Pacing in village1: chain advanced 1620 -> 2160 in 31 s, about 17 chains/s.
- The sky/VRAM dumps are written once at level load, not per frame (mtime stable over 6 s).

## The defect that this round closed

`ottosel_mobile_jak1_pc_port_bucket_candidate()` in `src/shell/mobile_generic_policy.h`
allowed only the merc-ledger union texture-upload bucket ids, but the 400-byte
`OttselPcPortData` camera/TFRAG3 packet is emitted by `add-pc-tfrag3-data` from
`tfrag-init-buffer`, the TIE draw, and the shrub draw, and those DMA ranges land in
`tfrag-0/1` (6/13), `tie-0/1` (9/16), and `shrub-generic0/1` (24/30). The camera
packet was therefore never scanned, `cam-entries` froze at 6994, and math-camera went
stale. The 512-transfer linear pass cannot compensate, because a heavy level's early
buckets exhaust that budget before the terrain buckets are reached.

The fix is the predicate now returning `bucket_id < 70u`, plus two bounded diagnostics
(`OTTSEL PC_PORT CAMERA`, `OTTSEL PC_PORT CENSUS`). Confirmation: the census walks
buckets 0-69 and `OTTSEL PC_PORT CAMERA: chain=3 bucket=6 n=11` finds the packet in
bucket 6 = `tfrag-0`, exactly as predicted, and `cam-entries` now climbs past 6994 with
zero level rejects.

## The open defects, ranked

1. **N1-B — the player model never submits during gameplay.** `eichar=722` is frozen
   across the whole village1 phase while `merc-submits` climbs past 25,000, and
   `eichar-attempts=722` equals `eichar`, so nothing is being culled after the fact:
   the packets are simply never produced. In training the level sends
   `scarecrow-a-lod0`, `scarecrow-b-lod0`, `money-lod0` and `crate-wood-lod0` and
   never eichar. Instrument where the player actor's draw node is reached before
   touching any matrix.
2. **N1-C — the merc transform looks degenerate.** `ottsel-metal-merc-draw.log` reads
   `projection=1 sign=1.0 indices=14244 first=(45010.852,-160.674,-22078.443)
   pc-row0=(0.000057,-0.000000,0.000000,-0.000000) raw-row0=(-0.400123,0.000000,0.000000,0.000000)
   trans=(0.000,0.000,0.000)`. A `pc_camera` row-0 x-scale of ~5.7e-5 against a raw
   perspective x-scale of -0.400 is a ~7000x collapse, which would flatten merc
   geometry to a line even if it were submitted. Careful: this probe fires once, at
   the first merc draw of the process, and `camera_trans` may simply not be populated
   on this path. Establish which of the two it is before editing.
3. **N1-D — the training target is never re-seated.** `OTTSEL ROUTE MARKER` reports the
   training target at `(-5393740.5000,28259.5332,4360945.5000)`, byte-identical to
   misty and ~5,000,000 units from the training origin. Second lead after the model.
4. **I1 pacing.** ~17 chains/s in village1 is not playable fluidity; the decode cache is
   ~99.5% hitting, so the remaining cost is elsewhere.

## Operating contract

- Never claim playability from a log, a counter, a menu, a HUD line, or a single frame.
  The exit bar for a gate is fresh, inspected, animated gameplay with real input.
- One falsifiable question per experiment, smallest possible change, before/after
  regression, exact route, explicit exit bar. Stop at the first failed gate instead of
  switching platforms as a workaround.
- Evidence cap: one concise document per proven gate (60 lines maximum) and at most
  eight appended `docs/STATUS.md` lines. `STATUS.md` is append-only.
- Do not open a new R-round until the `presentRGBA:` / `_MTLCommandEncoder` crash and
  the Jak 1 linker SIGABRT each have a root cause and a regression.
- Frozen without a proven source mismatch: the camera matrix math in
  `set_mobile_tie_camera`, TBP/lookup, strip-restart, the touch frontend
  (`build_touch_overlay`, `main.cpp:629-641`), and all iPhone work. If the camera matrix
  is the fault, write the finding rather than remapping it.
- Route input is file-triggered and polled every 30 main-loop iterations
  (`main.cpp:993`): `ottsel-press-start`, `ottsel-press-cross`, `ottsel-press-down`,
  `ottsel-press-left`, `ottsel-bg-village1`, armed with `: > "$W/ottsel-<name>"`.
  The correct branch is `CONTINUE WITHOUT SAVING` at index 4, not the index-3
  save-slot branch.
- Never `git add -A`. Never commit `docs/BOT46_PROMPT.md`, `docs/BOT48_PROMPT.md`,
  `docs/evidence/I1/BOT46-menu-text-renders.md`, or
  `docs/evidence/I1/BOT48-g1-pc-progress-path.md`.
- Simulator recording uses only the contract in `AGENTS.md` rule 1, under
  `/tmp/ottsel-video/`.

## Exit bars

- **N1-B:** `eichar-lod0 packets` climbs while `scene-level='training'`, measured with a
  route harness rather than by hand.
- **N1 (the gate):** a fresh frame burst during training gameplay shows Jak in the world,
  moves under injected input, and the camera frames him coherently.
- **I1:** sustained pacing with no per-frame disk write and no decode-cache regression.

