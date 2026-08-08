// Ottsel S1.3 — no-emit runtime boot driver for iOS.
//
// Mirrors the host boot (runtime.cpp + jak1::kboot) minus the subsystems the
// headless shell does not have: no IOP/OVERLORD, no graphics, no sound, no
// listener/REPL.  KERNEL.CGO is read from the app bundle and linked by the
// no-emit linker; code pages flip RW -> RX exactly like the host H3 proof.

#include "ios_boot.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <csignal>
#include <string>
#include <sys/mman.h>
#include <ucontext.h>
#include <unistd.h>
#include <vector>

#include "common/common_types.h"
#include "common/goal_constants.h"
#include "common/log/log.h"
#include "common/symbols.h"
#include "game/kernel/common/kboot.h"
#include "game/kernel/common/kernel_types.h"
#include "game/kernel/common/kdgo.h"
#include "game/kernel/common/fileio.h"
#include "game/kernel/common/klink.h"
#include "game/kernel/common/klisten.h"
#include "game/kernel/common/kmachine.h"
#include "game/kernel/common/kmalloc.h"
#include "game/kernel/common/kmemcard.h"
#include "game/kernel/common/kprint.h"
#include "game/kernel/common/kscheme.h"
#include "game/kernel/jak1/kboot.h"
#include "game/kernel/jak1/kdgo.h"
#include "game/kernel/jak1/klisten.h"
#include "game/kernel/jak1/klink.h"
#include "game/kernel/jak1/kmachine.h"
#include "game/kernel/jak1/kscheme.h"
#include "game/runtime.h"

namespace {

std::string g_bundle_dir;

// Gated-error path: a boot failure must stop with a clear message instead of
// crash-looping.  lg::level::die aborts after flushing the log file.
[[noreturn]] void gated_fail(const char* what) {
  lg::error("OTTSEL_IOS BOOT FAILED (gated): {}", what);
  lg::finish();
  abort();
}

// Gated signal stop: a fault in the no-emit runtime (data-dependent slot /
// function-pointer resolution bug in the H3 work) must stop with an explicit
// message in the log instead of a silent crash loop.  This is the S1.3
// "explicit gated error" fallback, NOT a fix for the underlying defect.
void gated_signal_handler(int sig, siginfo_t* info, void* ctx) {
  ucontext_t* uc = (ucontext_t*)ctx;
  uintptr_t pc = 0;
#ifdef __aarch64__
  pc = uc->uc_mcontext->__ss.__pc;
#endif
  lg::error("OTTSEL_IOS BOOT FAILED (gated): signal {} at pc=0x{:x} fault addr=0x{:x}",
            sig, pc, (uintptr_t)info->si_addr);
  lg::error("OTTSEL_IOS: stopping with a gated error (no crash loop); the no-emit "
            "symbol-slot resolution is the suspected root cause (see docs/reports/).");
  lg::finish();
  // Hold briefly so the shell's visible log surface shows the gated error
  // before the process exits (evidence capture).
  sleep(6);
  _exit(1);
}

void install_gated_signal_handlers() {
  struct sigaction sa = {};
  sa.sa_sigaction = gated_signal_handler;
  sa.sa_flags = SA_SIGINFO;
  sigemptyset(&sa.sa_mask);
  sigaction(SIGSEGV, &sa, nullptr);
  sigaction(SIGBUS, &sa, nullptr);
  sigaction(SIGILL, &sa, nullptr);
}

}  // namespace

void ottsel_ios_set_bundle_dir(const std::string& dir) {
  g_bundle_dir = dir;
}

std::string ottsel_ios_bundle_dir() {
  return g_bundle_dir;
}

void ottsel_ios_stop_dispatch() {
  MasterExit = RuntimeExitStatus::EXIT;
}

