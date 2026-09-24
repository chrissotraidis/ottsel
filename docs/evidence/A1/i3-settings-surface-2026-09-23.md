# I3: the persistent three-dot settings entry, with real behaviour and persistence - 2026-09-23

Gate item: the completion plan's "persistent three-dot settings entry" for the I3 frontend, implemented under
its own rule - useful settings only, with working behaviour and persistence, no decorative controls.

## What landed (src/shell/main.cpp)

- A `Menu` touch region **appended after `R1`** so no existing region index - and therefore no saved layout -
  changes meaning; it is drawn as three small dots (quads) inside the region the hit-test already owns, in both
  the tablet and phone tables, and it has a touch trigger like every other region.
- `ShellSettings` with a per-class file beside the layout (`settings-tablet.cfg` / `settings-phone.cfg`,
  version + value), loaded when the writable directory and class are known and saved on every change.
- The settings screen is composed on the CPU into `g_rgba` - the surface the shell status screen already
  uses - and handed to the product pass through `ottssel_metal_set_status_overlay`, so no glyph geometry is
  needed in the overlay vertex path.  It draws a header, one row per entry with the value, a highlight band on
  the selected row, and two hint lines.
- `handle_settings_touch` runs before the layout editor and before the game's pad producer: the Menu region
  opens the screen, D-pad up/down move the selection, Cross or left/right change the value, Circle or Menu close
  it, and **every** finger is consumed while it is up so the game cannot be driven behind the screen.
- Three entries, each with behaviour that already existed to drive:
  **SURFACE OPACITY** (0.25 steps, writes the overlay tint and the layout file), **SURFACE VISIBLE**
  (AUTO/ALWAYS/HIDDEN, drives the overlay upload policy added here), **RESET LAYOUT** (restores the class
  defaults).  `AUTO` keeps the previous rule: a keyboard, pad or mouse event hides the surface.

## Verification (touch path only, one run plus one relaunch)

    touch menu      -> OTTSEL SETTINGS: screen open visible=AUTO opacity=1.00
    touch dpad-down -> (row 1 selected)
    touch cross     -> OTTSEL SETTINGS: saved visible=ALWAYS path=.../settings-tablet.cfg
                       OTTSEL SETTINGS: row=1 value=ALWAYS opacity=1.00
    touch menu      -> OTTSEL SETTINGS: screen closed row=1 visible=ALWAYS

File written: `settings-tablet.cfg` = `1` then `1` (version, visibility).  After terminating and relaunching,
opening the screen again reports `screen open visible=ALWAYS` and the capture shows the row, so the value
survives a fresh process.  Captures (/tmp/ottsel-route-2026-09-23/settings-surface/): `title-with-entry.png`,
`settings-open.png` (row 1 highlighted, `100%` / `AUTO` / `CROSS`), `settings-always.png` (row 2
highlighted, `ALWAYS`), `closed.png`, `relaunch-reopen.png`.  Captures are the portrait device frame while
the surface is landscape, so the screen reads rotated by x'=1-y, y'=x (the mapping recorded in the previous
round).  Lane health throughout: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`.

## Boundary

Proven: a persistent settings surface exists, is driven by the touch path, changes real behaviour and survives
a relaunch.  Still open in I3: the Video, Audio, Data & Saves and Diagnostics sections, region labels/art,
controller handoff and accessibility labels.  No audio, device or playability claim.

