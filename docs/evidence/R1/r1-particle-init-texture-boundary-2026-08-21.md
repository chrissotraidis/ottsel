# R1 particle init texture boundary — 2026-08-21

This is a source-side follow-up to the page-directory/remap result. It records
the texture value at the `sp-init-fields!` consumer boundary, immediately
after the launcher `spt-texture` init-spec is applied and before
`particle-adgif` consumes the initialized field. The trace is bounded to 32
records and is diagnostic only; it does not remap TBP or alter renderer policy.

## Host capture

Runtime: native macOS `out/jak-project/build/h1/game/gk`, arm64,
`-boot -fakeiso -nosound`. Executable SHA-256:
`a5cc6b8b6b098784d284194825f76329cab795817e2bf0df519e42d9b7e6bd2a`.

The trace was armed before launch. Representative 3D records were:

```text
system=0x01892ab4 launcher=0x043c20a4 declared=0x00203500 page=2 index=53 initialized=0x00203500
system=0x01892ab4 launcher=0x043c1ea4 declared=0x00200400 page=2 index=4  initialized=0x00200400
system=0x01bc1e44 launcher=0x049bcdf4 declared=0x00201200 page=2 index=18 initialized=0x00201200
system=0x01892ab4 launcher=0x049c0434 declared=0x00202900 page=2 index=41 initialized=0x00202900
```

The declared value and initialized value agree for these records. This moves
the next comparison boundary to the same trace on the fresh signed iPad
replay: if the declared/spec sequence differs there, the remaining issue is
launcher/DGO allocation or ordering; if it agrees, continue into the texture
object/data-family state after initialization.

## Boundaries

The initial host-only capture was not an R1 parity pass and did not establish
playability. The later fresh signed iPad replay below remains diagnostic: the
one booted iPad Simulator is the only mobile runtime; no TBP, camera, shader,
or Metal policy change was made.

## Fresh signed iPad correlation replay

The signed executable was rebuilt after adding the iOS-sandbox AdGif trigger
and passed strict deep codesign. Executable SHA-256:
`1e219d8a0fe4881b3f37aff102096559ed37b0e309c703d217598011eef3db03`.

One fresh install on the same iPad Pro 11-inch (M4) Simulator replayed the
validated pack through title-wait → Start → Cross → Down×4 → Cross and reached
Village1 twice. The first raw page-2 lookup prefix was:

```text
4, 53, 4, 18, 0, 15, 28, 27, 3, 54, 49, 48, 42, 44
```

All sampled entries were resident hits. The particle init trace showed the
declared and initialized values agreeing, including mobile raw `0x00203600`
and the later page-2 families `0x00203100`, `0x00201200`, and `0x00203000`.
AdGif output correlated page-2 `0x00201200` with
`TEX0=0x2004d0e59930a506`, and page-2 `0x00203100` with
`TEX0=0x2004cc651130a52d`. The native Sprite3 source boundary in the same
process reported the first eligible `MSCAL=211` 48-sprite group at
`TBP=0x24d2`, `first-tex0=0x2004d2e59930a4d2`, followed by its 16-sprite
tail at `TBP=0`.

The owner-index follow-up mapped the first mobile launcher family to
`*part-id-table*` indices `336,334,335,331,332,333,341,340,339,338,342,347,346,337`.
The same macOS route selected platform-local indices `1951,1950,1949,1975,
1974,1973` for the initial `0x2035/0x2004` family and later `485,483,481,480,
479,414,510,1972,1971,1970,1969` across the `0x200f/0x2012/0x2000/0x2029/
0x2003` families. The indices are not stable identities; their divergence is
itself evidence of different launcher/DGO registration order or allocation.

This confirms that the remaining mismatch is producer phase/order and family
selection before native composition. It does not justify TBP remapping or
camera, shader, or Metal-policy changes. Fresh screenshot:
`/tmp/ottsel-r1-owner-index-route.png` (SHA-256
`e578c0880850947fe7c366b27cce002077ad7fb4eb6ca5104d1bd9134106ea47`); fault
log: 0 bytes; audio windows remained `pcm-peak=0`. The screenshot is still
partial/corrupted and is not playability proof.

The macOS owner-index capture used the native synthetic input seam
(`0x8`, `0x4000`, four `0x40` edges, `0x4000`) and reached Village1 twice.
It was one host runtime, terminated after capture; no macOS and Simulator
runtime overlapped. Raw owner output was retained in
`/tmp/ottsel-owner-id-mac-route2.log` (SHA-256
`3284b2d667d484f9bf86e43d05f4859a9a59695b5fe703e3959245943996fad4`).

The source definitions explain the family split: iPad indices `331–347` are
progress/HUD `defpart` entries, while macOS initial indices `1949–1951` and
`1973–1975` are weather/sun entries; later macOS indices `479–485` and
`1969–1972` are Village1 particle definitions. This is a concrete content
selection/order mismatch before the native Sprite3 consumer, not a texture
addressing correction.

## Phase-aligned post-Village1 correction

The startup owner capture above was phase-contaminated. A fresh replay armed
the owner and AdGif traces only after the current-boot `GAMEPLAY: enter
village1` marker. The iPad then selected the same launcher IDs as the macOS
route: `1951`/`1950` for raw `0x00203500`, followed by `1949` for raw
`0x00200400`. Their AdGif outputs matched the macOS values exactly:

```text
0x00203500 -> TEX0 0x2004d0e59930a506
0x00200400 -> TEX0 0x2004cfe55530a518
```

The post-Start lookup prefix in the same iPad log was
`4,53,4,18,15,28,27,3`; the macOS route began
`4,53,4,18,15,30,0,28,3`, with the differing tail occurring before the
matching owner/TEX0 family. This rules out the earlier progress/HUD-versus-
weather interpretation as a startup timing artifact and closes the selected
particle/data-family mismatch for the matched Village1 phase. Native source
composition remains open: the screenshot hash is
`236a1d8b6b58ec6b621a4f106f88edffd1c4cb78cb07bc8e336d4efc6b676fe0`, the
fault log is 0 bytes, and audio remains `pcm-peak=0`.

## Final phase-aligned source-boundary replay

One further fresh signed iPad replay armed the native Sprite3 source boundary
before launch, then armed owner/AdGif traces after Village1. The source
boundary captured the macOS-comparable first group:

```text
MSCAL=211 count=48 TBP=0x24f2 first-tex0=0x2004d1e59930a4f2
MSCAL=211 count=16 TBP=0x2525 first-tex0=0x2014cd655530a525
```

The same process retained the phase-aligned owner/TEX0 pair
`0x00203500 -> 0x2004d0e59930a506` and the exact route reached Village1.
Fault output remained 0 bytes. Fresh screenshot:
`/tmp/ottsel-r1-phase-aligned-final.png` (SHA-256
`1849202a6c12a64f80b3f2f5722ac9d80eff00d0b5e5d0f4c4393162d67e7b65`). The
frame remains partial/corrupted and audio remains `pcm-peak=0`; this closes
the source/resource parity slice but not native playability.
