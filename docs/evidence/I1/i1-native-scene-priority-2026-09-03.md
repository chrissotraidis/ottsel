# I1 native scene priority — 2026-09-03

## Question

Are the colored rectangles and black contamination in the iPad frame coming
from the CPU GS fallback being composited beneath the native scene?

## Change and regression

Added `ottsel_mobile_cpu_frame_should_draw`: the CPU fallback remains enabled
until both native TFRAG and TIE snapshots are resident, then yields to the
native scene. The explicit no-CPU diagnostic path remains forceable. Focused
policy tests passed 2/2, including bootstrap, complete-native, and override
cases.

## Result: PASS for contamination isolation; OPEN for I1 playability

Fresh signed build and title → New Game → Village1 route on the single iPad Pro
11-inch (M4) Simulator. TFRAG and TIE snapshots loaded (`76264/53524` and
`511138/359812` vertices/triangles). The fresh frame is:

`/tmp/ottsel-video/bot36-native-priority-village1-2026-09-03.png`

(SHA-256 `2da5a5b1c1fbdb656cf21dad3273aab60d2980586395c2d9fb8e927305cfadb8`).

The colored CPU rectangles are gone and the native Village1 geometry is
substantially more coherent. The scene is still incomplete: sky/ocean and
other native families are missing, Jak/HUD/input/audio are not accepted, and
no stable playable soak has been proven. Fault log remained empty.

Next: preserve this native-first composition and implement or validate the
missing background/native families one at a time, starting with the audit's
remaining TFRAG/TIE environment coverage.
