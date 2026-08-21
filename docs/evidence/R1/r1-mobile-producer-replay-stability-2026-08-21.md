# R1 mobile producer replay stability — 2026-08-21

## Gate

Determine whether the first post-setup Sprite3 producer records vary within a
fresh, valid mobile route before changing renderer state or texture policy.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed app SHA-256: `7b16c7bed88ea5c0219e89848374121e51f7ceaede833bb10e1925d1d5027f36`.
- `codesign --verify --deep --strict` passed.
- iPad Pro 11-inch (M4) Simulator, iOS 18.5,
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Durable validated user-data root was selected before Metal.

## Live proof

The bounded record ledger was armed after the in-runtime title-wait route and
captured the first Village1 groups at chain 3714. The same frame state repeated
on chains 3715–3717:

```text
pc-level='village1'
pc-trans=(-482016.1,218586.67,1151304.5)
pc-fog=-0.036405455
pc-r0=(-0.95494163,0.056473088,-0.2913713)
pc-r2=(0.29679358,0.18197167,-0.93744326)
frame-pfog0=-0.036405455 frame-inv-area=0.036767285
```

Each repeated group began with the same resource and the same first records:

```text
tbp=0x2c8d psm=19 tw=5 th=5 tex0=0x2005a0455530ac8d
index=0 xyz=(-401268.7,8755866,1.9756194e+07,288325.4)
index=1 xyz=(-1.1088943e+07,787090.25,-1.6328894e+07,197616.28)
```

The ledger completed 64 records and `ottsel-fault.log` remained 0 bytes. The
Simulator was shut down after capture.

## Interpretation and verdict

OPEN. The mobile producer is stable within this route state; the earlier
post-Village1 capture with `0x2d8c`/`0x2c8d` and different camera values was a
different route/frame state, not evidence of random producer corruption. This
does not establish parity: the macOS accepted world phase still begins at
`0x24f2` with a different raw vector domain. The next experiment is a
serialized same-route macOS capture with the same route boundary and producer
fields, followed by a direct mobile/macOS group-state comparison. No TBP
remap, camera sign change, or native-consumer widening is justified.
