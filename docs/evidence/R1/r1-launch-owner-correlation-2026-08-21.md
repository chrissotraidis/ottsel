# R1 lower-level launch-owner correlation — 2026-08-21

## Result

A fresh macOS `gk` run from the current checkout was traced at the actual
`sp-launch-particles-var` mips2c entry, before `particle-adgif`. The bounded
trace captured the launch system and launcher pointers at entry, then stamped
those pointers onto the later `is3d=yes` raw texture-ID record.

The post-Village1 window included these producer correlations:

```text
raw 0x00200800 page=2 index=8   system=0x01bc1e44 launcher=0x049ae854
raw 0x00201b00 page=2 index=27  system=0x01bc1e44 launcher=0x049ae5b4
raw 0x00200f00 page=2 index=15  system=0x01892ab4 launcher=0x049a8794
raw 0x00200400 page=2 index=4   system=0x01892ab4 launcher=0x049abee4
raw 0x00201e00 page=2 index=30  system=0x01bc1e44 launcher=0x049c13c4
raw 0x00201200 page=2 index=18  system=0x01bc1e44 launcher=0x049bcdf4
```

This confirms that the page/index sequence is selected by distinct lower-level
launch-owner instances before AdGif lookup/TEX0 generation. The first attempt
to read a launcher texture field at a guessed offset produced values such as
`0x00000001` and `0x001bfe84`; those are not treated as texture IDs and the
probe does not use that offset for product behavior.

## Boundaries

The run reached `GAMEPLAY: enter village1`. The trace is diagnostic-only; no
texture remap, TBP change, camera change, shader change, or Metal-policy change
was made. The existing iPad producer-to-DMA evidence still shows exact vector,
RGBA, and TEX0 handoff for its selected family, so the unresolved R1 issue
remains selection/order/phase ownership upstream of native composition.

The owner probe is preserved in
`patches/r1-sparticle-launch-owner-fields.patch` and
`patches/r1-sparticle-launch-owner-correlation.patch`. The latter reverse-checks
against the current source after the former is applied.

## Fresh signed iPad replay

The signed iPad app was rebuilt from the current checkout, installed into the
single booted iPad Pro 11-inch (M4) Simulator, and passed strict deep codesign.
The executable SHA-256 was
`c6fb92017247db7ff7d816f6fa844579adc3a3ded7fec4ccdbb099a4becc64af`.

The exact title-wait → Start → Cross → Down×4 → Cross route delivered native
keyboard events and reached `GAMEPLAY: enter village1` twice. The fresh
post-route page-2 lookup tail was `25,24,10,41,30,34`; all captured entries
were resident hits. Representative source-side 3D records repeatedly reported
first TBP `9426` in the selected phase window.

Fresh artifacts:

* Screenshot: `/tmp/ottsel-r1-signed-owner-route.png`
* Screenshot SHA-256: `1158459e831bd03fe403d5b31ad6f75356d731c4e6b9b9ccea37bff59df713f5`
* Fault log: 0 bytes
* Audio: callbacks and mix windows observed, but `pcm-peak=0`

The screenshot remains severely rotated/distorted and is not playable-frame
evidence. The mips2c `/tmp` owner trigger did not emit a separate iPad launch
owner trace in this replay; the GOAL lookup/TEX0 and native source traces remain
the authoritative iPad evidence for this run.

## Sandbox-triggered iPad owner correlation

The diagnostic trigger was extended to check the iOS app sandbox
(`$HOME/Library/Application Support/local.ottsel/OttselShell`) in addition to
macOS `/tmp`. After rebuilding and signing, a validated pack was imported into
the fresh app container and the exact route was replayed again.

The iPad trace correlated raw launch IDs with launcher pointers in the
post-Village1 window:

```text
raw 0x00201900 page=2 index=25 system=0x01892da4 launcher=0x049c0754
raw 0x00200a00 page=2 index=10 system=0x01bc2134 launcher=0x049a0794
raw 0x00202900 page=2 index=41 system=0x01892da4 launcher=0x049c0434
raw 0x00201800 page=2 index=24 system=0x01892da4 launcher=0x049c0914
```

This is fresh iPad owner-to-raw-ID correlation. It confirms that the mobile
phase selects distinct launcher instances before AdGif/TEX0, while the shared
page-directory/TEX0 hits remain intact. It does not prove mobile/macOS owner
sequence parity.

Fresh artifacts:

* Screenshot: `/tmp/ottsel-r1-signed-owner-ios-trigger-route.png`
* Screenshot SHA-256: `ad212243f30aad39e3251f40bb601d7d83108e8347cdfe7a9e7c7eaba1fee9e8`
* Fault log: 0 bytes
* Audio: mix windows observed, `pcm-peak=0`

The screenshot remains rotated/distorted and is not playability proof. No
texture, TBP, camera, shader, or Metal policy was changed.

The iOS sandbox trigger is preserved in the reversible canonical delta
`patches/r1-sparticle-launch-owner-ios-sandbox-trigger.patch`, which
reverse-checks against the current nested source.
