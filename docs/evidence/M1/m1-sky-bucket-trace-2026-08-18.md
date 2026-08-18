# M1 — macOS sky-bucket trace (2026-08-18)

## Scope

One `gk -v --game jak1 -- -boot -fakeiso -nosound` run on the macOS reference
host. No iPad runtime was active. The process was stopped after the bounded
trace; this is renderer provenance, not a gameplay acceptance replay.

## Result

The desktop `SkyRenderer` accepted its built-in three-chain trace. The first
chain was skipped by a `CALL`; the next two carried a 64-byte setup packet and
completed with zero direct GIF draw packets. The run then displayed `title`
and `village1` normally.

## Consequence

The black region in the current iPad Village1 capture cannot yet be assigned
to a missing sky Direct draw. Do not add a synthetic sky/fill renderer. The
next probe must attribute live Direct/Sprite submissions from the active
Village1 phase before a mobile Direct implementation is chosen.

## Active-Village Direct follow-up

The Direct renderer then received a bounded, producer-side trace after
Village1 was already displaying. The only geometry-producing Direct bucket in
that window was `[67] debug`, at one draw / 44 triangles per frame. The
desktop sky bucket still produced no visible Direct geometry. The trace was
refined to log each active bucket name once per request, then rebuilt, so it
can be used without per-frame log flood in the next phase.
