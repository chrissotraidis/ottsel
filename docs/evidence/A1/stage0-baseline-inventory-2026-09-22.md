# Stage 0 baseline reconciliation - 2026-09-22 (post A1.13/A1.14)

Gate: Stage 0 (PROJECT_COMPLETION_PLAN.md) - resume safely, reconcile the dirty tree and prove the
named crash checks green for the current source before any new round.

Preflight: `df -h /` reports 64 GiB available (>= 40 GiB) and zero `.git/objects/pack/tmp_pack_*`.
One booted Simulator (iPad Pro 11-inch M4, 08636791-2675-4675-8335-EF72EF954DCF).

Named crash checks, run sequentially against the current tree:
- `bash scripts/test-metal-encoder-guard.sh` PASS (encoder scope, explicit end, ObjC/C++ unwind,
  exactly-once, nil).
- `bash scripts/test-link-begin-args.sh` PASS (production `link_begin_args_valid`, 6 malformed/valid
  cases).
- `python3 scripts/verify-link-begin-patch.py` PASS (pin + h3 + linker + signed-gstate overlays match
  all three current source files; `test/test_kernel_jak1.cpp` sha256 901aa0b7...).
Supporting guards re-run in the same pass and all PASS: `verify-asm-ret-guard-patch.py`,
`verify-asm-synthetic-return-patch.py`, `test-a11-call-goal-asm-ret.sh`, `test-a11-asm-ret-guard.sh`
(8 guarded `.ret` sites compute the keep-mask from the slot), `test-goal-bridge-regfile.py`.

Overlay reconciliation (new guard `scripts/verify-overlay-coverage.py`): the nested checkout has 180
dirty entries (147 modified, 33 untracked). 178 are covered by a maintained overlay in `patches/`
(matched by `diff --git`/`+++ b/` hunks, with untracked directories matched by prefix). The two
uncovered entries are documented strays, both unreferenced by the build: `--help/` (a stray
`ottsel-a11-slice` output directory holding `slice.s`/`slice.obj`/`a11_slice_map.h`) and
`goal_src/jak1/kernel/aligner.gc` (0 bytes; `game.gp` references `anim/aligner.gc`, and the compiled
`aligner.o` is the `anim` module). They are left in place; delete or overlay them and update the
allowlist in the guard.

Overlays added this pass to close real gaps: `patches/a11-diagnostic-traces.patch` captures the two
unoverlaid diagnostic GOAL deltas - the bounded BOT62 target-position trace in
`engine/gfx/shadow/shadow.gc` (gated by `*ottsel-target-trace-left*`) and the title-screen option
trace in `engine/ui/progress/progress-draw.gc` (gated on `display-state = title`). Both are
diagnostics, not behavior changes.

Identity of the tested build (Stage 0 step 6): `OttselShell` sha256
035f4d9a04ca7338af47d541ae74d7229f5f88fefb0096cc5297f979b1016105 in the build output and identical
in the installed bundle (`xcrun simctl get_app_container ... app`), so the running app is the tested
code; `GAME.CGO` sha256 7da4305e6118deb3a4bdc2342dec8dcd42ad425622db29dfde3f29f45c46bf89. Profile:
`OTTSEL_SIGNED_GSTATE_EXPERIMENT=0`,
`OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json`, `OTTSEL_SIGNED_EXPORT_BANKS=1`.

Behavioural baseline after the A1.13/A1.14 source fixes (evidence
`a11-kernel-stack-separation-2026-09-22.md`): two fresh strict runs with 0-byte fault logs, all 55
village1 DGO objects served, `LINKBEGIN: name=oracle` + `SIGNED MODULE ENTER/RETURNED` + `signed took
oracle`, 346 ENTER = 346 RETURNED, `scene-level='village1'`, and live draws
(`DIRECT FRAME drawn=44`, `SPRITE FRAME drawn=23`). Run 2 is still up after several minutes of
observation (`chain=2070`, `cam-accepted=17246`, 0 rejects, `merc-submits=27860`, `eichar=4`).

Known reconstruction gaps, enumerated: (1) the two strays above; (2) `tools/ottsel_a1*`,
`tools/ottsel_h1`, `tools/ottsel_h2` are untracked tool directories whose files the maintained
patches create, so a clean reconstruction must replay patches in the documented order rather than
`git apply --check --reverse`; (3) a full clean-checkout reconstruction driver does not exist yet -
Stage 0 records that gap, Stage 7 finalizes it. No product claim: visible gameplay under input,
audio, lifecycle/saves and level ownership are still open gates (I0/I1 onward).
