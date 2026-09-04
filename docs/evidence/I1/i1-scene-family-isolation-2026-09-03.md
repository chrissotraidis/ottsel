# I1 scene-family isolation — 2026-09-03

Status: OPEN. Paired family-isolation frames show an interaction failure.

Route: signed rollback build, one iPad Pro 11-inch M4 Simulator, title → Start
→ Cross → Down ×4 → Cross. The raw simctl PNGs are portrait-encoded landscape
captures; that encoding is not treated as a render defect.

Frames:

- `scene-no-merc`: `/tmp/ottsel-video/bot36-scene-no-merc-2026-09-03.png`
  SHA-256 `03b158beac141aeacd39b86dc607a0725664289fab0f4a7c17867ec946c6ac8c`.
- `scene-no-tie`: `/tmp/ottsel-video/bot36-scene-no-tie-2026-09-03.png`
  SHA-256 `ad1ebfb1ca180d730d3be8618471b905b032c73acc357d1c017a0434bd37f229`.

Observation:

- No-Merc removes the actor layer but leaves malformed background geometry.
- No-TIE leaves a sparse TFRAG/background composition with stable-looking
  geometry; the extreme full-scene failure is not caused by TIE alone.
- The normal scene's failure is therefore an interaction between scene-family
  ordering/depth/composition, not a standalone Merc capture failure.

Next question: can the shared depth/order contract be proven by comparing the
same frame with Merc and TIE independently enabled under identical camera,
texture, and drawable state? I1 remains OPEN.
