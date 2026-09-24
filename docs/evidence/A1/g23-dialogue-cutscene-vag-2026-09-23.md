# G2.3 dialogue: the cutscene VAG channel plays on iOS now - 2026-09-23

Gate item: the cutscene half of G2.3's dialogue.  The voicebox half landed earlier today; this is the other
channel, and landing it turned up two bugs that had to be fixed before it could be trusted.

## The gap

`ja-play-spooled-anim` streams a cutscene's audio with `str-play-async`, whose consumer is the PLAY-STR RPC
(`stream.cpp` `RPC_PLAY`).  On iOS that channel was only **clock-emulated** in `game/sce/sif_ee.cpp` -
`g_ottsel_stream_clock.play(...)` plus an `OTTSEL STREAM CLOCK: play ... name=` line - so a cutscene's timeline
advanced and did not abort, but no audio played.  The desktop handler resolves the command's name (a `$`-prefixed
name is already a VAG name, anything else goes through `ISONameFromAnimationName`) and streams the VAG; the iOS
branch did neither.

## What landed

The iOS PLAY branch now resolves the same 8-character name and hands it to the shell's VAG player, so both
dialogue channels share one implementation.

## Two bugs found and fixed on the way

1. **Stack smash.**  `RPC_Play_Cmd_Jak1::name` is `char[48]`, and my first cut copied `sizeof(command.name)` into
   a 17-byte local.  The canary caught it: `__stack_chk_fail` -> SIGABRT inside `sceSifCallRpc`, reported as
   `~/Library/Logs/DiagnosticReports/OttselShell-2026-09-23-100557.ips` on the GOAL thread.  The copy buffer is
   now sized from the field.
2. **Use-after-free in the sample buffer.**  The shell player kept only the last four samples alive, on the
   assumption that a voice ends quickly.  A cutscene line does not: `SAISA` is 2.36 MB (~11 s at 48 kHz) and
   outlived four later plays, so its buffer was freed while the decoder was still reading it - a 38,728-byte fault
   log naming `snd::Voice::DecodeSamples` (called from `snd::Voice::Run`).  Every buffer handed to the engine now
   stays alive, keyed by name so a repeated line reuses its buffer instead of allocating a second copy.

## Measured

The exact five-play sequence that faulted before now runs clean:

    VAG dialogue name='NDINTRO ' bytes=419696 started=1     (ndi-intro)
    VAG dialogue name='LOINTRO ' bytes=183040 started=1     (logo-intro)
    VAG dialogue name='SAISA   ' bytes=2357968 started=1    (sage-intro-sequence-a)
    VAG dialogue name='SAGEVB38' bytes=153632 started=1     (a training-level hint)
    VAG dialogue name='ASSTVB40' bytes=163296 started=1     (a training-level hint)
    scene-level='training'  346 SIGNED MODULE ENTER = 346 RETURNED  ottsel-fault.log 0 bytes, app alive

Before the keep-alive fix the same sequence produced the 38,728-byte `DecodeSamples` fault; after it the fault log
is empty and the route still reaches Training.

## Boundary

Proven: cutscene narration resolves and starts, the voicebox path is unaffected, and neither the stack smash nor
the decoder fault recurs.  Not proven: a human listening check; and every line shares one engine voice, so a new
line replaces the previous - fine for dialogue, but it would need per-voice handling if a cutscene ever overlaps
music and speech.
+
## Stop handling

The stream RPC's stop (`result 1`) ends a spooled line, and the log shows five stops against three plays - so
ignoring it would leave a line playing over whatever comes next, which is exactly what skipping a cutscene does.
`snd_StopVAGProbeShared` (a hard `Voice::Stop`, added to the sound shim) is now called from the iOS stop branch
through the shell, and the verified run shows **5 plays / 5 stops**, `scene-level='training'`, 346 = 346 and a
0-byte fault log.
