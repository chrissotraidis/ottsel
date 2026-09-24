# A1.7 - the strict-lane font/draw-string SIGBUS: root cause, fix, regression, next gate
(2026-09-22, live)

Status: the font crash is closed by a source-level fix with a regression, verified in two runs of the
same code.  A different, deterministic blocker is now exposed in rpc-h.  No playability claim.

## Symptom
The strict signed-GAME profile died within a minute: SIGBUS (signal 10) inside draw-string at font seg0
+0x6864 (font.gc:1462), fault address = ee+4, with *font-work*.buf = 0 - the invocation's dma-buffer
argument was null.  The low-EE page is readable (reads return 0) but not writable, so only the final
store trapped.

## Root cause (measured, in process)
At the fault the flag *debug-segment* is #f (0x18fe04 = s7; FIX_SYM_TRUE = 0x8) and the on-screen
frame's +0x24 slot - the one the emitted cmp flag,x21(#f); b.eq <+0x24> selects - is non-null
(0xcdcfd4), so the chain should have returned a live buffer.  The registers explain it: x25 (the
dma-buffer argument) = 0, x24 = (-> s3-1 base) = 0, and x19 - the register holding display-loop's disp -
held a foreign value.  draw-string has no calls and writes none of x19/x24/x25, and the caller is
display-loop (LR = main+0xB090 = main.gc:513), whose entry does load disp into x19 and saves it (main
seg0 +0x7D24/+0x7DA4 in the running binary).  So a call inside the frame destroyed x19.

## What destroyed it
GOAL's register file on this port is x19-x28 plus v8-v15 (RegisterInfo::make_register_info_arm64;
Asm.cpp maps GOAL's rbx to x19).  The GOAL->C++ trampolines _arg_call_arm64 and _stack_call_arm64 saved
only x29/x30 and q8-q15, so whenever a C++ callee returned without restoring x19 the GOAL caller kept
the wrong value.  A counter added to those trampolines (A1.7b) measured it: 42 of 7268 GOAL->C++ calls
in one run returned with a changed x19, the last being jak1::method_set; the faulted register itself
resolved to ottsel::signed_gstate::villagep_obs_manifest, a C++ loader pointer left in GOAL's register.

## Fix and regression
Both trampolines now save and restore the whole GOAL register file, LIFO and balanced (A1.7c), matching
what the C->GOAL bridges already did after A1.7.  Source out/jak-project/game/kernel/asm_funcs_arm64.s;
overlay patches/a11-goal-bridge-regfile.patch (listed in verify-asm-synthetic-return-patch.py, which
reconstructs that file, and reverse-applies clean).  Regression scripts/test-goal-bridge-regfile.py
covers all four boundaries - x20/x21/x22 for the bridges, x19-x28 + v8-v15 for all - PASS on the fixed
tree and FAIL naming exactly the missing pairs on a pre-fix copy.  test/a11_call_goal_asm_ret_test.cpp
supplies storage for the diagnostic counters when that harness links the assembly.

## Verified
Two runs of the fixed code (154 and 335 signed modules as far as the logs got, ~5600 renderer frames
each): the font site never faults, where earlier runs faulted there within a minute.  The residual ABI
violations are unchanged and now contained: the counter still reports 4 leaks in 1933 calls, target
jak1::asize_of_basic, but GOAL's register is restored after every call.

## Next gate (G1.16)
Both runs die deterministically at ottsel_module_rpc_h_s0_code + 2232 (GOAL 0x83b48b8), SIGBUS with
fault address ee+0xC - the same readable-but-unwritable low page, i.e. a null-object field write.  Keep
the trampoline guard and its regression; chase the rpc-h site next (module base 0x83b4000).

## A1.9 - the next gate: the sound IOP-RPC path (2026-09-22, live)
The deterministic fault after the fix is rpc-h seg0 +2232 (GOAL 0x83b48b8, module base 0x83b4000): a
store of w23 at [x19 + 0xC] with x19 = 0 - a null-object field write on the same readable-but-
unwritable low page - called from gsound seg0 +988, i.e. the sound module's IOP RPC path
(engine/ps2/rpc-h.gc's rpc-buffer-pair current/last-recv-buffer writes; gsound.gc allocates
*sound-loader-rpc*/*sound-player-rpc* and calls add-element/call).  The probe now prints those
symbols, and the contrast is decisive: both are valid heap objects (0x1549294 / 0x15441b4) while the
base from the faulting caller's own adrp).  The fault's x0 at the call site is 0, so gsound's code
loaded a zero slot and passed this = 0.  link() writes its slots before the entry call and the same
pass is right for main (*display*'s slot reads 0xffff78a8), so the open question is why gsound's write
is 0: the intern result (sym.offset - s7.offset == 0 means the name resolved to s7, the #f slot) or a later overwrite of that page. Keep the guard, its regression, the A1.7b counter and this probe.
