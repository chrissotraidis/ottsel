# R1 lookup replay and native mouse/keyboard controls — 2026-08-21

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity; native input follow-up |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; patch SHA-256 `846ccf40bcb01cbb9f4d3da54e2314bf7c95bf40db721f3d21cbc407a479863a`; latest signed executable SHA-256 `e4c4a7b5f468554d1e9be877e7758b7025ff8e6c3963a6832b54d47073493399` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal runtime; fresh retained validated pack |
| Focused proof | `goalc-test --gtest_filter='Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*'`: 20/20 passed; `scripts/build-ios.sh`: signed app and strict deep codesign passed |
| Live route | title-wait → Start → Cross → Down×4 → Cross; `GAMEPLAY: enter village1` reached; screenshot captured at `/tmp/ottsel-r1-current/post-route.png` |
| Fault scan | `ottsel-fault.log`: 0 bytes; no crash/assert/Metal-validation/unsupported/placeholder/bounds markers in the replay slice |
| Verdict | R1 OPEN; controls source change build-verified, not human playability-verified |

## R1 result

The post-Start page-2 lookup sequence begins `54,49,48,42,44,...` on iPad,
while the completed macOS oracle begins `4,53,4,18,15,30,0,28,3,...`.
Shared entries are resolved hits. The same source-side phase reports native
first `TEX0`/TBP in the iPad `0x2bc1`/`0x2b8d` family, versus macOS `TBP=0x24f2`.
This is a producer/page-directory/FR3/DGO ordering or allocation divergence;
it does not justify TBP remapping or camera, shader, or Metal-policy changes.

## Controls change

`src/shell/main.cpp` now accepts physical SDL scancodes as a fallback for
WASD, neutralizes on window focus loss, exposes native mouse motion as the
right stick with idle neutralization, maps left/right buttons to Cross/Circle,
and supports the desktop two-button forward gesture. The iPad build compiled
and signed with these changes. A live mouse/keyboard acceptance replay remains
open, as does the explicit blank/partially corrupted Simulator playability
warning.

The shared desktop `InputManager` now also clears keyboard/mouse active-action
lists on focus loss/minimize and when `clear_inputs()` is called. The focused
canonical patch is `patches/r1-input-focus-neutral.patch` (SHA-256
`90025c138ea2d2c8961b87ada35dc36186b1d4304ad45d1c7b5dafb71a7a20bf`); it
applies cleanly to the upstream index. The current maintained worktree has
additional user-owned input changes, so a direct working-tree check is
intentionally not used as a clean-tree proof. The desktop runtime target
compiled successfully after the change.

## Post-rebuild control regression replay

The mouse impulse fix was rebuilt into signed executable
`b42a9e4e9ebd8a71fb779fafdaff95ec4c9aada38c46e7851b1b3a9cd9efdb0d`.
The focused input suite passed 4/4, and the fresh installed-app replay again
completed title-wait → Start → Cross → Down×4 → Cross, reaching Village1
twice. Mouse relative input now neutralizes after each event-loop pass; focus
loss clears keyboard/mouse actions; WASD retains physical-scancode fallback;
and the two-button forward gesture is preserved across keyboard events.

Fresh artifacts: `/tmp/ottsel-r1-controls-post-route.png`
(`a8641fe88b02b98c57c869a965051c5d49a8dc65ef1a3a2dd23f2073de3a04d1`),
`/tmp/ottsel-r1-controls-runtime.log`, and
`/tmp/ottsel-r1-controls-fault.log` (0 bytes). The screenshot remains
severely corrupted/partial and audio still reports `pcm-peak=0`; this is not
playability evidence. The same fresh source-boundary trace recorded only
world `MSCAL=3` groups, with first TEX0 `0x2005a8459930abc1` / TBP `0x2bc1`
and later 32×32 TEX0 `0x2005a0455530ac8d` / TBP `0x2c8d`, so the R1
producer-phase divergence remains open.

## Post-accumulation rebuild

The native shell now accumulates multiple SDL relative-mouse events within one
event-loop frame before the existing neutral settle. This prevents the last
motion packet from overwriting earlier motion in the same pad-sample interval.
The rebuilt signed executable is
`e162c1d42c3a7ad8bb92d3d456d38c96303b2c2b651300cf04b83de95bfd3b4c`; strict
deep codesign passed and the focused input suite remained 4/4.

A fresh install/replay of the rebuilt app consumed Start, Cross, Down×4, and
Cross, reached `GAMEPLAY: enter village1` twice, and retained a zero-byte fault
log. The fresh screenshot is `/tmp/ottsel-controls-post-build.png` with SHA-256
`d79e1fab71b58b463df857f8288352914b9e26d375d7bfc36c57c8a32bae51af`. It is
still partial/corrupted and therefore not visual or playability acceptance.

## Native-input overlay follow-up

The shell now hides the diagnostic touch-region overlay when native keyboard or
mouse input is first observed, while retaining the overlay for touch-only
sessions. The rebuilt executable SHA-256 is
`50e6628a61a5124fd64cfd8b304edc0464aba9ef56f348e6d015897d5ef7124a` and
strict deep codesign passed.

