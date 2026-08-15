# 13 — Current state (handoff snapshot)

## 2026-08-15 update (BOT13) — stable title boot; enter-state fault fixed

The previous deterministic blocker is FIXED and verified (one boot, one
Simulator, Windowed, zero faults).  Root cause, evidence chain, and fix are
in `docs/evidence/S2/s21-bot13-titlefix.md`; short version:

- The BOT12 "state-symbol mislink" reading was disproven by in-process
  probes: `target-continue` -> 0x19818c -> value 0x4624074 (correct, no
  duplicates) right up to the fault.
- The fault was `enter-state` (gstate+0x2d4) entering the TARGET process
  (pid 12) with `pp->state = pp->next-state = 0`: the second `go` in
  target-continue's `:code` is `(go target-title)`, and `target-title` had
  value 0 because its defining object (title-obs.gc) was never linked.
- Why: title-obs lives in TIT.DGO.  The port served the raw ISO TIT.DGO,
  whose GOAL objects use the PS2 v3 header (first word 0x0); the DGO serve
  skip test (`tag == 0xffffffff`) skipped them as "non-GOAL".  GAME.CGO does
  not contain title-obs (upstream packs it in `dgos/tit.gd`).
- Fix (runtime-side, no game source patched): build + ship the recompiled
  TIT.DGO (no-emit v3 static-screen.o/title-obs.o), accept the "GOAL" magic
  (0x4c414f47) in the DGO serve skip test, and make `link_begin` complete the
  v3 link synchronously (the goal-side multi-frame resume path never fired
  for the v3 DGO objects).

Verified outcome: zero faults; `link finish: static-screen` / `title-obs`;
the target process executes title-obs code (pc 0x492a9fc in the title state
machine); `GAMEPLAY: enter title` twice; the boot then requests village1
(`begin load village1-vis [vi1.DGO]` -- not in the bundle, the ROM-safe
boundary the game tolerates); full process tree (24 nodes: target, camera,
display, HUD, subtitle, etc.); dispatcher stable past 121,000 iterations.
The only repeated activity is the STR subtitle/text RPC emulation returning
the ROM-safe no-data response.

Next gate: S2.2 -- first real Jak frame via Metal (the Metal shell still
presents the log surface; the game's GfxRendererModule seam is the
connection point).  See `docs/reports/2026-08-15-bot14-handoff.md`.

---

# 13 — Current state (handoff snapshot)

## 2026-08-11 update (BOT12) — boot reaches the title screen

The engine-integration boot now advances past every earlier boundary to the
game's title state machine: KERNEL.CGO (8) + GAME.CGO (346) link; ART.CGO
(21) + TIT.DGO (15) serve from the bundle `iso_data`; title-vis loads; the
dispatcher runs; **"GAMEPLAY: enter title"** prints (the target's
level-enter handler).  This loop's verified fixes:

1. `src/shell/ios_boot.cpp`: low-EE guard `PROT_NONE` -> `PROT_READ`
   (zeroed).  The PS2 has no MMU; game code legitimately reads low memory
   through default-initialized pointers (`vector<-cspace!` null-bone read;
   its `w == 0` guard returns `{0,0,0,1}`).  Writes/execute still fault.
2. `goalc/emitter/IGenARM64.cpp` `msub_gpr32`: MSUB base lacked the "o" bit,
   so `(mod a b)` compiled to `a + (a/b)*b` (update-wind array index fault
   at 0x41d83c4).  Fixed + clang-verified (`msub w0,w0,w1,w17 = 0x1B01C400`).
3. Same file `min_vf`/`max_vf`: FAMIN/FAMAX (ARMv9.2 FEAT_FAMINMAX) raise
   SIGILL on the M4 (bones.gc at 0x42308c8); replaced with ARMv8 FMIN/FMAX
   (`fmin.4s v1,v0,v1 = 0x4EA1F401`, `fmax = 0x4E21F401`).

