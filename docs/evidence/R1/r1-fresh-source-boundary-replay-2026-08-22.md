# R1 fresh source-boundary replay — 2026-08-22

| Field | Result |
|---|---|
| Gate | R1 — producer/source boundary before native composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; current signed app was already installed and launched on the designated Simulator |
| Environment | One booted iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; one `com.ottsel.shell` runtime, PID `43158` during replay |
| Route | Fresh launch with the validated durable pack; title-wait → Start → Cross → Down×4 → Cross; Village1 marker reached; the source-boundary trigger was armed before launch and self-cleared |
| Focused/live evidence | `docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-boundary-r2/` |
| Fault/audio | `ottsel-fault.log` is 0 bytes; audio callback remains non-audible with `pcm-peak=0` |
| Verdict | **OPEN** — source parity is narrowed; iPad playability remains unproven |

## Source result

The fresh source-boundary ledger captured `MSCAL=211` at chains 129–130. The
first textured group was 48 sprites, `TBP=0x2506`, 64×64 PSM19, with
`first-tex0=0x2004d0e59930a506`, `first-tex1=0x120`, clamp `0x1010001c0`, and
alpha `0x48`. Its frame/matrix setup was transfer `9`/`12`; the earlier setup
window also captured transfer `4`/`7`. The second group was the expected
16-sprite zero-texture/color-only record. The same source family was captured
again on the following chain.

This matches the already retained macOS early phase/resource family. It does
not prove the later accepted macOS `TBP=0x24f2` phase is reached on iPad, and
it does not identify a page-directory or texture lookup defect. The sampled
page-2 lookup records were resident hits; raw `OTTSEL TEX LOOKUP` output and
the source-boundary TEX0 remain consistent with the earlier phase-aligned
comparison. No TBP, camera, shader, culling, or Metal-policy remap was made.

## Visual and crash boundary

The fresh screenshot is rotated/dislocated with large blank regions and is
still a partial/corrupted Simulator frame, not playability proof. The pasted
crash report was separately attributed to an older app UUID/PID (`41979`,
06:07): Metal aborted in `MTLRenderCommandEncoder` deallocation inside
`presentRGBA`. The current replay used a later app/runtime and did not
reproduce that abort; the current fault log stayed empty. The report remains
useful historical Metal-stability evidence, but it is not evidence of the
current source-boundary run.

Next experiment: correlate the complete ordered producer phase list, including
the transition to the macOS `0x24f2` family, then trace the native composition
consumer/data-family state. Do not remap TBP or change camera, shader, or Metal
policy before that source-side result.

## Active visual capture and expanded phase window

The diagnostic source window was widened from eight 3D-only records to 32
recognized 3D/world/HUD records. A fresh signed rebuild and exact route then
captured world `MSCAL=3` and 3D `MSCAL=211` records in the same ordered window.
The first 32 records remained in the early `TBP=0x2506` family with
`first-tex0=0x2004d0e59930a506`; no later `0x24f2` transition appeared in this
bounded window. This is a stronger producer-phase result, but not yet the
complete transition list.

The same run has active visual artifacts:

- `before-input.png`: blank white/portrait Simulator surface;
- `exact-route.mp4`: live H.264 recording during the exact route;
- `after-route.png`: rotated/dislocated Village1 geometry with large blank
  regions and detached vertical geometry.

All are under
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-boundary-r4-video/`.
The executable SHA-256 is
`37286db2d68df0080bc0ccf7529e6ebdcfbe9a97f3adda805deba73bd35bdc7e`, the
fault log is 0 bytes, and exactly one iPad Simulator/runtime remained active.
This remains diagnostic evidence, not an iPad playability pass.
