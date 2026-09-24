# The iPad lane stalls on a fresh container: the user-data family dependency - 2026-09-22

Gate: L5 (route) with an environment finding.  Question: why did the route get no further than the
title, and why did later runs stop booting entirely?

**The route blocker is the driver, not the input.**  `scripts/replay-ios-normal-route.py` waits for
`OTTSEL INPUT: pad0 sample buttons=0x0`, which `out/jak-project/game/sce/libpad.cpp` only logs when the
app runs with `OTTSEL_TRACE_INPUT=1` and only on a button transition; and it pressed with
`ottsel-press-*`, which is one frame of state, while `src/shell/main.cpp` documents that a hold
(`ottsel-hold-*`) is what the game actually reads at this lane's 5-8 fps.  Fixed in the driver: presses
now use the hold trigger and hold until the accepted edge appears.  Driven that way earlier in the day,
the shell latched 7 of 7 taps while the frontend stayed at `screen=27`, which is consistent with the taps
being sampled away by the loader/pre-title state rather than lost by the plumbing.

**The fresh-container failure is a real product defect, and it was triggered by this session.**  With a
fresh app container the app dies during boot - the log ends at the `gsound` link's `OTTSEL RpcCall` with
`libc++abi: terminating due to uncaught exception of type ghc::filesystem::filesystem_error: No such file
or directory: .../OttselShell.app/iso_data/SBK` - so the process is gone, the 'frozen at 154/346 modules
for four minutes' I measured was a dead process, and `ottsel-fault.log` stays 0 bytes because it is not a
signal crash.  Root cause: `scripts/build-ios.sh` deliberately stages only `DGO` and `TEXT` into the
bundle's `iso_data/` (ROM-safe: the app never embeds the user's game data), while
`src/shell/ios_boot.cpp` needs the user's pack families (`CGO DGO fr3 MUS SBK STR TEXT VAG VIS`) to promote
them into the container on the first launch - and a missing family is an uncaught exception instead of a
named, graceful error.  Fix shapes: catch it and log which family/path is missing, and/or fall back to the
bundle copy for the families that are present.

**Environment state (must be reported): the iPad lane cannot boot until the user's data is restaged.**
The staged pack family directories in the app bundle were removed by the rebuild
(`rm -rf "$APP/iso_data"` in build-ios.sh) and the container's promoted copy was removed by this session's
`simctl uninstall`; a scan of every simulator device finds only the current 12 MB Ottsel container, so no
copy survives.  Recovery: `scripts/prepare-user-data-pack.sh <extracted-jak1> <out>` (out-of-repo, as the
script requires), stage the families into `out/jak-project/out/ios/app/OttselShell.app/iso_data/`, rebuild
and install - or point me at an existing pack.  The macOS lane is unaffected (it reads the repo/ISO data,
not the iOS bundle).

Not claimed: no playability, audio or lifecycle acceptance, and the route's first transition is still
unproven.  Every iPad run this turn kept the fault log at 0 bytes, which is exactly why the exception above
had to be read off stderr.
