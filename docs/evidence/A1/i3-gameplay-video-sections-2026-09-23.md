# I3: the Gameplay and Video settings sections, with behaviour that is measured - 2026-09-23

Gate item: the completion plan's settings entry "owns Gameplay, Controls, Video, Audio, Data & Saves and
Diagnostics", and only Gameplay and Video were still absent ("no shell-side setting with real behaviour").

## What landed (src/shell/main.cpp)

- **GAMEPLAY / CAMERA SENSITIVITY** (50..200%, 25% steps): scales the touch camera region's drag gain.
- **GAMEPLAY / INVERT CAMERA Y**: flips the region's vertical drag.  Both are the shell's own producer, so
  they are the shell's to offer; the defaults (100%, not inverted) reproduce the previous behaviour exactly.
- **VIDEO / RENDER SCALE** (100 / 75 / 50%): the shell owns the CAMetalLayer, so the drawable the game and
  every native draw render into is `bounds * contentsScale * scale / 100`; the layer scales it back up.
- `load_settings` is now tolerant: a field the file does not carry keeps its default, so a file written
  before a field existed loads instead of being discarded (the previous loader rejected a short file).

## A correction on record

The first cut of VIDEO was **brightness + contrast**, applied as a 256-entry tone table on the frame the shell
scales.  It persisted and logged correctly but measured as a **no-op on screen**: the tone lands on the
shell's CPU buffer, while the visible frame is drawn natively by the game's Metal path.  An A/B/A capture set
at the settled title read band-mean 56.48 / 56.60 / 56.21 for 100% / 50% / 150% - no effect.  It was removed
and replaced by render scale, which changes the drawable the game actually renders into.

## Verification (measured, both classes)

    camera sensitivity (touch camera hold, the game's own pad sample):
      iPad   sens 50%  -> right=(147,117)      sens 200% -> right=(208,87)
      iPad   sens 200% + INVERT ON -> right=(208,167)   (righty flips 87 -> 167)
      phone  sens 50%  -> right=(147,117)      sens 50% + INVERT ON -> right=(147,137)
    render scale (the surface the shell drives, from `OTTSEL TOUCH: class=... surface=`):
      iPad   class=tablet 1210x834 -> 907x625 (75%) -> 605x417 (50%)
      phone  class=phone   667x375 -> 500x281 (75%) -> 333x187 (50%)
    animation-free visual check (the static settings screen, bright-pixel fraction):
      100% -> 0.0234      50% -> 0.0544  (the text is drawn at a quarter of the pixels and upscaled)
    persistence (relaunch):
      iPad  boots at surface 605x417 with `screen open ... sens=200 invert=1 scale=50`; cfg `1 0 100 0 200 1 50`
      phone cfg `1 0 100 0 50 1 50`; the section list capture shows GAMEPLAY / CONTROLS / VIDEO / AUDIO /
      DATA & SAVES / DIAGNOSTICS / CLOSE on both

Lane health: iPad and phone each 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log` throughout.

## Boundary

Proven: the two missing sections exist, are driven by the touch path, change real behaviour that is measured
rather than inferred, and survive a relaunch.  Not proven: nothing device-side; a tone/colour control is
absent on purpose because the shell cannot reach the displayed pixels without a renderer post-process.  No
audio, device or playability claim.