Fresh iPad Simulator evidence recorded
`OTTSEL INPUT: native keyboard/mouse active; touch overlay hidden`, a zero-byte
fault log, and an actual Simulator screenshot at
`/tmp/ottsel-native-overlay-hidden-sim.png` (SHA-256
`3346dfba6d7d2a153654d76364e7e5c50984eeecaddead8e03ba5b470a980b8e`). The
colored diagnostic blocks are absent and textured village geometry is more
clearly visible. Large missing/rotated regions remain, so this is a composition
diagnostic improvement, not iPad playability acceptance.

The raw Simulator framebuffer is `1668x2420` portrait even though the signed
bundle declares landscape-only orientations. Rotating that captured artifact
90 degrees yields the expected landscape inspection view; it does not remove
the missing geometry. The rotated inspection copy is
`/tmp/ottsel-native-overlay-hidden-sim-rotated.png`. This is a capture-
orientation note, not evidence for changing SDL orientation policy. The same
runtime retained substantial native TFRAG/TIE geometry (`75960` TFRAG vertices
and `511138` TIE vertices), so the remaining black regions stay an open native
composition/layout problem rather than an empty-resource claim.

## Next experiment

Trace page-directory login order, FR3/DGO texture ordering, and the selected
default texture-page allocator on the first matching producer chain. Keep the
raw particle ID, AdGif TEX0, and native `first-tex0`/TBP values stamped to that
same chain. Do not alter TBP, camera, shader, or Metal policy first.

## Fresh exact signed iPad R1 replay — 2026-08-21

The current signed executable was rebuilt from the canonical R1 trace patch
and passed strict deep codesign. Executable SHA-256:
`47316cb3805ca05fd972a4e09f9b55c4e39678f22159de5cee69df4b34219aba`.
`patches/r1-texture-lookup-trace.patch` SHA-256:
`5dcae3fedd6ba955258aa85bbc8acc9fb4e422e5acc6732164105196727d29bb`.
The replay used one runtime (PID 19926) and the single booted iPad Pro 11-inch
(M4) Simulator. The validated user pack was imported by F1 into the fresh app
container; no ROM or user pack was added to the repository.

The exact input route was title-wait → Start → Cross → Down×4 → Cross. The
runtime reached `GAMEPLAY: enter village1` twice. The raw page-2 lookup order
after Start was `54,49,48,42,44`; the later Village1 sequence was
`24,25,10,41,30,34,9`. Representative raw particle-to-AdGif results from the
same capture were `0x00200400` → `0x2004cfe55530a518`, `0x00201200` →
`0x2004d0e59930a506`, `0x00200000` → `0x2004c1259930a6e1`, and `0x00200f00`
→ `0x2004c8e55530a5d2`. Resolved outputs retained TEX1 `0x120`, clamp
`0x1010001c0`, and alpha `0x44`.

The aligned native source boundary was chain 1643, VSYNC 1644, level
`village1`: 512 world sprites across 11 groups, with the first observed group
using TBP `0x25d2`, PSM 19, 32×32, and first TEX0 `0x2004c8e55530a5d2`. The
native Sprite3 consumer was live for group 0, index 4, using texture `0x2506`,
64×64, with CPU raster skipped for the native candidate.

This closes the current page-directory/lookup-resource mismatch hypothesis for
this route, but does not prove macOS phase parity for the later `0x25d2` group.
The fresh Simulator screenshot is `/tmp/ottsel-r1-exact-route.png` (SHA-256
`5b8d6820ee0e4fac8aa1b3f88694a96bda6f101198164b5ede1414045c5a466f`). It still
shows large missing regions and severe triangular/corrupted geometry. The
fault log is zero bytes. Audio callbacks and 48,000-frame mix windows were
observed, but every captured window reported `pcm-peak=0`, so audio audibility
is not proven. This remains source/resource and native-composition evidence,
not iPad playability acceptance. The next falsifiable step is a same-phase
macOS pairing for the `0x25d2` producer record before any camera, shader, TBP,
or Metal-policy change.

## Producer-object trace follow-up — 2026-08-21

The GOAL source trace was extended at `particle-setup-adgif` and rebuilt with a
full ARM64 `(mi)` regeneration of all 546 targets. The signed iPad executable
SHA-256 is `c044eed202c1a19a34696ef9cc78937d575ca1ade75058db830ba29cdec7c188`;
the regenerated `GAME.CGO` SHA-256 is
`dbda14a90d2af93e753cc015c6f25f20d18a15d8b0df250569edd3623f97b3dd`.
The canonical patch SHA-256 is
`64bfe8b23bca995a144cffe83b3a3820ddc27d6e83652bf838d4997bb6c8f51e`.

The fresh one-runtime route consumed Start, Cross, four Down edges, and the
final Cross, then entered Village1 twice. The new producer trace captured the
resolved object shape and generated TEX0 without rewriting either state. The
same route included page-2 examples:

