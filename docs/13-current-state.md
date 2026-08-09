# 13 — Current state (handoff snapshot)

Date: 2026-08-08. Author: Bot 3 (build agent), end of work session.
This is the authoritative state document. Read it before doing anything.

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
  from game systems. S2.1 (renderer seam + first real drawable) is next.
- The game does **not** load levels yet. The no-emit boot links all 8
  KERNEL.CGO objects, runs every top-level under RX, prints
  `Got correct kernel version 2.0`, starts the machine, and then the GOAL
  `kernel-dispatcher` runs in the C++ dispatch loop, returning cleanly each
  iteration. The process pool is idle (no listener/GAME.CGO in no-emit boot),
  so no game processes are created yet — that is S1+ scope.
- All prior work is captured in `patches/*.patch` (each applies clean to the
  pinned commit) and in `docs/evidence/`.
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
| S2 First frame (Metal) | **S2.0 PASS (2026-08-09)** — Metal spike; game frame pending (S2.1/S2.2) | `docs/evidence/S2/s20-metal-spike.md` |
| S3 Touch MVP + lifecycle | not started | — |
| R1 Handoff package | not started | — |

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
- 15 IR lowerings remain NYI (Asm push/pop/add/sub/ret/fnop/fwait/regset-asym,
  get-sym-asym, JumpReg, BlendVF, SplatVF, SwizzleVF, SqrtVF, partial FloatMath).
  These matter for engine code, not the kernel headers; H3 boot may hit them
  only after kernel link completes.
- The `make` system and `gk` were modified directly in the worktree; all
  changes are captured in `patches/h3-jak1-host-boot.patch` (and the earlier
  H1/H2 patches are supersets; apply the newest one).

## Repo layout (current)

- `docs/` — plans/status (00–13) and `docs/evidence/{H1,H2,H2.5,H3}/`
- `patches/` — h1/h2/h3 patch files (each applies clean to the pin)
- `ref/` — research corpus (unchanged from Phase 1)
- `out/` — gitignored build tree + worktree
- `src/`, `scripts/` — not yet created (H3 is host-only; S1+ will need them)

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
- **Next:** identify the ret-to-x22 inside the make-village1-light-kit chain,
  then continue linking objects 205-346 (S2.1 -> S2.2 renderer seam).
