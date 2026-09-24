# G2.6: the allowlist package inspection - 2026-09-23

Gate item: G2.6's second half, "the allowlist package inspection" - what the built product actually ships, and
whether any of it is ROM-derived.

## Method

Enumerate the built app bundle recursively, classify every entry, and hash the bundled DGO/TEXT against the
extracted ROM's copies of the same names.  The extraction lives in `out/jak-project/iso_data/jak1` and the bundle
in `out/jak-project/out/ios/app/OttselShell.app`.

## What ships (61 MB, and nothing else)

    OttselShell                       the shell binary (22 MB)
    Info.plist                        bundle metadata
    _CodeSignature/CodeResources      the signature
    GAME.CGO, KERNEL.CGO              goalc output from the game's GOAL source
    iso_data/DGO/TIT.DGO              built title DGO (1.4 MB)
    iso_data/DGO/VI1.DGO              built village1 DGO (11.5 MB)
    iso_data/TEXT/*.TXT               48 text files (COMMON/SUBTIT), built

A search for ROM families finds none: no `*.iso`, `SCUS*`, `*.SBK`, `*.VAG`, `VAGWAD*`, `*.MUS`, `Z6TAIL*` or
`*.STR` anywhere in the bundle.

## The bundled assets are the build's, not the ROM's

Same names, different bytes:

    TIT.DGO       bundle 7421fc02714448e4...   extracted ROM 7226f8e0d2c833b6...
    VI1.DGO       bundle ccbce3090b8c1adc...   extracted ROM 9300242a9ce06f48...
    0COMMON.TXT   bundle d28eb00a1b60ef5c...   extracted ROM 2defc22236422918...

so they are goalc/GOAL-source output rather than copies of the disc.  That distinction is the one the loop doc
records the hard way: staging the pack's *originals* over the built DGO/TEXT boots to 332 modules and then
crashes, while the build's own boot to 346.

## Where the user's data lives

Not in the bundle.  The app's own Files import promotes the player's pack into the app container
(`.../Application Support/local.ottsel/OttselShell/OttselUserData`, 1.5 GB), which is the player's own copy of
their game - the bundle stays asset-free by design.

## Boundary

This is a content inspection of the built bundle, not a legal opinion, and it does not cover the container's
user-imported copy (the player's own data, by design) or a device-signed build.  It also says nothing about
whether the product *reconstructs* from the pin - that is the other half of G2.6, which is file-level complete
and whose build half is disk-gated.
