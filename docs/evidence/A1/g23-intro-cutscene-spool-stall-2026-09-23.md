# G2.3/G2.6: the intro cutscene does not play - its art spool stalls on a locked buffer - 2026-09-23

Open question from the dialogue thread: does the intro cutscene play its intended sequence?  It does not, and the
reason is now visible and named.

## What renders

The cutscene's level loads and draws.  The lane logs `GAMEPLAY: enter title -> village1 -> misty -> village1 ->
training`, and a capture every 0.45 s through the route shows the title, the main-menu wheel over the village
backdrop, and then - immediately after New Game - a close-up of rock geometry with no camera framing, no actors
and no HUD (`/tmp/ottsel-intro/i32.png`).  So the *level* is there; the cutscene's own sequence is not.

## Why: the spool buffer is locked by another owner

`ja-play-spooled-anim` streams the cutscene's animation through the art spool and waits for each part's file
status to become `active`.  The port's own bounded `STALL-ART` trace shows it never does:

    STALL-ART sage-intro-sequence-a 0 fs=#f,locked b0=#f/-1/inactive/lk=#f/own=#f
                                     b1=sage-intro-sequence-a/0/locked/lk=#f/own=sequenceA-village1
                                     r0=sage-intro-sequence-a/0/-20.0000 r1=sidekick-human-intro-sequence-b/0/-1.0000
    STALL-ART sage-intro-sequence-a 1 fs=locked,#f b0=sage-intro-sequence-a/1/locked/own=sequenceA-village1

The buffer holding the cutscene's part is `locked` with owner **`sequenceA-village1`** - the village1 sequence
the title screen runs - so the intro cutscene's part never activates, the wait loop spins, and the sequence
aborts.  That also explains the audio: `ja-play-spooled-anim` calls `str-play-stop` on its way out, which is why
the cutscene's lines are played and stopped in the same second while the training hints - no spool - play in full.

The port already has a spool recovery (`OTTSEL SPOOL RECOVER`, added for a permanently locked buffer), and it did
**not** fire here: its condition evicts a partner buffer whose status is `active`, and this one is `locked`.

## Follow-up: my "freed process" reading was wrong, and the PID is already zeroed

`handle->process` (`gkernel-h.gc:369`) dereferences the handle's process pointer and returns the process **only if**
the handle's PID equals the process's PID - the design's own stale-handle check.  I read the port's `owner-alive`
trace as a freed process whose PID still matched, and that is **wrong**: `deactivate` already ends with
`(set! (-> this pid) 0)` (`gkernel.gc:2012`), so a deactivated process can never match a live handle's PID.  The
trace still shows a dangling object, so the owner is not a deactivated process at all.

That leaves two candidates, and one bounded measurement separates them: either the owner is *alive* but its object
is unreadable (a corrupt type pointer), or the *handle's own* PID is 0, which would make `0 == 0` pass against a
zeroed process.  Printing `(-> b load-file-owner pid)`, `(-> (-> b load-file-owner process) pid)` and that
object's `status` for the stuck buffer names it in one run.

The buffer's other half is unchanged: it sits `'locked` holding *our* part while its owner field still names the
other sequence, so it never promotes to `'active` for us and nothing releases it.

## Boundary

Proven: the cutscene's level renders; its sequence does not; the spool part never reaches `active`; the owner handle
resolves to a dangling object while a deactivated process would have PID 0.  Retracted: the "freed process whose
PID still matched" reading.  Not proven: which of the two candidates it is, the fix, or whether every cutscene is
affected.
