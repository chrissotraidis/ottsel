# M1 macOS keyboard edge — canonical title menu

Date: 2026-08-18

## Fault

The macOS title accepted no short Computer Use keyboard tap even though SDL
logged both key events. `GLDisplay::render` polls keyboard state before it
drains SDL events. A brief down/up pair can therefore be fully queued after a
poll and fully released before the next one, never reaching `scePadRead`.

## Fix

`KeyboardDevice::process_event` now activates a bound key-down immediately and
keeps an event-only tap active for eight subsequent keyboard polls (about 133
ms at 60 Hz). This preserves ordinary held-key polling/release while ensuring
the independent EE thread sees at least one pad sample. `scePadRead` now emits
transition-only host input traces under `OTTSEL_TRACE_INPUT=1`, so the proof is
at the actual consumer rather than merely at SDL.

## Regression and live replay

Focused tests passed after rebuilding `gk`:

```text
KeyboardEventEdge.DeliversBriefCrossPressToPadState
PlatformInput.CarriesCanonicalButtonsPressureAndNeutralState
```

A fresh Windowed macOS app launch with `-boot -fakeiso -nosound` reached
`target-title-wait`. A Computer Use Space tap produced the following exact
consumer transition:

```text
SDL key event type=768 key=32 scancode=44
pad0 sample buttons=0x4000 left=(127, 127) right=(127, 127) cross-pressure=255
pad0 sample buttons=0x0 left=(127, 127) right=(127, 127) cross-pressure=0
```

Return then produced START and the game accepted its edge:

```text
pad0 sample buttons=0x8 left=(127, 127) right=(127, 127) cross-pressure=0
OTTSEL TITLE: start edge in title-wait abs=8 rel=8 progress=#f
```

The visible result was the canonical title menu with **New Game**, **Load
Game**, **Options**, **Secrets**, **Quit Game**, and **Back**. This proves the
keyboard title path, not physical-controller or mouse acceptance; those remain
separate P0 checks.
