# I3/P1: the touch defaults are per device class and clear the tap guideline - 2026-09-22

Gate I3 (frontend/controls) with P1's reachability item.  Question: do the default touch regions give a
phone a usable target without changing the accepted iPad lane?  The previous document measured that the
shared table did not: regions are fractions of each axis, so on the iPhone 16 Pro's 874x402 surface the face
buttons came out 48x22 pt and the D-pad arms 44x20 pt.

**The same check showed the tablet was short too.**  On 1210x834 its D-pad arms were 60x42 pt and its top
bars 145-169x38 pt, against Apple's 44 pt tap guideline - so both class tables are sized here, not just the
phone's.

**Change.**  Two default tables (`kTouchDefaultsTablet`, `kTouchDefaultsPhone`) and the class comes from
`ottosel_ios_shell_is_phone()` (UIUserInterfaceIdiom, implemented in `metal_shell.mm`, declared in
`ios_boot.h`), not from the surface width.  The width test was a pixels-versus-points trap: the simulator's
CAMetalLayer reports 874x402 because its contentsScale is 1, while a device's layer reports points x
contentsScale, so `g_surf_w < 1000` would have called a real iPhone a tablet.  The idiom is also known
before any drawable exists, so the class defaults can be applied first and a persisted file can override
them.

**Geometry, checked before running** (script over both tables, each against its own measured surface):
every region inside the screen, no two overlapping, and no region under 44 pt in either axis.

```
phone  874x402: stick 166x92  camera 175x80  face 60x58 (x4)  dpad 48x48 (x4)  bars 114x46 (x3)
tablet 1210x834: stick 157x138 camera 194x83  face 67x46 (x4)  dpad 60x46 (x4)  bars 145-169x46 (x3)
```

**Measured at runtime**, one line per lane from the app's own log (once per surface size):

```
phone  OTTSEL TOUCH: class=phone  surface=874x402   min-region=48x46
iPad   OTTSEL TOUCH: class=tablet surface=1210x834  min-region=60x46
```

**The route still works on both classes with the new geometry.**  Phone, touch only: Start ->
`TITLE: start edge`, Cross -> `accept screen=27 index=0`, D-pad down, Cross through the empty-slot and
confirm screens -> `GAMEPLAY: enter village1` / `enter training` with `scene-level='training'`.  iPad: the
same, `GAMEPLAY: enter training`, 346 SIGNED MODULE ENTER = 346 RETURNED and a 0-byte `ottsel_fault.log`.
The editor round trip was re-run on both after the change (double-tap Start, drag, double-tap Start,
relaunch -> `loaded persistent layout ...touch-layout-phone.cfg` / `...tablet.cfg`), and both saved files
carry the new rows, so the new defaults are saveable.  Captures: `/tmp/ottsel-p1/phone-newdefaults-land.png`
and `/tmp/ottsel-p1/ipad-newdefaults.png`.

**Limits.**  The 874x402 figure is the simulator's surface; on a device the same fractions are the same
fraction of a 3x-larger surface, i.e. the same physical size, but that is reasoning from the code and not a
device measurement.  The phone's landscape safe-area insets were not measured, and the stick and L1 sit near
the left edge where the Dynamic Island is - the insets are the next P1 input.  An older phone with a
667x375 pt surface would compute 46x54 pt face buttons, i.e. just under the guideline in width, and needs
its own check when a device or that profile is available.  A fresh container also needs one extra Cross on
the YES/NO save dialog before the level starts - container state, not layout.  The iPad's test save was
moved to `/tmp/ottsel-p1/ipad-saves-kept/` so NEW GAME does not hit the overwrite dialog, and both
containers were left with no persisted layout file.
