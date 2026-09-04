# I1 — Eichar Village1 clip-space series

Status: OPEN.

Question: does the retained, CPU-skinned Eichar model enter clip space after
the title-to-Village1 camera transition?

Evidence:

- The diagnostic retains the exact 9,942 CPU-skinned Eichar vertices and
  evaluates them with the existing raw Merc perspective equation.
- First Village1 transition packets: `visible=0`, clip-x `(0.4886,1.3657)`,
  clip-y `(-0.4170,0.6426)`, clip-z `(-1.0543,-1.0405)`.
- Later Village1 packets improve x to `(0.2291,0.6403)`, but all vertices
  remain outside the near plane: clip-z `(-1.0543,-1.0405)` and visible `0`.
- The actor slot build signed successfully; fresh runtime frame SHA-256:
  `4b14aa663452b1344767f43362193d1cb66969dc1aed64500b3a1029d699d16d`.
- The frame remains malformed and does not visibly identify Jak.

Decision: actor submission is no longer the only explanation. The retained
vertex cloud is consistently just behind the near plane under the product
perspective path. Preserve the no-camera-math constraint; next compare the
Merc source matrix/vertex contract against the upstream `emerc.vert` inputs
and add a focused regression before changing skinning.

Follow-up:

- A 32-packet signed diagnostic series reached the same conclusion: the first
  transition packets had clip-x `(0.4886,1.3657)`, while later packets moved
  x to `(0.2291,0.6403)`; clip-z stayed `(-1.0543,-1.0405)` and visible stayed
  `0` throughout.
- Series frame SHA-256:
  `4b14aa663452b1344767f43362193d1cb66969dc1aed64500b3a1029d699d16d`.
- This is not a camera-transition timing problem. The next source comparison
  is the packet matrix representation and CPU skinning sign/layout.
