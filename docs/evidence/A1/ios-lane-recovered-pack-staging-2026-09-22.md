# iPad lane recovered: the user-pack staging rule - 2026-09-22

Gate: I0/L5.  Question: can the iPad lane be brought back without new user data, and does the injected
input now reach the game?

**Recovery (no new user data needed).**  The extracted game data was still on this machine in the
repository's gitignored `out/jak-project/iso_data/jak1/` (`CGO DGO MUS SBK STR TEXT VAG VIS`, plus the
derived `fr3` in `out/jak-project/out/jak1/fr3`), which is exactly what
`scripts/prepare-user-data-pack.sh <source> <out> [fr3]` consumes.  It built a 1.5 GB pack at
`/tmp/ottsel-user-pack` in 12 s (all families + `fr3` + `manifest.txt` + `SHA256SUMS`).

**The staging rule matters, and it cost one boot to find.**  `build-ios.sh` deletes and repopulates the
bundle's `iso_data/` with only the *built* `DGO` and `TEXT` (`out/jak1/iso/*`), so the pack families must
be staged *after* the build.  Staging the pack's `DGO`/`TEXT` over the built ones boots to 332/346 modules
and then crashes - the fault handler logs `fault pc=0x10534c000 ... GOAL offset=0x0 code-range=invalid`,
`x0=0x0803c2d4`, and holds the process for lldb.  Keeping the built `DGO`/`TEXT` and adding only
`CGO fr3 MUS SBK STR TEXT VAG VIS` boots cleanly:

```
t=20s title=1 modules=346 fault=0   -- TITLE REACHED (fault log 0 bytes)
```

So the lane is back: 346 signed modules, `title-wait-ready`, a 0-byte `ottsel-fault.log`, and the title
rendering `screen=27 state=27`.

**The input path is proven end to end** (this is the L5 result of the turn): launched with
`OTTSEL_TRACE_INPUT=1`, the driver's press produced
`OTTSEL INPUT: pad0 sample buttons=0x8 ...` (START) followed by `buttons=0x0 ...` (release) - the injected
keyboard tap is mapped by the shell, published through `ottosel::platform_input`, and sampled by GOAL's
pad.  What still does not happen is the frontend transition, and the route driver's expectations are the
reason it cannot report success: in August the route was `title-wait -> Start -> Cross -> Downx4 -> Cross`
with a `screen=27` acceptance per press, and the current build's log shows only the title's own
`OTTSEL PROGRESS: request/entering/normal screen=27` lines after a press.  The driver now holds instead of
tapping (a tap is one frame at this lane's 5-8 fps) and needs its expected edges re-derived from the
current frontend before the route can be called proven.

Not claimed: no playability, audio or lifecycle acceptance; the route's first transition is still unproven.
The macOS lane was never affected.  Packaging gap worth fixing: the build should stage the pack families
into `iso_data/` when a pack is present, and a missing family should be a named error rather than an
uncaught `ghc::filesystem::filesystem_error`.
