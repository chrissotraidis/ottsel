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

// Safe 32-bit read for the signal handler: probes the page with mincore
// before dereferencing so a bad pointer in the dump path cannot re-fault
// the handler (which would mask the real fault and stop the log early).
bool safe_read_u32(const volatile void* p, u32* out) {
  const uintptr_t page = (uintptr_t)sysconf(_SC_PAGESIZE);
  uintptr_t addr = (uintptr_t)p;
  char vec = 0;
  if (mincore((void*)(addr & ~(page - 1)), page, &vec) != 0 || (vec & 1) == 0) {
    return false;
  }
  *out = *(volatile u32*)p;
  return true;
}

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
  uintptr_t lr = uc->uc_mcontext->__ss.__lr;
  lg::error("OTTSEL_IOS: regs x0=0x{:x} x1=0x{:x} x2=0x{:x} x3=0x{:x} x4=0x{:x} x5=0x{:x}",
            uc->uc_mcontext->__ss.__x[0], uc->uc_mcontext->__ss.__x[1],
            uc->uc_mcontext->__ss.__x[2], uc->uc_mcontext->__ss.__x[3],
            uc->uc_mcontext->__ss.__x[4], uc->uc_mcontext->__ss.__x[5]);
  lg::error("OTTSEL_IOS: regs x8=0x{:x} x9=0x{:x} x10=0x{:x} x11=0x{:x} x12=0x{:x} x13=0x{:x}",
            uc->uc_mcontext->__ss.__x[8], uc->uc_mcontext->__ss.__x[9],
            uc->uc_mcontext->__ss.__x[10], uc->uc_mcontext->__ss.__x[11],
            uc->uc_mcontext->__ss.__x[12], uc->uc_mcontext->__ss.__x[13]);
  lg::error("OTTSEL_IOS: regs x14=0x{:x} x15=0x{:x} x17=0x{:x} x19=0x{:x} x20=0x{:x} x23=0x{:x}",
            uc->uc_mcontext->__ss.__x[14], uc->uc_mcontext->__ss.__x[15],
            uc->uc_mcontext->__ss.__x[17], uc->uc_mcontext->__ss.__x[19],
            uc->uc_mcontext->__ss.__x[20], uc->uc_mcontext->__ss.__x[23]);
  lg::error("OTTSEL_IOS: fault lr=0x{:x} x21(st)=0x{:x} x22(offset)=0x{:x} x16=0x{:x}",
            lr, uc->uc_mcontext->__ss.__x[21], uc->uc_mcontext->__ss.__x[22],
            uc->uc_mcontext->__ss.__x[16]);
  // dump the linked instruction words around the call site (lr - 0x40)
  if (lr >= 0x7000000000ull && lr < 0x7000000000ull + EE_MAIN_MEM_SIZE) {
    u32 word = 0;
    for (int i = 0; i < 20; i++) {
      if (safe_read_u32((volatile u32*)(lr - 0x40 + i * 4), &word)) {
        lg::error("OTTSEL_IOS: lr-{:#x} word: 0x{:08x}", 0x40 - i * 4, word);
      }
    }
  }
#endif
  lg::error("OTTSEL_IOS BOOT FAILED (gated): signal {} at pc=0x{:x} fault addr=0x{:x}",
            sig, pc, (uintptr_t)info->si_addr);
  u32 fw[4] = {0, 0, 0, 0};
  for (int i = 0; i < 4; i++) {
    safe_read_u32((volatile u32*)(pc + i * 4), &fw[i]);
  }
  lg::error("OTTSEL_IOS: faulting words: 0x{:08x} 0x{:08x} 0x{:08x} 0x{:08x}", fw[0], fw[1],
            fw[2], fw[3]);
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

// Generic CGO loader: stage the DGO into EE memory and link+exec every
// object (the no-emit linker pattern used for the kernel).
void ottsel_ios_link_cgo_from_bundle(const char* cgo_name) {
  if (g_bundle_dir.empty()) {
    gated_fail("bundle dir not set before CGO load");
  }
  std::string path = g_bundle_dir + cgo_name;
  lg::info("OTTSEL_IOS: reading {} from {}", cgo_name, path);

  FILE* fp = fopen(path.c_str(), "rb");
  if (!fp) {
    gated_fail(("cannot open " + path).c_str());
  }
  fseek(fp, 0, SEEK_END);
  long fsize = ftell(fp);
  fseek(fp, 0, SEEK_SET);
  if (fsize < 64 || fsize > 64 * 1024 * 1024) {
    fclose(fp);
    gated_fail((std::string(cgo_name) + " has an implausible size").c_str());
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
  lg::info("OTTSEL_IOS: {} has {} objects", cgo_name, count);
  u32 flags = LINK_FLAG_OUTPUT_LOAD | LINK_FLAG_EXECUTE | LINK_FLAG_PRINT_LOGIN;
  for (u32 i = 0; i < count; i++) {
    u32 size = *(u32*)(stage.c() + off);
    const char* name = (const char*)(stage.c() + off + 4);
    lg::info("OTTSEL_IOS: linking object {} ({}) size {}", i, name, size);
    jak1::link_and_exec(stage + off + 64, name, (int32_t)size, kglobalheap, flags, true);
    off += 64 + ((size + 15) & ~15u);
  }
  lg::info("OTTSEL_IOS: {} linked ({} objects)", cgo_name, count);
}

extern "C" void ottsel_ios_load_kernel_from_bundle() {
  // Called from jak1::InitHeapAndSymbol after the GOAL heap + symbols exist.
  ottsel_ios_link_cgo_from_bundle("KERNEL.CGO");
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
    // S2.1: load the full game engine after the kernel so the game's
    // top-levels run and (in the full boot) the game processes start.
    ottsel_ios_link_cgo_from_bundle("GAME.CGO");
    jak1::KernelCheckAndDispatch();
    jak1::ShutdownMachine();
    lg::info("OTTSEL_IOS: kernel dispatch loop exited cleanly");
  } else {
    gated_fail("jak1::InitMachine returned an error");
  }
}
