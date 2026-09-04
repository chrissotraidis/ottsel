# I1 MERC raw-perspective correction — 2026-09-03

Status: OPEN. This is a native-family diagnostic result, not playability proof.

Question: are the displaced Village1 panels caused by submitting MERC vertices
through the background TIE/TFRAG camera equation?

Evidence before the change:

- With TIE disabled, the large displaced panels remained.
- With TFRAG disabled, the same malformed panels remained.
- With TIE, TFRAG, and MERC disabled, the panels disappeared.
- Desktop `merc2.vert` uses raw `perspective_matrix * vtx_pos`, where
  `vtx_pos` is already bone-skinned camera-space data; it does not subtract
  the background camera translation or use `pc_camera`.

Correction:

- Added a separate Metal MERC projection branch using the raw PC_PORT
  perspective matrix and the existing fog/HVDF conversion.
- Kept TIE/TFRAG on the existing derived `pc_camera` path.
- Added a focused projection-contract regression.

Verification:

- Focused suite: 3 tests passed, including linker and present guards.
- Signed iPad app build completed; executable SHA-256 begins
  `53f8d933788f30872f9924ef5f9ec2b3e608b71faec0dfa4cfa0b502b9f90738`.
- Fresh visible replay frame: `/tmp/ottsel-video/bot36-merc-raw-perspective-20260903.png`.
- The corrected live frame removes the giant panels/rays and shows coherent
  Village1 structures. Jak is not yet clearly visible or controllable.
- Fault log is 0 bytes; no `SIGABRT`, `MTLCommandEncoder`, or link-version
  marker appeared in the fresh runtime log.
- Game audio remains OPEN: `pcm-peak=0`.

- Follow-up no-TIE replay with corrected MERC removed the horizontal band,
  while the remaining TFRAG/MERC composition stayed fragmented. This assigns
  the band to TIE or its interaction with composition; it does not establish
  that TIE's camera equation itself is wrong.

Next: repeat the accepted title-wait replay after the route is armed, confirm
Jak/MERC visibility and input, then test camera motion and bounded soak before
any I1 promotion. Do not begin the touch frontend or iPhone gate.
