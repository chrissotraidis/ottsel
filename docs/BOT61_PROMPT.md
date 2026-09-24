# BOT61 — make the world render correctly: restore MERC shading, unblock the sky

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT60_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Product goal (unchanged, from the PRD and the gate loop)

An honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible and
controllable under real input, a stable camera, nonzero game PCM, clean
lifecycle, and sustained frame pacing. Signed-native and ROM-safe.

Gate ownership this round is the visible-correctness half of **Gate I1**. A log
line, a counter, a still frame, a menu, or a Simulator-only result is not
playability.

## Zoom-out — what actually moved, and what did not

BOT60 spent a round on "is the cutscene stalled". This round stopped asking
diagnostic questions about the *frame timeline* and started asking what the
frame is *made of*. That produced three results, one of them a shipped fix.

**The inherited "sky never encodes" refutation is dead.** The prior handoff
concluded the sky bucket stops presenting, from a `SKYFRAME` log that stops at
17:39. Re-armed on a **fresh launch**, the sky path encodes every frame. The
`sky-debug-fill` probe painted **33.4% of the frame solid magenta** and the
magenta covers *exactly the background* -- behind the cliffs, around the
village, right up to the geometry silhouettes. The sky vertex path, the pooled
buffer, and the encoder parameters are all correct. What fails is downstream of
geometry.

