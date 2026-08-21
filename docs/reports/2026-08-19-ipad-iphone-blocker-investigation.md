# Ottsel iPad/iPhone blocker investigation — implementation decision

Date: 2026-08-19
Checkpoint inspected: `dc60af38433879ccf65ac30d0c16a5f155e9541e`
(`main` = `origin/main`)
Scope: read-only technical investigation; no build, runtime, patch regeneration,
asset import, signing change, or platform-pass claim was made.

## Feasibility verdict

The iPad and iPhone blockers are resolvable engineering work, not a demonstrated
Apple-platform prohibition. Signed native/no-emit execution, real New Game
bootstrap, canonical pad-state transport, and a partial full-screen Metal scene
are already proven on the iPad Simulator. The shortest credible next route is
to continue the native-Metal renderer, beginning with one attributed Jak 1
Direct font packet and its exact desktop state/order contract. The important
correction is that the captured 14-qword glyph packet is **not yet proven to be
an offscreen render-target packet**; the first implementation gate must measure
its actual desktop bucket, framebuffer, shader transform, and visibility path.
ANGLE remains a fallback experiment for renderer breadth, not the next change.
Physical-device signing, controller/audio-route acceptance, and the legal
user-data import flow are genuine later external/product gates.

## Evidence boundary

| Boundary | Verified evidence | Not established |
|---|---|---|
| Native execution | `docs/evidence/A1/`; signed Mach-O/no-runtime-executable-code path | Device signing or physical-device acceptance |
| macOS reference | `docs/evidence/M1/m1-retail-single-runtime-retest-2026-08-18.md` | Fresh physical-controller and audible route/interruption acceptance |
| iPad bootstrap | `docs/evidence/I1/i1-new-game-sequence-a-2026-08-18.md` | Visually complete title/menu/gameplay |
| Input transport | `docs/evidence/I1/i1-platform-input-shell-2026-08-18.md` | Visible/customizable touch UI or controller ownership |
| Partial Metal scene | `docs/evidence/I1/i1-fullscreen-composed-frame-2026-08-18.md` | Direct/Sprite and remaining bucket parity |

None of these observations is an iPad-playable, iPhone-parity, or device-ready
claim.

## Critical correction: identify the packet before designing its target

The captured packet fingerprint is source-proven as a Jak 1 font glyph:

- `out/jak-project/goal_src/jak1/engine/gfx/font-h.gc:232-274` defines DMA
  `qwc=0xe`, VIF `DIRECT 0xe`, and one packed GIF tag with `prim=0x5c` and
  `nreg=13`.
- Its records are ordered `A+D(TEX0)`, followed by four repetitions of
  `ST`, `RGBAQ`, `XYZF2`. Four vertices form two textured, alpha-blended strip
  triangles.
- `out/jak-project/game/mips2c/jak1_functions/draw_string.cpp:933-1047`
  emits that template, the glyph texture state, and its vertices.

The earlier inference that this packet must use a 128x128 offscreen target is
not established for Jak 1:

- `OpenGLRenderer::init_bucket_renderers_jak1` registers Sprite3 in bucket 66
  and plain `DirectRenderer("debug")` in bucket 67 at
  `out/jak-project/game/graphics/opengl_renderer/OpenGLRenderer.cpp:655-674`
  and `:867-873`.
- `ProgressRenderer`, whose `FRAME.fbp=126` behavior creates a 128x128 target,
  is registered on the Jak 2 path at `OpenGLRenderer.cpp:600-621`, not Jak 1.
- Base `DirectRenderer::handle_frame` is a no-op at
  `out/jak-project/game/graphics/opengl_renderer/DirectRenderer.cpp:877`.
- The failed CPU diagnostic's coordinate conversion at
  `src/shell/metal_gfx.mm:1160-1167` is not the desktop shader transform in
  `out/jak-project/game/graphics/opengl_renderer/shaders/direct_basic_textured.vert:20-27`.

Consequently, `SCISSOR 0..127` and decoded positions near `(2430,4040)` do not
by themselves prove an offscreen target. The next experiment must fingerprint
the glyph on macOS and record renderer/bucket, `FRAME.fbp`, bound FBO,
`m_offscreen_mode`, viewport, scissor, XY offset, transformed bounds, texture
lookup, draw, and the later draw that makes it visible. Only those observations
select normal Direct versus target-backed Direct.

