# A fresh install names the missing game data instead of aborting - 2026-09-22

Gate: I0 (bootstrap robustness).  Question: with no imported user pack anywhere, does the iPad lane
report the missing game data and keep running, instead of dying with an uncaught filesystem error?

**Before (held log, /tmp/ottsel-i0-b.log, 13:53).**  The lane names the gap at boot - `OTTSEL F1: no user
pack at .../Documents/OttselUserData; using diagnostic bundle data` and `OTTSEL F1: bundle data at
.../OttselShell.app/iso_data is incomplete (missing: CGO, fr3, MUS, SBK, STR, VAG, VIS)` - then reaches
`OTTSEL_IOS: linking object 147 (gsound)`, dispatches one sound RPC and dies:

```
libc++abi: terminating due to uncaught exception of type ghc::filesystem::filesystem_error: No such file
or directory: '.../OttselShell.app/iso_data/SBK'
```

**Cause.**  `fake_iso_FS_Init()` (`game/overlord/common/fake_iso.cpp`) constructs the *throwing*
`fs::directory_iterator(root)` with `root = <iso_data>/SBK`, which `jak1::mobile_sound_banks_ready()`
(`game/overlord/jak1/srpc.cpp`) sets before the first bank load; ghc::filesystem raises when that
directory is absent.  The sound RPC is reached through the GOAL asm bridges, which carry no unwind
information, so `ottosel_ios_run_boot`'s `catch (const std::exception&)` guard never saw it.

**Fix - one guard, `patches/i0-fake-iso-missing-root.patch`.**  `fake_iso_FS_Init()` now tests the root
with `fs::is_directory(root, ec)`, logs `[FAKEISO] no readable root <root>: <reason>; sound data is
unavailable` once (a static flag - the sound loader retries the RPC) and returns `-1`.  That is the
contract its callers already implement: `mobile_sound_banks_ready` and the three `ios_boot.cpp` probe
sites all check `< 0`, so the lane runs without sound instead of aborting.  The overlay is narrow and
layered after H3; pin `641fb572e` + H3 + this overlay reconstructs `fake_iso.cpp` byte-for-byte, it
reverse-applies to the current checkout, and the Stage 0 overlay-coverage guard still passes.

**Measured, fresh install (simctl uninstall -> install, no pack in the bundle, Documents or durable
copy), two runs, product build `OTTSEL_SIGNED_GSTATE_EXPERIMENT=0
OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json OTTSEL_SIGNED_EXPORT_BANKS=1`:

- Run 1 (`/tmp/ottsel-i0c.log`, guard before the one-shot bound): same F1 lines, **5256**
  `[FAKEISO] no readable root` lines, 0 `terminating`/`uncaught exception`, and the lane was still
  presenting at the end of a 200 s window (vsync 4861, 18886 log lines).
- Run 2 (`/tmp/ottsel-i0d.log`, final binary `OttselShell` sha256 `239cee03...`): the same F1 lines,
  **exactly one** `[FAKEISO] no readable root .../iso_data/SBK: No such file or directory; sound data is
  unavailable`, no `terminating`/`uncaught exception`, 346 ENTER = 346 RETURNED, and the lane ran the
  whole 200 s window (vsync 10351, chain 10350, game-base 355725, ending at the
  `OTTSEL STR: chunked animation not found name=ndi-intro` stage) with `ottsel-fault.log` at 0 bytes.
  `scene-level=''` and `drawn=0` are expected there: the no-pack lane has no level data to reach the
  title with.

**Regression with the pack (the guard must not fire when the data is there).**  After
`scripts/import-ios-user-data.sh` promoted the 1.5 GB pack, a 90 s run (`/tmp/ottsel-i0e.log`) logs one
`OTTSEL F1: imported validated user pack into ...`, **zero** `no readable root` lines, 346 ENTER = 346
RETURNED, `scene-level='village1'`, tie-ready/tfrag-ready true, cam-accepted 9506 with 0 rejects,
merc-submits 19272, eichar=4, vsync 1171, a 0-byte fault log, and the screenshot
`/tmp/ottsel-i0e-title.png` shows the title screen (PRESS START) over the rendered village background.

Not claimed: no route/New Game proof, no playability, audio or lifecycle acceptance.
