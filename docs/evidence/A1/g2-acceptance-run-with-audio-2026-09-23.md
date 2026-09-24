# G2 acceptance: visible gameplay, input, stability and audio in one run - 2026-09-23

Gate item: the product bar asks for fresh visible gameplay with input, stability, lifecycle and audio together,
not counters.  The audio substrate only became reachable on the Simulator this session, so this is the first
run that can carry all of it at once.

## The run

Fresh install, launch with `SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1` and `SIMCTL_CHILD_OTTSEL_AUDIO_DUMP=80`,
`scripts/replay-ios-normal-route.py` to Training (rc 0), then in-level play driven through the **touch path**
(`ottsel-touch-*`, so the drawn controls stay up), with a bounded `simctl io recordVideo` capture.

## Measured

    stability   346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte ottsel-fault.log, scene-level='training' x75
                (village1 x6 during the route)
    input       pad0 samples carry the driven state - left=(167,107) for the touch stick, buttons=0x4000
                (Cross), 0x20 (DpadRight) - and the target trace spans 5,642,301 x 3,666,344 units over 159
                samples, i.e. Jak translated through the level
    audio       stream opened on device=21 (`route='System audio playback device'`, no dummy driver); PCM dump
                80.00 s, peak 32768, rms 3743, 71 of 80 seconds carrying signal; `Load music village1`
    events      27 distinct PLAYER RPC sounds, tied to the driven input: walk-grass1/2, walk-sand1/2,
                walk-water2, land-grass, land-sand, jump, eco-bg-blue, swim-jump, swim-stroke, swim-idle1/2,
                swim-kick-surf, breath-in/out-loud, training-amb, bird-2, fly7, and the frontend's
                cursor-up-down / select-menu / select-option / menu-close
    visible     /tmp/ottsel-accept/acceptance-inlevel*.png show live in-level gameplay with the touch controls
                drawn (74,608 / 75,739 overlay pixels); /tmp/ottsel-video/g2-acceptance-touch-2026-09-23.mov is
                the 25 s recording of the same stretch

Lifecycle was exercised separately in the previous run and again here: background gives
`input neutralized and audio paused`, foreground gives `controller rechecked and audio resumed`.

## What this does and does not establish

It establishes, in one process on the current build, the simulator-side half of the acceptance bar: visible
gameplay, input reaching the game, stability, lifecycle and audio with signal.  It does **not** establish
playability on a device (no signing identity or provisioning profile exists here), dialogue audio (the training
level defines no `level-hint-spawn`, so its voicebox dialogue is unreachable on this route), or a human
listening check - the audio claim is that the real output device is handed non-silent PCM, not that an ear
confirmed it.
