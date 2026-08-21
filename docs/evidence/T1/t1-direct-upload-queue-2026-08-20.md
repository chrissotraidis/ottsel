# T1/R1 Metal upload stability increment — 2026-08-20

| Field | Result |
|---|---|
| Gate | T1 support boundary; also unblocks R1 live replay |
| Source/build identity | outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `d73f906331f1e4d914a4c83fdf27ff66af6eca6523f19f1942008f39873faa70` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, one booted Simulator |
| Before failure | Fresh updated-overlay replays hit `MTLCommandBufferErrorDomain` followed by `SimMetalHost` XPC loss while `uploadDirectTexture` synchronously created hundreds of native textures from the GOAL boot thread. |
| Change | `src/shell/metal_shell.mm` now queues each keyed Direct texture once from the producer thread and drains at most eight uploads per presentation frame. The synthetic Direct fixture path retains synchronous upload behavior. |
| Focused proof | `DirectFixture.*` — 6/6 passed; `git diff --check`; D2/D3 patch reverse-apply checks passed. |
| Live proof | Fresh clean boot/install/UI launch remained foreground through title/Nintendo scene progression. `T1-touch-overlay-queued-scene-2026-08-20.png` shows the rendered scene and mapped overlay; a later UI inspection still showed the foreground scene. No fresh `OttselShell*.ips` report appeared during the follow-up window. |
| Fault scan | The prior crash signature was absent in this bounded replay. This does not prove long-soak stability or renderer parity. |
| Verdict | OPEN — renderer-host burst is mitigated in this replay; Direct/Sprite image parity, complete touch interaction, customization, persistence, and lifecycle remain open. |
| Next gate | R1 — use the now-stable live route to capture a same-phase Sprite3/Direct attribution or isolate the next renderer divergence. |