**Current deterministic blocker (DIAGNOSED)**: `enter-state` (gstate.o)
calls the target's first state (`init-target` ends `(go target-continue
arg0)`) and the state symbol value is garbage (0x42b4000 — shrub-work's
zeroed static region).  The target-death state objects are correctly linked
(0x4624074, 0x46252d4) and the linker's ADRP+ADD static patch is correct
(verified with a temporary LINKSTAT diagnostic); the failure is in the
state-symbol value write/read path (the `(sym - s7)` slots live in the
transient top-level segment).  See
`docs/evidence/S2/s21-bot12-state-mislink.md` and
`docs/reports/2026-08-12-bot13-handoff.md` for the exact next probes.

Evidence: `docs/evidence/S2/s21-bot12-*` (protre-advance, title-enter,
topdump, state-mislink).  The canonical patch `patches/h3-jak1-host-boot.patch`
was regenerated and clean-applies to the pin (reverse-apply OK).

---

Date: 2026-08-09. Updated by the operator-requested repository audit.
This is the authoritative state document. Read it before doing anything.
Read `docs/15-progress-audit.md` first for the corrected execution order.

## Bottom line

- Gates H1 (ARM64 goalc codegen), H2 (no-emit host runtime), H2.5 (packaging
  decision) are **PASS** with evidence.
- Gate H3 (Jak 1 host AOT boot proof) is **PASS (2026-08-08, host)** — the
  GOAL **kernel dispatcher executes and loops** under RX with zero faults.
- Gate S1 (Simulator shell boots the no-emit runtime to the dispatcher
  loop) is **PASS (2026-08-08)**.
- Gate S2 (first frame, Metal): **S2.0 PASS (2026-08-09)** — the shell now
  presents its log surface through a real Metal (CAMetalLayer) pipeline on
  the iPad Pro 11-inch (M4) Simulator. Declared sub-gate: not yet a frame
  from game systems.
- S2.1 is a research checkpoint: GAME.CGO compiles completely, and the
  Simulator RX-blob linker advances to object 204 before a deterministic
  ret/jump-to-EE-base fault. An active dirty debugger experiment is present.
- **Gate A1 is now active before further S2 expansion.** The current app's
  CGO RW→RX path is a Simulator research vehicle. It does not prove H2.5's
  selected product path: real generated GOAL code inside signed Mach-O text
  with no runtime-created executable code.
- Committed OpenGOAL work is captured by the canonical
  `patches/h3-jak1-host-boot.patch`, which clean-applies to the pinned commit,
  and by `docs/evidence/`. The active dirty object-204 trace experiment is
  newer and intentionally not yet captured in that patch.
- **Operator constraints (binding):** (1) test apps must never go fullscreen
  — game window must stay Windowed (fixed: `display-settings.json`
  `display_mode: 0`, and source default in `game/settings/settings.h` is now
  Windowed; rebuild `gk` for the source change to take effect, the settings
  file fix is immediate); (2) at most one `gk`/runtime process at a time.

## Environment

- Host: macOS 26.5.2 (arm64, Apple M1). Xcode toolchain, CMake 4.4.0, Ninja.
- Worktree: `out/jak-project/` (gitignored), pinned to
  `641fb572e876750d8618434d9f7c1a531b43b366` (upstream open-goal/jak-project).
- Build dir: `out/jak-project/build/h1/` (configured `-DOTTSEL_NO_EMIT=ON`,
  `-DCMAKE_OSX_ARCHITECTURES=arm64`).
- Legal ISO: `~/ottsel-user/iso/... .iso` (never in git). Extracted to
  `out/jak-project/iso_data/jak1/` (gitignored).
- Disk: ~17 GB free as of this snapshot. Builds are slow (10-20 min per
  compiler/runtime rebuild); plan around it.

## Gate board

| Gate | Status | Evidence |
|---|---|---|
| H1 ARM64 goalc codegen | **PASS** | `docs/evidence/H1/` (run-h1-proof.log: 5 cases) |
| H2 no-emit host runtime | **PASS** | `docs/evidence/H2/` (RX-only exec, bridge, shim) |
| H2.5 packaging decision | **PASS** | `docs/evidence/H2.5/` + `docs/10-code-packaging-and-signing.md` |
| H3 Jak 1 host AOT boot | **PASS (2026-08-08, host)** | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` |
| S1 Simulator shell boot | **PASS (2026-08-08)** | `docs/evidence/S1/` (s13-dispatcher-loop.*, s11-*, s12-*) |
| S2.0 Metal shell spike | **PASS (2026-08-09)** — game frame still pending | `docs/evidence/S2/s20-metal-spike.md` |
| S2.1 GAME.CGO integration | **RESEARCH CHECKPOINT** — compile pass; RX-blob link reaches object 204 | `docs/evidence/S2/s21-*` |
| **A1.0 semantic ARM64 regressions** | **PASS (2026-08-09)** — 14/14 assertions; CGOs still validate; object-204 localized by bounded call trace | `docs/evidence/A1/a1-semantic-regressions.md`, `a1-object204-bounded-trace.md` |
| **A1.1 real GOAL in signed `__TEXT`** | **PASS (2026-08-09)** — real KERNEL.CGO slice executes on the Simulator; codesign verifies | `docs/evidence/A1/a11-signed-text-slice.md` |
| **A1.2 execution-permission proof** | **PASS (2026-08-09)** — AOT path audited clean; slice passes without CGO bundles; codesign/Mach-O evidence | `docs/evidence/A1/a12-execution-permission-proof.md` |
| **A1 signed-native execution** | **PASS (2026-08-09)** — real OpenGOAL artifact executes from signed Mach-O text, no runtime-created executable code | `docs/evidence/A1/*` |
| **S2.1 GAME.CGO engine integration** | **ACTIVE (2026-08-10/11)** — AND encoder fixed regression-first; all 346 GAME objects link; the kernel dispatcher loops on the Simulator with GAME.CGO loaded; no-emit main segments live in a dedicated region above the global heap (`klink.cpp`, OTTSEL_CODE_BASE 0x3ebc000); the code/heap-overlap root cause is DISPROVEN. **Camera stack corruption ROOT CAUSE FIXED**: the ARM64 call shim pushes two 16-byte slots (incoming x30 + synthetic post-blr continuation); `thread-suspend` read the continuation with an advancing `.pop`, and the resume's post-blr then popped both slots — a net +0x10/dispatch sp climb (the WRITER-SP measured 0x1d7fd0 -> 0x202000 over 10755 iterations) that drove the camera thread's stack into the *debug-dead-pool* region and corrupted process type tags (dispatcher called the code word `0x8b36e010` -> SIGILL).  Fix: new `.load` asm form (`IR_AsmLoadSp` = `ldr reg, [sp]`, no post-index on ARM64) + `thread-suspend` uses it; A1.0 test 26 asserts 0xf94003e0 / rejects 0xf84107e0; full suite PASS; emitted kernel starts `ldr x0, [sp]`.  Boot verified: camera sp constant at 0x1d7fc0, zero REGION-CHANGE, 213k+ subtitle-load iterations with no dispatcher fault.  S2.1 remains ACTIVE: the boot spins on `load-subtitle-text-info` (no ISO data, expected ROM-safe boundary); no renderer-ready boundary or Jak frame yet. | `docs/evidence/S2/s21-andfix-progress.md`, `s21-fix-spstable-runtime.log`, `s21-tracer-writersp2-*`, `docs/reports/2026-08-10-bot8-handoff.md` |
| S2.2 First game frame | blocked on S2.1 | — |
| S3 Touch MVP + lifecycle | blocked on S2 | — |
| R1 Handoff package | blocked on S3 | — |

