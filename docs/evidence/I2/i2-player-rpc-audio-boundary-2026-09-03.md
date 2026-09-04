# I2 PLAYER RPC audio boundary — 2026-09-03

Status: PARTIAL / OPEN. PLAYER dispatch now produces native sound handles and
nonzero PCM, but audible/lifecycle acceptance is not complete.

Regression-first:

- The temporary `IosPlayerRpcRouteIsEnabled` regression failed before the
  attempted route and passed after the routing contract was enabled.
- The final build compiles Jak 1 `srpc.cpp` through its bounded `OTTSEL_IOS`
  adapter and passes the focused route regression.
- The fresh VILLAGE1 run reached `pcm-peak=10478` with nonzero handles for
  `fly7` and `drip-on-wood`.

Boundary decision:

- `sceSifCallRpc` now dispatches the PLAYER channel into `RPC_Player`; the
  adapter loads `COMMON.SBK` and receives live commands such as `fly7` and
  `water-drop`.
- `FS_LoadSoundBank` now detects each bank’s `SBlk`/`SBv2` container offset;
  COMMON and VILLAGE1 both load without assertion.
- The visible frame remains malformed and the audio route has not received
  human-audible, interruption, background/resume, or relaunch acceptance.

Evidence:

- Current signed app: `out/jak-project/out/ios/app/OttselShell.app`.
- Runtime log/container: fresh Simulator container `B6BF2C38-969B-4B84-8917-663430FDEC25`.
- Fresh frame: `/tmp/ottsel-audio-village1.png`; it remains OPEN for scene
  correctness despite the audio improvement.
- Next: gate dump/VU diagnostics and retain pacing evidence before lifecycle
  acceptance.
