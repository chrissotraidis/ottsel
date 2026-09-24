# A1.9 the null field is font-work.buf, a static structure in font-h data (2026-09-22, host + live)

Gate: the `font`/`draw-string` fault is a null pointer field of the game's own static font work object.
No playability claim.

## The base is the global *font-work*
`x2 = 0x3db9990` is the value of `*font-work*`. Read live: the `font` module's own slot for
`*font-work*` (emitter json: seg0 data offset 8792 = 0x2258, kind `symbol_offset`) holds `0xffff7be0`;
sign-extended and added to s7 (0x18fe04) that is GOAL 0x1879e4, and the symbol there holds value
`0x3db9990` with a name string pointer at +0x20000. So the game global `*font-work*` is exactly the
faulting base, and it is not a heap object.

## The object is legitimate: a static structure
`goal_src/jak1/engine/gfx/font-h.gc:232` is `(define *font-work* (new 'static 'font-work ...))` and the
type is `(deftype font-work (structure) ...)`. A structure has no runtime type pointer, which is why the
emitter's record set for font-h has no `type_pointer` slot: the earlier 'module data used as an object'
reading is refined, not wrong - the static object really lives at `font-h` seg0 data + 0x50
(`aggregate.json` places that segment at 0x3db9940) and the live arena there matches the module's data
template word for word.

## The null field is buf
The fault block reads `(-> *font-work* buf)`: `font-work`'s `(buf basic)` field sits at +0xbd0, i.e.
`font-h` data + 0xc20, which is 0 in the template, has no emitter record, and is 0 live. `buf` is a
pointer field (type `basic`), so `draw-string` adds the arena base and stores `(-> buf 1)` at
`g_ee_main_mem + 4`, which is the SIGBUS. The object size validates the offset too: buf plus
str-ptr/flags/reg-save is 0xbf0 bytes, so the static object spans data 0x50..0xc40, exactly where the next
font-h records (object, *math-camera*, log2) begin.

## Who fills buf
Nothing in `goal_src/jak1` sets `(-> *font-work* buf)` (grep across the tree) and the static initializer
does not set `:buf` either, so buf is zero in both modes by construction and must be filled by other code
at runtime - the MIPS/mips2c font path or a streamed legacy module. In the KERNEL-only control the
loading-overlay path through `draw-string` completes with a zero fault log, so whatever fills buf ran there
and did not run in the strict lane. That is a runtime setter/ordering difference, not an emission or
placement defect at this site.
## The display-frame buffer is not null, so that caller is not the one
The emitted @draw-progress@ chain was decoded to get the exact offsets
(@*display*@ + 0x22c for the frame base, x32, + @*display*@ + 0x234, then +0x10, +0x24, +0x4). Reading them live
in the held process gives @*display*@ = 0x509d34, frame base 0x509f88, and the final value 0xce8400 - nonzero.
So a @draw-string-xy@ caller taking its buffer from the display frame's global-buf is not the faulting path; the
caller is elsewhere, and the cheap decisive tool left is the emitter's own GOAL call trace.

## Next iteration (one variable)
Rebuild with @OTTSEL_TRACE_GOAL_CALLS=1@ (regenerate the objects, then build), re-enable the ring dump in the fault
handler, and run @scripts/a11-goal-ring-audit.py@ over the captured ring: the last entries before the fault name
the caller of @draw-string@, and the argument it passed is then a two-line read.