## What works (verified)

1. ARM64 `goalc` compiles the full Jak 1 GOAL kernel: `gcommon`, `gkernel-h`,
   `gkernel`, `pskernel`, `gstring-h`, `gstring`, `dgo-h`, `gstate` →
   `out/jak1/obj/*.o` and `out/jak1/iso/KERNEL.CGO` (new object format with
   per-segment `code_size` in the header, ~404 KB).
2. ISO extraction: `extractor` tool extracts the legal ISO into
   `iso_data/jak1/` (CGO/DGO/MUS/STR, SCUS-97124).
3. `gk` (game runtime) builds for arm64 with `OTTSEL_NO_EMIT` and boots:
   - EE memory mapped RW-only (W^X respected, no RWX).
   - Missing `fr3` level data tolerated (empty common level) so boot proceeds.
   - IOP/OVERLORD emulation starts; `KERNEL.CGO` loads via the real linker.
   - `gcommon` links with data-only relocations.
   - Code pages flip to RX after link (16KB page size on Apple Silicon);
     main-segment code pages stay RX permanently, static/data pages stay RW
     (real code/data page split), top-level pages flip RX only for the
     duration of each top-level call (transient), then back RW.
   - `call_goal_on_stack` enters the ARM64 GOAL top-level with correct
     `st`/`offset` and a 16-byte-aligned goal stack.
