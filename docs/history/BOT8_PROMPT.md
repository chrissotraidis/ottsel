# BOT8 — Ottsel goal-based continuation loop (S2.1 native-fault first)

```text
/goal Continue until Ottsel's original product roadmap is complete:

/Users/chrissotraidis/GitHub/ottsel

Do not substitute another handoff for implementation. Keep this goal active
through compaction. Work the next falsifiable gate, record evidence, then move
to the next gate; stop only for a genuine external blocker with three materially
different diagnostic attempts recorded.

# ORIGINAL PRODUCT GOAL (binding)

Build a native iPadOS/iOS port of Jak and Daxter: The Precursor Legacy from
OpenGOAL pin 641fb572e876750d8618434d9f7c1a531b43b366. The product must be
ARM64 AOT, use signed Mach-O executable text (not runtime-generated GOAL code),
use Metal, remain ROM-safe, and be reproducible from a clean checkout and
user-supplied legal assets. RX-blob CGO boot is Simulator diagnostic machinery,
never product/device proof.

# REQUIRED GATE ORDER

R0 -> A1.0 -> A1.1 -> A1.2 -> S2.1 -> S2.2 -> S3 -> R1

H1-H3, S1, S2.0, A1.0-A1.2 are PASS. Do not reopen them absent contradictory
evidence. S2.1 is ACTIVE. S2.2, S3, and R1 remain blocked on it.

# READ FIRST

1. docs/15-progress-audit.md
2. docs/BOT6_PROMPT.md
3. docs/BOT7_PROMPT.md and docs/reports/2026-08-10-audit-bot7.md
4. docs/STATUS.md, docs/13-current-state.md, newest docs/00-loop-log.md
5. docs/evidence/S2/s21-trace4-boot.log and s21-bot7-shimfix-boot.log
6. git status --short; git diff; git log --oneline -8; pgrep -fl OttselShell;
   xcrun simctl list devices booted; df -h

Preserve every existing modification. Root modifications are the BOT7 audit,
its evidence, and the temporary native-fault guard in src/shell/ios_boot.cpp.
The app rebuilt successfully at 06:19, but the older pid 65554 is still the
only active OttselShell. Do not launch a second app before stopping it.

# CURRENT VERIFIED S2.1 STATE

- The BOT7 audit disproved the claim that the rfn catch-frame continuation
  defect could not explain the raw-rfn fault. Live code identified the bad ret
  at the process trampoline ee+0x0244a700.
- ARM64 IR_FunctionCall now preserves incoming x30, pushes an ADR-derived
  post-BLR continuation, discards it after normal return, then restores x30.
  Its new A1.0 regression failed before the fix and passes afterward.
- KERNEL.CGO and GAME.CGO regenerated successfully; validation passed all
  5,337,088 code words across 346 objects. The replacement Simulator boot
  linked all game objects and `time-of-day` top-level returned normally. The
  old raw-rfn fault is therefore fixed.
- New blocker: immediately after that return, a native fault at
  0x10218d87c symbolized as SDL VULKAN_CreateDeviceResources +7516. It is not
  an EE-relative GOAL ret. The old handler's GOAL-only dump re-faulted at EE
  base and prevented an LLDB capture; BOT7 added a guard so those probes run
  only for EE PCs. That guard is built but has not yet been installed/run.

# FIRST S2.1 ACTION: CAPTURE THE NATIVE FAULT

1. Confirm only one booted Simulator. Kill only stale pid 65554 after verifying
   it is OttselShell. Install the already-built app from
   out/jak-project/out/ios/app/OttselShell.app.
2. Launch once without a console pipe; wait for the guarded handler to hold.
   Attach lldb immediately. Capture `thread backtrace all`, `register read`,
   `image lookup --address <pc>`, and disassembly around the actual faulting
   instruction. Store a concise log under docs/evidence/S2/.
3. Determine whether SDL Vulkan initialization is entered by the shell, SDL
   renderer selection, or a newly active game display path. Do not infer the
   cause from symbolization alone.
4. Form the smallest falsifiable hypothesis. Add a regression before changing
   emitter/ABI code. For SDL/shell code, prefer a narrow source assertion or
   bounded boot probe. Rebuild only what changed, launch one app, and capture
   the resulting evidence.

# S2.1 PASS BAR

All 346 GAME.CGO objects integrate, their top-levels run, the game process tree
reaches a stable renderer-ready boundary, and no crash loop is hidden by a
handler. A successful compile, validator run, shell surface, or signed-AOT
slice is not S2.1 PASS.

# AFTER S2.1

- S2.2: first real Jak 1 frame through Metal from game systems; no synthetic
  triangle/clear-color substitute.
- S3: touch movement/actions plus pause, background/foreground, save/config,
  and sustained Simulator session.
- R1: clean-checkout artifact instructions, user asset import, ROM-safety
  audit, reproducible build/package checks, canonical patch regenerated and
  clean/reverse-apply checked against the pin, honest device boundary.

# OPERATING RULES (binding)

- At most one runtime executable and one booted Simulator. Windowed only.
- Never commit ISOs, extracted assets, CGO/DGO packages, ROMs, or scratch
  binaries. One build tree; disk is tight (~13 GiB free).
- Small reversible changes; no renderer/touch/marketing work out of order.
- Simulator != device; compiler/validator != runtime; RX blob != product AOT.
- After every passed gate: update STATUS, 13-current-state, loop log, evidence;
  regenerate/verify canonical patch if tracked upstream sources changed; run
  relevant tests/safety checks; commit one coherent checkpoint; continue.
- Do not push, merge, publish, or open a PR without explicit authorization.
```
