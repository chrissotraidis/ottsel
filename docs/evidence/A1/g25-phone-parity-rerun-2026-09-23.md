# G2.5: the phone parity re-run on the current build, then the iPad re-check - 2026-09-23

Gate item: G2.5's re-run ("do the accepted route, the save/load sequence of G2.1 and the system checks hold on
the phone profile with the new layout? ... Sequential: stop the iPad lane first, then re-check shared
regressions on iPad").  The phone's earlier route evidence predates the labelled surface, the settings entry and
the per-class label fit, so this re-run is on the current build.

## Phone (Ottsel iPhone SE3, `class=phone surface=667x375`)

Driven entirely through the **touch path** (`ottsel-touch-*`, the same handler a finger takes), one launch:

    touch start -> OTTSEL TITLE: start edge
    touch cross -> accept screen=27 index=0        (NEW GAME)
    touch cross -> accept screen=18 index=0        (the save screen's first slot)
    touch dpad-left, touch cross ->
        edge screen=11 index=0                      (the overwrite dialog the slot raised)
        accept screen=11 index=0                    (the YES answer, second accept -> memcard-saving)
    memcards: bank1.bin b4e89c5f9e69 -> 2e7f1460ddc3   (bank0 and bank2 byte-identical)
    then GAMEPLAY: enter training                   (a title-screen save starts the game, as documented)

In-level, the **touch** stick moved the target: 30 `OTTSEL TARGET POS` samples with `pad-max=0.3424` and a
displacement of (36951.0, 31792.5).  Lane health: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte fault log.

## iPad re-check (primary lane, `class=tablet surface=1210x834`), same build, same steps

    touch-driven save: bank0.bin 01a8adfdb8ff -> 36d71248a01a   (bank1 and bank2 byte-identical)
    GAMEPLAY: enter training reached; touch stick pad-max=0.3424, displacement (37236.5, 32574.0)
    lane health: 346 = 346 modules, 0-byte fault log

The two writes landing on different banks of the same slot is the port's own rule (each save file is
double-buffered and a save writes the older bank), which the earlier rounds established; here it is the
same-slot alternation on two lanes.

## Harness note

The first phone attempt reported nothing because my script omitted the START press, so the menu wheel never
opened and the later touches were swallowed by the title - a harness defect, recorded so the sequence is not
misread as a lane problem.

Artifacts: `/tmp/ottsel-route-2026-09-23/phone-g25-rerun/` and `ipad-g25-recheck/` (title, in-level and post-stick
captures on each lane; captures are the portrait device frame while the surface is landscape).

## Boundary

Proven: on the current build the accepted route, the frontend save write and in-level touch control hold on
the phone class and, re-checked sequentially, on the tablet class.  Not claimed: audibility, lifecycle beyond
what earlier rounds measured, or physical devices; the settings surface and the labelled controls were verified
on the phone in the round that landed the per-class label fit.

