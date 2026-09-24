# L3: the two MERC changes, measured against the pre-change binary in the same state - 2026-09-22

Gate: L3.  The two landed changes (`l3-merc-packet-hot-path`: per-chain trigger latch and reused scratch;
`l3-merc-vertex-span`: skin and upload only the referenced vertex slice) were each reported with the caveat
that their fps effect was not controlled.  This closes that: the pre-change source was reconstructed by
reversing the first change out of the saved intermediate file (the reversal script asserts every region
matches exactly once, and the result differs from the intermediate by exactly those 57 lines), built, and
both binaries were then measured in the **same state, back to back**.

**Why fps windows could not answer it.**  The host here carries the Codex app itself (~35% of the load), so
"quiet" is not available, and the same binary produced 5.81 fps and 3.00 fps in two consecutive 30 s windows
of the same state at load 4.00 and 3.71.  A 20-30% effect cannot be read out of that.

**The load-robust comparison: leaf shares of the game thread's chain walk**, both samples taken as 3 s
`sample`s in the title state (the span build under a *heavier* load, which biases against it):

| leaf | pre-change | both changes | pre-change % | both % |
|---|---|---|---|---|
| `capture_mobile_merc` | 253 | 10 | 18.7% | **0.8%** |
| `_platform_memmove` | 264 | 74 | 19.5% | **5.6%** |
| `vector::__insert_with_size` | 67 | 0 | 5.0% | 0.0% |
| `decode_texture_pixels_raw` | 20 | 17 | 1.5% | 1.3% |
| `__bzero` | 181 | 235 | 13.4% | 17.7% |
| `access` | 136 | 167 | 10.1% | 12.6% |
| `SDL_main` | 224 | 203 | 16.6% | 15.3% |
| sum of that set | 1162 | 718 | **86.0%** | **54.0%** |

(chain-walk totals 1351 pre-change and 1329 with the changes, under loads 4.00 and 4.91.)

So the two changes remove their targets: the MERC packet handler itself falls 25x in share, the vertex and
lighting copies fall 3.5x, and the vector insert disappears.  The remaining set is 54% instead of 86% of the
same walk, and that is with the changed build running under a 23% heavier load - a controlled, like-for-like
attribution rather than an fps claim.

**Follow-up attempt this turn: the sky-isolation probe poll.**  `SkyIsolationProbe::activeRequest()`
(`src/shell/metal_sky_isolation.h`) ran two `access()` calls on *every present* for a diagnostic whose
trigger files only appear when a driver asks for a capture; it now polls every sixteenth call and memoises,
which keeps a request visible within a fraction of a second and keeps the caller's check-then-capture pair
consistent.  **Refuted as a lever:** a third 3 s sample in the same title state shows `access` 167 -> 156
(chain-walk 1329 -> 1358, main thread 1515 -> 1492, load 4.91 -> 5.12), i.e. no real change.  The change is
kept because it removes stats without changing behaviour, but it is not a win.

**What the same measurement says to do next.**  `__bzero` (13-18%) did not move and is a per-chain/per-packet
zeroing the slice work never touched.  `access` is not one caller: grouping the 156 leaf samples by enclosing
frames gives the main loop's own trigger polls (51 - the hold list plus the thirteen `ottsel-touch-*` polls
this session added), `presentRGBA:` (49), the nested Mips2C particle launcher (42) and `render_mobile_sprite_bucket`
(5).  Batching the main loop's polls to every few frames and moving the particle-launcher probe behind its own
trigger are the next bounded targets; the touch trigger's own per-frame cost is this session's own debt.

Not claimed: no fps number is offered from this turn; the title-state windows measured 5.81/3.00 fps
pre-change (loads 4.00/3.71) and are quoted only as the reason the attribution above is a share comparison.