## Source and function map

| Concern | Exact checkout reference | Why it matters |
|---|---|---|
| Jak 1 bucket order | `out/jak-project/game/graphics/opengl_renderer/OpenGLRenderer.cpp:655-884` | Identifies Sprite3/Direct and final composition order |
| Direct state model | `out/jak-project/game/graphics/opengl_renderer/DirectRenderer.h:90-284` | Reference contract for GS state and pending vertices |
| Bucket reset/end flush | `DirectRenderer.cpp:93-168` | Defines state lifetime and mandatory final flush |
| VIF/GIF walk | `DirectRenderer.cpp:592-781` | Preserves VIF order, GIF `PRE`, descriptors, and records |
| A+D state dispatch | `DirectRenderer.cpp:783-875` | Applies GS state in packet order |
| Texture/vertex handlers | `DirectRenderer.cpp:971-1078` | TEX state and per-vertex snapshots |
| Test/blend/primitive handlers | `DirectRenderer.cpp:1080-1199` | State changes that must flush pending geometry |
| Primitive assembly | `DirectRenderer.cpp:1225-1430` | Strip/ADC and triangle behavior |
| Vertex conversion | `DirectRenderer.cpp:1481-1510` | GS-to-shader coordinate reference |
| Final draw semantics | `DirectRenderer.cpp:230-590` | Blend, test, depth, mask, texture, sampler, and draw order |
| Direct shaders | `shaders/direct_basic.vert`, `direct_basic_textured.vert`, `direct_basic.frag`, `direct_basic_textured.frag` | Position, texture, alpha, fog, and color behavior |
| Genuine offscreen example | `out/jak-project/game/graphics/opengl_renderer/ProgressRenderer.{h,cpp}` | Pattern to reuse only if attribution proves target aliasing |
| Mobile Direct decoder | `src/shell/metal_gfx.mm:1546-1783` | Useful VIF/GIF and state parsing seed |
| Mobile Sprite3 decoder | `src/shell/metal_gfx.mm:1785-1985` | Useful record expansion; replace CPU consumer |
| Diagnostic CPU path | `src/shell/metal_gfx.mm` (`OttselRaster`, `OttselTexCache`, `g_frame`) | Fixture oracle only; not a product renderer |
| Live Metal ownership | `src/shell/metal_shell.h:17-87`; `src/shell/metal_shell.mm:136-369` | Device, queue, layer, depth, pipeline, and one-present architecture |
| Shared pad state | `out/jak-project/game/sce/ottsel_platform_input.{h,cpp}`; `libpad.cpp:92-137` | Existing input consumer seam |
| Mobile event bridge | `src/shell/main.cpp:94-214,357-452` | Keyboard/touch mappings and lifecycle neutral; controller ownership missing |
| Mobile IOP/audio gap | `out/jak-project/game/ios_stubs.cpp:1-4,88-108,174-179`; `src/shell/ios_boot.cpp:1445-1450` | Sound/IOP are intentionally inert today |
| iOS packaging inputs | `scripts/build-ios.sh:224-273` | Local bundle copy exists; user-data import and audio families are absent |
| Signed-native constraint | `docs/10-code-packaging-and-signing.md:70-125` | Binding architecture boundary |
| ROM-safe constraint | `docs/07-asset-safety.md` | Protected data cannot enter source, fixtures, or evidence |

## Renderer decision

Continue native Metal for the Direct/title proof.

The checkout already has an iOS `CAMetalLayer`, Metal device/queue, render
pipelines, drawable/depth targets, texture/sampler creation, indexed draws, and
a complete `GfxRendererModule` callback seam. The iOS build compiles the local
Metal files and connected TFRAG data path. A small Direct consumer can therefore
reuse live platform ownership and add only the state/draw slice proven by the
fixture.

Do not pivot the current gate to ANGLE/GLES-on-Metal. No ANGLE/EGL dependency,
surface/context path, CMake target, or package is present. The desktop renderer
requests OpenGL 4.1 on Apple/4.3 elsewhere; its bundled GLAD is desktop GL 4.3,
all 92 renderer shaders declare `#version 410 core`, and the wider renderer
uses desktop-only families such as 1D textures, `glGetTexImage`, indexed color
masks, multisample texture creation, polygon mode, and primitive-restart/multi-
draw calls. ANGLE would require dependency, build, EGL lifecycle, shader, and GL
compatibility work before it could test the same packet.

