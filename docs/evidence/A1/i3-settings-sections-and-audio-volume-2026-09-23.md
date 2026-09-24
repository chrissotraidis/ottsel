# I3: the settings sections, and a music-volume setting whose effect is measurable - 2026-09-23

Gate item: the completion plan's settings entry owns Gameplay, Controls, Video, Audio, Data & Saves and
Diagnostics.  This round gives the surface the section structure and fills the sections that have an entry
with real behaviour; the plan's own rule is "no decorative controls", so the rest wait for behaviour instead
of being drawn empty.

## Structure (src/shell/main.cpp)

A section list (CONTROLS, AUDIO, DATA & SAVES, DIAGNOSTICS, CLOSE) opens one section screen per section, and
each section screen holds its rows plus BACK.  D-pad up/down selects, Cross opens a section or changes a
value, left/right change a value, Circle goes back one level (or closes at the list), and the three dots close
the screen from anywhere.  Everything is driven by the same touch path a finger takes, and every finger is
consumed while the screen is up so the game cannot be driven behind it.

| section | entry | behaviour |
| --- | --- | --- |
| CONTROLS | SURFACE OPACITY | 0.25 steps on the overlay tint, written to the layout file |
| CONTROLS | SURFACE VISIBLE | AUTO / ALWAYS / HIDDEN, drives whether the surface is uploaded |
| CONTROLS | RESET LAYOUT | restores the device class defaults |
| AUDIO | MUSIC VOLUME | 10% steps through `snd_SetMasterVolume(16, 0x400 * v / 100)` - group 16 is the port's own music master (`989snd/player.cpp`: group 16 feeds the synth master) |
| DATA & SAVES | USER PACK | read-only: PRESENT / MISSING (`ottsel_ios_has_user_data()`) |
| DATA & SAVES | DATA ROOT | read-only: the writable root the shell imports and saves under |
| DIAGNOSTICS | LOG OVERLAY | ON keeps the shell log surface up over the game after this screen closes |

Gameplay and Video are absent on purpose: no shell-side setting with real behaviour exists for them yet.

## The music volume is measurable, and this lane can measure it

The persisted value is applied when the screen opens, whenever it changes, and once at startup (frame 5), so a
relaunch honours it.  Its effect is not inferred: the lane's own PCM dump (`OTTSEL_AUDIO_DUMP`) captures the
samples the audio callback hands to the stream and logs `peak=… rms=…` per second, and it moves with the
setting.  Two launches, same build, same window (seconds 1-39 of a 40 s dump):

    MUSIC VOLUME 0   -> second=1..39 all peak=0 rms=0
    MUSIC VOLUME 100 -> second=8  peak=27218 rms=4554, second=21 peak=16747 rms=3638, ... second=39 rms=1087

## Persistence and the touch-only drive

`settings-<class>.cfg` holds version, surface visibility, music volume and log overlay.  Driven by touch only:
`menu` opens the list, `dpad-down` selects AUDIO, `cross` enters it, `dpad-left` twice takes music
100 -> 80, `circle` backs out, DATA & SAVES shows `USER PACK PRESENT` and the data root, DIAGNOSTICS toggles
LOG OVERLAY to ON, `menu` closes.  The file then read `1 | 0 | 80 | 1`; after terminating and relaunching,
opening the screen reported `screen open level=0 visible=AUTO music=80 log=1`, so all three values survived a
fresh process.  Captures in `/tmp/ottsel-route-2026-09-23/settings-sections/`: `01-sections.png`,
`02-audio-selected.png`, `03-audio-rows.png`, `04-audio-90.png`, `08-audio-90-left.png`,
`10-data-rows.png` (USER PACK PRESENT + the path), `06-diag-on.png`, `07-log-overlay-after-close.png`,
`11-relaunch-sections.png`.  Lane health: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`.

One wart, recorded rather than hidden: the loader is version-gated and the previous file carried only two
fields, so the first launch after this change discarded the older choices once (defaults) before rewriting the
new four-field file.

## Boundary

Proven: the sectioned settings surface, four sections whose entries have behaviour, and a music-volume control
whose effect is measured in the lane's own PCM.  Still open: the Gameplay and Video sections, region labels and
art, controller handoff, accessibility labels, and audibility "heard" on a surface whose audio device opens.