**Jak's white body is a structural omission, not a tuning problem.** ```
tfrag3::MercModelGroup stores only vertices/indices/models -- there is no
colour table for MERC at all. ```
The shell's MERC draw used the TFRAG/TIE fragment path, which reads a
per-level time-of-day table at ```colors[in.color_index]```. MERC vertices
hard-coded ```color_index = 0``` and the MERC colour buffer defaulted to
```{255,255,255,255}```, so ```tod = 1.0``` and the shader's ```tod.rgb * 2.0```
doubled every texel to pure white. The desktop reference is unambiguous:
```merc2.vert: vtx_color = rgba * light_color``` and
```merc2.frag: color = vtx_color * T0 * 2```. MERC carries its shade **per
vertex**, never through the background colour table. The native path dropped
those bytes; ```tgrag3::PreloadedVertex``` has an unused ```rgba[4]``` at offset
12 waiting for exactly this.

**The stray coloured plates were the developer touch-layout overlay.** Nine flat
rectangles (cyan, yellow, pink, grey) sat over every frame. Arming
```ottsel-trace-metal-scene-no-overlay``` -- which gates exactly one draw, at
```metal_shell.mm:1966``` -- replaced every plate pixel with real scene content
(sampled: ```(186,186,189) -> (8,10,18)```, ```(83,206,208) -> (8,10,18)```) and
left the rest of the frame untouched. ```upload_touch_overlay()``` uploaded
whenever ```g_native_input_mode``` was false, never consulting ```g_touch_editor```
-- even though ```adjust_touch_opacity()``` already returned early on that flag.
On a touch-only Simulator run the editor is off, ```hide_touch_overlay_for_native_input()```
never fires, and the plates stayed up forever. Fixed by making the upload honour
the editor flag and clear the buffer when the editor is off.

### Honest progress assessment

The rendering defects were never mysterious; they were **unmeasured**. BOT57-60
each produced correct but non-explanatory facts (counters, stall readings,
"sky is black") and each round re-asked the same question in a new way. This
round converted three defects into located causes, and shipped one. That is
faster than the previous four rounds combined -- the leverage was in reading the
desktop reference renderer against the native path, line by line, instead of
probing the Simulator again.

Still not playable. Jak is still unlit, the sky is still black, the top strip is
still wrong, and the game's own VU1->GIF pipeline is still off. No playability
claim.

## Measured start state for BOT61

- Disk: `/dev/disk3s3s1 460Gi 12Gi 13Gi 48% /`, zero
  `.git/objects/pack/tmp_pack_*`. The operator has authorized working below the
  repo's 40 GB rule. Hard stop: any `tmp_pack_*`, or below 5 GiB free. Re-run
  `df -h / | tail -1` before every experiment.
- iPad Pro 11 M4 Simulator `08636791-2675-4675-8335-EF72EF954DCF`, bundle
  `com.ottsel.shell`. `ottsel-fault.log` 0 bytes, 127-148% CPU sustained.
- Data container
  `.../Data/Application/6DD7F5F6-D50D-4998-BD1F-47C5408D516A`; trigger dir is
  that path + `/Library/Application Support/local.ottsel/OttselShell/`.
- Never `simctl install` (it recreates the container and destroys game data).
  Install = `cp` the binary in, `codesign --force --sign -`, `codesign --verify
  --deep --strict`. Rebuild with `scripts/build-ios.sh` (~4 min).
- `ottsel-runtime.log` is in the writable dir, not `Documents/`; `[MM:SS]`
  stamps are minutes:seconds. Filter with
  `grep -a -vE 'MOBILE DIRECT|OTTSELVRAM|SPRITE FRAME|DIRECT FRAME'`.
- Screenshots: `xcrun simctl io <udid> screenshot f.png`, then
  `sips -r -90 -Z 900`; every `banddiff.py` input must be the rotated PNG.
- Outer HEAD `c66a139`, 16 ahead of `origin/main` (`5209405`). Working tree is
  dirty and must be preserved. Never `git add -A`; stage exact files.

## Q1 (primary) — does the MERC shade fix remove the white blowout?

The change is already in the tree: `metal_gfx.mm` copies `MercVertex.rgba` into
`PreloadedVertex.r/g/b/a`; `metal_shell.mm` adds the `UChar4` vertex attribute at
offset 12, threads `vtx_color` through `tie_vs`, adds `merc` to `TieMaterial`,
and makes `tie_fs` select `in.vtx_color` for MERC instead of the colour table.

Validate from the frame, not the log:

1. Launch, press CROSS, reach a scene with Jak (Village1 or Training).
2. Confirm `OTTSEL MERC SHADE LEDGER` reports a **non-white** rgba range for
   `eichar-lod0`. A range of `(255,255,255)..(255,255,255)` refutes the fix and
   means the shade lives somewhere else -- say so and do not paper over it.
3. Capture 3 frames and compare Jak's body pixels against the pre-fix frames.
   The claim is "Jak is no longer blown out to white", not "Jak looks right".
4. Confirm TFRAG/TIE ground rendering is **unchanged**. The shader edit touches
   the shared TIE pipeline, so a regression in the cliffs/grass is a fail, not a
   side effect to accept. `tfrag` must still be textured and colour-correct.

If MERC's shade is genuinely white in the data, then the missing term is the
per-vertex **lighting** (`merc2.vert: vtx_color = rgba * light_color`), which the
native path also never computes. The VuLights block is already in the packet at
offset 128 (`Packet layout: name, VuLights, Jak1 water padding, ...`, see
`metal_gfx.mm` `capture_mobile_merc`), and it is currently parsed past and
ignored. Implementing the ambient+diffuse term is the next increment.

## Q2 — why does the sky sample black when its geometry is correct?

`sky-debug-fill` proves coverage; `sky-debug-tex` (which forces alpha opaque and
shows the raw sampled texel) still returned `(0,0,0)` across the sky band. So
the sky batch's bound texture samples black, or the uv is wrong.

The desktop reference is `sky.frag: color = fragment_color * T0 * 1.0` and
`sky.vert: fragment_color = vec4(rgba.x, rgba.y, rgba.z, rgba.a * 2)` -- the sky
is **vertex-coloured**, with no colour table, exactly like MERC. Check, in order:

1. Is `sky.texture` the real sky texture, or a 1x1 placeholder? The probe loop
   already skips batches under 32x32 for the debug pipelines, so a dummy was
   excluded -- capture the bound texture's dimensions and key.
2. Are the sky vertices' `color[4]` zero? `direct_fs` computes
   `color.rgb = in.color.rgb * texel.rgb`, so a zero vertex colour blackens the
   sky even with a correct texture. This is the same class of bug as Q1.
3. Only then suspect uv/projection.

## Q3 (only if Q1 and Q2 land) — the corrupted top strip

Measure the constant y-band in rotated frames, then check whether
`setScissorRect` at `metal_shell.mm:1945` -- the only scissor in the file, in
the Direct path -- maps the 512x448 game surface scissor onto the drawable
without clipping it to the game viewport.

## Loop rules

- One runtime at a time. Never launch the desktop oracle while the Simulator
  app runs (`docs/15` rule 1).
- Read the desktop reference renderer before hypothesising. Every defect this
  round was located by comparing a native line against its OpenGL counterpart;
  none were located by adding another probe.
- Capture a sequence, never one frame, and always region-resolve it.
- The app stays signed-native, ROM-safe and non-JIT; `ottsel-fault.log` stays
  0 bytes.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines.

## Stop conditions

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in the
repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.