ANGLE is not rejected forever. If native Metal proves this Direct slice but
remaining Merc/Sprite/transparent/world-effect work grows unpredictably, run a
bounded ANGLE spike: pin one dependency, create one iOS surface, compile only
the Direct closure, replay the same ROM-safe fixture, and count every required
compatibility shim. Reconsider only if it reaches the same target/image/counter
bars without renderer-wide shader or API changes.

## Minimum Direct contract

Preserve the following values and their ordering, even if the first fixture
does not exercise every field:

- Target: full `FRAME` (`FBP`, `FBW`, `PSM`, `FBMSK`) and any target-to-texture
  alias identity.
- Clip/position: `SCISSOR` and `XYOFFSET`.
- Primitive: kind, `IIP`, `TME`, `FGE`, `ABE`, `AA1`, `FST`, `CTXT`, `FIX`.
- Texture: full `TEX0`, `TEX1`, `CLAMP`, `TEXA`, upload identity, and CLUT.
- Tests/writes: `TEST`, `ZBUF`, `ZMSK`, alpha/date/depth modes, color mask.
- Blend: `ALPHA` A/B/C/D/FIX and `PABE`.
- Vertex: STQ or UV, RGBAQ, XYZ/F, ADC.
- Sequence: VIF order; GIF EOP/PRE/NLOOP/NREG/descriptor order; flush before a
  state mutation; target store/switch; later sampling; desktop bucket order.

For the glyph, `PRE` applies PRIM before the thirteen records; `TEX0` is
applied before the four vertex triplets; each `XYZF2` snapshots a vertex; and
the state/bucket end flush encodes the draw. If attribution proves an offscreen
target, it must be stored before a later draw samples it. If it proves plain
Direct, no target abstraction belongs in this minimum gate.

## Reuse and retirement boundary

Retain:

- `DmaFollower` ingestion and the bounded VIF `DIRECT` walk.
- GIF PACKED/REGLIST parsing and A+D state capture.
- `OttselDrawState`/`OttselVertex` as an ordered intermediate representation,
  expanded to carry complete state snapshots and explicit flush boundaries.
- Texture page placement/un-swizzle and CLUT decode as upload/fixture oracles.
- Sprite3 record expansion, with Metal rather than `OttselRaster` as consumer.
- `OttselMetal` device, queue, layer sizing, texture/sampler/depth ownership,
  and single-present command-buffer model.

Retire from the product path after it supplies the bounded fixture:

- `OttselRaster`, `OttselTexCache`, `g_frame`, and `g_frame_pending`.
- CPU triangle/sprite/blend code, coordinate guesses, largest-texture selection,
  and periodic frame publication.
- The generic VU fallback and any proposal for a second generic VU interpreter.
- Silent unsupported-register/VIF behavior and persistent decoder state without
  desktop-equivalent bucket reset/flush semantics.

Resolve ADC behavior against the fixture: the mobile diagnostic currently
clears its strip, while desktop passes ADC as `advance=!adc` and preserves strip
history while suppressing that kick.

## Smallest proof

### Fixture

First attribute the live glyph on macOS. Then capture from the last reset/flush
before the glyph through the first draw that makes it visible. Commit only a
ROM-safe synthetic fixture: retain the open-source packet structure and state,
replace protected font texels/CLUT with a tiny generated texture, and record
expected state and image hashes.

Expected core counters for one unsplit glyph:

| Counter | Expected |
|---|---:|
| VIF `DIRECT` transfers | 1 |
| PACKED GIF tags | 1 |
| Packed records | 13 |
| Input vertices | 4 |
| Emitted triangles | 2 |
| Texture lookups/hits | 1 / 1 |
| Draw calls | normally 1 |
| Placeholder textures | 0 |
| Unsupported registers | 0 |
| Out-of-range reads | 0 |

The regression must fail before the fix because the current Metal product path
does not consume Direct into a reference-equivalent draw. It passes only when
the decoder/state trace matches desktop, the selected target has a stable
nonzero pixel count/hash, the final reference image has a stable nonzero region
within a stated tolerance, no CPU frame contributes, and validation/fault scans
are clean.