* index `18`: object 64×64 PSM 19; TEX0 TBP `9478`, TW/TH `6/6`, TCC `1`;
* index `15`: object 32×32 PSM 19; TEX0 TBP `9682`, TW/TH `5/5`, TCC `1`;
* index `28`: object 32×32 PSM 19; TEX0 TBP `9509`, TW/TH `5/5`, TCC `1`;
* index `0`: object 64×64 PSM 19; TEX0 TBP `9953`, TW/TH `6/6`, TCC `1`.

The correctly armed raw MIPS2C hook then recorded repeated same-route pairs
`0x00201800 → 0x2004c6659930a6d1` and `0x00200a00 →
0x2004d2e59930a4d2`, retaining TEX1 `0x120`/`0x12c`, clamp
`0x1010001c0`, and alpha `0x44`. This confirms that the lookup-hit path now
exposes the post-login texture-object/TEX0 state needed for the next paired
macOS capture; it does not yet establish host/mobile phase parity.

The fresh screenshot is `/tmp/ottsel-r1-producer-object-route.png` (SHA-256
`2599e37d84743f4f92a5915a525e8cec8289951cd3c84dc6c39c697bd27ce389`). It
remains visibly partial/corrupted and is not playability evidence. The fault
log was zero bytes; audio transport remained alive but reported `pcm-peak=0`.
The next falsifiable step is to run the same producer-object trace on macOS at
the matching first 3D/world phase, then fix the GOAL-side producer/data-family
handoff if the object/TEX0 state diverges. No TBP remap, camera, shader, or
Metal-policy change is justified yet.

## Native WASD/mouse rebuild — 2026-08-21

`ShellPadInput::keyboard` now treats `SDL_SCANCODE_W/A/S/D` as the primary
movement path, with keycode fallback for compatibility. This keeps movement
stable across keyboard layouts while preserving the existing action-key
mapping. Mouse button changes now recompute the complete movement-stick state,
so releasing a mouse button cannot leave a stale forward direction or override
held WASD.

The signed rebuild produced executable SHA-256
`b4270359669d6dab50eff5f9513ce214944317c1da303d385646f015682ddb34`.
The focused native suite passed 20/20, including Sprite3, platform-input, and
keyboard-edge groups. This is compile/regression evidence only: a fresh human
mouse/keyboard playability acceptance run has not been completed, and the
current iPad Simulator frame remains partial/corrupted with silent PCM peaks.
The iPad playability gate therefore remains open.

## GOAL sprite-frame handoff and fresh same-route comparison — 2026-08-21

The canonical R1 trace now includes a bounded diagnostic at
`sprite-add-frame-data`, recording the framebuffer/TEX0 frame handoff and
camera scalar fields before the DMA packet is consumed. The full ARM64 `(mi)`
regeneration rebuilt all 546 targets, the signed iPad app passed strict
codesign, the focused native suite passed 20/20, and the canonical patch
reverse-check passed.

The fresh host replay and the fresh iPad replay both completed the exact
title-wait → Start → Cross → Down×4 → Cross route and reached Village1 twice.
The ordered page-2 lookup streams were:

```text
macOS: 4,53,4,18,15,30,0,28,3,41,24,35,31,36,9,10,25,34,27,8,54,49,48,42,44,7,2
iPad:  4,53,4,18,15,28,27,3,54,49,48,42,44,25,10,41,0,24,30,34,9
```

Shared page/index objects resolve to the same source-side TBP and shape on
both runs. Examples include index `18 → TBP 9478`, `28 → 9509`,
`54 → 9495`, `49 → 9517`, `42 → 9666`, `44 → 9586`, `25 → 9921`,
`10 → 9426`, `41 → 9417`, `0 → 9953`, and `24 → 9937`. The iPad source
boundary then begins `MSCAL=211` at `TBP=0x24d2`, TEX0
`0x2004d2e59930a4d2`, followed by `0x2525`; this is a producer-phase/order
selection difference, not evidence for remapping TBP or changing camera,
shader, or Metal policy.

Fresh iPad artifacts: screenshot
`/tmp/ottsel-r1-sprite-frame-discriminator.png` (SHA-256
`efee3e550e687e9dabaac2887257eba52a0a4469f134b7ea69ff4436c3047e0d`), the
runtime log in the installed app container, and a zero-byte fault log. The
screenshot still has a large blank region and severely triangular/corrupted
geometry; audio transport is alive but reports `pcm-peak=0`. This diagnostic
increment narrows R1 but does not close iPad playability or human controls
acceptance.

The next falsifiable slice is to align the first selected particle/spec and
Sprite3 DMA phase that produces iPad `0x24d2` against macOS's first 3D/world
phase. Preserve the shared-object match and do not compensate with a TBP,
camera, shader, or Metal-policy rewrite.

## Native CPU Sprite3 post-divide correction — 2026-08-21

The source-side comparison authorized one narrow native-composition fix. The
CPU `sprite_raster_vertex` path was multiplying the already perspective-scaled
screen coordinate by homogeneous `w`; the reference shader performs that
multiplication before the GPU perspective divide, so the CPU path must use the
post-divide coordinate. A red regression failed before the change (`expected
1.0`, observed `4.0` for a representative `w=4` case); after the correction,
the focused suite passed 21/21.