4. ARM64 C-export stubs (in `make_function_from_c`) emit valid ARM64 bytes
   (previously wrote x86 bytes on aarch64).
5. `_arg_call_arm64` and `_call_goal_on_stack_asm_arm64` fixed (target read,
   stack restore, alignment).
6. Cross-segment function addresses now encode as `ADRP+ADD` (patched by the
   runtime linker), fixing the previous `adr` ±1MB range failure.
7. ARM64 encoder fixes this session: `cmp_gpr64_gpr64` (was dropping the
   first operand; countdown loops spun forever) and
   `load32u_gpr64_gpr64_plus_gpr64` (missing option bits; emitted invalid
   `0xb8760801` instead of `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`).
8. `InitListener` in no-emit mode interns the C/GOAL shared symbols
   (`kernel_dispatcher`, `ListenerFunction`, etc.) so the dispatch loop can
   find the kernel dispatcher.

Evidence log: `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` shows the
full arc to the dispatcher loop:

    Got correct kernel version 2.0, loaded in 13 ms
    kernel: machine started
    OTTSEL no-emit: stub arena B flipped RX (8568 bytes used)
    ... dispatcher loop runs for minutes, zero faults ...
    GOAL Runtime Shutdown (code 2)   # graceful window-close EXIT, not a crash

Per-iteration dispatch lines (`call_goal_on_stack: fptr=0x70001a5384 ...
returned 1375532`) go to stderr (PTY), verified in both runs.

## Next steps (S1 and beyond — see `docs/BOT4_HANDOFF.md`)

- H3 is proven. Before starting S1, the next agent should do one clean
  verification run capturing stderr too (`2>&1`) so the durable log includes
  the dispatcher-loop lines, and rebuild `gk` so the Windowed source default
  is in the binary.
- **S1 is PASS (2026-08-08)** — the shell boots the no-emit runtime to the
  GOAL kernel dispatcher loop on the iPad Pro 11-inch (M4) Simulator
  (`docs/evidence/S1/s13-dispatcher-loop.md`; 48,200+ iterations, zero
  faults). The key fix: the kernel dispatcher's first call is the C export
  `pc-prof`, which an OTTSEL_IOS guard had left unregistered (value 0 ->
  jump to EE 0); registering the PC-port exports + a full-table fallback
  scan in `find_symbol_from_c` (order-dependent intern could create
  duplicate symbol entries) resolved it.
- **Gate S2 (first frame, Metal) is next** — see `docs/BOT5_HANDOFF.md`.

## S2 status (2026-08-09)

