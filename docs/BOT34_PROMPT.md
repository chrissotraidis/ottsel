# Goal prompt for the next bot

Read `/Users/chrissotraidis/.codex/attachments/543c6b48-6b98-4895-abcf-1beaab22a730/goal-objective.md` completely before acting. Then read:

- `docs/STATUS.md`
- `docs/13-current-state.md`
- `docs/15-macos-to-mobile-goal-loop.md`
- `docs/BOT34_HANDOFF.md`
- `docs/evidence/R1/r1-texture-lookup-page-directory-trace-2026-08-21.md`

Preserve the fixed goal: deliver an honestly playable native Ottsel Jak 1
build on iPad first, then prove iPhone parity and physical-device readiness.
Do not replace it with a Mac boot, a blank/partial Simulator frame, or a
static build result.

The first open dependency is R1 source/resource parity. Build the signed iPad
app with `patches/r1-texture-lookup-trace.patch`, replay one fresh validated
pack through title-wait → Start → Cross → Down×4 → Cross, and compare the
raw `OTTSEL TEX LOOKUP` page/index sequence against the completed macOS run.
Correlate it with raw particle IDs, AdGif TEX0, and native `first-tex0`/TBP.
If lookup differs, trace page-directory/FR3/DGO ordering and allocation. If
it matches, trace texture-object/data-family state. Do not remap TBP or change
camera, shader, or Metal policy before a falsifiable source-side result.

Use one runtime and one booted Simulator. Keep the Simulator blank-screen
warning explicit. Preserve ROM safety, signed-native/no-runtime-codegen, the
dirty user-owned upstream worktree, and canonical patches. Use fresh
screenshots, input, lifecycle, fault, and audio evidence. Build success,
logs, counters, title screens, and first frames are not playability proof.
After R1, continue Direct/Sprite/material composition, input/audio/lifecycle,
iPhone parity, and physical-device gates until the original completion
definitions pass. Do not import MAP_JIT, runtime executable pages, dynamic
trampolines, Jak 2 game changes, or the external Metal shell.
