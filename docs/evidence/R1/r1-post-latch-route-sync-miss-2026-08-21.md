# R1 post-latch route synchronization miss — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 phase-specific Sprite3 composition/readback |
| Source/build identity | Outer checkout with current dirty state; signed executable SHA-256 `a3af1793efce65018e3829358bb49740e0805388079485167aa07bf39823da69`; bundle identifier `com.ottsel.shell` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `F6625076-2171-4C92-8870-09EB0500D76A`; Simulator shut down after capture |
| Before failure | The presentation latch was live-proven, but a synchronized post-latch Sprite3 aggregate was still missing. |
| Change | No product change. Retried the fresh route using the installed app's actual bundle identifier and the writable file-trigger input seam. |
| Focused proof | The app launched and logged `OTTSEL RUNTIME BOOT: pid=86971`; delegated VSYNC calls included 1–8 and 60. `ottsel-fault.log` was 0 bytes. |
| Live proof | The current log did not contain a consumed `BOT22` Start/Cross/Down sequence or a valid current-boot `GAMEPLAY: enter village1` transition after the route triggers. The Simulator remained blank/non-audible. |
| Verdict | OPEN — route synchronization miss only; no Sprite3 phase, visual, audio, or playability claim. |
| Next gate | Retry one current-boot title-wait → Start → Cross → Down×4 → Cross route, then capture the immediate same-transition Sprite3 aggregate. |

This note preserves the failed capture boundary. It does not reinterpret the
existing accepted route evidence or authorize a renderer/resource remap.
