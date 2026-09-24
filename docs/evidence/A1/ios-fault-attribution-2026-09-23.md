# Stability: the fault handler now names its own site, and the phone fault does not reproduce - 2026-09-23

Open item carried in: one fault on the phone lane during the early-frame title runs - a 338-line
`ottsel-fault.log` with `fault pc=0x1049539c4 lr=0x104953988` (adjacent addresses in the app's own host
text), the host register/stack dump, GOAL process and region reads, and the symbol-slot scan, and **no**
attribution line anywhere in it.

## What landed (src/shell/ios_boot.cpp)

The fault handler now reports, right after `pc`/`lr`/`sp`:

- the image slide (`_dyld_get_image_vmaddr_slide(0)`), and
- the pc and lr named through `dladdr` - symbol, offset from that symbol, and the image path for the pc.

Before this, a host-text fault left only raw addresses, which cannot be attributed after the fact because the
run's slide is not recoverable (the past dump's stack and symbol-slot lines carry EE/GOAL addresses, not host
anchors, so that dump stays unattributed).  With the slide and the symbol recorded, any recurrence - and any
dump whose slide is known - identifies its own site.  The change is diagnostic only: no behaviour, ordering or
control flow moves.

## Reproduction attempt: 6/6 clean

Six launch cycles on the phone lane, alternating the `ottsel-trace-sky-skip-draw` control that was set during
the runs in which the fault appeared, each reaching `title-wait-ready` and dwelling 20 s at the title:

    cycle 1 skip=False ready=7.60s modules=346 fault_bytes=0
    cycle 2 skip=True  ready=7.09s modules=346 fault_bytes=0
    cycle 3 skip=False ready=6.58s modules=346 fault_bytes=0
    cycle 4 skip=True  ready=6.60s modules=346 fault_bytes=0
    cycle 5 skip=False ready=7.09s modules=346 fault_bytes=0
    cycle 6 skip=True  ready=6.59s modules=346 fault_bytes=0

With the earlier repeat of the same run that is seven clean attempts of the route and window in which the
fault was seen, so it is not reproducible from them.  The lane left no `ottsel-trace-*` trigger behind.

## Boundary

Stated plainly: the single fault is **not explained**.  What is established is that it does not reproduce on
this route in seven attempts, that the lane stayed live through the original occurrence (346 modules and
continuous captures), and that the next occurrence will name its own site in the dump.  Its artifact is
preserved beside the phone lane as `ottsel-fault.log.prev`.  A broader stability sweep belongs with the
soak item, not here; no cause is claimed and no fix is implied.

