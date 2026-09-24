# Recovery prerequisite — named crash boundaries

Historical causes: `m1-supplied-simulator-link-version-assertion-2026-08-21.md`
traces the link SIGABRT to empty/malformed optional-object headers;
`m1-crash-boundaries-2026-08-22.md` traces the encoder assertion to an open
render encoder during exception unwinding. These are distinct failures.

Current-source checks, rerun 2026-09-12:

| Check | Result |
|---|---|
| `bash scripts/test-metal-encoder-guard.sh` | PASS normal scope, repeated explicit end, Objective-C/C++ unwind, exactly-once completion, nil encoder |
| `bash scripts/test-link-begin-args.sh` | PASS actual production predicate: null args/data/name, zero/negative size, valid args |
| `python3 scripts/verify-link-begin-patch.py` | PASS pin + H3 + overlay reproduces current linker implementation/header/test byte-for-byte |

`RenderEncoderEndGuard` moved unchanged into `src/shell/metal_encoder_guard.h`,
used by both production and the fake-encoder regression. The linker overlay
is `patches/jak1-link-begin-argument-regression.patch`; apply after H3 per
`patches/README.md`. No blanket regeneration of nested changes occurred.

PASS for regression coverage/reconstructability of these named boundaries;
the recovery may proceed to the next tested source defect. This does not
prove every Metal validation/exception path, validate all possible malformed
objects, or close runtime stability. An actual recurrence reopens the gate.
No new Simulator launch or playability evidence is claimed by this document.
