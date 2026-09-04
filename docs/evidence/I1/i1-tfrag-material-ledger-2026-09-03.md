# I1 TFRAG material/texture ledger — 2026-09-03

Status: OPEN. The upload and source alpha contract is live, but the scene is
still not visible as a coherent playable world.

Question: are TFRAG fragments blank because native Metal receives missing or
uniformly transparent source textures?

Build: signed `out/jak-project/out/ios/app/OttselShell.app`; focused
`PlatformInput.*` suite passed 27/27.

Fresh bounded iPad route/frame:
`/tmp/ottsel-video/bot36-tfrag-alpha-ledger-2026-09-03.png`.
SHA-256: `2a0b0a2c037141d5d1ff9a76b7b4ec5f7d07c6269dbd52244451fd57e99d3413`.

Runtime source ledger for Village1 selected 84 TFRAG draws, all with
nonnegative IDs. The first eight uploaded textures included `vil-beachrock`
(alpha 128..128), `vil1-jng-leafyground-hang-2x1` (0..128),
`vil1-jng-leafyground` (128..128), and `vil-hut-wood-01` (39..57).
No TFRAG out-of-range or not-uploaded skips were emitted.

Observed frame remains black with debug rectangles and no coherent TFRAG
world. Fault log was 0 bytes; PLAYER RPC playback remained live. The evidence
rules out absent textures and uniformly zero source alpha, but does not yet
prove the fragment material equation or depth interaction correct.

Follow-up solid-material probe was active but produced no solid TFRAG field;
see `i1-tfrag-solid-probe-2026-09-03.md`. The texture-index contract and
per-draw depth semantics remain OPEN.

Additional source comparison: upstream `TFragment.cpp` rejects a positive
texture ID at draw time when it is outside that level's texture vector. The
native producer currently still submits such batches and the Metal consumer
skips them; the retained probe log showed IDs 395–399 against a 395-entry
table. This is a confirmed bounded omission, but not yet proof that it causes
the entire blank frame, so no texture remap is applied.
