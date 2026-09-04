# I1 title enter-state fault — 2026-09-03

Status: OPEN. This is a runtime blocker for repeating the level-ownership
experiment; it is not playability evidence.

Question: did the ownership build fail because title-obs was absent or because
the packet-level ownership change corrupted the scene transition?

Evidence from the retained signed-build container log:

- `link finish: title-obs` and `link finish: title-vis` both occur before the
  first title frame.
- `GAMEPLAY: enter title` and the route marker execute successfully.
- Immediately afterward the gated fault probe reports
  `enter-state pp=x20=0x0`, with all inspected process fields zero, at
  `pc=0x10055a288`, fault address `0x140`.
- Symbolizing the exact installed bundle gives
  `spu_memory + 191584` for the PC and `spu_memory + 191544` for the LR.
  Both addresses are inside the writable audio sample buffer, so this is an
  attempted execution of audio-buffer data, not a PC-proven `enter-state`
  fault.
- The corresponding GOAL-relative target is `0x0055a288`; the installed
  bundle's `_spu_memory` begins at `0x10052b628`. This makes the failure an
  invalid code pointer that lands in the SPU buffer after the title event.
- A fresh signed diagnostic build reproduced the gated crash at
  `pc=0x1005aa708` immediately after `GAMEPLAY: enter title`. The attempted
  runtime classifier did not emit its marker because the fixed EE mapping and
  the statically linked `_spu_memory` address occupy the same low image range;
  this address-space overlap is now an additional confirmed investigation
  target, not evidence that the classifier passed.
- No `OTTSEL TITLE: entered bootstrap` or `title-play received wait` marker is
  emitted, and no Village1 transition occurs.

Interpretation: the old “title-obs was not linked” explanation is falsified for
this run. The remaining defect is a bad GOAL function/continuation pointer that
lands in `spu_memory` after the title level event, before the title bootstrap
state can enter. The ownership source change has no observed packet, FR3, or
Metal fault in this run, but its runtime gate remains OPEN until this fault is
root-caused and covered by a focused regression.

Next experiment: prove the EE-map/`_spu_memory` address contract on iOS and
identify which state/function slot contains the invalid target before and
after the first PLAYER audio RPC. Add a before-failing regression, then run
one signed build only.
