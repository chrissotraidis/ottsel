# I1 — BOT57 Q1: the game's own VIF -> VU1 -> GIF path is viable but unwired

Round 2026-09-11 (BOT57), gate I1, device `08636791-2675-4675-8335-EF72EF954DCF`,
bundle `com.ottsel.shell`.

## Question

Does the game's own VU1 path run when the shell's diagnostic gate is lifted, and
does lifting it change the presented frame?

## Method

One bounded launch, no source change, no rebuild:
`SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1 xcrun simctl launch <udid> com.ottsel.shell`.
Product-path launches were then re-sampled at the same boot offset (launch, sleep
55 s, four screenshots 4 s apart) so both sets cover the same camera window.
Black fraction = share of pixels with `r<14 && g<16 && b<24`.

## Result 1 — the path is viable (exit-bar branch A)

`cpu-diagnostic-path=enabled` at [32:17] (was `disabled`). Per 90-chain
period: `vu1-runs` 3485 / 10206 / 8538, `xgkicks` up to 124145,
`nonzero-gif` 39 / 52 / 130, `gif-words` 433564 / 496580 / 190744, and
`last-pc` reaching 1694 — the strip-output phase. The early `run#1..#6` lines
are `mscal imm=0x0 top=0x0 pc=79 gif_out=0`: the zero-entry TFRAG setup pass with
an empty frag list, spinning to the 50k cap by construction. The first nonzero
dispatcher call (`imm=0x3`) also reads empty VU memory,
`mem0=0/0/0/0 kick=0/0/0x34/0`.

## Result 2 — lifting the gate does not change the presented frame

Matched boot-window black fraction, product vs diagnostic:

- product: 23.2%, 19.2%, 42.3%, 42.3%
- diagnostic: 55.2%, 13.7%, 24.6%, 24.2%

The ranges overlap; neither path is systematically darker. An earlier unmatched
product set at a later chain window read 42.0 / 53.1 / 62.5 / 70.7 / 75.8%, which
had looked like a difference but was camera position. The diagnostic flag is not
a frame fix, and B56-F (black lower two thirds) is untouched by it.

## Conclusion

Branch A holds at the interpreter level, so `src/shell/metal_gfx.mm:6711`
(`!g_metal || getenv(...)`) hides a working execution path rather than masking a
broken one. The BOT57 lead is therefore wiring `g_vu.gif_out` into the renderer,
not repairing the interpreter.

## Falsified / not established

- No causal link between the flag and the frame. Shared `g_dec` is a plausible
  coupling, but `native_primitives` is only consumed inside the sky/direct capture
  modes (`metal_gfx.mm:4029-4094`, `4120-4165`), so no geometry path is proven.
- Frame A/B must be chain-matched: the camera is a scripted fly-through and black
  fraction varies 13-76% with camera position alone.

Next: `docs/BOT57_PROMPT.md`.

