# S2.2 BOT12: boot reaches "GAMEPLAY: enter title" -- title screen alive

Date: 2026-08-11.  Status: VERIFIED MILESTONE (title screen state entered;
next fault = target state object is zeroed static data).

## What was fixed since the PROT_READ milestone

Two more ARM64 emitter bugs found by booting with the rebuilt CGOs:

1. **MADD instead of MSUB for `mod`** (`goalc/emitter/IGenARM64.cpp`
   `msub_gpr32`): the 22-bit base lacked the MSUB "o" bit, so `(mod a b)`
   compiled to `a + (a/b)*b` (~2x float bits).  Crashed update-wind's
   wind-array index (pc 0x41d83c4).  Fixed base
   `0b0001101100000000100000`; verified msub w0,w0,w1,w17 = 0x1B01C400
   (clang), emitted was 0x1B014400 (madd).
2. **FAMIN/FAMAX (ARMv9.2 FEAT_FAMINMAX) SIGILL on the M4** (same file,
   `min_vf`/`max_vf`): bones.gc float min/max at pc 0x42308c8 raised
   signal 4.  Replaced with ARMv8 baseline FMIN/FMAX
   (fmin.4s v1,v0,v1 = 0x4EA1F401, fmax = 0x4E21F401).

## What the boot now does (one boot, one Simulator, Windowed)

With the mod + fmin/fmax fixes, the boot (GAME.CGO 346 objects linked,
ART.CGO 21 + TIT.DGO 15 served from the bundle) now:

- Loads title-vis, spawns the title-screen actors.
- Runs `update-wind` and the bones/vector min/max paths without faulting.
- Requests vi1.DGO (not in the bundle -- expected ROM-safe boundary;
  the emulation replies ERROR, the game continues).
- Prints **"GAMEPLAY: enter title"** -- the target's level-enter handler for
  the title level ran; the game's title state machine is alive.
- Faults in `enter-state` (gstate.o, pc 0x3eec874 `blr` to EE+0): the
  target's `(go target-continue arg0)` (end of init-target) enters a state
  object that is **all zeros**.

## Root-cause evidence for the zeroed state object

- `intern_from_c("target-continue")` -> symbol at EE 0x19810C, value
  = **0x42b4000** (read via lldb expression calling the app's function).
- The memory at 0x42b4000 is all zeros (no type, no handlers).
- 0x42b4000 = 0x42b0000 (object 178 **shrub-work** main seg) + 0x4000
  (its code_size) -- i.e., shrub-work's static-data region.  The state
  should live in **target-death**'s static data (main seg 0x4610000,
  code_size 0x14000 -> static data at 0x4624000, which IS populated with
  real strings/objects).
- Other states resolve correctly ('target-stance -> 0x46b0134 in target
  seg data; 'title -> 0x14e6094 in the heap).

So the target-continue state object's linked address is wrong: the static
reference resolved into another object's static-data region, which is
zeros.  This is the same defect class as the earlier constant-pool anomaly
(process-drawable's 0.0 fcmp constant at 0x4520040 held a relocated symbol
value): the no-emit linker's static-data/static-reference patching is
placing some references at the wrong address.

## Next step (smallest falsifiable probe)

Investigate `cross_seg_dist_link_v3` in `game/kernel/jak1/klink.cpp` (the
ADRP+ADD static-address patch, lines ~118-129): verify every patched
reference is a genuine ADRP+ADD pair (not ADRP+LDR), that the page-delta
and lo12 are correct for same-segment static data, and that static object
references (the `new 'static` state objects) resolve to the owning
object's static data.  Compare the linked address of the target-continue
state against the freshly-compiled target-death.o static layout.  A
clean-apply/regression harness (like the A1.0 semantic tests) for static
ADRP+ADD patching would gate the fix.

Evidence: `s21-bot12-title-enter-runtime.log`, `s21-bot12-title-enter-fault.log`.
