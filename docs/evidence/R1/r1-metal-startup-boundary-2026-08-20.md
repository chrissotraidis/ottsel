# R1 Metal startup boundary versus SDL-only route — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; signed app from the current iOS build; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The trigger-gated Sprite3 phase was not observed in the prior replay, but the append-only runtime log mixed multiple launches and could not distinguish a route stop from stale teardown lines. |
| Change | No product behavior change. Cleared only diagnostic runtime/fault logs, replayed the same durable-pack route with Metal enabled, and compared it with SDL-only diagnostic mode. |
| SDL-only proof | `SIMCTL_CHILD_OTTSEL_DISABLE_METAL=1` imported the validated pack, linked generated Village1 DGO objects, displayed Village1, and continued producing runtime logs; fault log remained 0 bytes. |
| Fresh-pack timing | Host `scripts/validate-user-data-pack.sh` completed in `6.600s` for the 1.5G test pack. A fresh SDL-only replay logged import at roughly `+8s`, reached Village1, remained running at `+20s`, and kept a 0-byte fault log. |
| Metal proof | With the fresh `Documents/OttselUserData` test pack present, phase markers reached `selecting iOS data root` but no later phase before the bounded run ended; fault log remained 0 bytes. With that local test copy moved aside so the already-promoted durable pack was selected, markers reached `selected iOS data root`, optional sound probe complete, low-EE protection installed, and kernel globals initialized, followed by the existing long linker trace. |
| Interpretation | The pack validator/import path is viable on the same Simulator; the Metal-enabled process is lost during or immediately around that startup transaction before Sprite3. The durable-pack comparison also reaches kernel setup before the known long link/Simulator boundary. No `SDL_EVENT_QUIT` evidence was captured, and no lifecycle change is justified. |
| Simulator boundary | The Simulator was blank/non-audible; this is log/fault evidence only, not rendered-content, audible, or playability proof. |
| Verdict | OPEN — R1 native Sprite3 parity remains unproven; F1 fresh-pack validation cost and the later Metal/link boundary are now separately observable without broadening renderer scope. |
| Next gate | D3/R1 Metal startup instrumentation or a stable native drawable replay, then the same Sprite3 trigger and CPU/native comparison. |
