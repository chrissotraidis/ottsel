# I2 VU diagnostic gate — 2026-09-03

Status: PARTIAL PASS. The default native-Metal route no longer creates or
writes the two large CPU/VU diagnostic dumps.

Regression / implementation:

- The native path retains its 512-transfer decode and 4096-transfer PC_PORT
  tail policy.
- `tfrag-vu-data.bin`, `tfrag-vif-replay.bin`, and the generic VU state copy
  are now gated by `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`.
- Existing TOD alpha code is already scaled by 4 and was left unchanged.

Fresh runtime evidence:

- Signed app: `out/jak-project/out/ios/app/OttselShell.app`.
- Simulator: iPad Pro 11-inch (M4), UDID
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Container: `299F49ED-B0F0-4E33-842A-E1ABAFF585BE`.
- Log reports `cpu-diagnostic-path=disabled`; after stale files were moved
  aside, no `tfrag-*` files were recreated during the clean relaunch.
- Container root measured 1,601,200 KiB; VU1STAT remained uncapped, but the
  frame is still malformed and this is not a playability pass.
- Audio remained live in this run (`pcm-peak=2819`), with no assertion/fault
  marker observed in the inspected log.

Open: capture an enabled-diagnostics run separately, then prove longer native
frame pacing and coherent Jak gameplay before promoting I1/I2.
