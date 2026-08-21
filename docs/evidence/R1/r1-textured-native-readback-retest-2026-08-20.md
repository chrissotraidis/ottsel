# R1 textured native Sprite3 readback revalidation — 2026-08-20

## Gate

Revalidate the known textured native Sprite3 probe after the TCC=0/color-only
changes, without widening bucket ownership or claiming product playability.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed Simulator executable SHA-256:
  `f224fcacc6615e588f9e178e5e776ccef4cd058df222f1d1943a245b9f640a99`.
- One iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`.

## Live proof

The supported prelaunch Village1 route armed the existing textured native
probe and readback trigger. It logged:

```text
native group=0 index=0 bounds=(0.438,0.484)..(0.617,0.788)
texture=0x2bc1 tcc=1 size=64x64
native visibility color-alpha=0.8448 texture-alpha-max=128
texture-alpha-nonzero=2615 area-fade=1 uploaded-alpha=0.8448
```

The diagnostic Metal readback was nonzero and converted for visual inspection;
its PPM SHA-256 was
`ef30ac092987cd9ac9c7e074f930b14868e24996f86c7e24dc52dd17b05e9da1`.
The frame showed the composed diagnostic/title scene and native textured
content. `ottsel-fault.log` was 0 bytes.

## Verdict

OPEN. This proves the prior textured native probe still reaches a nonzero
Metal readback after the TCC=0 work. It is not a final on-screen playability
or Sprite3 parity pass: the Simulator remains treated as blank/non-audible,
the macOS phase/resource sequence still differs, and CPU/TFRAG/TIE, touch,
audio, save/reload, iPhone, and physical-device gates remain open.

## Next gate

Compare this textured candidate’s ordered phase/resource state with the macOS
`0x24f2` world dispatch, then extend native composition only for the next
falsifiable missing phase.