The signed rebuild executable SHA-256 is
`97c9c4e626eb7549ca4324487eb0aa567c58b4f6caad4c0f5457f0595e1eb5e9`.
The exact route again reached Village1 twice with a zero-byte fault log. The
fresh screenshot `/tmp/ottsel-r1-raster-fix.png` has SHA-256
`eba0a3894d0dac4326c979085072c068eb4b998e87f685c126006c6142e38a4e`, but
inspection still shows a large blank region and severe triangular corruption;
audio remains `pcm-peak=0`. The correction is retained as a verified narrow
contract fix, while iPad playability remains OPEN.

## Native TFRAG/TIE Jak 1 Y-space parity correction — 2026-08-21

The upstream Jak 1 `tfrag3.vert` reference applies
`transformed.y *= 512.0 / 448.0` before rasterization. The native Metal TIE
vertex shader had omitted that exact game-surface expansion. After the R1
source-boundary evidence established a native composition consumer, the
smallest corresponding Metal correction was added; no TBP remap, texture
selection, camera policy, or runtime-code-generation path was changed.

The signed iPad build completed with strict deep codesign. Its executable
SHA-256 is `e7a8d74c1a05afb48771ca0b90624c397e021afc04e25cbac02cb9234839e0f6`.
The focused `Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*` suite passed
21/21, the canonical R1 patch reverse-check passed, and exactly one iPad
Simulator remained booted. This is build/regression evidence only; a fresh
post-change route screenshot and human mouse/keyboard acceptance replay are
still required, and the last fresh iPad image remains severely corrupted with
silent PCM peaks. iPad playability is OPEN.

## Fresh native Y-space replay and material-coverage discriminator — 2026-08-21

The latest signed executable was installed into one iPad Pro 11-inch (M4)
Simulator. The host arrow-key attempt delivered Start/Cross but no SDL D-pad
events; the app's native writable file triggers then delivered four D-pad-down
presses and Cross through the same `ShellPadInput::keyboard` path. The fresh
fault log remained zero bytes. The screenshot
`/tmp/ottsel-y-scale-trigger-route.png` has SHA-256
`c955d2f9c4e7ab60be1b8cbdf25637eb6b7ca8ca9469f84dcb87d05456bd1801`.

The image is materially more coherent after the reference `512/448` Y-space
correction, but it still has large missing regions and is not an honestly
playable frame. Audio continued to report `pcm-peak=0`. This replay did not
produce a clean `GAMEPLAY: enter village1` marker, so it is not a completion
replay; it remains a composition diagnostic.

The loaded `village1.fr3` reports `tfrag-normal=(3,240,148180)`,
`tfrag-trans=(3,3,220)`, and `tfrag-dirt=(3,9,624)`, while the native consumer
currently builds only the normal TFRAG category (`75960` visible vertices and
`53304` triangles). This is the next falsifiable native-composition boundary:
add the proven TRANS/DIRT bucket families with their correct alpha/depth
ordering and compare a fresh image. Do not remap TBP or change the camera or
texture lookup path.

## Native TRANS/DIRT TFRAG coverage increment — 2026-08-21

The native TFRAG consumer now includes the loaded NORMAL, TRANS, and DIRT
families and selects Metal source-alpha blending plus depth-write behavior
from each record's source DrawMode bits. The signed build executable SHA-256
is `b4134cc63319fd2cbcd156be0a55b7a5fe63889316bfdf132d20a447687c9e20`.
The focused Sprite3/input/keyboard suite passed 21/21 and deep codesign
passed.

Fresh Village1 FR3 evidence changed from the prior normal-only boundary to
`TFRAG: ... trees=3 nodes=137/256 groups=706/837 batches=81 vertices=76264
triangles=53524`, with TFRAG time-of-day color storage increasing to `2168`
from `1024`. The fault log remained zero bytes. The fresh screenshot
`/tmp/ottsel-tfrag-coverage-live.png` has SHA-256
`5c91869e96d672cd543721477c15ba731989ffa55a8cd1568e77b22764424528`.

This proves the additional source families reach the native consumer, not
that they are visually correct. That capture was made before a native input
event and therefore includes the touch overlay; it is not a clean composition
comparison. The underlying scene still has missing regions, while
audio/playability remain open. The next experiment is a clean native-input
capture followed by attribution of any remaining artifacts to native material
state/order and remaining Direct/Sprite composition, with no TBP or camera
remap.

## Camera-dependent visibility snapshot invalidation — 2026-08-21

The exact fresh route was replayed with the signed executable SHA-256
`46349ecd296294bb830dd73bd36a61c3012989952369e4c827a508b7618fbdb7`.
It reached `GAMEPLAY: enter village1` twice. The native visibility consumer
rebuilt its TFRAG/TIE snapshots as the camera frustum changed, with fresh
snapshots ranging from `TFRAG triangles=12450` / `TIE triangles=37214` to
`TFRAG triangles=61192` / `TIE triangles=344500`. This confirms the previous
top-strip/black-region failure was stale camera-dependent visibility state.