- **S2.0 PASS** — Metal spike: `src/shell/metal_shell.{h,mm}` render the
  shell's log surface through a CAMetalLayer pipeline (device, command
  queue, fullscreen textured triangle, per-frame texture upload, present).
  `src/shell/main.cpp` sizes the CPU surface to the drawable each frame
  (the simulator's windowed presentation keeps a 480x320 drawable; the
  surface adapts on resize/rotation) and presents via Metal; SDL software
  surface remains as fallback. Evidence + pixel verification
  (title 1746/1746, GPU line 1566/1566 vs the font table):
  `docs/evidence/S2/s20-metal-spike.md`.
- **S1 log-font bug found and fixed:** `font5x7.h` rows are 7 bits wide
  (bit 6 = rightmost) but the draw loop used `kFontW = 5`, clipping every
  glyph's right edge in all S1/S2 screenshots. Fixed `kFontW` to 7.
- **S2.1 progress (2026-08-09):** GAME.CGO — the full Jak 1 game engine,
  346 objects / 22 MB — **compiles for ARM64** and all 3,801,088 emitted
  code words validate (decode + round-trip + assembler fallback; zero
  invalid). Evidence: `docs/evidence/S2/s21-game-cgo-arm64.md` +
  `s21-game-cgo-build.log`. The remaining 15-IR NYI list is now closed for
  compile: the engine exercised and we implemented BlendVF/SplatVF/
  SwizzleVF/SqrtVF, VPSHUFLW/VPSHUFHW, and fixed the vector-shift
  encodings, static vector loads, IR_RegValAddr stack addressing, and a
  STR Q opcode-width bug that corrupted 2-vector prologue stores. The
  renderer seam (`GfxRendererModule`) read-ahead is recorded there; the
  first real drawable is the background path via the game's renderer
  process -> sceGraphicsInterface -> Gfx.
- **S2.1/S2.2 next:** link + boot GAME.CGO on the Simulator (the no-emit
  linker must link the game objects and run their top-levels; the game
  process tree then starts), then implement the minimal Metal
  GfxRendererModule (make_display / texture_upload_now / send_chain) for
  the first real frame.
- **S2.1 runtime linking (2026-08-09):** the shell bundles GAME.CGO and
  links it on the Simulator after the kernel. 36 of 346 objects link; the
  first runtime fault is a symbol-value call in `pad`'s top-level
  (`lr=pad main+0x294`) that resolves to `st+0x20c0` (inside the GOAL heap,
  not code) — the game's first exercised symbol-value resolution. Fixed en
  route: cross-segment LDR-literal overflow (static loads now ADRP-based;
  GAME.CGO revalidates 3,825,664 words). The gated handler logs
  pc/lr/st/offset/faulting-words for the next fault. Evidence:
  `docs/evidence/S2/s21-game-cgo-simboot.md` + `s21-simboot.log`.
  Next: identify the symbol at `st+0x20c0` and fix the value-field
  resolution (mirroring the S1 canonical-intern fix), then continue linking
  the remaining 310 objects.
- Reproduce S2.0:

      ./scripts/build-ios.sh
      xcrun simctl boot <iPad Pro 11-inch (M4) UDID>
      xcrun simctl install <udid> out/jak-project/out/ios/app/OttselShell.app
      xcrun simctl launch <udid> com.ottsel.shell
      xcrun simctl io <udid> screenshot docs/evidence/S2/s20-metal-frame.png

  Expected: `ottsel S2.0: Metal surface active (CAMetalLayer)` on the
  console; the window shows the log surface rendered through Metal
  (title `ottsel S2.0 - Metal`); the runtime boots to the GOAL kernel
  dispatcher loop (`s20-runtime.log`).

## Known non-goals / boundaries

- Physical device proof is not claimed from Simulator/host evidence.
- No game assets in git; ISO stays at `~/ottsel-user/iso/`.
- The old 15-IR compile blocker is closed: GAME.CGO compiles completely.
  Semantic correctness remains open; legal-but-wrong ARM64 instructions and
  ABI behavior now require focused regression tests under A1.0.
- The `make` system and `gk` were modified directly in the worktree; all
  changes are captured in `patches/h3-jak1-host-boot.patch` (and the earlier
  H1/H2 patches are supersets; apply the newest one).

