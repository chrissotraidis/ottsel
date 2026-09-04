# R1 TIE/TFRAG projection experiment R14 — 2026-08-22

## Result

The native TIE/TFRAG projection/sign experiment was falsified by a live
signed iPad replay. It was not retained as a product fix.

The experiment added the desktop-style perspective divide, HVDF/GS offsets,
and separate TIE/TFRAG camera signs to the shared Metal vertex contract. The
app built and deep codesign passed, but after the active Simulator reached the
title route and Start was sent through keyboard capture, the game surface went
fully blank. Only the diagnostic/touch surface remained before Start; after
Start no scene was visible.

The source was reverted to its prior state and rebuilt. The restored signed
app was installed on the same one booted iPad Pro 11-inch (M4) Simulator;
there was no second Simulator or runtime. The restored build returned to the
known prior diagnostic/title surface rather than the experiment's blank
surface.

## Evidence boundary

- Experimental build: signed and `codesign --verify --deep --strict` passed.
- Experimental runtime: one app process on UDID
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Restored runtime: one app process on the same UDID.
- Direct Simulator UI screenshots were actively inspected before and after
  Start. The experimental post-Start frame was fully blank.

## Decision

R1 remains open. This does not prove the desktop shader contract is irrelevant;
it proves the attempted shared-shader implementation did not preserve the
current Metal submission contract. The next experiment must first log the
actual `pc_camera`, HVDF, fog, sign, and one transformed vertex at the CPU
boundary and compare it to the OpenGL `make_new_cam_mat`/shader path. No TBP,
page-directory, resource, ROM, or runtime-codegen policy was changed.
