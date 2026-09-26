# A1.1 whole-corpus signed-module census — 2026-09-14

Read-only inventory while the disk gate holds (11 GiB free, zero temporary packs): no product build, Simulator or source
change. Method: `scripts/a11-corpus-census.py`, a pure-Python port of `parse_signed_module`
(`out/jak-project/tools/ottsel_a1_1/a11_module_emitter.h`) over every member of every `out/jak-project/out/jak1/iso/*.CGO|*.DGO`;
reproduce with `python3 scripts/a11-corpus-census.py [--simulate|--links|--types|--relax-all|--budget|--identity]`, full output in the sibling `.log`.

## Corpus
28 containers, 1506 members: 872 code (body SHA-256 matches a loose `out/jak1/obj/*.o`) and 634 art (`*.go` actorbanks/tpages); 381 accepted, 491 rejected at the strict default policy below, 872/872 at the maintained emitter (log: real-emitter cross-check).

| container | members | code | emit-OK | art |
| --- | --- | --- | --- | --- |
| KERNEL.CGO | 8 | 8 | 8 | 0 |
| ENGINE.CGO | 306 | 306 | 178 | 0 |
| GAME.CGO | 346 | 326 | 183 | 20 |
| SUB.DGO | 21 | 0 | 0 | 21 |
| 24 other region DGOs | 825 | 232 | 12 | 593 |

KERNEL.CGO's eight accepted members match `config/signed-kernel-full.json` exactly and in order.

## Identity is the member name, not the container name or a payload scheme
`--identity`: 872 code entries reduce to 518 distinct names, 512 bodies and 518 loose `.o` with chosen stem == name for every one, and all 518 are members of the 28 built containers (the 25 `out/jak-project/out/jak1/iso/*.DGO` level DGOs supply the 184 names absent from KERNEL/GAME/ENGINE, body-identical), so only the consumer excludes level code: `signed-module-build-profile.py` `locate_member` scans KERNEL then GAME and the bundle ships only TIT.DGO/VI1.DGO (`.log` addendum);
325 names repeat across containers with byte-identical bodies, no name collides after the `-`/`_` fold and no
container repeats a code name, so dual `sidekick` (`.o` vs `.go`) separates cleanly. Art needs no tiebreak: 0 of the 634
art members have >1 `.go` stem, so the body hash is unique even though 472 map to a `<name>-ag` actorbank; and each of the
four whitelisted bootstrap types appears only at `methods/9`, so pinning them at 9 costs nothing and no name is ever requested at two counts.
Body SHA, not the name, is the ambiguous key (seven declaration-only names share one body), so the name tiebreak in `pick_member` stays and name-keyed dedup is required (354 guard hits otherwise); `--budget` then packs those 518 names at 2.44 MiB static data and 19.48 MiB signed text, and its formula reproduces the shipped KERNEL reservation exactly (11104 B data -> `0x3eb4000`, 17120 B slot). Across 117 names / 117 pairs the count is a primary key, so the kind-2 relaxation cannot reach `intern_type_from_c`'s `size_of_type(existing) < size_of_type(requested)` assert (`kscheme.cpp:1176`) in any order; `--types` now fails closed on that and on the pinned four at 9, and a synthetic second `flut-bank/13` flips it to exit 1.

## The 491 rejections have exactly four causes
- **315** `unsupported type/method count`: a four-name whitelist (`function`, `string`, `kernel-context`,
  `state`) plus `methods == 9`; real names `skeleton-group` 118, `array` 45, `sparticle-launch-group` 27,
  `nav-enemy-info` 21, `shadow-control` 14, `surface` 10, then ~45 singletons (`fact-info`, `bfloat`).
- **96** `unsupported distance32 instruction pair`, every one `add = 0x3dc00000` (ADRP + 16-byte SIMD LDR Q).
- **76** `unsupported data-only main segment`: genuine data-only modules (`vu1-macros`, `quaternion-h`,
  `euler-h`, `video-h`, `text-h`, `main-h`) have `seg0.text == 0`.
- **4** `pointer target outside static data`. No other error string occurs in the corpus.

## What the corpus requires, and what it predicts
1. **Type identity is a load-time name+methods lookup, not a tag index.** `--types`: all 872 code
   members carry kind-2 records, 66,154 over 117 distinct `(name, methods)` pairs, 356 needing the
   guard relaxed (a strict parse rejects an earlier record). Genuine `typelink_v3` (klink.cpp:200) reads
   `name\0`, a `methods` byte and patch offsets, then calls `intern_type_from_c(name, methods)`, which
   already resolves any pair (`0`->12, `1`->44, else that count). So widen only the emitter's kind-2
   guard to the authenticated `(name, methods)` set for data-side slots; keep text-side slots
   `function`-only and one immutable `function_type`. No tag table is invented.