### One-Simulator live proof

Use one Windowed runtime and at most one booted Simulator; never run macOS `gk`
and the Simulator together. Stop macOS after the reference capture, build the
fresh iPad app, boot one iPad Simulator, replay the real title/menu path, and
record:

- commit/build identity, runtime PID, Simulator model/OS, and drawable size;
- the matching packet fingerprint and the fixture counters above;
- target ID/size, state-change and flush counts, texture hit, triangles/draws;
- a screenshot with a visible title/menu element composed with the existing
  scene, plus a same-phase macOS screenshot;
- `ottsel-fault.log`, crash/assert, Metal validation, placeholder, unsupported,
  and bounds-error scans.

Pass requires a repeatable visible result, matching state/counter contract, no
regression of TIE/TFRAG, and clean fault scans. A compiler pass, packet count,
nonzero texture, partial bucket, shell log, or first launch is not a pass.

## Dependency-ordered implementation plan

1. **Desktop packet attribution.** Instrument the exact glyph fingerprint and
   record bucket/class, `FRAME.fbp`, FBO/viewport, offscreen flag, scissor,
   XY offset, texture state/hit, shader-space bounds, flush/draw/triangle counts,
   and the first consuming/composition draw.
   **Exit:** the evidence unambiguously selects plain Direct or target-backed
   Direct. Otherwise stop; do not implement a guessed target model.

2. **ROM-safe red fixture.** Preserve the required state prefix/order, replace
   protected texels/CLUT, and make the current Metal path fail the image/trace
   assertion.
   **Exit:** desktop passes; current Metal fails for the expected missing
   consumer, with stable hashes/counters and a repository asset audit.

3. **Separate decode from render.** Emit ordered state, vertex, draw, and flush
   records; reject unsupported/out-of-bounds input in the fixture.
   **Exit:** Metal-side IR matches the desktop trace field-for-field before any
   draw implementation.

4. **Implement the selected native-Metal Direct slice.** Implement normal
   final-target Direct first unless Gate 1 proves target aliasing. Mirror only
   exercised texture, transform, blend/test/depth/write-mask, and ordering
   semantics.
   **Exit:** the fixture image/counters pass with no CPU raster contribution.

5. **Add target alias/composition only if proven.** Key Metal targets by the
   observed GS framebuffer identity and encode store/switch/sample lifetime.
   **Exit:** nonzero target and final composite match the desktop contract; a
   missing target consumer is localized to one observed draw.

6. **Run the one-iPad live gate.** Replay the fingerprinted title/menu packet
   and compare with the same-phase macOS frame.
   **Exit:** visible repeatable foreground plus existing scene, required
   counters, screenshot, and clean fault scan. This is Direct-slice proof, not
   iPad playability.

7. **Move Sprite3 and remaining renderer buckets to Metal.** Feed retained
   Sprite3 expansion to GPU buffers; then close material/bucket parity in
   screenshot-diff order: normal TIE semantics, transparent/dirt/ice TFRAG,
   Merc, remaining Direct/Sprite/effects.
   **Exit:** each bucket has a before-failing fixture, same-phase Mac/iPad image
   comparison, live route proof, and no fallback contribution.

8. **Harden input ownership and lifecycle.** Enumerate/open/retain SDL gamepads,
   handle add/remove/disconnect, route one controller to pad 0, and add a
   coordinated runtime/render/audio pause seam.
   **Exit:** active input reaches `scePadRead`; cancel, disconnect, editor/menu,
   background, and resume all return canonical neutral. Controller acceptance
   requires real hardware.

9. **Build the visible customizable touch UI.** Replace the invisible split
   bridge with a landscape overlay using the existing `PadState`; support
   movement/action/camera multitouch, safe areas, opacity/scale/position,
   tablet/phone layouts, persistence, and accessibility labels.
   **Exit:** a visible multitouch play sequence works, customization survives
   relaunch, and all cancellation/lifecycle paths neutralize.

10. **Create the ROM-safe data/save boundary, then mobile audio/streaming.**
    Import a versioned user-owned pack into durable app storage with manifest,
    hash, version, and free-space validation; prove save/reload. Replace boot
    shims with fixture-backed IOP/stream/audio behavior, initialize playback-only
    audio, and handle route/interruption/lifecycle.
    **Exit:** fresh no-data install imports legally supplied data, boots after
    relaunch, streams title-to-level, saves/reloads, produces nonzero PCM and
    audible correct output, recovers routes/interruption, and never requests
    microphone permission. Audible acceptance requires physical hardware.

