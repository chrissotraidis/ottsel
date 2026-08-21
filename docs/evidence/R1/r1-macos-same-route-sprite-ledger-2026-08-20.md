# R1 macOS same-route Sprite3 reference — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 same-phase Sprite3 resource/state comparison |
| Source/build identity | Ottsel outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; OpenGOAL `641fb572e876750d8618434d9f7c1a531b43b366`; Mac `gk` SHA-256 `7b0c1bb080bc15c33aaae5475131865ad755d971d74cafd14e35aa1d7fdf0883`; log `out/jak-project/log/jak1.2026-08-20T16-26-06.log` |
| Environment | One native arm64 macOS Windowed `gk`, `-boot -fakeiso -nosound`, isolated empty config `/tmp/ottsel-newgame-config.43ClWY`; no Simulator concurrent |
| Route | Fresh title-wait → Start → Cross → Cross → four settled Down edges → Cross route. The log reached `GAMEPLAY: enter village1` twice before the bounded Sprite3 hook was armed. |
| Live trace | `/tmp/ottsel-trace-sprite3` captured three frames. Frame 1 recorded group 0 as 51 blocks / 2,432 sprites, HUD as 3 blocks / 128 sprites, and 24 item samples. |
| Reference resource | The identified world draw is decimal TBP `9458` (`0x24f2`), 64×64, `TEX0=0x2004d1e59930a4f2`, `TEX1=0x120`, `CLAMP=0x1010001c0`, `ALPHA=0x48`, blend 2, ztest 2, zwrite false, alpha-test 2, `aref=0`. A nearby double-draw resource is TBP `9509` (`0x2525`), 32×32, blend 1, zwrite true, `aref=0.299`. |
| iPad comparison | The fresh iPad ledger captured bucket 66/chain 54830 with first populated records at TBP `0x2c8d` (32×32), `TEX0=0x2005a0455530ac8d`, same `TEX1=0x120`, `CLAMP=0x1010001c0`, and `ALPHA=0x48`. It did not capture the Mac world TBP `0x24f2`. |
| Fault scan | No crash/assert/fatal marker in the bounded Mac log; the process was stopped after the trace. This is renderer attribution, not audible or playability proof. |
| Verdict | OPEN — the same canonical route now has a concrete desktop resource oracle, and the iPad mismatch is resource/bucket ownership or phase, not an unproven camera policy. |
| Next gate | Compare the producer-side bucket/group ordering and texture-page ownership for `0x24f2` versus `0x2c8d`; change native Metal only after that comparison identifies a specific missing handoff. |

The Mac scene itself is a behavioral reference. The iPad Simulator remains
blank and non-audible, so no visual or audio acceptance claim is made.
