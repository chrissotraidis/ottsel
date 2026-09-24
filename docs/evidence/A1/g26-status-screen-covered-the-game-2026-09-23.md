# G2.6: the shell's status screen was covering the running game - 2026-09-23

Found while checking whether the intro cutscene renders: a screenshot showed the shell's own surface - the
`ottsel S2.0 - Metal` header, `GPU path: Metal`, `DATA: import OttselUserData in Files` and the scrolling log
tail - filling the screen, while the game ran behind it (sprites drawn, 346 = 346 modules, the route reaching
Training).  A player would have seen the log, not the game.

## Root cause (measured, not guessed)

A bounded `OTTSEL DATA: status state=... data-missing=... live-scene=... has-user-data=...` line (logged only
when the reason changes) showed the flag **oscillating**:

    state=2  data-missing=0  live-scene=1  has-user-data=1
    state=3  data-missing=1  live-scene=1  has-user-data=0     <- the status screen goes up over a live game
    state=2  data-missing=0  live-scene=1  has-user-data=1

`select_ios_iso_data_dir()` reset `g_has_user_data = false` at its start, and it runs again mid-run while a pack
is re-imported (the lane's log shows the import twice, the second ~7 s after boot).  During that call's
`remove_all(durable)` / `rename(staging, durable)` window a frame rendered with `data_missing=1`.

It then stayed up because of where the clear lives: the status overlay is uploaded inside
`if (!g_metal || !has_live_scene() || data_missing)`, and the clear is the `else if` of that same branch - so once
the scene is live and the data is present the branch is skipped and the overlay is never cleared.

## The fix

Only the fallback path clears the flag now (`bundle_data_fallback` sets it false; the pack branches set it true),
so a re-import can no longer make a frame believe there is no data.  One file, `src/shell/ios_boot.cpp`; the
bounded diagnostic that found it is in the same patch.

Verified: the state sequence is now `1 -> 0 -> 2` with **no state=3**, and the screen reads **mean 59.7, dark
0.04** (game) against the status screen's 34.4 / 0.84.  346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte fault log.

## Residual

The overlay's clear is still inside that branch, so any future path that uploads the status screen after the scene
goes live would still stick.  The flag fix removes the observed trigger; moving the clear out of the branch is the
defensive follow-up.  This also means the current build had been hiding the game since the import began running
twice - earlier rounds' "visible gameplay" captures predate it, and the logs alone could not show it.

## Follow-up: the clear is reachable now

The residual above is closed.  `status_overlay_active` is hoisted out of the branch and the overlay is cleared
after it whenever it is still up, the data is present and the scene is live - so an upload that happens *after*
the scene goes live can no longer stick.  A normal run is unchanged (`1 -> 0 -> 2`, screen mean 60.7 / dark 0.03,
346 = 346, 0-byte fault log); the new branch's own trigger is the bug just fixed, so it is not exercised by that
run - it is a guard, not a fix.

## Aftermath: the visible evidence re-established

The bug hid the game, so the visible claim was re-checked on the fixed build rather than carried over.  A fresh
route with captures every 1.2 s now shows the screen *changing with the game* (`route00` mean 34.7 through
`route16` 124.2) instead of the frozen status surface, and the in-level frame is the game itself - Jak on the
training cliff with palms, the portal and the sky - at mean 60.8 / dark 0.03 against the status screen's
34.4 / 0.84.  The frame has no touch controls only because the route drives with keyboard triggers, which hide the
surface by design; one `ottsel-touch-cross` puts them back (90,133 overlay-tint pixels, `feedback mask=0x8
uploaded=1`).  `/tmp/ottsel-fixed/inlevel.png` and `touch.png` are the artifacts.

Still open from the same thread: whether the intro cutscene plays its intended sequence - the frames now vary, so
it is visible at all, but its audio lines are still played and stopped in the same second.
