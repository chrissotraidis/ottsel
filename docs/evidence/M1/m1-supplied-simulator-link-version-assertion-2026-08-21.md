# M1 supplied Simulator link-version assertion — 2026-08-21

## Source

User-supplied translated crash report:
`/Users/chrissotraidis/.codex/attachments/264189c0-2e14-4bbe-b074-fd06e71d1997/pasted-text.txt`

Incident `F2004949-CDA2-4C31-9544-117378B11FBA`, Process `OttselShell [63063]`,
iPad Simulator, 2026-08-21 03:02:32 -0500.

## Finding

The report is an `EXC_CRASH (SIGABRT)` from the GOAL link path. The crashed
stack is:

`ottsel_ios_run_boot` → `jak1::link_begin` →
`link_control::jak1_jak2_begin` → `private_assert_failed` → `abort`.

The corresponding runtime log identifies the assertion as:

`OTTSEL LINK VERSION MISMATCH: object= major=0 minor=0 expected=1.0`

at `game/kernel/common/klink.cpp:81`. This is an empty or malformed object
link boundary, not a Metal, Sprite3, producer-table, or audio-rendering
failure.

Thread 13, `SDLAudioP15`, is parked in CoreFoundation's run loop through
`AudioQueueThreadEntry`; it is not the crashing thread. This incident is
therefore separate from the earlier supplied Simulator audio-abort incident
documented in `m1-supplied-simulator-audio-abort-2026-08-21.md`.

## Gate decision

This report does not reopen the signed-native/no-runtime-emit foundation and
does not justify changing the R1 producer table, bucket indexing, camera,
shader, Metal, or audio path. It does make the link/data boundary an explicit
stability blocker for shortcut or malformed-object replays. The retained
title-wait route remains the valid R1 route; its fresh 13-group / 576-sprite
capture with zero rejected groups and zero boundary stops is unaffected.

The next product investigation remains the ordered producer/resource
divergence after the validated route. Link-version failures must be recorded
and triaged separately rather than used as renderer evidence.
