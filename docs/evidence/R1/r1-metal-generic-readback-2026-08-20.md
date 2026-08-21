# R1 generic Metal drawable readback — 2026-08-20

The one-shot readback trigger was run without Sprite3 or Village1 triggers.
It produced a `1210x834` PPM from the actual CAMetalLayer drawable, with a
zero-byte app fault log. The inspected artifact shows the GPU-rendered shell
text and background on the drawable: [generic readback](r1-metal-generic-readback-2026-08-20.png).

This proves the diagnostic readback path and a base Metal present in isolation.
It does not prove Sprite3 composition, title/menu parity, audio, or playability.
The subsequent Sprite3-gated run reached the native candidate but produced no
fresh PPM, so the R1 image gate remains open.

