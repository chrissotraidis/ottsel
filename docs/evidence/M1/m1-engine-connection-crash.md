# M1 — BOT29: the post-spawn crash pinned to engine-connection dispatch (2026-08-16)

## Where the game is when it dies

Boot -> title -> bg trigger -> village1 displayed -> (start 'play cp) ->
Jak spawns -> "GAMEPLAY: enter village1" -> seconds later, EE thread dies
calling EE 0x3075274 (EXC_BAD_ACCESS -> after the exec-healer flips the
page, EXC_BAD_INSTRUCTION: the bytes are not code).  Reproduces
identically every run (same pc/lr/registers).  The Sony boot logo renders
(the display path is proven end-to-end); the black screen after the mode
switch is this crash freezing the last frame.

## Ground truth (lldb crash-hook dumps, deterministic addresses)

- lr = EE 0x41e32bc — inside the compiled `bsp` object (bsp-header draw /
  background engine execution).
- The called address 0x3075274 is a DATA OBJECT: type tag 0x0153db74 at
  ref-4, then 0x00070e5d, heap pointers, bounding-sphere floats.
- The memory around 0x153e2d0 (reached via the dispatch) is a table of
  16-byte rows shaped {level-heap obj, level-heap obj (0x3075xxx, stride
  0x40 descending), code ptr (stub arena 0x4f0xxxx / code arena
  0x46xxxxx/0x42xxxxx), code ptr} — i.e. an ENGINE CONNECTION LIST
  ({params, function}), not a method table.  The crash calls a PARAM slot
  as the function.

## Hypothesis (one probe from confirmation)

`deactivate` on the discarded title level ran `remove-by-param1
*background-draw-engine* title-bsp`; if the ARM64-compiled connection
list surgery (engine remove/iterate in engine.gc) corrupts links or the
iterator's field offsets are off, the next `execute-connections` walks
misaligned rows and calls a parameter.  Timing matches: the crash only
appears after a level discard + active background engine.

Next session: dump `*background-draw-engine*` (alive-list head, each
connection's {next, function, param0..2}) at the crash and immediately
after the title discard; compare against engine-h.gc offsets; suspect
the compiled `remove-by-param1` / `execute-connections` codegen.

## Also this session

- Reverted the BOT21c goal_src draw restorations (tie/tfrag ln calls) to
  upstream state — they were for the retired VU1 track and are disabled
  upstream; crash persists without them (so they were not the trigger).
- gkernel.gc is now the ONLY goal_src divergence from upstream.
- Exec-fault healer (runtime.cpp) + v3 main-seg RX flips are in and
  working (the crash moved from protection-fault to bad-instruction,
  proving the healer functions).
