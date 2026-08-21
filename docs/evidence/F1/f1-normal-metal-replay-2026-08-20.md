# F1 — normal-Metal replay boundary — 2026-08-20

| Field | Required value |
|---|---|
| Gate | F1 — legal user-data import and save persistence |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `6bb49fdbc4b2afa72ad5aeb50126da0c79b1f9894ab09bca468bc6d0491e6b09` |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal `OttselShell` runtime |
| Before failure | The preceding SDL-only F1 proof used `SIMCTL_CHILD_OTTSEL_DISABLE_METAL=1`; normal product-mode visual proof was still untested. |
| Change | No source change. Replayed the signed app in normal Metal mode against the already validated durable user pack, preserving the F1 import/save boundary. |
| Focused proof | `codesign --verify --deep --strict out/jak-project/out/ios/app/OttselShell.app` passed. The runtime reached `presentRGBA` with `1210x834` drawable/layer dimensions and `pipeline=1`. |
| Live proof | The normal-Metal run logged the EE mapping and gamepad acquisition, then Metal reported `MTLCommandBufferErrorDomain error 1`; the Simulator log recorded loss of the `SimMetalHost` XPC service. The capture `/tmp/ottsel-metal-current.png` shows the Simulator home screen after termination, not a composed product frame. A Computer Use inspection opened the iPad Files app and exposed the `Ottsel Shell` container; the host-folder drag/copy attempt did not create a new pack, so the pre-existing `OttselUserData.after-import` folder was not counted as a legal delivery. |
| Fault scan | `ottsel-fault.log` was zero bytes; no app crash report was found. Metal command-buffer abort and SimMetalHost loss are recorded as the external Simulator/runtime failure. The Simulator was terminated and shut down after capture. |
| Verdict | OPEN — the durable user-data and save behavior remains diagnostically proven, but legal Files delivery and normal-Metal product-mode playability are not proven. This is not a gate pass. |
| Next gate | Re-establish a discriminating normal-Metal replay or isolate the first native renderer divergence before claiming F1/P2; then repeat the same route with an actually transferred Files pack. |
