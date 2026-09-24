# G2.5: the phone lane re-checked on the current build - 2026-09-23

Gate item: G2.5 iPhone parity.  The phone was last driven before three shell changes landed - the Gameplay/Video
settings sections, VIDEO render scale, and the fix that lets a touch restore the touch surface - so it was
re-driven on the current build rather than assumed to still hold.

## The run

Fresh install on `Ottsel iPhone SE3`, launch with `SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1` and
`SIMCTL_CHILD_OTTSEL_AUDIO_DUMP=80`, `scripts/replay-ios-normal-route.py` (rc 0).

## Measured

    class/surface   class=phone surface=667x375 min-region=37x43 safe-lrtb=0x0x0x0
    route/gameplay  GAMEPLAY: enter training, scene-level='training'
    stability       346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte ottsel-fault.log
    input           pad0 sample buttons=0x4000 cross-pressure=255; target trace 160 samples spanning
                    5,558,057 units
    audio           stream opened device=21 (`route='System audio playback device'`), `Load music village1`,
                    80.00 s PCM dump peak 32768 rms 3467, 21 named PLAYER RPC events (walk-grass1/2,
                    land-grass, jump, swim-jump/stroke/idle1/2, swim-kick-surf, breath-in/out-loud,
                    training-amb, bird-2, fly7, water-drop, warpgate-tele, and the frontend's
                    cursor-up-down / select-menu / select-option / menu-close)

## The new items, on the phone

    VIDEO / RENDER SCALE   667x375 -> 500x281 (75%) -> 333x187 (50%) -> 667x375, read from
                           `OTTSEL TOUCH: class=phone surface=`; persisted as scale in settings-phone.cfg
    GAMEPLAY / camera      CAMERA SENSITIVITY 50% with INVERT CAMERA Y ON gives right=(147,137) on the
                           camera hold's own pad sample (147 = 127+20 for 50%, 137 = 127+10 inverted)
    touch-surface fix      keyboard hold then release -> 0 overlay pixels; one touch -> 39,559, counted from
                           the overlay's own left-stick tint in phone-ab-hidden/-restored.png

`settings-phone.cfg` after the run is `1 0 100 0 50 1 100` (visibility, music, log, sensitivity, invert,
scale), so the new fields persist on the phone as they do on the iPad.  `/tmp/ottsel-accept/phone-gameplay.png`
is the in-level frame with the controls drawn (39,532 tint pixels).

## Boundary

Proven: the current build holds parity with the iPad on the accepted route, the new settings and the
touch-surface fix behave identically on the phone profile, and audio reaches the real device there too.  Not
proven: anything device-side - there is no signing identity or provisioning profile on this machine, so the
physical iPhone (D1) remains open.  No playability claim beyond the simulator.