11. **Close iPad playable, then iPhone parity.** Run the complete iPad definition
    below before one landscape iPhone Simulator pass with safe-area, layout,
    drawable, frame-time, and memory evidence.
    **Exit:** every definition clause passes; iPhone work does not start from a
    partial iPad renderer.

12. **Add physical-device build and acceptance.** Create an `iphoneos` arm64
    build/archive/sign/install path and run the device matrix.
    **Exit:** cold signed installs on one supported iPad and iPhone pass data
    import, touch, controller disconnect/reconnect, audio routes/interruption,
    lifecycle, save persistence, sustained performance/memory/thermal soak, and
    signed-native/ROM-safe package audits. Requires Apple signing authority,
    devices, controller, audio accessories, and a legal user-owned game copy.

## Risk decisions and falsifiers

| Claim | Confidence | Principal unknown | Discriminator/falsifier | External dependency |
|---|---:|---|---|---|
| No current hard iOS renderer prohibition | 95% | Full parity/performance cost | A required observed semantic cannot be expressed by supported Metal, or device resource limits are unworkable | Device for final perf |
| Native Metal is shortest to one Direct proof | 82% | Exact target/visibility path | Small ANGLE Direct spike passes while a trace-matched Metal slice cannot | None for fixture |
| The packet is a Jak 1 font glyph | 99% | Live payload match | Descriptor/payload fingerprint differs from `font-h.gc` | Local user data |
| The glyph needs `ProgressRenderer` offscreen behavior | <30% | Desktop target attribution | Desktop logs non-default FBP/FBO, offscreen mode, store, and later sample | None |
| Existing decoder is a useful parser seed | 85% | Silent/ordering/ADC defects | Byte/state trace disagrees with desktop fixture | None |
| CPU raster must leave product path | 98% | None material | It cannot model complete target/state/flush/depth/composition behavior | None |
| Pad seam can support product input | 90% | Multitouch/disconnect races | Any focused/live path leaves a latched non-neutral state | Controller later |
| GameController ownership is bounded | 65% | SDL open/enumeration behavior | Events fail before shell state after explicit open/device ownership | Real controller |
| Mobile audio/IOP is feasible | 65% | Thread, data, route, lifecycle coupling | Fixture cannot mix PCM or route cannot resume without duplicate/drift | Device/audio routes |
| iPhone follows the iPad architecture | 70% | Compact UI, memory, frame cost | Same accepted iPad route fails only at iPhone constraints | Simulator/device |
| Signing is an acceptance gate, not a prohibition | 90% | Account/profile and device-only behavior | `iphoneos` compile/sign/install or native-code audit fails | Developer account/devices |

If the attributed packet is plain Direct, implement final-target Direct and
remove offscreen scope. If a proven target becomes nonzero but the final frame
is blank, inspect only its alias, store lifetime, and first consuming draw. If
the first divergence is decoder/state ordering, fix that boundary before any
renderer expansion. Never respond to failure by broadening into a generic VU
interpreter or wholesale renderer port.

## Completion definitions

**iPad playable** means a fresh app with validated user-supplied data presents
a coherent, macOS-comparable title/menu and completes the real New Game route
through Village1/Training with complete required renderer buckets, visible and
customizable touch controls, canonical external-controller input, streaming,
audible playback-only audio, save/reload, lifecycle neutralization, and a
bounded active soak with no crash/fault/assert/validation markers.

**iPhone parity** means the same accepted path passes in a landscape iPhone
Simulator with safe-area-correct rendering and controls, phone-specific saved
layout, and recorded drawable size, frame time, and memory. It does not include
device thermal, signing, route, or ergonomic acceptance.

**Device-ready** means a reproducible `iphoneos` arm64 build is signed and cold-
installed on one supported iPad and one iPhone, both pass the complete data,
touch, controller, audio-route/interruption, background/resume, save,
performance/memory/thermal matrix, no microphone prompt appears, and package
audits confirm signed native/no-runtime-executable-code and ROM-safe contents.
