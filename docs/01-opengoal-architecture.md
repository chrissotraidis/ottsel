# 01 — OpenGOAL architecture (Jak 1 focus)

Research date: 2026-08-07  
Upstream pin: `open-goal/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366` (2026-07-31)  
License: ISC  
Primary tree: `ref/open-goal-jak-project/repo/`

## 1. What OpenGOAL is

OpenGOAL is a PC port strategy for the Jak & Daxter trilogy based on:

1. decompiling Naughty Dog GOAL into human-readable OpenGOAL (`goal_src/`)
2. compiling that code with a custom compiler (`goalc`) to a custom object format
3. linking and executing those objects inside a C++ runtime (`game/`) that replaces PS2/IOP services

It is **not** a conventional C/C++ decompilation like Ship of Harkinian. Game logic remains GOAL and is compiled by `goalc` into native machine code for the host.

Upstream goals (from README):

- native x86-64 application (not emulated/interpreted/transpiled)
- performance around unoptimized C
- preserve live code modification / REPL-style development
- support modifications

Upstream status (README @ pin):

- Jak 1: polished/complete for years
- Jak 2: beta / essentially complete for casual play
- Jak 3: substantial work remaining
- Supported hosts: **x86_64 Windows/Linux/macOS (Rosetta on Apple Silicon)**
- Explicit: **"There are no plans to ever make a mobile release."**

## 2. Major components

| Component | Path | Role |
|---|---|---|
| Compiler / REPL | `goalc/` | Parses OpenGOAL, IR, register allocation, machine-code emission, object packing |
| Runtime | `game/` | EE memory, linker, kernel helpers, graphics, sound, I/O, SDL host |
| Decompiler | `decompiler/` | PS2 → OpenGOAL / assets (build-host tool) |
| Game source | `goal_src/` | OpenGOAL game code (not sparse-checked out in this research pin clone) |
| Shared support | `common/` | type system, versions, sockets, util |
| Docs | `docs/project-overview.md`, `docs/setup/system/macos.md` | architecture + host setup |

## 3. Runtime model

### 3.1 Process shape
`game/runtime.cpp` launches system threads (EE, IOP/overlord, DECI2 listener, etc.). The EE thread:

1. `mmap`s a large **GOAL main memory** region (`EE_MAIN_MEM_SIZE` = 128 MB)
2. initializes kernel globals, heaps, linker, listener
3. loads/links object files and jumps into GOAL

### 3.2 Executable memory is load-bearing
`game/runtime.cpp` maps EE memory with `PROT_EXEC | PROT_READ | PROT_WRITE` and comments explicitly that Apple Silicon cannot keep pages both writable and executable at once. Current macOS ARM experiments flip permissions only in the small `CodeTester` path; the production EE map is still RWX-oriented.

Constants (`common/goal_constants.h`):

- `EE_MAIN_MEM_SIZE = 128 * (1 << 20)`
- default map address `EE_MAIN_MEM_MAP = 0x2123000000` (high address to catch pointer bugs)
- first 512 KB of EE memory is `mprotect(... PROT_NONE)` after init

### 3.3 Object load / link / exec
Object files are custom GOAL objects with code + link tables (`goalc/emitter/ObjectGenerator.*`, `game/kernel/**/klink.*`).

Typical Jak 1 path:

- assets/objects arrive via overlord/DGO loaders (`kdgo`)
- `link_and_exec(...)` links into EE memory
- optional top-level execution via `call_goal` / `call_goal_on_stack`
- listener/REPL path can also `link_and_exec` code into the debug heap (`klisten`)

This means "compile the game" is not the same as "produce a normal Mach-O with all code signed once." The runtime expects to receive relocatable code blobs and patch them while loading.

### 3.4 C↔GOAL bridges are also code generation
`game/kernel/jak1/kscheme.cpp` builds tiny function objects at runtime for C functions exported into GOAL (`make_function_from_c*`). Even on `__aarch64__` branches, the currently checked implementation still **emits x86 machine bytes** into the GOAL heap (with a `TODO - x86 code still being emitted below`). ARM64 trampoline assembly exists (`game/kernel/asm_funcs_arm64.s`), but the heap-stub emitters are not fully converted.

Mips2C functions also rely on small dynamically generated stubs that jump into shared call helpers (`game/mips2c/readme.md`).

## 4. Compiler / emitter model

### 4.1 Instruction sets
`goalc/emitter/InstructionSet.h` defines:

- `InstructionSet::X86`
- `InstructionSet::ARM64`

`goalc/main.cpp` currently constructs the compiler with **`InstructionSet::X86` only**.

