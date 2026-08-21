# R1 phase-aligned lookup and allocator attribution — 2026-08-21

## Ledger

| Field | Required value |
|---|---|
| Gate | R1 source/resource parity |
| Source/build identity | Outer `b2e36fc8037f3f1a7984ede59f7114cd03604b2f`; upstream pin `641fb572e876750d8618434d9f7c1a531b43b366`; diagnostic patch SHA-256 `eba576d31ff964d83d2ba5552df16d2c2a5aec7486ae5223bc5124a40f2a21e5`; installed signed executable SHA-256 `b7c8abff762d8d5378808d69fd77075e4393d52d2366f5c80f6152d20397385f` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`, iOS 18.5; live replay PID 36291; fresh validated user pack |
| Before failure | The completed R4 capture was compared as one 21-entry post-Start sequence against an 18-entry macOS oracle. That made position 5 look like an additional `15 → 0` anomaly and obscured which lookups belonged to title versus Village1. |
| Change | Analysis-only phase realignment of existing R4 records. No source, GOAL payload, TBP, camera, shader, allocator, or Metal policy change. |
| Focused proof | Re-extracted ordered records from `launch-transcript.log`; strict deep codesign PASS for the installed executable. |
| Live proof | Same-boot input route remained Start → Cross → Down×4 → Cross with shell latches at transcript lines 179995–183334. `GAMEPLAY: enter village1` appeared at lines 183372/183429. The first post-route SPARTICLE 3D record began at line 183727. |
| Fault scan | No fault in the R4 capture window. A separate supplied crash report for PID 34171 at 12:01:49 is archived under `artifacts-2026-08-21-ipad-trace-r3/`; its abort occurred in `jak1::ottsel_stub_flip_phase_a()` during link. It predates live PID 36291 and is not the R4 texture-run result. |
| Verdict | OPEN — phase contamination corrected, but the mobile/macOS lookup-family divergence remains. New allocator attribution narrows it to differing default-allocated runtime particle families. |
| Next gate | Capture raw 32-bit particle IDs reliably on both platforms, then compare the producer/spec ownership of macOS-only indices `35/31/36` against iPad-only `54/49/48/42/44`. Do not remap TBP or change renderer policy first. |

## Phase realignment

R4 contains 21 page-2 lookup records. Nine occur before the Start trigger:

```text
4,53,4,18,0,15,28,27,3
```

Only twelve follow Start:

```text
54,49,48,42,44,24,10,41,25,30,34,9
```

This invalidates a direct 21-versus-18 comparison. The prior R2 post-Start
artifact was:

```text
4,53,4,18,15,28,27,3,54,49,48,42,44,24,25,10,41,0,30,34,9
```

The retained macOS oracle remains:

```text
4,53,4,18,15,30,0,28,3,41,24,35,31,36,9,10,25,34
```

After removing R4's pre-Start block, both mobile runs retain the same core
mobile-only family (`54/49/48/42/44`) and omit the same macOS-only family
(`35/31/36`). Their remaining order differs only in common-family interleaving
(`24/25/10/41` versus `24/10/41/25`) and the later placement of index 0.
Thus the extra leading zero was phase contamination, not a new source anomaly.

## Allocator correlation

R4's login trace reports every member of the mobile-only family as
`alloc=1`, meaning `texture-page-default-allocate`. The shared/common family
is `alloc=2` (`texture-page-common-allocate`) for indices `24/10/41/25`.
Index `53/4` uses `alloc=6` (`texture-page-level-allocate`). All inspected
page-2 entries were already resident.

This does not prove a page-directory allocation defect. It shows that mobile
reaches a different set of permanently allocated runtime particle resources.
Because all entries are resident and hits, the mismatch is upstream of lookup
resolution: particle-spec/system selection or phase execution, not failed VRAM
login.

## Native-boundary clarification

R4 did not need to repeat the native boundary proof. The retained R2 same-boot
source boundary correlates the first two mobile MSCAL=211 groups to TEX0
`0x2005aa459930ab8d` / TBP `0x2b8d` and `0x2015a4c55530abe0` / TBP `0x2be0`,
followed by six world groups. The empty R4 `native-boundary.log` reflects the
absence of that native probe in this build, not missing data in R2.

The GOAL SPARTICLE trace did run in R4 and reported repeated valid=64,
64x64, `first-tbp=11149` (`0x2b8d`) records after Village1 entry.

## Boundaries

The Simulator warning remains explicit: current output is blank or partially
corrupted. This is not visible composition, audio, interaction, playability,
iPhone parity, or physical-device proof. One Simulator remains booted; the
dirty upstream worktree remains user-owned and unchanged by this analysis.
