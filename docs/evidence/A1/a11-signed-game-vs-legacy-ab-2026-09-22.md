# A1.6 signed-GAME vs legacy control: the surviving fault needs arena-executed GAME code (2026-09-22, app)

Gate: the `font`/`draw-string` fault is specific to executing GAME code from the module arena. The same
tree, machine and emitter with GAME left on the legacy path loads village1 with a zero fault log.

## Method
Same worktree (including the A1.4 `.ret` mask fix), same booted Simulator, one app at a time, no
recording, both launches with no environment or arguments. The only difference is the signed registry:
strict `config/signed-game-cgo-tit-vi1-control.json` (27.4 MB app, 335 signed modules) versus the
control `config/signed-kernel-full.json` (6.9 MB app, 6 signed modules). Nothing else was rebuilt or
moved.

## Strict run
All 335 signed modules report ENTER *and* RETURNED, so no module top-level was abandoned. The streamed
lane signs `static-screen`, `title-obs` and `villagep-obs` and falls back to legacy for thirteen
objects (`tpage-1609/416/415/397/1499`, `logo`, `logo-black`, `logo-cam`, `logo-volumes`, `ndi`,
`ndi-cam`, `ndi-volumes`, `title-vis`). It then faults: `signal 10` in signed `font` offset 0x6864,
nearest symbol 0x852c004 (`draw-string`, +0x6860), faulting word `0xb9000205` = `str w5, [x16]` with
x16 = g_ee_main_mem + 4, x0 = 0, x20/pp = 0, drawn = 0. Decoded chain:
`ldr w0,[x2+0xbd0]; add x16,x0,ee; add x16,x16,#4; str w5,[x16]` with x2 = 0x3da7140 (a heap object
below the arena reservation) whose field at +0xbd0 holds 0.

## Control run
`config/signed-kernel-full.json` + banks 1: `ottsel-fault.log` stays 0 bytes and the runtime log runs on
past the strict run's failure point to `LINKBEGIN: legacy fallback village1-vis`, `windspinner`,
`yakow`, `water-anim-village1` and `warpgate` with two `GAMEPLAY` markers. So the village1 level load
itself, including the PC loading overlay path that reaches `draw-string`, works when GAME code runs from
the heap.

## Reading
The crash class the objective names - signed GAME text transferring control into the module-arena data
region (the A1.1 `FAR=0x181674`, `x20/pp=0` case) - is fixed at the `.ret` site (A1.4). What survives is
not a pre-existing port bug reachable in both modes: it needs GAME code to execute from the arena. So
the next work is the signed-GAME lane's execution and initialization - the streamed signed scope plus the
loader's value-0 intern per `SIGNED_AOT_RECOVERY.md` - with the `font` site as the acceptance probe, not
as the defect.

## Next iteration (one variable)
Read the same level object in both modes while each run is live (strict faults with the object base in
x2; the control run keeps running) and compare the field at +0xbd0 and the object head. Prediction: the
strict run's signed loader leaves a pointer field unwritten (value 0) that the legacy object-file link
writes, which names the missing write and makes it a bounded loader regression.