## Repo layout (current)

- `docs/` — plans/status/audits (00–15) and gate evidence
- `patches/` — h1/h2/h3 patches; `h3-jak1-host-boot.patch` is canonical
- `ref/` — research corpus (unchanged from Phase 1)
- `out/` — gitignored build tree + worktree
- `src/`, `scripts/` — iOS shell/Metal sources and build/validation tools

## How to reproduce the boot

    cd out/jak-project
    # (worktree already has all patches applied)
    cmake -S . -B build/h1 -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_APPLE_SILICON_PROCESSOR=arm64 \
      -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
      -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF -DOTTSEL_NO_EMIT=ON
    ninja -C build/h1 gk goalc extractor
    ./build/h1/goalc/goalc --isa arm64 -c \
      '(load-project "goal_src/jak1/game.gp") (make "GROUP:kernel")'
    ./build/h1/game/gk -fakeiso -boot -v

Expected today (with the load32u/cmp fixes): boots to the GOAL kernel
dispatcher loop —

    Got correct kernel version 2.0, loaded in 13 ms
    kernel: machine started
    OTTSEL call_goal_on_stack: fptr=0x70001a5384 ... returned 1375532   (loops)

Use `-- -nosound` (host coreaudiod is wedged). Keep the window Windowed
(no fullscreen) and one `gk` at a time. Under lldb, `process launch --
-fakeiso -boot -v -- -nosound` and interrupt after `kernel: machine started`
to snapshot the EE thread PC inside the RX kernel code.

## Session history (short)

- H1: ARM64 RegisterInfo + function codegen + core IRs; fixed encoder bugs.
- H2: RX-only AOT execution, call_goal bridge, static shim, no-emit flag,
  emit-site checklist.
- H2.5: packaging decision (generated-native, Option 2/3) with Mach-O proof.
- H3: kernel compiles ARM64, ISO extracted, `gk` boots with no-emit runtime,
  reaches GOAL top-level entry; cross-segment ADR fixed to ADRP+ADD; encoder
  fixes (cmp, load32u); **GOAL kernel dispatcher executes and loops** —
  H3 PASS (2026-08-08, host).

## 2026-08-09 late — S2.1: linking 55 -> 204; mood-tables fault (checkpoint)

- **GAME.CGO on-device linking advanced 55 -> 204 of 346 objects** with six
  verified fixes: (1) ARM64 stack-variable addressing (IR_GetStackAddr used
  ORR where register 31 = xzr, so `mov xd, sp` became xd = 0); (2) mips2c
  ARM64 no-emit dispatch + jak1 table + pre-registration + jalr shim;
  (3) iOS SIF RPC stubs + get-irx-version emulation; (4) `_stack_call_arm64`
  arg-pair order (format); (5) LDRH imm12 scaling in 16-bit static-field
  loads; (6) reusable 512KB CGO stage slot (was staging the whole 22MB from
  the global heap).
- GAME.CGO revalidates 3,829,760 code words PASS; the app reproduces the same
  fault deterministically.
- **Current blocker:** object 204 (mood-tables) top-level -> `make-village1-light-kit`
  call chain: `signal 10 at pc=0x7000000000` (jump/return to the EE base =
  x22).  All symbol/slot values in the chain verified valid; the deep
  ret-to-x22 site needs a live call tracer or a debugger that can breakpoint
  RX-flipped GOAL pages (lldb cannot).  Gated handler now prints pc/regs and a
  GOAL-stack LR walk via raw stderr.
- **Audit sequencing correction:** preserve the current dirty ret-to-x22 probe
  and its result, but do not continue broad GAME.CGO/renderer work from this
  checkpoint. Execute A1.0 semantic regressions and A1.1/A1.2 signed-native
  integration first. After A1 passes, return here, identify the ret-to-x22,
  and continue objects 205-346.

## Product-path boundary (2026-08-09 audit)

