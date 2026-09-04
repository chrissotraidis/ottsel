# I1 Merc matrix ledger — 2026-09-03

Question: are invalid bone slots or malformed CPU skinning the reason
`eichar-lod0` never appears in Village1?

The diagnostic records the same upstream packet fields consumed by
`Merc2::render`: matrix-slot string, matrix pointers relative to the DMA
chain, and `MercMat`-compatible 112-byte matrices. All 79 advertised slots
were valid. The source model bounds were
`(-7127,-1894,-5244)..(7099,13294,5203)`.

The CPU-skinned bounds were consistently
`(10167,-11580,-50536)..(24068,7414,-37559)`, with the first bone translation
`(-15882.56,-5357.58,47290.94,1)` and last
`(-15880.25,-5350.17,47290.19,1)`. The bounds remain stable while the camera
packet changes, so this is not a transient NaN or missing-slot condition.

Build: direct iOS translation-unit compile passed; the diagnostic build was
linked from the existing signed app objects and passed deep codesign. Binary
SHA-256: `60c746a664287d648709e24a0d4c304df184bf6610e6067221eed2fdd2aaf7b3`.

Runtime: iPad Pro M4 Simulator
`08636791-2675-4675-8335-EF72EF954DCF`, launch PID `18163`.
The raw-perspective ledger still reports 9,942 finite Eichar vertices and
`visible=0`, with clip-Z `(-1.0543,-1.0405)`.

Result: OPEN. Bone slots are present, but the actor-space origin/transform
does not yet reconcile with the Village1 camera. Do not alter the camera
matrix or claim actor visibility; compare the captured matrix interpretation
and model ownership against the upstream Merc draw bucket next.
