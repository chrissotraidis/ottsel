# BOT8 Handoff — S2.2 blocked: "the level never activates" — investigate, unblock, and produce a composed frame

Date: 2026-08-16.  From: the S2.2 continuation loop (BOT21g–u).  To: the
next investigation bot.  Goal: deeply investigate what IS and ISN'T
working, unblock the level activation, and drive Ottsel to a verified
composed frame (the S2.2 gate).

## Targeted goal prompt (feed this to the next bot)

> Investigate the Ottsel (native Jak 1 on the iPad Pro 11-inch M4
> Simulator via Metal) S2.2 blocker: the game boots and runs with zero
> faults and Metal presents real Jak textures, but NO composed geometry
> frame appears because the village1 level never activates.  The
> bsp-header relocate returns success yet the level slots end
> `'inactive` with bsp=0, and the background-work list stays empty every
> frame (tfrag-count=0, tie-count=0) so the bsp's 11 drawable trees
> (including the tie instances 6+42/2+14) are never drawn.  Deeply
> investigate what is working and what is not (read the evidence trail:
> docs/evidence/S2/s22-reorientation.md + s22-bot21*.md/log + the handoff
> below), fix the smallest falsifiable fault so the level reaches
> `'alive`/`'active` and the background engine draws the bsp's trees (the
> tie bucket chains appear), OR — per Track B — compose a visible frame
> from the LOADED tie geometry through the shell's renderer (tie
> instances + tie.txt microcode + the proven VU1/GIF/rasterizer path).
> Verify every claim against the running app, bundle logs, and compiled
> ground truth (type-system offsets minus the basic offset, checked
> against disassembly).  One Simulator, one runtime, Windowed.  Record
> milestones in docs/evidence/S2/ and update STATUS.md / 13-current-state.md
> / 00-loop-log.md only after a verified gate.  Never patch game source
> to mask runtime bugs; never commit ROMs/ISOs/assets.  Stop and report
> honestly at any gate that repeats three consecutive blockers.

## The blocker chain (all verified live)

1. The runtime boots and runs the real game (KERNEL.CGO + GAME.CGO link,
   dispatcher loops, title-obs, process tree, 0 faults).  S2.1 verified.
2. Metal presents real Jak textures (the present path + GS un-swizzle
   decode; village tpage 0x1cf tex 44 visible).
3. The village1 geometry LOADS: the bsp-header linked (type
   'bsp-header, name 'village1) with 11 drawable trees (tree0 = 1-drawable
   tfrag; tree1/tree2 = drawable-tree-instance-tie with 4 drawables each,
   real instances 6+42 and 2+14; 8 more).
4. The bsp-header relocate RETURNS SUCCESS (`RELOC7RET: arg=0x2ef80d4
   ret=0x2ef80d4`) — the goal `(else ... this)` branch ran.
5. BUT the level never activates: the loading-level (0x3fdd674, the
   level-group+8 value) and the level0/level1 slots all read bsp=0 and
   have NO bsp-header reference (0x2ef8xxx) anywhere in their memory
   (full-object scans).  The kheap reads all-zero.
6. The background-work list stays empty (`tfrag-count=0`, `tie-count=0`
   every sampled frame) — the bsp's trees are never added, so the
   background engine never draws the village geometry.  The tfrag VU1
   chains that appear come from a loading-state path, not the bsp's trees.
7. The tie-ln (draw-inline-array-instance-tie) is RESTORED in goal_src +
   recompiled GAME.CGO (md5 4e33a7fb, in the bundle) but never runs (the
   trees are never drawn).

## Key evidence files

- docs/evidence/S2/s22-reorientation.md — the roadmap (Track A / Track B)
  + the Track B implementation plan.
- docs/evidence/S2/s22-bot21r-relocate-full.log — the full bsp-header
  relocate disassembly (512 bytes; the x22-based store
  `str w19,[x23,x22,sxtx]` is the unresolved write target).
- docs/evidence/S2/s22-bot21s-reloc-ret.log — the relocate success.
- docs/evidence/S2/s22-bot21u (commit b2e1ddc) — the bsp write lands
  nowhere in the level-group objects.
- docs/evidence/S2/s22-bot21t (commit 68bf956) — served-object buffer
  churn: the bsp-header object at the heap top is transient; earlier
  served-buffer reads (BSPHDR/BSPFT/BSPRELOC) may be churned data.
- docs/evidence/S2/s22-bot21k/21m — tie draws disabled/restored; the
  goalc --isa arm64 recompile.
- docs/evidence/S2/s22-bot21g — the per-draw renderer attribution
  (tfrag pc0/L11, not generic).

## The two hypotheses for the bsp-write target (Track A)

- H1: the goal codegen's "off" register (x22) semantics — the store
  `str w19,[x23,x22,sxtx]` at the relocate entry (0x041e01d8) targets an
  address outside the level-group's known objects.  Determine x22's value
  (the port's codegen documentation / a register log at the goal call) to
  find where the bsp write lands.
- H2: the level died after login-begin (the bsp was set, then unload!
  cleared it).  Trace the level status transitions (`loading → loaded →
  alive → active`) via probes on the level-status-set! / the login state
  machine to pin the death point.

## Track B (the more direct route to the gate)

Execute the plan in s22-reorientation.md: build the tie-bucket VIF from
the LOADED tie data (tree1/tree2 at 0x32670c4/0x33a48a4; the leaf arrays;
the prototypes) + the tie.txt microcode (994 instr), feed it through the
proven VU1 interpreter (tools/ottsel_vu1), decode the XGKICK output, and
rasterize through the existing Metal path.  Verify a composed frame with
real geometry (screenshot + draw_count > 0) as the S2.2 gate candidate.

## Environment / constraints

- One booted Simulator (iPad Pro 11-inch M4, UDID
  08636791-2675-4675-8335-EF72EF954DCF), one runtime, Windowed only.
- Rebuild: /tmp/build-shell.sh (shell-only; copy the binary into
  out/jak-project/out/ios/app/OttselShell.app then simctl install).
- Runtime archive edits: compile the changed file into
  out/jak-project/out/ios/app/obj/*.o, `ar d` + `ar rcs` into
  libottsel-runtime.a, then build-shell.
- GAME.CGO recompile: ./build/h1/goalc/goalc --isa arm64 -c
  '(load-project "goal_src/jak1/game.gp") (make "out/jak1/iso/GAME.CGO")'
  (the --isa arm64 flag is REQUIRED).
- Patches: regenerate patches/h3-jak1-host-boot.patch from inside
  out/jak-project (`git diff 641fb572 > ../patches/...`); reverse-apply
  check clean.
- The nondeterministic link-phase SIGILL (1-in-3-4 boots): relaunch until
  ottsel-fault.log is 0 bytes.
- Never commit ROMs/ISOs/assets; keep the bundle's GAME.CGO/data local.
