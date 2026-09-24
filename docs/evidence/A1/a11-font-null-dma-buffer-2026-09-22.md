# A1.5 - the strict run's crash site: a null font DMA buffer (2026-09-22, app, traced guard-on build)

The ring said the last call is main -> font+0x4. Naming that target and reading its code turns the
crash from an unnamed data fault into one identified instruction and one identified null field.
No playability claim. Builds and module tables are the ones A1.4 audited (installed shell sha256
206662cf, slide 0x4588000, arena 0x104f80000, emission modules.vLhp7r).

## The target and the caller are named
The font module has exactly five immutable function tags (0x0, 0x68c0, 0x6a30, 0x7430, 0x7730) and
font.gc has exactly five top-level function forms in the same order, so the tag table maps by
construction: 0x4 draw-string (spans 0x4..0x68c0, ~27 KB from ~875 source lines), 0x68c4
draw-string-adv, 0x6a34 get-string-length, 0x7434 draw-string-xy, 0x7734 draw-string-xy-scaled.
So the ring's last call, main+0x12774 -> font+0x4, is a call into draw-string.
The caller is the module main's largest function, entry main+0xb2c4 (0xb2c4..0x14f40, ~40 KB). The
main module has 14 tags against 13 top-level forms in engine/game/main.gc, so the extra tag(s) come
from a nested defstate; the entry is pinned, the name is not.

## The crash instruction, disassembled (font+0x6864 = 0x108f2a864)
    add  x16, x2, x22          ; x16 = EE(x2), x2 = the local font-work pointer (0x3da7140 here)
    add  x16, x16, #0xbd0      ; + 0xbd0 = the buf field offset
    ldr  w0, [x16]             ; w0 = fw.buf  -> 0
    add  x16, x0, x22          ; dereference that pointer
    add  x16, x16, #4          ; + 4
    str  w5, [x16]             ; <-- FAULT: store to EE 4, the EE mapping's protected first page
The next instructions are the function's own epilogue (fsub.4s, fmov/sxtw, add sp, sp, #0x1e0), and
the fault is 0x5C bytes before the function's end - i.e. this is draw-string's last store.
This is not the arena-first-bytes Symbol-address class: the address is literally null + 4.

## The source line that store implements
font.gc's draw-string sets fw.buf from its own argument at line 791, (set! (-> fw buf) context), and
its final statement is (label cfg-189) (let ((v1-6 (-> fw buf))) (set! (-> (the-as (pointer pointer)
v1-6) 1) dma-out)) - so the 4-byte store at +4 writes dma-out into the buffer's write pointer, and
what is null is the font path's DMA buffer (the context argument), not a call target or module entry.

## Context worth keeping
The ring tail (entries 17-39) is the text/HUD chain main -> drawable/progress/hint-control/text/
gstring/depth-cue -> font. The same frame shows x20 (pp) = 0 and x19/x23/x24/x25/x28 = 0 (the A1.3
register anomaly), and the trace probe is compiled into this build, so "product fails identically"
is not claimed: the next measurement is the same route with the trace off.

## The caller side (same build, disassembled)
The call is well formed: at main+0x127ec main pushes its own x30, sets the continuation with
adr x17, 0x1094da800 (main+0x12800 - exactly the lr in the fault log) and blr's the callee. The
buffer argument is set four instructions earlier by mov x1, x25, and x25 is written only twice in
that function - both mov x25, x0, the later at main+0x70a4 from the chain ldrsw x0,[x19+0x22c];
lsl x0,#5; add x0,x19+0x234; ldur w0,[x0+0x10]; ldur w0,[x0+0x24] - so the null is a value main read
out of that object graph, not a fresh allocation.

## Build identity (matters for reading this)
This run carries the inert .ret form (34 sites emit lsr x17, x17, #32, taking the mask from the
pushed continuation) - the defect the A1.4 gate fixed at goalc/compiler/IR.cpp. The board's
A1.6/A1.7 record the same store surviving that fix, so this null buffer is a second defect.

## Next
Re-run the same strict profile with the trace off and the guard on; if the fault pc is the same
store, the font DMA buffer is genuinely null on this route and the fix belongs in the font/HUD call
path (who passes context), not in the call ring.
