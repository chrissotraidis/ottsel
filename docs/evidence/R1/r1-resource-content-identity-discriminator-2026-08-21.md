# R1 resource-content identity discriminator — 2026-08-21

## Gate

R1 first mobile/macOS Sprite3 resource identity before native composition.

## Source and focused proof

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed app executable: `9010f0cd3314b5635abda087f9fc666f64412ce63da1518d9372451d49a82024`.
- `scripts/build-ios.sh`: passed; strict deep codesign: passed.
- `./build/h1/goalc-test --gtest_filter='Sprite3Native.*'`: 14/14 passed.

## Change

Added bounded diagnostic-only RGBA FNV hashes and alpha summaries:

- desktop `Sprite3::dump_trace_texture` logs the decoded OpenGL texture bytes;
- mobile logs the first textured Sprite3 group after the producer record trigger
  using the existing `download_texture_rgba8888` path.

No texture address, phase, visibility, shader, or product rendering behavior
was changed. No texture bytes are retained in the repository.

## Live proof

One iPad Pro 11-inch (M4) Simulator run used the signed app with
`OTTSEL_PREPARE_DATA_BEFORE_METAL=1` and audio disabled. The actual writable
directory was corrected to
`Library/Application Support/local.ottsel/OttselShell/`. The run reached the
Village1 display marker, but the bounded identity/record lines were not
emitted before shutdown. The fault log was 0 bytes. This is an instrumentation
capture miss, not a resource-equality or resource-inequality result.

## Verdict and next gate

OPEN. Existing evidence still establishes different first producer tuples:
mobile `TBP=0x2bc1`/64x64 versus macOS `TBP=0x24f2`/64x64, with different
Sprite3 counts and phase ordering. The new content hash is not yet available,
so no remap or native widening is justified. The next slice is to arm the
content discriminator at the same already-proven Village1 producer window,
or add a source-item/group ordinal trace at that boundary if the trigger cannot
be consumed there.

