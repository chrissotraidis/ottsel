# A1.2 — product execution-permission proof (PASS, 2026-08-09)

## Signed-AOT build mode

The OttselShell app now contains a distinct signed-AOT artifact: the real
KERNEL.CGO slice (`string=`, `name=`, `ref`, `last`, `nmember`) linked into
the Mach-O `__TEXT` (symbol `_ottsel_a11_slice_code`).  The app runs the
slice proof first (a11_slice_runner.mm) and then continues to the kernel +
GAME.CGO RX-blob boot, which remains clearly diagnostic (the existing
`ottsel_ios_link_cgo_from_bundle` RW->RX transport, never the product path).

## Source audit — the signed-AOT path

`src/shell/a11_slice_runner.mm` + `tools/ottsel_a1_1/a11_slice_emitter.cpp`:

- No `mprotect`, `PROT_EXEC`, `MAP_JIT`, or executable mmap calls (grep
  clean on the AOT path).
- No CGO/DGO instruction bytes are read or executed: the slice functions are
  compiled GOAL code that already lives in the app's `__TEXT`.
- No GOAL instructions are copied into the EE heap.
- No instruction words are patched at runtime: the ADRP/ADD references were
  resolved offline (symbolic `@PAGE/@PAGEOFF` forms assembled by clang and
  fixed by the Mach-O linker); the Mach-O's own code pages are RX by the
  signed image.
- Runtime mutation is limited to the slice's writable `__DATA`:
  function/type-pointer table values (the `name=`/`string=`/type symbol
  values) and the test objects.  This is exactly the "runtime linking
  limited to writable data and function-pointer tables" allowance.
- No JIT / MAP_JIT / unsigned-executable-memory / debugger entitlements: the
  app's Info.plist has none; execution uses only the signed image.

All `mprotect(..., PROT_READ | PROT_EXEC)` calls in the repo belong to the
diagnostic RX-blob linker (game/kernel/jak1/klink.cpp code flips and
kscheme.cpp stub-arena flips) — never on the slice's execution path.

## Negative proof — no bundled CGO bytes

Removed KERNEL.CGO and GAME.CGO from the app bundle, re-signed, ran on the
Simulator: the slice proof still PASSES all 7 checks (log
`a11-simulator-slice-pass.log`, run at 15:21).  The signed-AOT artifact
therefore does not depend on, read, or execute any bundled CGO/DGO bytes.

## Build commands (reproducible)

```
cmake --build out/jak-project/build/h1 --target ottsel-a11-slice -j 8
./out/jak-project/build/h1/goalc/ottsel-a11-slice <out>   # -> slice.s + a11_slice_map.h
./scripts/build-ios.sh    # assembles slice.s, links it into OttselShell, codesigns
```

## Mach-O / codesign / runtime evidence

- `_ottsel_a11_slice_code` in (__TEXT,__text) — executable text.
- `_ottsel_a11_slice_data` in (__DATA,__data) — writable data.
- `xcrun codesign -v OttselShell.app` -> PASS.
- Runtime log: all 7 GOAL checks PASS on the iPad Pro 11-inch (M4)
  Simulator (see `a11-simulator-slice-pass.log`).

## Verdict

A real OpenGOAL artifact executes from signed Mach-O text on the iPad
Simulator with no runtime-created executable GOAL code.  A1.2 PASS.