extern "C" void ottsel_ios_load_kernel_from_bundle() {
  // Called from jak1::InitHeapAndSymbol after the GOAL heap + symbols exist.
  if (g_bundle_dir.empty()) {
    gated_fail("bundle dir not set before kernel load");
  }
  std::string path = g_bundle_dir + "KERNEL.CGO";
  lg::info("OTTSEL_IOS: reading kernel DGO from {}", path);

  FILE* fp = fopen(path.c_str(), "rb");
  if (!fp) {
    gated_fail(("cannot open " + path).c_str());
  }
  fseek(fp, 0, SEEK_END);
  long fsize = ftell(fp);
  fseek(fp, 0, SEEK_SET);
  if (fsize < 64 || fsize > 64 * 1024 * 1024) {
    fclose(fp);
    gated_fail("KERNEL.CGO has an implausible size");
  }
  std::vector<u8> dgo((size_t)fsize);
  if (fread(dgo.data(), 1, (size_t)fsize, fp) != (size_t)fsize) {
    fclose(fp);
    gated_fail("short read of KERNEL.CGO");
  }
  fclose(fp);

  // Stage the whole DGO into EE memory (the no-emit linker reads objects via
  // EE-relative pointers).  Same pattern as the host's dgo-buffer-2: kmalloc
  // from the top of the global heap, 64-byte aligned.
  u32 stage_size = ((u32)dgo.size() + 0x3f) & ~0x3fu;
  auto stage = kmalloc(kglobalheap, stage_size, KMALLOC_TOP | KMALLOC_ALIGN_64,
                       "ottsel-ios-dgo-stage");
  if (!stage.offset) {
    gated_fail("kmalloc of DGO staging buffer failed");
  }
  memcpy(stage.c(), dgo.data(), dgo.size());
  dgo.clear();
  dgo.shrink_to_fit();

  // DGO layout: DgoHeader{ u32 object_count; char name[60] }, then per object
  // ObjectHeader{ u32 size; char name[60] } + blob (16-byte aligned).
  u32 count = *(stage.cast<u32>());
  u32 off = 64;
  lg::info("OTTSEL_IOS: kernel DGO has {} objects", count);
  u32 flags = LINK_FLAG_OUTPUT_LOAD | LINK_FLAG_EXECUTE | LINK_FLAG_PRINT_LOGIN;
  for (u32 i = 0; i < count; i++) {
    u32 size = *(u32*)(stage.c() + off);
    const char* name = (const char*)(stage.c() + off + 4);
    lg::info("OTTSEL_IOS: linking object {} ({}) size {}", i, name, size);
    jak1::link_and_exec(stage + off + 64, name, (int32_t)size, kglobalheap, flags, true);
    off += 64 + ((size + 15) & ~15u);
  }
  lg::info("OTTSEL_IOS: kernel DGO linked ({} objects)", count);
}

void ottsel_ios_run_boot() {
  install_gated_signal_handlers();

  // ---- EE memory map (same as the host runtime, OTTSEL no-emit) ----
  g_ee_main_mem = (u8*)mmap((void*)EE_MAIN_MEM_MAP, EE_MAIN_MEM_SIZE, PROT_READ | PROT_WRITE,
                            MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
  if (g_ee_main_mem == MAP_FAILED) {
    gated_fail("mmap of EE main memory failed");
  }
  lg::debug("OTTSEL_IOS: EE main memory mapped at 0x{:016x}", (u64)g_ee_main_mem);
  memset(g_ee_main_mem, 0, EE_MAIN_MEM_SIZE);
  mprotect(g_ee_main_mem, EE_MAIN_MEM_LOW_PROTECT, PROT_NONE);

  // ---- globals (kernel subset of the host init sequence) ----
  fileio_init_globals();
  kmalloc_init_globals_common();
  jak1::kboot_init_globals();
  kdgo_init_globals();
  jak1::kdgo_init_globals();
  klink_init_globals();
  jak1::kscheme_init_globals();
  klisten_init_globals();
  jak1::klisten_init_globals();
  kmemcard_init_globals();

  // ---- boot the kernel (IOP/gfx/sound/listener are OTTSEL_IOS-stubbed) ----
  MasterDebug = 0;
  MasterUseKernel = 1;
  if (jak1::InitMachine() >= 0) {
    // Ottsel S1.3: hard-disable the listener at the GOAL side too.  The GOAL
    // kernel dispatcher tests *listener-function* and CALLS it if non-zero;
    // the linker's symbol-table probe and the C-side intern can land on
    // different entries (OpenGOAL intern quirk), so the C-side value alone
    // is not what the GOAL side reads.  Point the GOAL-side slot (found via
    // the same slot chain the dispatcher uses) at the GOAL `nothing`
    // function, so the listener branch is a safe no-op.
    {
      // The dispatcher reads *listener-function* through a data slot at
      // within-segment offset 0x8f8c (gkernel main code); the dispatcher
      // entry is at 0x5384.  Slot -> s7-relative entry -> value.
      const u32 slot_addr = jak1::kernel_dispatcher->value + (0x8f8c - 0x5384);
      const u32 slot = *(u32*)(g_ee_main_mem + slot_addr);
      const u32 goal_entry = s7.offset + slot;
      const u32 nothing_fn =
          *(u32*)(g_ee_main_mem + s7.offset + jak1_symbols::FIX_SYM_NOTHING_FUNC);
      lg::info("OTTSEL_IOS: listener slot 0x{:x} -> entry 0x{:x} (old value 0x{:x}); "
               "setting to nothing-func 0x{:x}",
               slot_addr, goal_entry, *(u32*)(g_ee_main_mem + goal_entry), nothing_fn);
      *(u32*)(g_ee_main_mem + goal_entry) = nothing_fn;
    }
    jak1::KernelCheckAndDispatch();
    jak1::ShutdownMachine();
    lg::info("OTTSEL_IOS: kernel dispatch loop exited cleanly");
  } else {
    gated_fail("jak1::InitMachine returned an error");
  }
}
