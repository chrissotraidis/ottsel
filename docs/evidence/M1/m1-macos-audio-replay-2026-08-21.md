# M1 macOS audio replay — 2026-08-21

## Gate

Fresh macOS stability and playback-path observation, kept separate from mobile
playability and human-audible acceptance.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Runtime: `out/jak-project/build/h1/game/gk`, native arm64, `-boot -fakeiso`.
- Log: `out/jak-project/log/jak1.2026-08-20T20-17-00.log`.
- One Windowed macOS runtime; no Simulator concurrent.

## Live proof

The run stayed alive through a bounded window, reached Village1, and logged
SDL output callback activity after 3,072 frames. Real VAG playback streams
opened and advanced:

```text
OTTSEL AUDIO: output callback observed after 3072 frames
OTTSEL VAG CLOCK: id=65545 fd=open nosound=false selected=real
OTTSEL VAG CLOCK: id=65545 pos=4128 fake=0 real=1
Displaying level village1 [display-self]
OTTSEL VAG CLOCK: id=65659 fd=open nosound=false selected=real
OTTSEL VAG CLOCK: id=65659 pos=4104 fake=0 real=1
```

No runtime crash/fault/signal marker was found in the retained log. The
Sprite3 trigger was consumed during title before the world phase and captured
three zero-group frames, so this run does not add a same-route macOS producer
comparison.

## Verdict

OPEN. macOS audio is demonstrably initialized and producing real stream/PCM
activity, but human-audible speaker acceptance and route/interruption recovery
remain unverified. The mobile R1 producer comparison also remains open; the
next run must arm the macOS Sprite3 trigger at the Village1 boundary rather
than at process start. No mobile or full-playability claim follows from this
run.
