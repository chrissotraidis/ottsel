# A1.3 signed-GAME dispatch: which link feeds the walk (2026-09-22, app)

Gate: the faulting walk's food supply is localized to two EE words, and the
kernel-dispatcher argument group is shown correct one frame up. No playability claim.

## Method
Fault-path-only diagnostics in `src/shell/ios_boot.cpp` (shell-only build, same signed profile
`config/signed-game-cgo-tit-vi1-control.json` + banks 1): scan all EE words for the faulting `this`
and for the child pointer, print each hit with context and its 0x20-aligned owner block, and resolve
symbol names. Three further runs each reproduced the same crash in under a minute.

## Only two non-stack holders of 0x3db0fb4 exist
`*kernel-context*`'s Symbol value slot (0x18adfc - confirmed by resolving the arena slot
0x3db0fc4 = -0x5008 from s7, as in the A1.2 doc) and one pooled word at 0x1f66e0. Every other hit is
inside the GOAL stack at the top of EE (0x7fff6b0..0x7ffff10), i.e. argument and spill copies.

## The pooled holder is a stale object with a function table
0x1f66e0's owner block (read live, this run) is
`0x1f66b0: 1c2a24 19dad4 1f6464 18fe04 | 1f66c0: 08019e04 0801a074 0801fa74 1cb850 1cb850 00000400
0803c2d4 00000000 | 1f66e0: 03db0fb4 ...`. So 0x1f66b0 carries a Type pointer (0x1c2a24) and a name
symbol (0x19dad4), the block at 0x1f66c0 holds three signed-module code addresses and
0x803c2d4 (the `execute-process-tree` function value, also x3 at the fault), and the kernel-context
sits at 0x1f66e0. 0x1cb850 reads as zeroed EE, i.e. the block references freed pool memory. In the
previous run the words from 0x1f66e0 matched the live x24/x3/x4/x5/x6/x7 exactly, so the same region
also mirrors the faulting thread's registers.

## The pool tree itself is healthy
Resolving `*active-pool*` from its own module slot (0x3db0fc4 -> sym 0x193fec) gives 0x4f4504, and its
child chain is `0x4f4504 (mask 0x100) -> child cell 0x4f45bc -> 0x4f45a4 (a pool, mask 0x11c) -> child
cell 0x1f437c -> 0x1f4364 (a process, mask 0x1c) -> child '() (s7 = 0x18fe04)`. That chain contains no
arena address, so the walk that faulted is not this chain: a link outside it (or a link that is no
longer the one it was) supplied the poisoned cell. A bounded C DFS is the wrong instrument here - it
follows field values as addresses and walks the symbol table through a "no child" link - so the tree
walk was retired in favour of the holder scan above.

## One frame up, the arguments are correct
The host stack at the fault (sp = 0x10d57fe80) holds a spilled argument group
`0x4f459c 00000000 | 03db0fb4 00000000 | 0801d724 00000000 | 0d59d5b0 00000000`, i.e. a pool cell, the
kernel-context, the lambda and a return address: `(func, context) = (lambda, kernel-context)` as the
dispatcher passes them. The faulting frame's own saved slots carry `this` = 0x3db0fb4, i.e. the
context value, so at the faulting edge `this` is the context while an outer frame still had the
correct pair. That matches the x19 anomaly in the A1.2 doc (the indirect GOAL call returns with x19
holding the call's host continuation 0x801d51c instead of the lambda) and makes the indirect-call
argument group the leading defect candidate.

## Next iteration (one variable)
Instrument the walk itself rather than its aftermath: regenerate the objects with the emitter's
bounded GOAL call trace enabled and re-enable the ring dump in the fault handler (shell change), then
read the last calls into `execute-process-tree` with their `site`/`target`/`pp`. Prediction: the
recursion's argument group is already rotated at the dispatcher edge (x19/x23 swapped or shifted),
in which case the fix is the indirect-call registration or the synthetic-return contract, with the
regression being an emitted-module check that an indirect GOAL call preserves x19/x23.

