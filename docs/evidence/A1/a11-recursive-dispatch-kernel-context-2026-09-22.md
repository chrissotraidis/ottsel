# A1.2 strict signed-GAME dispatch: the walk reaches the static kernel-context (2026-09-22, app)

Gate: the strict signed-GAME crash is localized to one instruction, one GOAL function, one recursive
call edge, one object and one candidate cell. No playability claim.

## Reproduced three times, identical in GOAL space
Product app (OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json, banks 1) with
different ASLR bases (g_ee_main_mem 0x1010e8000 / 0x1037a8000 / 0x104d08000) gives the same
GOAL-space fault: pc = gkernel seg0 +0x5554 (GOAL 0x801d554), x30 = seg0 +0x55b0,
x24 = 0x3db0fb4, x0 = 0x70004000, x21 = s7 = 0x18fe04, x22 = g_ee_main_mem,
x23 = 0x801d724, si_addr = g_ee_main_mem + 0x70004000.

## Instruction, function, edge
Live memory at 0x109105540 matches the emitter output byte for byte; the fault word b876e801 is
`ldr w1, [x0, x22]` (register-offset LDR, SXTX, no shift) - a 32-bit load of the "type" word of the
object at GOAL 0x70004000. The function is `execute-process-tree` (gkernel, seg0 entry 0x5414).
x30 = seg0 0x55b0 is the continuation of the recursive call at seg0 0x55ac, so this frame is a
*recursive* invocation; x1 = s7 and x25 = 0x1f6464 show it took 0x5548 -> 0x554c -> 0x5550 ->
0x55bc -> 0x5554, i.e. the first loop iteration of a fresh frame.

## The dispatch passes the context where the pool belongs
`this` (x24) = 0x3db0fb4 is `*kernel-context*`'s value: the build's own gkernel.json puts gkernel's
seg0 data base at 0x3db0fb0, the loader writes a `TypePointer` slot for `kernel-context` at
arena+0 (live value 0x1c29e4), and the fault-time EE scan finds 0x3db0fb4 in exactly one symbol
slot, 0x18adfc, which is the symbol the arena's `*kernel-context*` slot (0xffffaff8 = -0x5008 from
s7) resolves to. Two independent readings therefore agree: the arena's first static object is the
kernel-context, and it is what the walk recurses into. At the same time x23 (context) = 0x801d724,
the lambda that `kernel-dispatcher` passes as `func`, so this/context are rotated relative to
`(execute-process-tree *active-pool* lambda *kernel-context*)`.

## The cell that feeds the walk
`this` arrived as `(-> brother)` = mem[cell] (seg0 0x558c). The fault handler now scans the EE word
space for it (fault path only): the only non-stack hits are the `*kernel-context*` symbol slot
0x18adfc and one word at 0x1f66e0 inside a pooled process's memory
(`... 1cb850 400 803c2d4 0 [3db0fb4] 0 803c2d4 0 ...`). So the walked cell is the kernel-context
symbol slot, whose value is the kernel-context object, or the pooled word at 0x1f66e0; no process
object field holds the value, and no arena word does either.

## Refuted
Heap/arena overlap: the app logs `gkernel: global heap 0x0013fd20 to 0x03db0000`, i.e. the global
heap is clamped to `reservation_begin` (kmachine.cpp under OTTSEL_SIGNED_GSTATE_EXPERIMENT).
`*active-pool*` as the source: in one run `active-pool-sym=0x4f4504` at dispatcher start while the
crash still used 0x3db0fb4, and its object reads as a valid pool. `(-> this child)` reading the
arena word at 0x3db0fc4 = 0x70004000 is a consequence, not the origin.

## Open, reproducible register anomaly
x19 (the `func` argument) is 0x10cd2551c / 0x10b7c551c = g_ee_main_mem + 0x801d51c - the *host
continuation* address of the `(func this)` call at seg0 0x5518 - instead of the lambda 0x801d724
that the caller passes, and x23 comes back holding the lambda. So an indirect GOAL call does not
leave the caller's x19/x23 intact; whether that rotation also feeds the walked cell is not proven.

## Next iteration (one variable)
Name the writer of the walked cell. Cheapest decisive test: regenerate the objects with the emitter
trace off but log `*kernel-context*`'s and `*active-pool*`'s symbol values plus the first words of
each at `kernel-dispatcher` entry in the same run, so the rotation hypothesis and the cell
hypothesis separate; then the fix is one site (argument setup or the symbol/cell slot, not the
walker). Reduction: the fault needs the strict signed-GAME registry; the KERNEL-only signed run
never enters this path.

