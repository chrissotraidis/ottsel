# G2.6: what an asset-free install actually shows - 2026-09-23

G2.6's first question: does a fresh asset-free install fail helpfully by naming the missing user-data
family?  Measured on the phone profile with its data absent (no `OttselUserData` in the container).

**The log half passes.**  `OTTSEL F1` reports:

    OTTSEL F1: no user pack at .../Documents/OttselUserData; using diagnostic bundle data
    OTTSEL F1: bundle data at <bundle>.app/iso_data is incomplete (missing: CGO, fr3, MUS, SBK, STR, VAG, VIS); import a user pack with scripts/import-ios-user-data.sh

so nothing dies with an uncaught `ghc::filesystem` error and every missing family is named - in the log.
The screen half does not pass: the capture is a full-frame grid of unresident tiles with some colour
blocks, and the boot then spins (921 `chunked animation not found name=ndi-intro` warnings, no
`title-wait-ready`).  Correction to this note's first wording: the loop is not "silent and names
nothing" - the log names the families; the user just cannot see them.

**Mechanism, read from the presenter.**  `presentRGBA:` is the single presenter for this lane (the shell's
`ottsel_metal_present`, and `ottsel_metal_gfx_game_frame()` is a stub returning 0, so the shell always
presents its own surface).  It composites the CPU base surface, then the game's scene, and it deliberately
*skips* the CPU base once the level's TFRAG and TIE meshes are both "ready"
(`ottsel_mobile_cpu_frame_should_draw`, metal_scene_policy.h) - a condition a data-less boot satisfies,
because the bundle's TIT/VI1 geometry loads even without a user pack.  That is why the shell's status
screen - the DATA line plus the log tail - is never painted.

**Three landed attempts, none yet visible, all measured on the same reproduction.**  (1) A gate drawing
the status screen when `!ottsel_ios_has_user_data()`.  (2) An in-pass status overlay
(`ottsel_metal_set_status_overlay`: the surface as one RGBA texture on a full-screen quad with a
half-intensity vertex colour, drawn right after the touch overlay); the same run logs
`OTTSEL STATUS OVERLAY: set 667x375 vertices=6`, so the upload and the quad are live.  (3) Keeping the CPU
base when the data is missing (the `cpu_base_wanted` extension above).  Each was built, installed and
captured at the same moment; the frame stayed byte-for-byte the same grid.

**The flat-colour probe separated one thing and is ambiguous about the rest.**  A trigger-gated flat green
fill of `g_rgba` just before the present turns the screen uniformly green and logs
`OTTSEL STATUS: surface=667x375 font-scale=3 flat-probe=1`.  So the status surface does reach the layer -
but both candidates upload `g_rgba`, so the colour names no presenter.

**The overlay mechanism is proven and the surface holds the status screen.**  A magenta-fill probe turns the
screen uniformly magenta, so the overlay draw rasterises, and `dump_surface_ppm()`
(`Library/Application Support/ottsel/shell/surface.ppm`, 667x375) holds the status screen itself.

**The question is now answered YES, and the defect was the shell's own font.**  The screen was unreadable
because `draw_char` read `font5x7.h` row-major while the table is column-major - five column bytes of seven
rows each - which transposed every glyph and read two bytes past each one.  With `kFontW` 5, `kFontH` 7 and
the loops swapped, the same dump reads "ottsel S2.0 - Metal / GPU path: Metal / DATA: import
OttselUserData in Files" plus the log tail, and the device capture shows the same legible lines.  A fresh
asset-free install therefore names the missing user-data family on screen (the yellow DATA line) as well as
in the log (the OTTSEL F1 list with all seven families), and the shell's whole text surface is legible for
the first time.  Cosmetic remainder: the log tail is dominated by repeated DIRECT/SPRITE FRAME lines.

**Lane handling recorded for re-runs.**  `simctl install` rotates the app's data container, so the imported
pack must be re-copied afterwards (contents-only: `cp -R src/. dest/`; `cp -R src dest` nests a level).
Reproduction: install into a container without `OttselUserData` and launch.

Not claimed: the asset-free install does not yet fail helpfully *to the user*; the log half is verified, the
screen half is not, and neither the reconstruction nor the allowlist half of this gate has been touched.
