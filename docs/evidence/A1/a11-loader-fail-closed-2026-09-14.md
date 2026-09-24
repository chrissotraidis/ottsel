# A1.1 signed-loader fail-closed — 2026-09-14 (host-only)

Read-only source audit while the disk gate holds (9.1 GiB free on the data volume, zero temporary packs): no build,
Simulator, product or harness change. It extends census `.log` addendum 3, which found the gap; this note fixes the
intended change and corrects one documented assumption about the symbol table.

## Gap
`game/kernel/common/ottsel_signed_gstate.cpp` cannot reject a module whose dependency is missing:
- `validate_layout()` (:159) checks slot alignment, kind, bounds and the three pinned bootstrap Type counts; no slot is
  required to resolve to a nonzero symbol value.
- the write loop interns every name: `auto sym = jak1::intern_from_c(slot.name);` (:285), then
  `value = slot.kind == SlotKind::SymbolAddress ? sym.offset : sym.offset - s7.offset;` (:288).
- `intern_from_c` (`game/kernel/jak1/kscheme.cpp:1090`) always succeeds: on a miss it allocates a new symbol at
  `symbol_slot` and sets only the type tag, `str` and `hash` (:1102-1108), never `value`, so the slot reads 0 out of
  the zero-filled GOAL heap. A name that was never defined therefore yields a valid symbol offset carrying value 0, and
  the signed code's indirect call goes to 0: the probe SIGBUS/SIGABRT class rather than a diagnosis.

## Fix (three edits, all inside this loader)
1. Symbol slots resolve find-only and fail closed. `find_symbol_from_c` (`kscheme.cpp:1011`, declared in
   `jak1/kscheme.h`) is a genuine miss-returns-`Ptr<Symbol>(0)` API: the miss path is `find_symbol_in_area` (:991-997)
   falling through to `find_symbol_in_fixed_area` (:962-971). So `auto sym = jak1::find_symbol_from_c(slot.name);
   require(sym.offset, "undefined signed slot symbol");` with :288 unchanged.
2. Capture the five diagnostic names (:277, :286-287) by explicit lookup instead of as a side effect of interning; they
   are already optional reads (`if (diagnostic_symbols[i])`, :305), so a miss stays non-fatal.
3. Fail closed when the symbol table itself is full. `symbol_slot` (`kscheme.cpp:63`) is zeroed on entry and set only by
   the first blank slot; if both probe regions overflow, `find_symbol_in_area` returns 1 twice (:1002), `symbol_slot`
   stays 0 and `intern_from_c` writes `symbol.cast<u32>().c()[-1]` through `Ptr(0)` — arena offset 0 — then
   `NumSymbols++`. Not reachable at the current 279-slot registry, but the same missing-`require` class.

## "Fail closed" here means abort, not `return false`
`ottsel::signed_gstate::link`'s two early exits - `:255` (no name) and `:258` (name not in the registry) - hand control back
to `link_and_exec` (`game/kernel/jak1/klink.cpp:936-940`), which falls through to the legacy
`link_control`/`lc.jak1_finish` path (:951-957, `return lc.m_entry` :983) that links and runs the object from the raw
data buffer, i.e. the executable-page route. `return false` is therefore correct only for "not a signed member" (level
art, `.TXT`, still-unsigned objects); for a registry member whose dependency is missing the loader must abort with the
offending name, as its existing `require(...)` checks do. `fail()`/`require()` take a fixed `const char*`, so naming the
symbol needs a small formatted variant. That path is real code execution: `jak1_finish` (`:681`) runs `CacheFlush` (`:693`), flips `PROT_READ | PROT_EXEC` (`:757`, `:791`, `:821`) and enters the linked object (`:860`).

## Not this
Type slots must keep interning. `intern_type_from_c` (`kscheme.cpp:1141`) *does* set `symbol->value` (via
`alloc_and_init_type`, :1168) and is deliberately load-order-tolerant: a first request creates the Type at the requested
method count and a later intern of the same name returns it after the shrink check (:1176-1182). A find-only require
there would refuse legitimate cross-module Type creation, and its failure mode is a wrong value, not a crash; the two
slot kinds are not interchangeable. S1.3 full-table fallback is unreachable.

## Correction: the S1.3 "order-independent" scan is dead code
## 2026-09-15 host proof
Disk gate clear (120 GiB Avail, zero tmp_pack). Stage 0 encoder-guard, xcrun link-begin, and
verify-link-begin-patch PASS. Find-only symbol slots are FALSIFIED: gcommon aborted
`undefined signed slot symbol: delete-car!` because KERNEL forwards self-defined names.
Landed instead: diagnostic find-only, intern retained, intern_from_c aborts when
`symbol_slot==0`. KERNEL 631, math 199, GAME prefix 31/379, GAME deep 78/802 PASS.
GAME lists load gstate after dgo-h. Host GAME full 315/2935 PASS. locate_member
scans bundled *.DGO; GAME+TIT+VI1 329/3061 PASS. Not an app/Simulator build or
playability. Next: GOAL link-begin/resume, then a signed iOS app.
`link_begin` now tries the signed loader first (GOAL passes string data, not the
String object). Host GAME full through link-begin: 315 begins, 3565 PASS.
iOS app 01480677, 348 CGO-order modules. GAME.CGO 346 signed-linked; TIT
static-screen and title-obs returned. SIGSEGV enter-state pp=0 on VI1 oracle.
drawn=0. Not playable.
