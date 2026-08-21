# R1 Sprite3 producer source-boundary trace — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — Sprite3 producer/phase ownership before native composition |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app SHA-256 `3e6a66d4a10a1a248b17189ae26c2e61d333416d080053b183740dc1cec952da` |
| Environment | One iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; app shut down after capture |
| Before failure | Earlier macOS/mobile comparison proved different post-setup phase/resource sequences but did not identify the mobile producer chain and route-state owner. |
| Change | Added trigger-gated `ottsel-trace-mobile-sprite-source-boundary` logging in `render_mobile_sprite_bucket`. It records chain, DMA interval/header offset, transfer, MSCAL phase, route level, frame/matrix transfer indices and hashes, camera source marker, and first texture tuple. Rendering and bucket ownership are unchanged. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; `Sprite3Native.*` passed 16/16. `scripts/build-ios.sh` completed; strict deep codesign passed. |
| Live proof | The current-boot route reached `title-wait-ready` and Village1. The trace armed at chain `2918`, vsync `2919`, interval `0x542920 -> 0x50efa0`, level `village1`, and recorded six `MSCAL=3` world records at transfers 13–18 (`48,48,48,48,48,48` sprites, `TBP=0x2c8d`), followed by a 32-sprite zero-texture record. Chain `2919` then began another world record with the same `TBP=0x2c8d`. All records carried frame transfer 9, matrix transfer 12, and the same camera-source chain/transfer marker. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The Simulator remained blank and non-audible; no visual or audio pass is claimed. `git diff --check` still reports pre-existing trailing whitespace in `patches/h3-jak1-host-boot.patch`; the new source file itself introduced no reported check result. |
| Verdict | OPEN. This capture proves the producer boundary is attributable to concrete chain/data intervals and that this phase window contains world-only output; it does not prove that the missing `MSCAL=211` family is absent from all windows or identify its producer. |
| Next gate | Repeat the source-boundary trace with a frame-aggregate trigger armed before the first active Village1 phase, then compare the complete ordered phase list against macOS. Do not remap TBPs, widen the consumer, or change camera/shader policy yet. |

The trace log remains in the Simulator container used for the run; the
trigger is diagnostic-only and should not be treated as product behavior.

## Numeric follow-up (pre-route context only)

A fresh signed app (`7e6769ade1e7d963fb8bb43c2f3c554116e80cdd80aabe28b13f80cf572ff2c2`)
repeated the trace with frame/matrix values included. Chains 256–258 carried
the same `pfog0=-0.046546843`, `inv-area=0.10231715`, camera translation
`(227569.38,47488.31,-5.7278464e+09,-31.885628)`, and first world texture
`TBP=0x2bc1` (48 sprites), followed by a 16-sprite zero-texture record. Chain
259 retained the same `TBP=0x2bc1` phase but changed the camera tuple and matrix
hash. In every item the camera source chain matched the Sprite3 chain.

This is useful phase-window context: the mobile stream is not borrowing a
stale camera packet from an adjacent chain, but this capture armed before the
current-boot `title-wait-ready`/New Game route marker. It must not be treated
as same-transition Village1 parity evidence. The Simulator fault log was 0
bytes and the surface remained blank/non-audible. The R1 gate remains OPEN; no
producer or renderer fix is selected from this trace alone.

## Same-transition follow-up

The trace was then rebuilt into signed app
`7e6769ade1e7d963fb8bb43c2f3c554116e80cdd80aabe28b13f80cf572ff2c2` and armed
only after the fresh boot emitted two `OTTSEL LEVEL MARKER:
level=village1 display=display-self` records. At chains 12699–12700 it captured
only `MSCAL=3` world records at `TBP=0x2c8d` (six 48-sprite records, then a
32-sprite zero-texture record). The first item carried
`pfog0=-0.046709098`, `inv-area=0.036767285`, camera
`(201342.55,58121.035,-7.326069e+09,-40.924698)`, frame transfer 9, matrix
transfer 12, and camera source chain 12699—the same chain as the Sprite3
record. Chain 12700 retained the phase and changed only the frame/matrix
values. The Simulator fault log was 0 bytes.

This is valid same-transition phase evidence, but still not a visual pass: the
surface was blank/non-audible and no `MSCAL=211` record appeared in the captured
window. It strengthens the producer/phase divergence diagnosis without
authorizing a renderer or resource remap.
