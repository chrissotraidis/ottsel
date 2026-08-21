# M1 supplied Simulator audio/teardown crash — 2026-08-21

Status: OPEN evidence for AU1 audio stability and M1 lifecycle stability. This
incident is not evidence about the R1 Sprite3 producer/resource phase.

Source: `/Users/chrissotraidis/.codex/attachments/f99b62a9-029e-4d86-83c5-1d9fc182e4ce/pasted-text.txt`

## Incident

- Incident: `BE5ADBFF-F8D1-4615-97B3-E1E8D1DF740B`
- Process: `OttselShell [66105]`
- Time: `2026-08-21 03:19:28 -0500`
- Exception: `EXC_CRASH (SIGABRT)`
- Crashed thread: `Thread 6 Crashed:: SDLAudioP15`

The crashed thread aborts while running `AudioQueueThreadEntry`, through SDL's
audio thread entry points. The main thread is concurrently destroying the SDL
window and UIKit view/controller state (`SDL_DestroyWindow` /
`UIKit_DestroyWindow`, orientation queries, and root-view-controller teardown).
The report therefore establishes an audio-thread plus window-teardown lifecycle
failure boundary. It does not establish the deeper CoreAudio exception cause.

## Reconciliation

This is distinct from the supplied GOAL link-version assertion
(`F2004949-CDA2-4C31-9544-117378B11FBA`) and the earlier supplied audio abort
(`BFC94005-4B2F-4720-B685-FC2FAE80EEBA`). All remain separate M1/AU1 evidence.

The Simulator was blank and non-audible, so no visual or sound pass claim is
made. R1 remains at the producer/phase-ownership gate; this report does not
justify changing Sprite3 resource mapping, Metal composition, or the signed
native execution boundary.

Next lifecycle/audio work must reproduce shutdown with audio enabled and prove
that the SDL audio thread is stopped and joined before UIKit window teardown.
