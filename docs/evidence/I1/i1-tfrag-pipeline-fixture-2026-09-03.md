# I1 — TFRAG Metal pipeline fixture — 2026-09-03

## Question

Can the native TFRAG Metal pipeline draw a controlled clip-space quad with its
actual vertex descriptor, shader, index path, texture, and fragment color?

## Method

Added a one-shot diagnostic trigger, `ottsel-trace-metal-tfrag-fixture`. It
submits six layout-compatible 32-byte vertices at clip coordinates
`(-.75,-.75)` through `(.75,.75)`, six indices, a 2x2 white texture, and a
single no-depth draw. The shader's diagnostic projection branch is reachable
only while this trigger is active; production level data and camera math are
not changed.

The signed app was rebuilt and installed on the single iPad Pro 11-inch (M4)
Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`. The trigger was
consumed and the fixture frame was inspected directly.

## Result: PASS for pipeline plumbing

Fresh frame: `/tmp/ottsel-video/bot36-tfrag-pipeline-fixture-2026-09-03.png`.
SHA-256: `4bca602dc42714267903523fa61a4611be0861a081466d433380affa01fe6624`.

The expected large centered white quad rendered through the TFRAG pipeline.
This validates the 32-byte vertex stride/attributes, index submission,
fragment texture/color path, Metal clip-space output, and drawable viewport.
The result does not validate live TFRAG coordinates, materials, depth, culling,
or complete scene composition.

## Boundary

The fixture is diagnostic-only and remains outside the product path. The live
Village1 frame is still malformed because the failure is downstream of basic
pipeline plumbing: likely live vertex/packet correspondence, draw/material
state, or missing pass composition. Next experiment: add a bounded CPU TFRAG
clip ledger for the exact live NORMAL draw and compare it with the fixture's
known coordinate contract before changing camera or texture policy.

`ottsel-fault.log` remained 0 bytes during the fixture run.