The post-transition screenshot `/tmp/ottsel-cull-invalidation-route.png` has
SHA-256 `9f5641022df832e09a9e2a7a1681b7b6689ac7b9c5863cae91045ecff42f3c27`;
its landscape-normalized inspection shows a coherent Village1 scene without
the touch overlay. The raw iPad page-2 lookup tail remains
`24,25,10,41,30,34,9`, with shared objects resolving to expected TBPs
(`24→9937`, `25→9921`, `10→9426`, `41→9417`). The fault log is zero bytes;
audio remains `pcm-peak=0`.

This is a real native-composition improvement, not playability completion.
Player/HUD/Direct coverage, audio, lifecycle, human mouse/keyboard acceptance,
iPhone parity, and physical-device readiness remain open.

## Fresh signed native-input route — 2026-08-21

The signed executable `46349ecd296294bb830dd73bd36a61c3012989952369e4c827a508b7618fbdb7`
was installed into the single booted iPad Pro 11-inch (M4) Simulator. The
title-wait → Start → Cross → Down×4 → Cross route reached
`GAMEPLAY: enter village1` twice. The same run emitted eight bounded Sprite
source items (`world=512`) and uploaded one native textured Sprite3 candidate:
`texture=0x26d1`, `64x64`, source-over blend, with CPU raster skipped for that
candidate. The screenshot `/tmp/ottsel-fresh-controls-r1.png` has SHA-256
`246e587053a160d46dd062e56b352c08c93b486f5a5da74584a857c17ba7b508`.

The fresh image remains blank/partial with a small visible artifact, so it is
not playability proof. Audio still reports `pcm-peak=0`; no fault output was
observed. Native controls remain source-backed but human acceptance is still
open: physical W/A/S/D scancodes drive the left stick, mouse-relative motion
drives a one-frame right-stick impulse, left/right mouse buttons map to
Cross/Circle, focus loss neutralizes input, and native input hides the touch
overlay. The focused Sprite3/platform/keyboard suite passed 21/21 and strict
deep codesign passed.

## Scene depth-state falsification probe — 2026-08-21

A trigger-gated Metal diagnostic `ottsel-trace-metal-scene-no-depth` was added
and exercised on a fresh signed build (`8c96bdbe1542f74bee6cf944d512846924816ece1a3f7d7e126b2410cee41d82`).
The exact title-wait → Start → Cross → Down×4 → Cross route again reached
Village1 twice. With normal depth testing, the prior fresh frame was nearly
empty despite CPU projection reporting `1876/4097` sampled TIE vertices inside
both OpenGL and Metal clip space and Metal submitting large TFRAG/TIE meshes.

With only the diagnostic depth test disabled, the fresh landscape-normalized
frame `/tmp/ottsel-scene-no-depth-landscape.png` has SHA-256
`7e0c802cdf89c67daf512ba49064c611b04e2f392015ddb23868cc9629e2f184` and
contains a full Village1 scene. This falsifies “no geometry reaches Metal” and
localizes the next source-side investigation to the native depth convention
(compare/depth mapping/order). The image remains heavily corrupted and is not
playability proof; the normal product depth policy is unchanged. Fault output
was zero bytes and audio still reported `pcm-peak=0`.

## Native forward-Z depth correction — 2026-08-21

The depth probe isolated the native contract: the shader already remaps the
desktop OpenGL depth range into Metal's forward `[0,1]` range, so the normal
Metal pass now uses `LESS_EQUAL` with a depth clear of `1.0` rather than the
inconsistent `GEQUAL`/`0.0` state. The no-depth path remains trigger-gated.

The fresh signed build executable SHA-256 is
`75d8832486032639e0bc334f95ae88ff4ec4a30627d52d268defdca4c7b09e51`. The exact
route reached Village1 twice without a probe trigger. The normal-depth
screenshot `/tmp/ottsel-forward-depth-route-landscape.png` has SHA-256
`5844373b7145dfde018210a799b050415899d65b610320da00fa4809216dba9a` and now
contains the full native scene instead of the prior nearly empty frame. It is
still heavily corrupted and not playability proof.

The same run retained the R1 lookup tail `24,25,10,41,30,34,9`; shared native
TFRAG/TIE visibility submissions remained live. Fault output was zero bytes,
audio remained `pcm-peak=0`, and the Simulator blank/partial warning remains
explicit. Direct/Sprite/HUD composition, human mouse/keyboard acceptance,
lifecycle, iPhone parity, and physical-device readiness remain open.

## Native layer isolation and camera-layout falsification — 2026-08-21

Trigger-gated layer probes on the forward-Z build isolated the remaining
corruption to a contract shared by both native scene families: the no-TIE
frame `/tmp/ottsel-no-tie-landscape.png` (SHA-256
`eae214c826f36a7a04197a36b3d574193e5aa5d9397b48738b5f17bb00399758`) still
contains warped TFRAG geometry, while the no-TFRAG frame
`/tmp/ottsel-no-tfrag-landscape.png` (SHA-256
`5ff6fc710551acc48662eb0b7ba938e13312c72ca36794b58fa36d6e488a638d`) still
contains warped TIE geometry. This rules out a single material family as the
sole cause.

