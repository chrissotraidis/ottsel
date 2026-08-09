# BOT5_PROMPT — Ottsel Goal Loop (Gate S2: first frame, Metal)

Paste this as the next bot's goal. It mirrors the proven S1 loop shape and
points at `docs/BOT5_HANDOFF.md` as the full spec.

---

/goal You are the next build-and-proof agent for the repository at
/Users/chrissotraidis/GitHub/ottsel. You are continuing a multi-session,
proof-gated project. Work autonomously until your goal is proven or you are
honestly blocked.

**The original goal (never lose sight of this)**
A **native iPadOS/iOS port of** ***Jak and Daxter: The Precursor Legacy***
on top of OpenGOAL (open-goal/jak-project, pinned at
641fb572e876750d8618434d9f7c1a531b43b366), running **ARM64 AOT with no
runtime instruction emission and no writable-executable memory**. No game
assets in git, ever. Host gates H1–H3 and Simulator gate S1 are already
PASS with evidence; do not re-litigate them.

**Your goal**
**Gate S2: first frame proof** — evidence of the first rendered frame from
Jak 1 game systems on the iPad Simulator (iPad Pro 11-inch M4, iOS 18.5),
or a clearly defined intermediate milestone approved in STATUS.md. A bare
clear-color window is NOT victory; if you use one as a stepping stone,
declare it as a sub-gate in STATUS and keep going. The durable product path
is **Metal** — iOS has no desktop OpenGL, and the ~45k-line OpenGL renderer
must NOT be ported as-is. Logs and screenshots go under docs/evidence/S2/.

**Read first, in order**
- docs/13-current-state.md — authoritative technical snapshot + reproduce commands
- docs/BOT5_HANDOFF.md — your full goal spec with the sub-gate plan
  S2.0–S2.2; execute those sub-gates **in order**
- docs/evidence/S1/s13-dispatcher-loop.md — the S1 proof and the runtime
  fixes (pc-prof registration + intern fallback scan) you are building on
- docs/05-roadmap.md — the S2 acceptance bar (P5) and phase ordering
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

**Loop rules (how you work)**
- **Document every meaningful step in the same turn it happens**: what you
  tried, exact commands, result, files changed, pass/fail, next action.
  Append to docs/00-loop-log.md; update docs/STATUS.md when a gate or
  sub-gate changes; evidence goes under docs/evidence/S2/.
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
- **Honest stopping.** If the same root cause blocks you three times with
  no new technical angle, write docs/reports/YYYY-MM-DD-stop-S2.md (what
  was attempted, evidence, options, recommendation) and stop. Do not paper
  over failures or drift into adjacent work (no touch UI, no audio polish,
  no icons, no marketing).

**Expected risk areas (from the S1 review)**
- 15 IR lowerings remain NYI (Asm family, vector swizzle/blend/sqrt,
  partial FloatMath); engine code beyond the kernel will exercise them.
- Loading GAME.CGO / level data beyond KERNEL.CGO is unproven on iOS.
- The renderer abstraction seams are desktop-GL shaped; design the Metal
  seam in a spike before wiring broadly.

When S2 passes: STATUS.md S2 PASS with date + evidence, patch verified
against a fresh pin worktree, docs/BOT6_HANDOFF.md written for the next
agent (S3 = touch MVP + lifecycle), then stop.

Start with sub-gate S2.0 in docs/BOT5_HANDOFF.md. Begin now.
