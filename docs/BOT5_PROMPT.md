# BOT5_PROMPT — Ottsel Continuous Goal Loop (S2 → S3 → R1)

Paste this as the next bot's goal. It replaces the stop-after-one-gate
pattern with a **continuous loop with checkpoint-continue semantics**: the
bot works the remaining roadmap in order, checkpoints at each gate, and
stops only when honestly blocked or when the roadmap is done. Rationale:
per-gate hard stops existed because sessions died at context limits; this
environment auto-compacts, so the checkpoints (not the stops) are what
protect the work. `docs/BOT5_HANDOFF.md` remains the S2 technical spec.

---

/goal You are the next build-and-proof agent for the repository at
/Users/chrissotraidis/GitHub/ottsel. You are continuing a multi-session,
proof-gated project. Work autonomously until the roadmap below is complete
or you are honestly blocked.

**The original goal (never lose sight of this)**
A **native iPadOS/iOS port of** ***Jak and Daxter: The Precursor Legacy***
on top of OpenGOAL (open-goal/jak-project, pinned at
641fb572e876750d8618434d9f7c1a531b43b366), running **ARM64 AOT with no
runtime instruction emission and no writable-executable memory**. No game
assets in git, ever. Host gates H1–H3 and Simulator gate S1 are already
PASS with evidence; do not re-litigate them.

**Your goal — the remaining roadmap, one gate at a time, in order**

1. **Gate S2 — first frame proof.** Evidence of the first rendered frame
   from Jak 1 game systems on the iPad Simulator (iPad Pro 11-inch M4,
   iOS 18.5), or a clearly defined intermediate milestone approved in
   STATUS.md. A bare clear-color window is NOT victory; if used as a
   stepping stone, declare it as a sub-gate in STATUS and keep going. The
   durable product path is **Metal** — iOS has no desktop OpenGL, and the
   ~45k-line OpenGL renderer must NOT be ported as-is. Full spec +
   sub-gates S2.0–S2.2: docs/BOT5_HANDOFF.md. Evidence under
   docs/evidence/S2/.
2. **Gate S3 — touch MVP + lifecycle.** Start the game, move Jak with
   touch overlay controls (core actions; controller support if cheap),
   pause, background/resume without dead audio or softlock. Simulator
   evidence under docs/evidence/S3/.
3. **Gate R1 — handoff package.** ROM-free package scripts, asset/ISO
   .gitignore audit, BUILDING docs, remaining-work list with honest
   external blockers (device signing, store policy). Done when a clean
   checkout can continue from docs alone, with no copyrighted assets in
   the git tree.

**Continuation rule (this replaces the old stop-at-gate rule)**
When a gate passes: checkpoint, then **immediately begin the next gate in
the same session** — do not stop, do not wait for a new prompt. A
checkpoint means: STATUS.md updated (PASS + date + evidence paths),
evidence files committed under docs/evidence/<gate>/, a loop-log entry,
docs/13-current-state.md refreshed so a fresh session could resume from
docs alone, a per-gate commit, and the canonical patch regenerated +
`git apply --check` on a fresh pin worktree if tracked OpenGOAL files
changed.

**Resume rule**
If your context was compacted or the session restarted: before doing any
work, re-read docs/13-current-state.md, the STATUS.md gate board, and the
last entry of docs/00-loop-log.md. Trust those docs over your memory of
the session; if they conflict with each other, record the conflict in the
loop log and prefer the newest dated evidence.

**Read first, in order**
- docs/13-current-state.md — authoritative technical snapshot + reproduce commands
- docs/BOT5_HANDOFF.md — the S2 spec (sub-gates S2.0–S2.2, in order)
- docs/evidence/S1/s13-dispatcher-loop.md — the S1 proof and the runtime
  fixes (pc-prof registration + intern fallback scan) you are building on
- docs/05-roadmap.md — gate bars (P5/P6/P7) and the ordering rule
- docs/STATUS.md, then docs/00-loop-log.md as needed

If anything conflicts, prefer the repo docs and record the conflict in the
loop log.

**Binding operator constraints**
- **At most ONE runtime process at a time.** Before launching anything,
  confirm zero instances (`pgrep -fl "gk -fakeiso"`). Never leave a stale
  gk, lldb, or Simulator app running.
- **ONE booted iOS Simulator at a time.** Check `xcrun simctl list devices
  booted`; shut down any other booted Simulator before booting yours, and
  shut yours down when a test cycle ends.
- **NEVER fullscreen.** Every test app/game window must stay Windowed on
  macOS; the iOS app uses no `SDL_WINDOW_FULLSCREEN` (filling the device
  display is the platform default, not a fullscreen mode). Verify window
  mode before and during every boot. If anything forces fullscreen, stop
  and fix the setting/source before continuing.
- **Never commit game assets, ISOs, or extracted data.** The legal ISO
  lives at ~/ottsel-user/iso/; extracted data stays under gitignored out/.
- Disk is tight (~16 GiB free): one build dir, clean stale artifacts, no
  extra Simulator runtimes.
- Re-verify these constraints at every gate checkpoint (pgrep, booted
  sims, `df -h`), not just at session start.

**Loop rules (how you work)**
- **Document every meaningful step in the same turn it happens**: what you
  tried, exact commands, result, files changed, pass/fail, next action.
  Append to docs/00-loop-log.md; update docs/STATUS.md when a gate or
  sub-gate changes; evidence goes under docs/evidence/<gate>/.
- **Commit per sub-gate** (docs + patch state together) so regressions are
  bisectable.
- **Prove, don't assert.** A sub-gate is done only when commands + outputs
  are captured, STATUS.md is updated with date + evidence paths, and the
  loop log has an entry. Simulator evidence is never device proof.
- **Smallest change that advances the sub-gate.** No broad refactors.
  Prefer patching the pinned tree; regenerate patches/*.patch (git diff vs
  pin) whenever you change tracked OpenGOAL files, and verify clean apply
  on a fresh pin worktree.
- **Reuse the S1 tooling before debugging blind.** Run
  scripts/validate-arm64-emission.py before hunting any boot fault, and
  keep the gated signal handler (no crash loops) intact.
- **One gate at a time.** Do not start S3 work before S2 is checkpointed
  PASS; do not open touch polish, icons, marketing, or Jak 2/3 at any
  point.
- **Honest stopping (the only early exits).** Stop before R1 completion
  only if: (a) the same root cause blocks you three times with no new
  technical angle — write docs/reports/YYYY-MM-DD-stop-<gate>.md (what was
  attempted, evidence, options, recommendation) and stop; or (b) an
  operator constraint makes further progress unsafe — document and stop.
  Do not paper over failures or drift into adjacent work.

**Expected risk areas (from the S1 review)**
- 15 IR lowerings remain NYI (Asm family, vector swizzle/blend/sqrt,
  partial FloatMath); engine code beyond the kernel will exercise them.
- Loading GAME.CGO / level data beyond KERNEL.CGO is unproven on iOS.
- The renderer abstraction seams are desktop-GL shaped; design the Metal
  seam in a spike before wiring broadly.

**Done condition**
R1 is checkpointed PASS and docs/13-current-state.md says so. Write no
BOT6 handoff — instead leave a short "what's next" section (physical
device proof, App Store policy, Jak 2/3 as explicit non-goals) in
13-current-state.md. Then stop.

Start with sub-gate S2.0 in docs/BOT5_HANDOFF.md. Begin now.
