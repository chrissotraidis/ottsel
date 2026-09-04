# R1 TIE primary-category probe R21 — 2026-08-22

## Result

A trigger-gated native TIE experiment included the primary NORMAL, TRANS, and
WATER category range instead of NORMAL only. The category ledger showed that
Village1 has substantial non-normal ranges, but the fresh live frame was
visually unchanged: textured ground remained, with the same large blue/black
missing regions. The probe was removed after capture.

## Evidence

- [fresh direct Simulator frame](artifacts-2026-08-22-ipad-r1-tie-category-probe-r21/fresh-village1-after-w.jpeg)
- [fresh simctl screenshot](artifacts-2026-08-22-ipad-r1-tie-category-probe-r21/fresh-village1-simctl.png)
- [runtime log](artifacts-2026-08-22-ipad-r1-tie-category-probe-r21/ottsel-runtime.log)
- [fault log](artifacts-2026-08-22-ipad-r1-tie-category-probe-r21/ottsel-fault.log)

The route used the durable validated pack and synchronized title-wait-ready →
Start → Cross → Down×4 → Cross; Village1 was entered twice. The signed
diagnostic build had one Simulator/runtime, zero fault bytes, and audio still
reported `pcm-peak=0`. This is a falsified composition hypothesis, not a
playability pass.

## Decision

Remove the temporary category probe/ledger and retain the normal-category
baseline plus strip-run corrections. The next boundary is material/depth
state or a missing non-TIE bucket; do not widen categories blindly.