- `scripts/build-ios.sh` currently bundles KERNEL.CGO and GAME.CGO; the linker
  copies and patches their code in the EE mapping and flips code pages RX. This
  is **Simulator research infrastructure only**.
- H2.5 selected generated native code compiled by clang into the signed app.
  A1 must demonstrate that with a real OpenGOAL artifact in Mach-O `__TEXT`,
  offline instruction relocations, and no runtime `mprotect(PROT_EXEC)` GOAL
  path before the project invests further in the renderer or touch UI.
- The encoding validator proves A64 legality, not semantics. Recent legal but
  incorrect instructions make focused semantic regression tests mandatory.
- Current continuation prompt: `docs/BOT6_PROMPT.md`.

## 2026-08-09 — realignment to Gate A1 (signed-native execution)

The active gate is now **A1** per docs/15-progress-audit.md and BOT6_PROMPT.md:
prove real OpenGOAL code executes from signed Mach-O __TEXT on the iPad
Simulator before any further renderer/touch work. The RX-blob RW->RX loader is
Simulator-only diagnostic infrastructure (oracle), not the product execution
model.

- **R0 done:** the object-204 call-trace probe experiment was captured
  (`docs/evidence/A1/r0-call-trace-probe-{shell,goalc}.patch`: goalc
  IR_FunctionCall recorder shim, kscheme ring buffer, handler dumps), then
  stripped from product sources. The shell gated handler retains the
  stderr-based pc/regs/GOAL-stack-LR-walk diagnostics. Scratch .o/.s probes
  removed. The app builds clean.
- **A1.0 next:** extend the smallest H1/H2 harness with semantic regression
  tests for the known legal-but-wrong defect classes (SP->xzr, load-as-store,
  wrong widths, scaled offsets, ABI arg-pair swap, LR/call/return), and reduce
  the object-204 value-0 call/return fault below the full boot loop.

## 2026-08-09 late — A1.0 PASS: semantic regressions + object-204 localized

- **A1.0 semantic regression layer PASS.** Harness
  `out/jak-project/tools/ottsel_a1/semantic_regressions.cpp` (target
  `ottsel-a1-sem`): 14/14 assertions — emitter-unit (static_load_f32 is
  LDR-s not STR-Q; load16u +s8 is unscaled LDURH; store16 STURH;
  `_stack_call_arm64` pushes (x6,x7)(x4,x5)(x2,x3)(x0,x1)) and goal-compile
  (SP->xzr fixed via ADD; u16 LDURH; non-leaf x30 save/restore; 2-level
  nesting).  Negative proofs captured (STR-Q/LDRH reintroduction fails 4;
  asm pair swap fails the source-scan check).
- **Object-204 localized below the boot loop.**  Temporary goalc
  IR_FunctionCall recorder shim + 256-entry ring + gated-handler dump
  (preserved as `docs/evidence/A1/a1-bounded-call-trace-probe.patch`,
  stripped from product sources).  One boot reproduces the fault
  deterministically: trace-count 30,422; chain mood-tables top-level ->
  0x23d8554 -> 0x23d8004 -> 0x5ab0e4 -> 0x5fc574/0x5fd9d4 -> 0x5a9234
  (called 3x from site 0x23d8408 loop) -> `signal 10 at pc=0x7000000000`
  (x8 = lr = 0x7000000000 = x22).  The 0x5a9234 target is real SIMD matrix
  code, so the corruption is call/return state around it (S2.1 will
  root-cause after A1).  Key probe fixes: save x8-x15 across the recorder
  (C-call clobbers; a first version destroyed the fn pointer in x8), and add
  the EE-base offset before the symbol value read.
- **Encoding validation:** product CGOs rebuilt clean — KERNEL.CGO 86,016
  and GAME.CGO 3,829,760 code words PASS.
- **Next: A1.1** — real KERNEL.CGO dispatcher slice in signed Mach-O
  `__TEXT` via the proven H2.5 `.word`->clang route.
