# S1.1 evidence — ARM64 emitter validation harness + latent-encoding fixes

Date: 2026-08-08 (Bot 4). Gate: **S1.1 PASS** (host).

## What was built

`scripts/validate-arm64-emission.py` — a host tool that validates **every
word the ARM64 goalc emitter produces for the compiled kernel objects** inside
`out/jak1/iso/KERNEL.CGO`:

1. **Decode check** — each code word is assembled (`as -arch arm64`) and
   disassembled (`llvm-objdump -d`); any undecodable word produces an
   "invalid instruction encoding" warning and an address gap, which the tool
   reports as an invalid word.
2. **Round-trip check** — every non-PC-relative word is reassembled from its
   disassembly and must produce the identical 4 bytes; PC-relative words
   (b/bl/b.cond/cbz/tbz/adr/adrp/literal loads) are verified by
   hand-computing the exact encoding from their resolved target, because
   Apple's `as` cannot express cross-page `adrp` label references.
3. **Deliberately skipped** — `0xaeaeaeae` words: the v3 object-format
   "function type tag" (8 bytes of 0xAE preceding every function, never
   executed). Zero-padding decodes as `udf #0` and is accepted.
4. **Self-test** — `--selftest` feeds the known-bad pre-H3 load32u word
   `0xb8760801` and requires the tool to catch it (it does, at +0x4).

## What it found (latent SIGILL bugs in the kernel objects)

The H3 boot only executes a fraction of kernel code (dispatcher path). The
harness found **43 invalid words in 3 objects** that would SIGILL the moment
the game calls those functions (div, 64-bit loads, vector loads/stores):

| Family | Word(s) | Emitter bug | Fix |
|---|---|---|---|
| SDIV/UDIV | `0x1ac10000`, `0x1ac30000` (25×) | `sdiv/udiv_gpr32_gpr32` base missing opcode bits (emitted opcode 0) | base `0b0001101011000000000011` (SDIV) / `0b0001101011000000000010` (UDIV) |
| 64-bit load | `0xf8760800/02/22/ae0` (8×) | `load64_gpr64_gpr64_plus_gpr64` base missing SXTX option bits (same bug class as the H3 load32u fix) | base `0b1111100001100000111010` |
| Vector load/store | `0x3ce40880`, `0x3ce30860`, `0x3cb60880` (6×) | `loadvf_gpr64_plus_gpr64` + `storevf_gpr64_plus_gpr64` bases missing option bits; `loadvf` also used `Rm(addr1)` (index register ignored, loaded from `[base, base]`) | bases `...111010`; `Rm(addr2)` |
| (latent, same class) | — | `store16_gpr64_gpr64_plus_gpr64`, `store32_xmm32_gpr64_plus_gpr64` (option bits; xmm32 also Rn/Rm swapped) | bases `...111010`; Rn/Rm fixed |

All fixes are in `goalc/emitter/IGenARM64.cpp`; each encodes exactly the
encoding verified by `as`/`llvm-objdump` (e.g. `ldr x0,[x16,x22,sxtx]` =
`0xf876ea00`).

## Verification (all captured)

- `s11-harness-selftest.log` — `SELFTEST PASS: known-bad word 0xb8760801
  caught at +0x4`.
- `s11-kernel-validation.log` — `PASS: all 86016 code words across 8 objects
  validate (decode + round-trip); 226 type-tag words skipped`.
- `s11-host-boot-after-emitter-fixes.log` — full host boot with the
  regenerated KERNEL.CGO: `kernel: machine started`, Windowed (1280x960),
  43,274 `call_goal_on_stack` dispatcher-loop lines in the first 30 s, zero
  SIGILL/EXC_BAD_INSTRUCTION, graceful operator stop.

Regenerate command (in the pinned worktree):

    ninja -C build/h1 goalc
    ./build/h1/goalc/goalc --isa arm64 -c \
      '(load-project "goal_src/jak1/game.gp") (make "GROUP:kernel")'
    python3 scripts/validate-arm64-emission.py --selftest
    python3 scripts/validate-arm64-emission.py

## Honest boundary

The harness validates the kernel objects in KERNEL.CGO (86,016 words, 8
objects). Unexercised emitter functions not present in the kernel (e.g. the
SIMD `_plus_s8`/`_plus_s32` variants) are outside this gate; they get
validated when GAME.CGO compiles (S2+). The `0xaeaeaeae` type-tag words are
skipped by construction, not validated.
