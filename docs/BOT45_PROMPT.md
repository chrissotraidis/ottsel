# BOT45 - defer the menu until the title spool is idle, then make the frame honest

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT44_PROMPT.md`. Read `AGENTS.md` first, then this file, then
`docs/STATUS.md` (tail) and `docs/evidence/I1/BOT45-intro-spool-start-stall.md`.

## Product goal (unchanged from the PRD)

Deliver an honestly playable native Jak 1 build on iPadOS, then iPhone, then
physical-device readiness. Playable means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe: no ISO or
extracted game data in Git, no RWX/`MAP_JIT`/trampoline code in the product
path, users supply their own legal data.

A build, log, counter, first frame, title screen, or Simulator-only success is
never playability proof.

## Where BOT45 starts

Confirmed live on iPad Pro 11-inch M4 (iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`): the title intro plays as a moving
camera over fully textured Village1 - ground, rocks, palms, huts, flag, lit by
the time-of-day system - with the app's own flat-colour touch overlay on top.
`GAMEPLAY: enter title` fires, Start is received
(`OTTSEL TITLE: start edge in title-wait abs=8 rel=8`), `activate-progress`
runs, and `master=progress` with the menu entering `normal`. The frame is
visible and the route seam works.

What is still wrong, in priority order:

1. Start during the intro spool wedges the loader
   (`docs/evidence/I1/BOT45-intro-spool-start-stall.md`).
2. The title prompt and the menu draw no text and no logo.
3. The sky is not a gradient; it reads as a flat dark field.

## What BOT45 corrected

Two carried claims are withdrawn. The "Mac gets past the intro, iPad stalls"
split was a confounded comparison, and `g_direct_texture_metadata` keyed by
`dest` alone is not confirmed for the sky source. Both are in the two BOT45
evidence files; do not re-derive them.

## Disk override

Re-run `df -h / | tail -1` and count `.git/objects/pack/tmp_pack_*` before
every build. If any temp pack exists, report its exact path and stop. The 40 GB
floor in `AGENTS.md` rule 2 sits above current capacity; the user explicitly
authorized working in the space that exists ("theres space to work, just keep
working").

## Gate contract

**Gate V2 (next, cheap).** Stop the Start-during-spool wedge. In
`target-title-wait`'s Start branch (`goal_src/jak1/levels/title/title-obs.gc:668`)
defer `activate-progress` until no title spool is in flight, gating on
`(= (-> *art-control* active-stream) #f)`. That field is set when a spool starts
(`engine/load/loader.gc:706`) and cleared by `ja-abort-spooled-anim`
(`loader.gc:762`) on both abort and normal completion, so it is exact. Passes
when Start during the intro no longer produces `loader stall on art` and the
menu still opens.

**Gate G1 (decisive for playability).** Make the title prompt and the menu
draw. The route to Village1 currently runs through an invisible menu, so this
blocks the product goal. Passes when `press-start` text is visible on the title
and the progress screen's labels are legible in a screenshot.

**Gate S3 (re-scoped).** Attribute the flat sky with a probe that reports the
GPU-side fetch rather than a CPU clamp, and check the sky draw's actual sampler
state and blend against the GS CLAMP/ALPHA registers. Do not re-chase the
`dest`-keyed registry: it is confirmed present for this path
(`docs/evidence/I1/BOT45-sky-probe-misleading.md`).

**Gate A1 (carried).** Audio: the mixer runs and reports `pcm-peak=0`. Confirm
or refute on a fresh launch before investigating.

## Frozen

Camera matrix math (`set_mobile_tie_camera`), TBP/lookup, strip-restart, the
touch frontend, and all iPhone work. If the camera matrix turns out to be the
fault, write the finding instead of remapping it.

## Next falsifiable experiment

One edit, one build: add the `active-stream` guard to the Start branch in
`title-obs.gc`, rebuild `TIT.DGO` + `GAME.CGO` with `goalc` `(mi)`, copy
both into the app bundle, `codesign --force --sign -`, `simctl install`, then
re-run `/tmp/b43_route3.sh`. Question: with Start injected mid-intro, is
`loader stall on art` zero and does `logo-loop` still get reached while
`master=progress` holds?