A source-backed repack of the camera matrix from row-backed OpenGL storage to
native shader columns was then falsified by a fresh exact route: the frame
`/tmp/ottsel-camera-layout-route-landscape.png` (SHA-256
`20d9d3364d8681c611c4668faf231bb5b33dd64530f31bf2baa4a57711334601`) showed
severe radial distortion. That experiment was reverted. The prior forward-Z
depth correction remains the product state; no camera policy rewrite is being
carried forward from this failed comparison.

## Restored clean route after falsified camera experiment — 2026-08-21

The camera repack was reverted and the signed app rebuilt as executable
`82991f20cb1a6ae7b30d1cb20f6147cce99ebf1ca5543d4044df40c9fb73457a`. A fresh
route with no isolation or camera probe reached Village1 twice. The normalized
screenshot `/tmp/ottsel-restored-forward-depth-route-landscape.png` has
SHA-256 `ddf1ea60f37eea802ee60c4c44b4faccb82e5cc0266d846015c7c5ae6093c63d`;
it confirms the forward-Z scene result but remains visibly corrupted and is
not playability proof.

The current post-transition page-2 lookup tail is
`8,30,25,10,41,24,34,9`, while the earlier completed macOS oracle contains a
different phase/order stream. These mobile lookups are resident hits; the
remaining R1 mismatch therefore stays upstream of TBP remapping and requires
same-phase producer/resource-family ordering correlation. The route reached
Village1 twice, fault output was zero bytes, and audio remained
`pcm-peak=0`.

## Valid post-Village1 product-walk ledger — 2026-08-21

The product-window, frame-aggregate, source-boundary, and bounded-record
triggers were armed only after the first fresh `GAMEPLAY: enter village1`
marker. The valid frame (`chain=2449`, `vsync=2450`) recorded five groups:

```text
world count=48 tbp=0x2506 tex0=0x2004d0e59930a506 psm=19 tw=6 th=6
world count=16 tbp=0 tex0=0
hud   count=48 tbp=0x2517 psm=20 tw=3 th=3
hud   count=48 tbp=0x252d psm=19 tw=4 th=4
hud   count=32 tbp=0x21fd psm=19 tw=4 th=4
```

The first mobile world group is the same decoded identity as the synchronized
desktop group-0 record: the raw TEX0, 64×64 shape, and RGBA hash
`0xc8679915dfac0e15` match. The mobile frame then has a zero-text placeholder
and HUD, but no 3D Sprite3 group; the completed macOS world phase continues
through the later `0x24f2` / 9458 family and many more world groups. This is a
producer phase/packet-window gap, not evidence for a TBP remap or texture
decode change.

The fresh diagnostic screenshot `/tmp/ottsel-product-window-village1-armed.png`
has SHA-256 `7a4e3c40309e63c2dcd4ae4a7e9c888265f706f4a1601ef194f1f0f9c7adc9d7`.
Fault output was zero bytes and audio remained `pcm-peak=0`; the frame is
diagnostic and not playability proof.
## 2026-08-21 — HUD phase contract and mouse action latch

The desktop reference path separates HUD from World2D: Jak 1 uploads a
0x500-byte `SpriteHudMatrixData` at the shared Sprite3 matrix address, then
MSCAL 109 uses `hud_matrix` and the selected default/user HVDF offset. The
native consumer previously recognized HUD records only for phase accounting;
it now captures this setup shape and applies the corresponding HUD transform
only to MSCAL 109 records. MSCAL 3 remains on the existing World2D path, and
no TBP, lookup, camera, shader, or Metal depth policy was changed.

Native mouse Cross/Circle presses now share the existing eight-pad-read latch
used by keyboard taps, fixing short click loss while preserving held buttons.
The signed rebuild executable is
`60d2d93f22ef427146f16c8a16b438584122dcc20fa89da1c59421b3afa3663a`; strict
codesign, the canonical patch reverse-check, and the focused 21/21 test suite
pass. A fresh visual replay and human WASD/mouse acceptance are still needed;
the current corrupted scene is not playability evidence.

## Fresh signed route and physical Simulator input — continuation

The rebuilt app was freshly installed and replayed through title-wait → Start →
Cross → Down×4 → Cross using the writable app trigger path. It reached
`GAMEPLAY: enter village1` twice. The post-route screenshot is
`/tmp/ottsel-continuation-route2.png` (SHA-256
`700d196499884210c81e4c094161c5a2f303e995b9e4ffe1bb9a4e24f7c5a7d4`), and
the fault log is `/tmp/ottsel-continuation-fault3.log` (0 bytes). The raw
post-transition lookup tail was `24,25,10,41,0,30,34,9`, all resident hits;
it remains different from the completed macOS phase/order oracle.

