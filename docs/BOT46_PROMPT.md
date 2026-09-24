# BOT46 - finish the title menu, then take the route into Village1

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT45_PROMPT.md`. Read `AGENTS.md` first, then this file, then
`docs/STATUS.md` (tail) and `docs/evidence/I1/BOT46-menu-text-renders.md`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO or
extracted game data in Git, no RWX/`MAP_JIT`/trampoline code in the product
path, users supply their own data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Where BOT46 starts

Confirmed live on the iPad (Simulator, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`):

- The title intro is a moving camera over fully textured Village1, with the
  app's own flat-colour touch overlay on top.
- The press-start prompt draws real glyphs ("PRESS START").
- Start opens the progress menu (`screen=27`, `normal`) and it draws text.
- Audio is live: `OTTSEL AUDIO: PLAYER RPC play` for `bird-2`/`seagulls-2`/
`fly7`, `OTTSEL STR: loaded LOI2.STR chunk`, `pcm-peak=5685`.

## Carried work withdrawn this round

Do not re-derive these; they are false leads.

1. BOT45 Gate V2 ("defer Start until the loader is idle") is withdrawn. The
   loader is legitimately busy for the whole ~54 s logo intro, so the guard
   never fires. Evidence: `docs/evidence/I1/BOT46-menu-text-renders.md`.
2. "The title prompt and menu draw no text" is refuted. Both draw.

## Gate contract

**Gate G1 (decisive, in progress).** The `*title*` menu is
`NEW GAME / LOAD GAME / OPTIONS / BACK` (`engine/ui/progress/progress-static.gc:54`)
but only `OPTIONS` renders. Find why the other three entries do not draw and
why there is no menu backdrop. Start from the progress draw path
(`engine/ui/progress/progress-draw.gc`, `progress.gc` `in-out`/state
machine) and the per-frame text counters, not from the renderer. Passes when
all four labels are legible in one screenshot.

**Gate N1 (next route step after G1).** Drive `NEW GAME` and follow the route
into Village1. Inject the pad via `/tmp/ottsel-press-button` (`<mask> <frames>`);
START is `8`. Passes when the frame shows Village1 gameplay with Jak present,
not a menu and not the intro camera.

**Gate S3 (carried).** The sky reads as a flat dark field. Probe the GPU-side
fetch, not a CPU clamp (`docs/evidence/I1/BOT45-sky-probe-misleading.md`), and
check the sky draw's sampler and blend against the GS CLAMP/ALPHA registers.

**Gate A1 (carried, largely closed).** Fresh launch shows `pcm-peak=5685`, so
the old `pcm-peak=0` note is stale. Re-confirm only if it regresses.

## Frozen

Camera matrix math (`set_mobile_tie_camera`), TBP/lookup, strip-restart, the
touch frontend, and all iPhone work. If the camera matrix turns out to be the
fault, write the finding instead of remapping it.

## Loop

One edit, one build, one measured run per gate.

1. `df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*`. Report and stop
   if a temp pack exists. The 40 GB floor sits above current capacity; the user
   explicitly authorized working in the space that exists.
2. Build: `goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'`
   from `out/jak-project`.
3. Package: copy `out/jak1/iso/{TIT.DGO,GAME.CGO}` (title changes touch TIT.DGO
   only) into `out/ios/app/OttselShell.app` at `iso_data/DGO/TIT.DGO` and the
   bundle root, then `codesign --force --sign -` and `simctl install`.
4. Measure with screenshots plus the filtered runtime log. Never claim a gate
   from a log line alone.
5. Write at most one <=60-line evidence doc per proven gate, and at most eight
   appended STATUS lines. Record refuted leads as clearly as confirmed ones.

## Next falsifiable experiment

With Start already injected and the menu up, capture the progress draw path for
one frame: how many text items are submitted, with what screen positions and
alpha, versus the four entries in `*title*`. Question: are the other three
entries drawn off-screen, drawn with zero alpha, or never submitted?
