# A1.7 - the null dma-buffer: caller, argument and trap, named (2026-09-22, live)

Read off the *installed* binary, the held fault process (pid 26828) and the emitted `modules.uiypGg`
manifest. No claim beyond what those three show; product state untouched.

## The faulting instruction is the last store of `draw-string`
`font` seg0 +0x6858..+0x6864 disassembles to `add x16,x2,x22; add x16,x16,#0xbd0; ldr w0,[x16];
add x16,x0,x22; add x16,x16,#4; str w5,[x16]` - `font.gc:1462`, `(set! (-> (the-as (pointer pointer)
(-> fw buf)) 1) dma-out)`. The pc's own words in the fault log (`0xb9000205 0x910003f0 0x91038210
0xf9400200`) match this disassembly instruction for instruction.

## Callee and caller
The live `draw-string` symbol value is 0x84BC004 = font+4, i.e. font's first seg0 function
[0x4,0x68C0) - the 6720-instruction mips2c body, which contains no `bl`/`blr` at all and never writes
x25. The fault's x30 = 0x10D5C7090 = main+0xB090, so the call is the `blr` at main+0xB08C: the
`display-loop` line `(let ((a3-8 (the int (draw-string *stdcon0* s3-1 *font-context*))))`
(`engine/game/main.gc:513`; the following `fmov s0,w0; fcvtzs w3,s0` is the `the int`). Every slot the
call site loads resolves to that source line: main data +3988/3992/3996/4000/4004 =
*debug-segment* / *master-mode* / `pause` / *cheat-mode* / `camera` (the pause `if`), +4008/+4028
`draw-string-xy`, +4012 *common-text* (`lookup-text!`), +4016 `draw-string`, +4020 *stdcon0*,
 +4024 *font-context*, +4032 *stdcon1*.

## The argument was NULL
Live `*font-work*` (arena+0x3DB9990, host 0x108AC5990): `buf` @+0xBD0 = 0 while `str-ptr` @+0xBD4 =
0x4F4DF4, which is the live `*stdcon0*` value - so the prologue `(set! (-> fw buf) context)`
(font seg0 +0x350) ran and stored a null context. The frame buffer never reached the callee.

## The trap is a store to a readable, unwritable page
`(-> context base)` (font seg0 +0x354, `ldur w1,[x1+ee+4]`) reads 0 rather than faulting, which is why
dma-out (= x5) is 0 at the fault; the SIGBUS (signal 10) comes from the final `str w5,[ee+4]`. The low
EE page is mapped and readable (lldb reads of ee+0 return zeros) but not writable, so this is a
write-protection trap, not the PROT_NONE guard read the A1.5 writeup assumed.

## Who passes the buffer: the frame field, not a clobbered register
`goalc/emitter/Register.cpp` `make_register_info_arm64()` sets `m_saved_gprs = {X19,X23,X24,X25,X26}`,
so x25 is callee-saved. x25 is written once in `display-loop` (main+0xAE68) from the
`(if *debug-segment* ...)` chain and reaches the call unmodified: *master-mode* (0x1992D4) differs
from `'pause` (the `pause` symbol's own address, 0x1993EC), so the pause block with `lookup-text!` and
`draw-string-xy` is skipped and no call intervenes. The null therefore came from the frame field.

## What the frame holds now (post-fault snapshot, arena-relative)
*display* = 0x509D34, on-screen = 1, frames[1] = 0x509F88, its `frame` = 0x50A114:
frame+0x04 = 0x50C884, +0x08..+0x1C = 0, **+0x20 = 0**, +0x24 = 0xCDCFD4, +0x28 = 0x50C8A0,
 +0x2C = 0. The chain emits `debug-buf` at +0x20 and `global-buf` at +0x24 (G1.11 read draw-progress's
`global-buf` at +0x24 as well, so the emitted layout sits 4 bytes below the deftype's 36/40), so the
path that ran read +0x20 = 0 - the debug buffer.

## Why a null buffer is reachable, and what decides it
`display.gc:236-238` allocates a frame's `debug-buf` only `(when *debug-segment* ...)`; `display-frame`'s
`new` starts it at 0 and `global-buf` is allocated unconditionally. `*debug-segment*` is written exactly
once, at boot (`kscheme.cpp:2213`, from `DebugSegment`), and the port's false value is exactly `s7`
(`set_fixed_symbol(FIX_SYM_FALSE, "#f", s7.offset + FIX_SYM_FALSE)`; `kboot.cpp:483` notes "an #f link
equals s7.offset (0x18fe04)"), so any other value - including a fail-open intern's 0 - is truthy for the
emitted `cmp flag, x21 / b.eq` pair and sends the frame loop down the debug path.
The post-fault frame read gives +0x20 = 0, +0x24 = 0xCDCFD4, +0x28 = 0x50C8A0; under the deftype's 36/40
offsets that says the *debug* buffer is non-null, so this snapshot is not the state at the crash and the
crash is only reachable with a null debug buffer (flag truthy). G1.13 therefore reads the flag and both
buffer slots *at* the fault - one bounded probe - and settles it between "the frames were built while the
flag was false and it read true later" and "the chain reads the other slot"; the fix follows from that.
