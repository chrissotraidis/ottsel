# I1 — New Game reaches Sequence A after ARM64 VI1 DGO packaging repair

Date: 2026-08-18

## Scope

One iPad Pro 11-inch (M4) Simulator and one `OttselShell` process. macOS `gk`
was not running. This records a script/bootstrap repair, not a renderer or
mobile-playability pass.

## Fault and cause

The first real New Game replay reached `target-continue`, loaded Misty, then
attempted `start-sequence-a` and faulted at the EE base. The fault register
state had a valid post-call return address but a zero resolved function target.
The live DGO log identified the producer boundary:

```
OTTSEL DGO RPC: skip non-GOAL obj 11 (sequence-a-village1, 9664 bytes, tag=0x0)
```

The installed app had the retail `iso_data/jak1/DGO/VI1.DGO` payload. Its
`sequence-a-village1` entry is PS2 v3 data and cannot provide a no-emit ARM64
function. The generated `out/jak1/iso/VI1.DGO` instead contains a 61,635-byte
entry beginning with `GOAL` magic.

## Repair

`scripts/build-ios.sh` now treats `VI1.DGO` like the existing `TIT.DGO`
exception: it skips the retail input in the asset copy loop and copies the
generated `out/jak1/iso/VI1.DGO` last. The actual test bundle was re-signed
after copying that payload. Its SHA-256 matched the generated DGO:

```
8910a4fcc117e966f30f76c357b68299d60024e2cf98361cd6b0763c76fe75e0
```

## Live replay

The rebuilt iPad app visibly booted to title. External keyboard input used the
shared pad bridge (Return for Start, Space for Cross, Left for the overwrite
confirmation) and produced the canonical title/new-game menu progression.
The runtime then recorded:

```
GAMEPLAY: enter village1
OTTSEL INTRO: preloading misty before sequence A
OTTSEL INTRO: misty ready status=loaded; starting sequence A
link finish: sage-intro-sequence-a
OTTSEL SPOOL: start name="sage-intro-sequence-a"
```

`ottsel-fault.log` remained zero bytes throughout. The two temporary
`loader stall on art sage-intro-sequence-a` messages occurred before the spool
start and are pending-to-active synchronization, not a persistent stall.

The visible frame during the sequence still showed incomplete world
composition (black lower field and camera/Direct presentation defects). It is
evidence that the real level script runs past the former null call, not a claim
that iPad rendering or touch controls are complete.

## Next gate

Keep the generated-DGO packaging invariant. Continue the explicit iPad
Direct/Sprite/offscreen-composition renderer gate and then finish the visible
touch overlay, controller/keyboard lifecycle, audio, and iPhone parity gates.