With Simulator Capture Keyboard enabled, actual window-delivered `w/a/s/d`
events reached the native seam and logged left-stick states `(127,0)`,
`(0,127)`, `(127,255)`, `(255,127)`, each followed by neutral `(127,127)`.
Captured pointer motion reached `source=mouse-motion`; left-click reached
`source=mouse-button` with Cross and pressure 255. The source path therefore
works for native keyboard and mouse delivery. Right-click acceptance remains
unproven because Simulator synthesized a touch/Cross event for that gesture.

The screenshot is still visibly distorted/rotated and audio remains
`pcm-peak=0`; this is not playability proof. HUD/Direct/3D composition,
input acceptance for right-click and held movement, lifecycle, iPhone parity,
and physical-device readiness remain open.

## Mixed-TEX0 World2D atlas upload — continuation

The first multi-texture attempt correctly exposed that the validated 48-sprite
World2D group is not single-texture: it contains three live TEX0 identities and
color-only placeholders. The product path now assembles those decoded live
textures into a transient 512×512 atlas and submits all 48 quads as one native
Metal triangle list. A stale-request guard was added after the prior fresh run
showed an incorrect 16-sprite zero-text placeholder upload.

Fresh signed executable SHA-256:
`4ab393d28e14ae48b23ff1d7b1e30304d731454d3e49f7740bfcf6851a7d1284`.
Fresh route evidence: `/tmp/ottsel-native-world-atlas-runtime.log` records
`native World2D atlas vertices=288 sprites=48 textures=3 atlas=512x512`; the
route reached Village1 twice. Screenshot
`/tmp/ottsel-native-world-atlas-route.png` has SHA-256
`b9510a2109ce3a5a0fc0b1678f9860354b5ec350ebe8b89df96ca6d44d895886`, and
`/tmp/ottsel-native-world-atlas-fault.log` is 0 bytes.

The visual frame remains a distorted partial scene without coherent player or
HUD composition, and audio remains `pcm-peak=0`; this is native-composition
progress, not playability proof. HUD/Direct/3D completion, audio/lifecycle,
iPhone parity, and physical-device readiness remain open.

## First normal-product World2D Metal upload — continuation

The signed executable was rebuilt as
`6937eb1c0cb37e83cc30dfdfcb2273063ed283a49fe359dd53ab607a5c8ef83d`, freshly
installed, and replayed through the required route. Without a Sprite3 Metal
trigger, the runtime accepted the validated World2D shape contract and logged
`product World2D group accepted count=48 psm=19 size=64x64`, followed by
`native group=0 index=0` using the live lookup TBP `0x2506`. This is a normal
product upload; no TBP remap or camera/depth/shader policy change was made.

Fresh evidence: screenshot `/tmp/ottsel-native-world-product-route.png`
(SHA-256 `ec65e31c8cad68e4695b2bb80511c974854c9ad07e14f5e2bbf3f51ce7d773dc`),
runtime log `/tmp/ottsel-native-world-product-runtime.log`, and fault log
`/tmp/ottsel-native-world-product-fault.log` (0 bytes). The route reached
Village1 twice and the lookup tail remained resident but phase-divergent.
The app window still shows only a distorted/partial ground-and-sky scene with
no coherent player/HUD composition, while audio remains `pcm-peak=0`; this
increment is not playability proof.

## 2026-08-21 — native HUD atlas composition and fresh signed replay

The presenter now keeps the validated World2D Metal batch persistent and
appends MSCAL 109 HUD batches, clearing only transient HUD batches after each
encoded present. The HUD consumer uses the existing 0x500-byte matrix,
default/user HVDF selection, post-divide clip conversion, live TEX0 decode,
and a transient 512×512 atlas. This source change did not remap TBP or alter
camera, shader, or depth policy.

Fresh signed executable SHA-256:
`291b28902ffa7c27d543ad728a91c9e1e171414e016400c158d008a5ce78e37f`.
After a fresh install and a fresh title-wait marker, the exact route
title-wait → Start → Cross → Down×4 → Cross reached `GAMEPLAY: enter village1`
twice. The runtime logged native HUD atlas batches of 48, 48, and 32 sprites
(repeated across frames), alongside the earlier native World2D atlas upload.
The final raw lookup tail was
`54,49,48,42,44,25,10,41,24,30,34,9`; every entry was a resident hit but the
sequence remains phase/order-divergent from the completed macOS oracle.

Fresh screenshot: `/tmp/ottsel-hud-route.png`, SHA-256
`02db39251b7f2c3987e097b4a8cafe726bdda634b7ef6d680e005ce83f102fad`.
Fresh runtime log: `/tmp/ottsel-hud-runtime.log`. Fresh fault log:
`/tmp/ottsel-hud-fault.log`, 0 bytes. Audio still reports `pcm-peak=0`.
The screenshot remains a visibly corrupted partial scene without coherent
Jak/player/HUD composition; this is not playability proof. Direct/3D/material,
audio/lifecycle, iPhone parity, and physical-device gates remain open.
## 2026-08-22 control correction and fresh signed replay