2. **One immutable Type across all signed code.** All 17,217 records whose patch lies inside text (518
   members) are `function`/9; every other pair is static-data only, so code-region `FunctionTag`
   emission is already correct. `methods == 9` is not global: 32 pairs differ (`babak` 76,
   `assistant-levitator`/`sage-finalboss` 53, down to 10), 12 in a single member.
3. **distance32 classes.** A tolerant scan past records that fail earlier shows only `0x91000000`
   x232,665 (accepted), `0xbd400000` x46,435 (accepted) and `0x3dc00000` x2,014 (rejected). One added
   class — LDR (unsigned offset) SIMD&FP, `size = 00`, imm12 scaled by 16, 16-byte-aligned target inside a
   static segment — covers the remainder.
4. **Data-only seg0 is implemented** as a load-time guard, not 76 pure-data modules — all pass once (1) applies. **Pointer**
   (kind 5) keeps fail-closed bounds and now accepts code targets: `--links` has 295 members / 41,380
   records with 1,255 data->code pointers (static-data patch, target below `text`, tagged `& 7 == 4`;
   `target_in_code_region` 1,255, `target_at_or_past_size` 0; member list in the log) — `ptr_link_v3`
   (klink.cpp:188) writes `target + seg_base`, so a code target is a runtime address of signed code.
5. **All four implemented and host-verified; no GAME build.** (1) alone leaves 650/872, the full `(name, methods)` table 785/872, and
   `--relax-all` 872/872 residual 0 (the pointer path the last 11); the compiled `module_cli` accepts all 872 itself (log: real-emitter cross-check), so the 381/491 split above is the strict default policy, not a maintained-emitter rejection. No GAME list emitted, linked or activated; no product build ran. Executed since: host-only probes drive the data-only member merc-vu1 and then the code-bearing member ocean-vu0 (seg0.text 16384) through the real link_and_exec (loaded=2, symbol_offset and interned type_pointer slots all match, SHA-mismatch control rc 134 on each), and the maintained fixture now carries the GAME members: `config/signed-data-only-control.json` (canonical KERNEL chain plus `merc-vu1` before the required final `gstate`) runs 181 checks all PASS, `config/signed-gamedata-control.json` (adding the code-bearing `ocean-vu0`) runs 190 and `config/signed-math-control.json` (adding the dependency-ordered GAME math prefix `math`) runs 199, each GAME member entering and returning through the real `link_and_exec` after a new `OTTSEL_SIGNED_GAMEDATA_TEST` lane registers the Mips2C stub table as product boot does (`kboot.cpp:115`), while the legacy, `--gcommon`, canonical-KERNEL (631 checks) and export-bank (657 checks) lanes stay unchanged; raw output in the log. The same host-only lane then ran single-member probes for navigate-h/gsound/ramdisk/load-dgo, which crash inside the real link_and_exec as one class of missing upstream types (the navigate-h report is SIGABRT at Ptr.h:40, (symbol-value 'vector) == 0; the other three are protection SIGBUS calls to a null Symbol::value in non-executable arena memory, rpc-buffer-pair), and inserting the parent module ahead of the member is decisive: config/signed-probe-navdep.json (canonical seven plus math+vector-h before navigate-h) runs 199 checks and config/signed-probe-{load-dgo,ramdisk}-rpc.json run 190 each, all PASS with the member entering/returning, while config/signed-probe-gsound-rpc.json advances gsound to a SIGSEGV (rpc_h_s0_code+2188) frame-identical to the 315-member control, root-caused as a fixture boot-scope gap rather than a product defect: the call is `((IOP*)nullptr)->kernel.sif_mtx.lock()` (far=x0=808 = offsetof(IOP,kernel) 592 + offsetof(IOP_Kernel,sif_mtx) 216 from a throwaway `#define private public` probe), since `sif_ee.cpp:36`'s internal-linkage `ee::iop` is zero-init and only `runtime.cpp:616` registers it (the fixture's `test/a11_gstate_loader_test.cpp` has zero `sceSif`/`iop` references) and the h1 runtime builds without `OTTSEL_IOS` so `sceSifCallRpc` takes the `iop->kernel.sif_rpc(...)` branch at `:605`/`:609` instead of the `#ifdef OTTSEL_IOS` shim at `:185` that `scripts/build-ios.sh:97` defines for the app; the loader's fail-closed gap on an undefined `Symbol::value` feeding an indirect call remains open; frames, disassembly and the per-lane table are in the sibling log.
