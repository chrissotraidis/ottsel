# S2.2 BOT12: PROT_READ low-EE fix advances the boot past the display spawn

Date: 2026-08-11.  Status: VERIFIED MILESTONE (display spawn cleared; new
deterministic fault in wind at the title screen).

## What was fixed

`src/shell/ios_boot.cpp` changed the low-EE guard from `PROT_NONE` to
`PROT_READ` (first 512KB, zero-filled).  The PS2 has no MMU: game code
legitimately reads low memory through default-initialized pointers
(`vector<-cspace!` reads `bone->transform.vector[3]` via a null bone and
relies on its `w == 0` guard to return `{0,0,0,1}` -- the documented
swamp-blimp tolerance).  `PROT_NONE` turned that same read into a fault.
Reads now see zeros; writes and execute still fault (SIGSEGV, caught).

## What the boot now does (one boot, one Simulator, Windowed)

Past the old display-spawn fault (`vector<-cspace!` null bone, pc
0x45182e0): GAME.CGO links (346), ART.CGO (21 objects) and TIT.DGO (15
objects) serve from the bundle, title-vis loads, the dispatcher runs, the
title-screen actors spawn, and the boot advances to a NEW deterministic
fault:

```
fault pc=0x70041d83c4  lr=0x7004500eec
x0=0xffffffff850b0010 (sign-extended garbage EE offset)
fault addr=0x6f850b0010
```

pc is in **wind** (object 152, wind.gc) at 0x3c4; lr is in cam-combiner.
The faulting instruction is `ldrb w0, [x0, x22, sxtx]` -- an array read in
`update-wind` with a garbage index.

## Root cause: ARM64 emitter emits MADD instead of MSUB for `mod`

`update-wind` computes `(-> arg1 (mod (the-as int v1-5) (-> arg1 length)))`.
The IR_IntegerMath IMOD_32 ARM64 lowering is correct
(`sdiv` + `msub_gpr32`), but `IGen::msub_gpr32`
(`goalc/emitter/IGenARM64.cpp`) encodes the 22-bit base
`0b0001101100000000000000`, which is **MADD** (0x1B000000) -- the MSUB
"o" bit (instruction bit 15) is missing.  Result: `(mod a b)` compiled to
`a + (a/b)*b` (~2x the float bit pattern of `(the-as int v1-5)`) instead of
`a - (a/b)*b`, so the wind array index became ~0x850b0000 and read far out
of bounds.

Verified encoding (clang): `msub w0,w0,w1,w17` = 0x1B01C400,
`madd w0,w0,w1,w17` = 0x1B014400 (the emitted word).

Fix applied: `Base(0b0001101100000000100000, 22)` (bit 5 = MSUB flag).

## What remains

The fix requires re-emitting: rebuild goalc, recompile the game objects,
repack KERNEL.CGO/GAME.CGO, rebuild the app, and boot again.  Expected next
boundary after the mod fix: the wind math becomes sane and the boot
continues toward the renderer/display path (S2.2 first-frame territory).

Evidence: `s21-bot12-protre-advance-runtime.log`, `s21-bot12-protre-advance-fault.log`.
