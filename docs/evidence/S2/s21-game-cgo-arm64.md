# S2.1 evidence — GAME.CGO compiles for ARM64; 3.8M code words validate

Date: 2026-08-09. Gate: **S2.1 progress milestone (not yet S2 PASS)** — the
entire Jak 1 game engine (`GAME.CGO`, 346 objects / 22 MB) now compiles with
the no-emit ARM64 `goalc` and **every emitted code word validates as a legal
A64 encoding** (3,801,088 words across 346 objects, decode + round-trip +
assembler fallback, zero invalid). This unblocks the first-real-drawable
path (S2.2): GAME.CGO was the last unproven compile barrier for a genuine
game frame; runtime boot of the game processes and the Metal renderer seam
remain.

## Prerequisite found and cleared

`GAME.CGO` requires decompiler data outputs (`tpage-dir.txt`,
`game_count.txt`, `raw_obj/tpage-*.go` for `dir-tpages.go`, `game-cnt.go`
and 8 always-loaded texture-page objects). The decompiler CLI
(`build/h1/decompiler/decompiler`) was built and run in data-only mode on
the extracted ISO:

    ./build/h1/decompiler/decompiler decompiler/config/jak1/jak1_config.jsonc \
      iso_data decompiler_out --version ntsc_v1 \
      --config-override '{"find_functions":false,"decompile_code":false,"levels_extract":false,...}'

`Decompiler has finished successfully in 2.08 seconds`; outputs under
`decompiler_out/jak1/` (gitignored).

## Compile command

    ./build/h1/goalc/goalc --isa arm64 -c \
      '(load-project "goal_src/jak1/game.gp") (make "$OUT/iso/GAME.CGO")'

Result: `Successfully built all 358 targets`. `out/jak1/iso/GAME.CGO`
22,058,064 bytes, 346 objects.

## Emitter / IR bugs found and fixed (all in the pinned worktree)

The game engine exercised codegen paths the kernel never hit. Each fix was
verified against clang's assembler encodings and/or the emission validator:

1. **Vector asm IRs were NYI on ARM64** — `IR_BlendVF`, `IR_SplatVF`,
   `IR_SwizzleVF`, `IR_SqrtVF` threw "NYI" the moment engine math compiled
   (`engine/math/vector-h.gc`). Implemented:
   - `splat_vf` via `DUP Vd.4S, Vn.S[i]`
   - `swizzle_vf` as an in-place-safe cycle rotation with `UMOV W,X16/17`
     + `INS Vd.S[i], Wn` (X16/X17 are the reserved veneer temps the
     allocator excludes)
   - `blend_vf` as per-lane `UMOV`+`INS` (x86 VBLENDPS semantics, aliasing
     safe)
   - `sqrt_vf` wired to the existing `FSQRT`
2. **`VPSHUFLW`/`VPSHUFHW` (16-bit word shuffles)** — implemented as
   `MOV Vd.16B, Vn.16B` + in-place cycle rotation of the low/high 4 words
   using new `UMOV W, V.H[i]` / `INS V.H[i], W` primitives.
3. **Vector shift encodings were wrong** — `pw_sra/pw_srl/pw_sll/ph_srl/ph_sll`
   used `Immb()` (assert imm <= 7) and did not encode the shift properly.
   Verified against `as`: SSHR/USHR/SHL use a 7-bit `immh:immb` field =
   element-size indicator (32/16) +/- shift; fixed and ranged.
4. **`shr/shl/sar_gpr64_u8` wrongly asserted `sa < 63`** — ARM64 shifts by
   63 are legal; relaxed to `sa < 64` (geometry.gc shifted by 63).
5. **Static vector loads used an un-patchable pattern** —
   `IR_StaticVarLoad` VECTOR_FLOAT used `ADD X16, X0, #0; LDR [X16,#imm]`
   which `patch_arm64_static_ref` cannot resolve; switched to
   `loadvf_rip_plus_s32` (ADRP + LDR, patcher-supported).
6. **`IR_RegValAddr` read a register instead of the stack slot** — the ARM64
   path called `get_reg(m_src, ...)` but `to_rai()` never reads m_src (x86
   uses `get_stack_offset`), causing an out-of-range in the allocator at
   `engine/entity/res.gc`. Fixed to compute `SP + stack_offset` via
   `lea_reg_plus_off` then subtract the EE base, matching x86.
7. **`store128_gpr64_simd128_s32/s8` emitted corrupt STR words** — the 10-bit
   STR Q opcode was passed as `Base(0b0011110110, 22)` instead of
   `Base(..., 10)`, so the opcode landed 12 bits low and the word became
   garbage (e.g. `0x0003da09`); every 2-vector prologue store was corrupt.
   Verified against `as` (`str q9, [x16]` = `0x3d800209`).
8. **Emission validator gaps** — the validator now (a) skips data-only
   objects (no GOAL magic), (b) assembles with
   `-march=armv8.5-a+faminmax` for FAMIN/FAMAX (ARMv8.6), and (c) falls back
   to an assembler-acceptance check for words Xcode's llvm-objdump cannot
   disassemble.

## Validation result

    python3 scripts/validate-arm64-emission.py --cgo out/jak-project/out/jak1/iso/GAME.CGO
    PASS: all 3801088 code words across 346 objects validate (decode + round-trip);
          6107 type-tag words skipped

`--selftest` still catches the known-bad word (`0xb8760801`).

## Renderer-seam read-ahead (S2.1 spec item)

The runtime's renderer abstraction is `GfxRendererModule`
(`game/graphics/gfx.h`): `init`, `make_display`, `send_chain`,
`texture_upload_now`, `texture_relocate`, `vsync`/`sync_path`, level
reload hooks. The first real drawable path for a genuine frame is the
**background draw** (fullscreen textured quad from a texture page) driven
by the game's renderer process via `(gs-draw ...)` ->
`sceGraphicsInterface` -> `Gfx::GetCurrentRenderer()`. A Metal module must
provide `make_display` (CAMetalLayer), `texture_upload_now` (texture page
upload), and `send_chain` (DMA-chain draw) at minimum; the S2.0 shell
already proves the CAMetalLayer device/queue/pipeline on the Simulator.

## Honest boundaries

- GAME.CGO compiles and validates; it is **not yet booted** on the
  Simulator (linking the game objects, running their top-levels, and
  starting the game process tree is the next integration step, and the
  engine will exercise further runtime codegen paths).
- Simulator evidence is never device proof.

## Files changed (this slice)

- Worktree (tracked, captured in `patches/*.patch`):
  `goalc/compiler/IR.cpp`, `goalc/emitter/IGenARM64.{h,cpp}`,
  `goalc/emitter/ObjectGenerator.cpp`
- Repo: `scripts/validate-arm64-emission.py`, `docs/evidence/S2/s21-*`,
  `docs/STATUS.md`, `docs/00-loop-log.md`, `docs/13-current-state.md`
