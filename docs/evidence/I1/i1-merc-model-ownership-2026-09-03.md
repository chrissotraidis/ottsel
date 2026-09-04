# I1 Merc model ownership — 2026-09-03

Question: does native duplicate-name lookup select the wrong loaded level for
`eichar-lod0`?

Before: `capture_mobile_merc` iterated `g_mobile_levels`, whose unordered-map
order could select a duplicate model from an arbitrary level. Upstream
`Loader::get_merc_model` resolves the first registered reference; common
`GAME` models are registered before level models.

Change: search `GAME` first, then the current camera level, then other loaded
levels. Record the selected level in the native ledger. No camera, shader,
TBP, or strip-restart code changed in this experiment.

Build: iOS translation-unit compile passed; signed Simulator binary SHA-256
`99867fbcca8730a741d85cb2eca8b29a41c6db971aa77efc55403389eff0f796`.

Runtime: iPad Pro M4 Simulator
`08636791-2675-4675-8335-EF72EF954DCF`; native ledger selected
`model='eichar-lod0' level='GAME'`, with 79 valid slots and 3,593 triangles.
The raw-perspective ledger remained `visible=0` for 9,942 finite vertices,
with clip-Z `(-1.0543,-1.0405)`.

Result: OPEN. Ownership is now deterministic and upstream-like, but it does
not explain the absent actor or the malformed scene. Next isolate the captured
PC_PORT/Merc matrix contract against the upstream draw-bucket inputs.