The native shell now keeps mouse buttons as Cross/Circle actions only; holding
both no longer injects an unintended forward left-stick direction. Native mouse
input requests SDL relative mode so camera motion is delivered as relative
events. The rebuilt signed executable is
`dec641e5fc776aaada46d67745da78710c166acc87fc2be19d52b61c2b543144`, and the
focused Sprite3/platform-input/keyboard suite passed 21/21.

The fresh install replayed title-wait → Start → Cross → Down×4 → Cross and
reached `GAMEPLAY: enter village1` twice. Fault output was 0 bytes. The fresh
Simulator screenshot `/tmp/ottsel-controls-fixed-route.png` has SHA-256
`81635093b4c750ef1e9c6d7e1380dac00980ca2d7aa8ebb4d88da381bf1e6cbc` and is
still partial/corrupted, not playability proof.

## 2026-08-22 native mouse fallback and exact lookup comparison

The shell now retains the last absolute SDL mouse position and derives a
position delta when a captured motion event reports zero `xrel/yrel`; lifecycle
neutralization clears that baseline. This preserves relative events while
covering Simulator pointer-capture events that otherwise leave the camera stick
neutral. The signed executable SHA-256 is
`2a8eac5049a0da1285d05b706cfd5c598485ed2ff785408aa0baa14c60d4ca45`, and the
focused Sprite3/platform-input/keyboard suite passed 21/21.

The fresh install replayed title-wait → Start → Cross → Down×4 → Cross and
reached `GAMEPLAY: enter village1` twice. Screenshot
`/tmp/ottsel-controls-route.png` has SHA-256
`da214f6c433f5b6e205845662476e71ed558731eb1b5c32224ee24475161606`; the
fault log was 0 bytes. Live Capture Keyboard input produced W/A/D stick values
`(127,0)`, `(0,127)`, `(255,127)` with neutral releases, and Space produced
Cross pressure 255. Pointer input reached the native `mouse-motion` and
`mouse-button` seam; the first captured motion was neutral, so human camera
movement acceptance remains open pending a non-neutral right-stick sample.

The raw post-Start lookup window in this iPad run was
`54,49,48,42,44,24,25,10,41,0,30,34`. That ordered list is not by itself a
stable iPad-only mismatch: `/tmp/ottsel-r1-particle-phase-runtime.log` from
the same source era also contains page-2 index `0` in the corresponding later
macOS route phase, while `/tmp/ottsel-r1-phase-tex0-runtime.log` omits it in
that later window. The phase timing differs between captures.

The decisive sampled source-side object does match. On both macOS and iPad,
page 2/index 0 resolves to a 64x64 PSM19 object and generated TEX0
`tbp=9953` (`0x26e1`), `tw=6`, `th=6`, `tcc=1`. R1 therefore does not have a
proven page-directory/lookup-resource divergence for this family. The next
trace is texture-object/data-family and native Sprite3 consumer state; no TBP
remap is authorized. The frame remains visibly corrupted and audio remains
`pcm-peak=0`, so this is R1 diagnostic evidence, not playability proof.

## 2026-08-22 — bounded native MSCAL=211 data-family ledger

The signed build was rebuilt after adding a trigger-gated ledger directly at
the native `MSCAL=211` Sprite3 consumer. The ledger records raw vector and
AdGif payload hashes, frame/matrix hashes, first vector, decoded texture
identity, and native first TBP; it does not alter the product upload or any
renderer policy. The focused Sprite3/platform-input/keyboard suite remained
21/21 and deep codesign passed. The executable SHA-256 is
`687456a2327ebcb566128d1679a5c150916e76d0e291f610c4bac9eb3255366f`.

Fresh replay of title-wait → Start → Cross → Down×4 → Cross on the single
booted iPad Pro 11-inch (M4) reached the Village1 markers. The first captured
native family was `TBP=0x2506`, `TEX0=0x2004d0e59930a506`, 64x64 PSM19, with
decoded texture hash `0xc8679915dfac0e15`; later 3D groups also retained the
known `0x24f2`/`0x2004d1e59930a4f2` family followed by `0x2525`. The first
family matches the completed macOS source-boundary TEX0, and the later family
matches the macOS Sprite3 phase ledger. Representative iPad payload ledgers
were:

`vector=0x8506753c3f55483b adgif=0x31ff971c7c91a3dd frame=0xae32e3f3687ba834 matrix=0x39c115c6e20e2b1c`

and, after the frame update,

`vector=0x4dfcb65b7a623c53 adgif=0x31ff971c7c91a3dd frame=0xdd85871ac539e0a5a matrix=0x39c115c6e20e2b1c`.

This further weakens a stable source lookup/page-directory/TBP explanation
for the captured family and moves the open R1 boundary to native Sprite3
composition/state consumption. The raw page-2 stream remains phase-sensitive
and resident-hit-only; the fresh screenshot
`/tmp/ottsel-r1-3d-family-hash-route2.png` (SHA-256
`6819f93bf50c2ab9561e8f4ff658e650150429a6d525ed024b1f7b2bc082655d`) is still
severely portrait/partial and not playable. Fault output was 0 bytes and
`pcm-peak=0`. No TBP remap, camera, shader, or culling change was made.
