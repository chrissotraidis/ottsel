# M1 macOS cold-start and lifecycle replay — 2026-08-21

## Verdict

**PARTIAL PASS.** This fresh replay strengthens the current macOS reference
but does not close the stable/playable gate.

## Fresh run

- One Windowed native `gk` runtime was launched through `launchctl submit` with
  `OTTSEL_AUDIO_OUTPUT_DEVICE='MacBook Air Speakers'`; no Simulator was
  booted.
- The current executable reached the title-wait route, accepted real keyboard
  input through overwrite confirmation, entered Village1, and remained alive
  through the bounded capture. The route produced the expected page-2 lookup
  records and `GAMEPLAY: enter village1` markers.
- Retained raw artifacts are `/tmp/ottsel-m1-current.stdout.log` and
  `/tmp/ottsel-m1-current.stderr.log`. SHA-256 values at capture were:
  `99cef6b801e996e85fbf386a589e6d3d3b11da02443f2018d5987ef577f3d62b` and
  `6949e9d8d27cceae44de908177ee7d878edd431eec28038f42ed0955a33566d2`.
- Audio output selected MacBook Air Speakers and retained nonzero mixed PCM
  windows, including `pcm-peak=2174`, `984`, `415`, `413`, and `140`. This is
  stream/PCM evidence only; no human-audible acceptance was performed.
- Visibility was toggled false, then true/frontmost through System Events while
  the process was alive. Before/after screenshots were retained at
  `/tmp/ottsel-m1-current-before-lifecycle.png` and
  `/tmp/ottsel-m1-current-after-lifecycle.png`; the process remained alive
  afterward and was stopped cleanly.
- A bounded fault scan over the retained stdout/stderr found no
  `OTTSEL CRASH`, assertion, signal, or Metal command-buffer marker.

## Remaining gate clauses

This does not prove human audibility, physical-controller acceptance, a long
controller-led soak, or complete neutral input behavior across a real
background/resume transition. macOS remains partial, and iPadOS remains
paused by the current handoff until those reference clauses are closed.

## 2026-08-22 — current-checkout macOS route and neutral movement increment

One fresh Windowed native `gk` was launched with audio enabled and retained
stdout/stderr at `/tmp/ottsel-m1-current3.stdout.log` and
`/tmp/ottsel-m1-current3.stderr.log`. It reached `title-wait-ready`, consumed
the documented desktop Start/Cross/Down×4/Cross button masks, and logged
`GAMEPLAY: enter village1` twice. The current `gk` SHA-256 is
`5ed65423602db7565ac3ec603f63582fe5455dfcd4d36a20a04a965553fc1533`.

Fresh route and movement captures are `/tmp/ottsel-m1-current3-route-correct.png`
(`c759a8f7ad4ff39249e952fb8f25723a3aedecdc95057e1dbec730e171b24590`),
`/tmp/ottsel-m1-current3-before-move.png`
(`a16844ae041ada81f1261849d2f7e5fd5dfb3ad16799abb6862c8c3415c02b4e`), and
`/tmp/ottsel-m1-current3-after-neutral.png`
(`f2c8a8648a94f7e92babfe4e050cd495ed71b948f4377cc7dc9d4c8e5caa8146`). The
left-stick hold was accepted for 180 reads and released to neutral. Audio
showed route peaks including 2101 and 2499; targeted crash/signal/panic/assert
scanning found no matches. This remains an M1 partial increment: human
audibility, physical-controller soak, longer stability, and complete lifecycle
proof remain open. The iPad output remains explicitly partial/non-playable.
