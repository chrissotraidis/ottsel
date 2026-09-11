# BOT44 - the numeric prints were empty and the host triggers were racing

Round BOT44, 2026-09-11. iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, `com.ottsel.shell`. Two separate
defects, both proven by reading the live log and the linked binary.

## Defect 1: `~D`/`~X`/`~B` printed nothing (FIXED)

`format` binds to C++ `kprint.cpp`. `case 'D'`/`case 'X'` call `kitoa()`
(`game/kernel/common/kprint.cpp:521`), which indexes `ConvertTable`, declared
`char ConvertTable[16];` and filled only by `kprint_init_globals_common()`
(`memcpy(ConvertTable, "0123456789abcdef", 16)`). The desktop runtime calls that
at `game/runtime.cpp:563`; the iOS kernel-subset init in
`src/shell/ios_boot.cpp` did not. The table stayed all zeros, `kitoa` wrote NUL
bytes, `strend()` saw an empty string, so every numeric field printed nothing
while `~A`/`~S`/`~F` were unaffected.

Fix: one call to `kprint_init_globals_common()` after `kmemcard_init_globals()`
in `ottsel_ios_run_boot()`.

Verified live after recompile/relink/install: the old infinite
`loader stall on art logo-intro-2` (3720 copies in one launch) is gone entirely
(`grep -ac 'loader stall' = 0`), and the previously empty fields now read, e.g.
`OTTSEL TITLE: start edge in title-wait abs=8 rel=8 progress=#f`,
`OTTSEL MOBILE DIRECT: bucket trace end transfers=64 glyphs=0`,
`... bucket trace end transfers=64 glyphs=0`, and
`OTTSEL PROGRESS: result process=268183 master=progress`.

## Defect 2: the synthetic-input triggers were stolen by the Mac reference

`/tmp/ottsel-press-button` and the other host triggers are resolved in the host
`/tmp`, which the Simulator app shares. A Mac reference `out/jak-project/build/h1/game/gk`
left running from an earlier check (`PID 4495`, 97% CPU) consumed each trigger at
its own `ottsel_pad_reads % 250 == 8` before the iPad app ever polled it, so the
file vanished with no `synthetic` log line in either process. Stopping the Mac
reference makes the trigger reliable again. Related trap: the newer mobile probes
read their triggers from `ottsel_ios_writable_dir()` (the app container), not
`/tmp`, so a `/tmp`-only trigger silently never arms them.

## Also corrected: the progress screen does load

The BOT44 gate text asserted the progress screen "never accepts". It does.
After START, `OTTSEL PROGRESS: request screen=27 allowed=#t` then
`OTTSEL PROGRESS: result process=268183 master=progress` - the menu process is
created and the master mode is `progress`. The remaining defect is that the
title/progress UI draws no text and no logo on iPad while the Mac reference draws
both, so the gate is a rendering defect, not a route defect. Sprites are also
submitted (contradicting the carried note): the log shows
`OTTSEL SPRITE METAL: native HUD atlas vertices=288 sprites=48 textures=9 atlas=512x512`.

## Open lead

Text and sky share the Direct/VRAM texture path (`decode_direct_vram_texture`,
`g_direct_relocated_textures`). The sky decodes to flat cyan and the glyphs draw
nothing, which is consistent with one wrong decode for uploaded VRAM textures
rather than two independent faults. Not yet tested.
