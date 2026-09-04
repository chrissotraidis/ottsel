# R1 TIE strip-run boundary correction R19 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native TIE composition |
| Source change | Preserve a `UINT32_MAX` restart after every visible TIE strip group in `src/shell/metal_gfx.mm`. |
| Reference | OpenGL `Tie3` uses separate visible multi-draw runs; native flattening previously concatenated adjacent visible groups. |
| Focused proof | `./build/h1/goalc-test --gtest_filter='Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*'` passed 25/25. |
| Build | Signed iPad build passed `scripts/build-ios.sh` and strict deep codesign. |
| Live route | Fresh F1-imported validated pack; synchronized title-wait-ready → Start → Cross → Down×4 → Cross; Village1 entered twice. |
| Environment | One booted iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; one runtime. |
| Fault/audio | Fault log 0 bytes; audio remained `pcm-peak=0`. |
| Verdict | OPEN — the fresh frame remains severely incomplete; no playability claim. |

## Evidence

- [fresh direct Simulator frame](artifacts-2026-08-22-ipad-r1-tie-strip-restart-r19/fresh-village1-after-w.jpeg)
- [fresh simctl screenshot](artifacts-2026-08-22-ipad-r1-tie-strip-restart-r19/fresh-village1-simctl.png)
- [runtime log](artifacts-2026-08-22-ipad-r1-tie-strip-restart-r19/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-tie-strip-restart-r19/ottsel-fault.log)

The fresh frame still shows textured ground and large missing/black or blue
regions. It does not establish a material visual improvement over R18, so the
TIE restart is retained as source/reference parity work but is not counted as
a visual gate closure. The next experiment must isolate the remaining TIE
category/material coverage or depth/composition ordering.