### 4.2 Two-layer backend
1. High-level IR codegen (`goalc/compiler/IR.cpp`, `CodeGenerator.cpp`)
2. Instruction encoder (`goalc/emitter/IGen*.cpp`, `Instruction.h`)

There is a real ARM64 instruction-encoding layer:

- `IGenARM64.cpp` ~2985 lines
- merged PRs in 2026 implementing bulk ARM64 encodings and load/store conversion
- `CodeTester` can allocate `MAP_JIT` buffers on Apple Silicon and flip RX/RW around execute

But the compiler middle-end is not finished:

- `CodeGenerator::do_goal_function_arm64` → throws `NYI`
- `CodeGenerator::do_asm_function_arm64` → throws `NYI`
- **all 41** `IR_*::do_codegen_arm64` methods in `IR.cpp` throw `NYI`

So ARM64 today is best described as:

> encoder + unit-test harness progress, not a game-capable ARM64 OpenGOAL compiler.

### 4.3 Build products for play
End-user/dev flow (docs/README):

1. build C++ tools
2. extract assets from user ISO into `iso_data/jak1` (local only)
3. run compiler to build game objects
4. run runtime

macOS docs:

- supported production path: **x86_64 build under Rosetta**
- experimental unsupported path: `Release-macos-arm64-clang` preset exists

## 5. Host platform dependencies relevant to iOS

| Subsystem | Current OpenGOAL choice | iOS implication |
|---|---|---|
| Window/input | SDL3 (`game/system/hid`) | Usable on iOS with lifecycle/document caveats |
| Graphics | OpenGL 4.3 core (4.1 on macOS) only (`GfxPipeline::OpenGL`) | No OpenGL 4.3 on iOS; GL ES / Metal required |
| Sound | 989SND + host shims | Needs iOS audio session path (SDL audio likely first) |
| Files | desktop paths + ISO extraction workflow | Must become Files-app / Documents import; no DVD |
| Live compile/REPL | DECI2 listener + goalc over sockets | Optional for players; dangerous/unwanted on iOS product path |
| CPU features | x86-64 + AVX assumed in supported builds | Must be pure ARM64 |

## 6. Why Jak 1 is the right first title

- most complete OpenGOAL title
- smallest unknown surface in game logic
- already the best-performing title
- enough to prove the **execution model** without Jak 2/3 decomp noise

The hard problem is not "can Jak 1's game code be understood?" Upstream already did that. The hard problem is host execution under iOS constraints.

## 7. Architecture diagram (as-is)

```
goal_src/*.gc  --goalc(X86)-->  .o / DGO objects (x86-64 code + link tables)
                                      |
                                      v
user ISO assets --> extractor/packer --+
                                      |
                                      v
                         game runtime (C++)
                           - mmap RWX EE memory
                           - link objects into EE
                           - call_goal into EE code
                           - SDL3 + OpenGL present
```

## 8. Architecture diagram (required for iOS)

```
host macOS tools (may use desktop freedoms):
  goal_src + assets -> goalc(ARM64 AOT) -> immutable code image(s) + data images

iOS app (no RWX, no runtime emit):
  load signed/readonly code image OR call prebuilt native code
  relocate data only
  C++ runtime + Metal/SDL shell
  never emit/patch instructions after process start
```

## 9. Takeaways for later docs

1. OpenGOAL is a **compiler + dynamic linker runtime**, not a static C port.
2. iOS feasibility collapses to whether that compiler/runtime can be constrained into an AOT, no-emit, ARM64 product mode.
3. Upstream ARM64 work is a head start on instruction encoding only; it is not yet a solution.
4. Graphics and input are secondary risks; they matter only after G2 is solved.


## 10. Deep-pass additions

### 10.1 Official porting mental model
OpenGOAL’s own porting docs (`ref/opengoal-docs/porting-info/porting_to_x86.html`) describe:

- `goal_src` = GOAL game code
- `game/` runtime = C kernel + system + SCE shims + overlord
- single EE OS thread runs C kernel + all GOAL
- IOP/overlord has multiple cooperative OS threads
- graphics intercepts DMA and copies to a graphics thread

This confirms Ottsel is porting a **custom virtual machine/runtime for GOAL objects**, not a normal static binary.

### 10.2 Register / pointer model
From OpenGOAL registers doc + source:

- GOAL keeps 32-bit style pointers into a main memory window
- x86 mapping uses dedicated special registers (process, symbol table, offset)
- ARM64 must redefine this ABI deliberately (asm helpers already sketch AAPCS64 preserve rules)

### 10.3 Quantified mobile blockers
See `08-emit-site-audit.md` and `09-arm64-compiler-gap-analysis.md` for counts and file-level evidence.
