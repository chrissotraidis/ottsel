// Ottsel S1.3 — no-emit runtime boot driver for iOS.
//
// Mirrors the host boot (runtime.cpp + jak1::kboot) minus the subsystems the
// headless shell does not have: no IOP/OVERLORD, no graphics, no sound, no
// listener/REPL.  KERNEL.CGO is read from the app bundle and linked by the
// no-emit linker; code pages flip RW -> RX exactly like the host H3 proof.

#include "ios_boot.h"

#include <cstdarg>
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

// Ottsel A1.0 bounded trace (TEMPORARY): ring buffer written by the goalc
// IR_FunctionCall shim via the 'ottsel-goal-call-trace' C export.
extern "C" {
extern volatile u64 g_ottsel_call_trace[];
extern volatile u64 g_ottsel_call_idx;
}

// Ottsel A1.1: real KERNEL.CGO slice proof runner (a11_slice_runner.mm).
extern "C" int ottsel_run_a11_slice_proof();

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
  // All handler output goes through raw stderr writes: the fault may have
  // happened inside a log call, and lg::error can deadlock/re-enter in that
  // state (observed as a 100% CPU spin after the regs dump).
  auto rawlog = [](const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (n > 0) {
      write(2, buf, (size_t)n);
    }
  };
#ifdef __aarch64__
  pc = uc->uc_mcontext->__ss.__pc;
  uintptr_t lr = uc->uc_mcontext->__ss.__lr;
  uintptr_t sp = uc->uc_mcontext->__ss.__sp;
  rawlog("OTTSEL_IOS: fault sp=0x%lx\n", (unsigned long)sp);
  // S2.1 debug: RAW stack slots (no address filter) so saved x30/x22 values
  // near the faulting frame are visible (the GOAL-relative filter hides
  // them).
  for (int i = 0; i < 48; i++) {
    uintptr_t addr = sp - i * 16;
    u32 w = 0;
    u32 w2 = 0;
    if (safe_read_u32((volatile u32*)addr, &w) &&
        safe_read_u32((volatile u32*)(addr + 8), &w2)) {
      rawlog("OTTSEL_IOS: rawstack[%d] @0x%lx = 0x%08x 0x%08x\n", i, (unsigned long)addr, w, w2);
    }
  }
  for (int i = 1; i < 24; i++) {
    uintptr_t addr = sp + i * 16;
    u32 w = 0;
    u32 w2 = 0;
    if (safe_read_u32((volatile u32*)addr, &w) &&
        safe_read_u32((volatile u32*)(addr + 8), &w2)) {
      rawlog("OTTSEL_IOS: rawstack[+%d] @0x%lx = 0x%08x 0x%08x\n", i, (unsigned long)addr, w, w2);
    }
  }
  // S2.1 debug: walk the GOAL stack for saved LR chain (each GOAL frame's
  // str x30, [sp, #-16]! leaves the return address at the frame top).
  for (int i = 0; i < 64; i++) {
    uintptr_t addr = sp + i * 16;
    u32 w = 0;
    if (safe_read_u32((volatile u32*)addr, &w) && (w >= 0x100000 && w < 0x4000000)) {
      rawlog("OTTSEL_IOS: stack[%d] @0x%lx = 0x%08x\n", i, (unsigned long)addr, w);
    }
  }
  rawlog("OTTSEL_IOS: regs x0=0x%lx x1=0x%lx x2=0x%lx x3=0x%lx x4=0x%lx x5=0x%lx\n",
         (unsigned long)uc->uc_mcontext->__ss.__x[0], (unsigned long)uc->uc_mcontext->__ss.__x[1],
         (unsigned long)uc->uc_mcontext->__ss.__x[2], (unsigned long)uc->uc_mcontext->__ss.__x[3],
         (unsigned long)uc->uc_mcontext->__ss.__x[4], (unsigned long)uc->uc_mcontext->__ss.__x[5]);
  rawlog("OTTSEL_IOS: regs x8=0x%lx x9=0x%lx x10=0x%lx x11=0x%lx x12=0x%lx x13=0x%lx\n",
         (unsigned long)uc->uc_mcontext->__ss.__x[8], (unsigned long)uc->uc_mcontext->__ss.__x[9],
         (unsigned long)uc->uc_mcontext->__ss.__x[10], (unsigned long)uc->uc_mcontext->__ss.__x[11],
         (unsigned long)uc->uc_mcontext->__ss.__x[12], (unsigned long)uc->uc_mcontext->__ss.__x[13]);
  rawlog("OTTSEL_IOS: regs x14=0x%lx x15=0x%lx x17=0x%lx x19=0x%lx x20=0x%lx x23=0x%lx\n",
         (unsigned long)uc->uc_mcontext->__ss.__x[14], (unsigned long)uc->uc_mcontext->__ss.__x[15],
         (unsigned long)uc->uc_mcontext->__ss.__x[17], (unsigned long)uc->uc_mcontext->__ss.__x[19],
         (unsigned long)uc->uc_mcontext->__ss.__x[20], (unsigned long)uc->uc_mcontext->__ss.__x[23]);
  // S2.1 debug (TEMPORARY): the catch-frame func call path uses x6/x7/x24/x25.
  rawlog("OTTSEL_IOS: regs x6=0x%lx x7=0x%lx x24=0x%lx x25=0x%lx x26=0x%lx x27=0x%lx\n",
         (unsigned long)uc->uc_mcontext->__ss.__x[6], (unsigned long)uc->uc_mcontext->__ss.__x[7],
         (unsigned long)uc->uc_mcontext->__ss.__x[24], (unsigned long)uc->uc_mcontext->__ss.__x[25],
         (unsigned long)uc->uc_mcontext->__ss.__x[26], (unsigned long)uc->uc_mcontext->__ss.__x[27]);
  rawlog("OTTSEL_IOS: fault lr=0x%lx x21(st)=0x%lx x22(offset)=0x%lx x16=0x%lx\n",
         (unsigned long)lr, (unsigned long)uc->uc_mcontext->__ss.__x[21],
         (unsigned long)uc->uc_mcontext->__ss.__x[22], (unsigned long)uc->uc_mcontext->__ss.__x[16]);
  // S2.1 debug (TEMPORARY): dump the process-spawn func-slot chain so the
  // func=#t regression can be traced without lldb (which cannot read these
  // pages reliably).
  {
    const uintptr_t ee = (uintptr_t)g_ee_main_mem;
    u32 slot = 0, sym_val = 0, sym_hash = 0, sym_str = 0;
    rawlog("OTTSEL probe: ee=%p\n", g_ee_main_mem);
    if (safe_read_u32((volatile u32*)(ee + 0x237c2b0), &slot)) {
      rawlog("OTTSEL probe: time-of-day func slot@0x237c2b0 = 0x%08x\n", slot);
      if (safe_read_u32((volatile u32*)(ee + 0x18fe04 + slot), &sym_val) &&
          safe_read_u32((volatile u32*)(ee + 0x18fe04 + slot + 4), &sym_hash) &&
          safe_read_u32((volatile u32*)(ee + 0x18fe04 + slot + 8), &sym_str)) {
        rawlog("OTTSEL probe: sym@0x%lx value=0x%08x hash=0x%08x str=0x%08x\n",
               (unsigned long)(0x18fe04 + slot), sym_val, sym_hash, sym_str);
      }
    } else {
      rawlog("OTTSEL probe: func slot read FAILED\n");
    }
  }
  // A1.0 bounded trace: last 48 GOAL->GOAL calls + the last target's code.
  {
    u64 idx = g_ottsel_call_idx;
    u64 base = (u64)g_ee_main_mem;
    // Ring holds 2 slots per call: even = (site<<32)|target, odd = caller LR.
    for (int i = 0; i < 40; i++) {
      u64 v = g_ottsel_call_trace[((idx - 40 + i) * 2) & 255];
      u64 lr = g_ottsel_call_trace[((idx - 40 + i) * 2 + 1) & 255];
      if (v || lr) {
        rawlog("OTTSEL_IOS: trace[%d] site=0x%08x target=0x%08x caller-lr=0x%08x\n", i - 40,
               (unsigned)(v >> 32), (unsigned)(v & 0xffffffff), (unsigned)(lr & 0xffffffff));
      }
    }
    rawlog("OTTSEL_IOS: trace-count=%llu (base=0x%llx)\n", (unsigned long long)idx,
           (unsigned long long)base);
    u64 last = g_ottsel_call_trace[((idx - 1) * 2) & 255];
    uintptr_t tgt = (uintptr_t)(last & 0xffffffff);
    rawlog("OTTSEL_IOS: last-target=0x%08lx words:\n", (unsigned long)tgt);
    for (int i = 0; i < 0x20; i++) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(base + tgt + i * 4), &wt)) {
        rawlog("OTTSEL_IOS:   [%02x] 0x%08x\n", i * 4, wt);
      }
    }
    // S2.1 debug: the code at the LAST recorded call site (the shim + the
    // actual call + what follows).
    uintptr_t site = (uintptr_t)(last >> 32);
    rawlog("OTTSEL_IOS: last-site=0x%08lx code:\n", (unsigned long)site);
    for (int i = -0x20; i < 0x90; i++) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(base + site + i * 4), &wt)) {
        rawlog("OTTSEL_IOS:   [%+d] 0x%08x\n", i * 4, wt);
      }
    }
  }
#endif
  rawlog("OTTSEL_IOS BOOT FAILED (gated): signal %d at pc=0x%lx fault addr=0x%lx\n", sig,
         (unsigned long)pc, (unsigned long)(uintptr_t)info->si_addr);
  u32 fw[4] = {0, 0, 0, 0};
  for (int i = 0; i < 4; i++) {
    safe_read_u32((volatile u32*)(pc + i * 4), &fw[i]);
  }
  rawlog("OTTSEL_IOS: faulting words: 0x%08x 0x%08x 0x%08x 0x%08x\n", fw[0], fw[1], fw[2], fw[3]);
  // S2.1 debug: hold the process alive at the fault so lldb can attach and
  // unwind the faulting thread (the jump source is one step behind pc).
  rawlog("OTTSEL_IOS: HELD AT FAULT for lldb attach (pid %d)\n", (int)getpid());
  for (;;) {
    sleep(3600);
  }
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

  // Ottsel S2.1: the no-emit linker copies each object out of the stage
  // during link (jak1_work_v3 state 0 -> ultimate_memcpy to the final heap
  // location), so a single reusable stage slot suffices.  Staging the whole
  // 22MB CGO from the global heap top left only ~3MB free at object 195 and
  // broke GOAL-side (new ...) allocations (kmalloc !alloc) -- the global heap
  // must stay available for the game engine's own allocations.
  const u32 STAGE_SLOT = 512 * 1024;  // largest object blob is ~110KB
  auto stage = kmalloc(kglobalheap, STAGE_SLOT, KMALLOC_TOP | KMALLOC_ALIGN_64,
                       "ottsel-ios-dgo-stage");
  if (!stage.offset) {
    gated_fail("kmalloc of the reusable DGO stage slot failed");
  }

  // DGO layout: DgoHeader{ u32 object_count; char name[60] }, then per object
  // ObjectHeader{ u32 size; char name[60] } + blob (16-byte aligned).  The
  // DGO is parsed in HOST memory; each object's blob is copied into the
  // reusable EE stage slot right before linking it.
  u32 count = *(u32*)dgo.data();
  lg::info("OTTSEL_IOS: {} has {} objects", cgo_name, count);
  u32 flags = LINK_FLAG_OUTPUT_LOAD | LINK_FLAG_EXECUTE | LINK_FLAG_PRINT_LOGIN;
  u64 off = 64;
  for (u32 i = 0; i < count; i++) {
    u32 size = *(u32*)(dgo.data() + off);
    const char* name = (const char*)(dgo.data() + off + 4);
    u64 blob_off = off + 64;
    u32 blob_size = (size + 15) & ~15u;  // blobs are 16-byte aligned in the DGO
    if (blob_size > STAGE_SLOT) {
      gated_fail("object blob larger than the reusable stage slot");
    }
    memcpy(stage.c(), dgo.data() + blob_off, size);
    lg::info("OTTSEL_IOS: linking object {} ({}) size {}", i, name, size);
    jak1::link_and_exec(stage, name, (int32_t)size, kglobalheap, flags, true);
    off = blob_off + blob_size;
  }
  lg::info("OTTSEL_IOS: {} linked ({} objects)", cgo_name, count);
}

extern "C" void ottsel_ios_load_kernel_from_bundle() {
  // Called from jak1::InitHeapAndSymbol after the GOAL heap + symbols exist.
  ottsel_ios_link_cgo_from_bundle("KERNEL.CGO");
}

void ottsel_ios_run_boot() {
  install_gated_signal_handlers();

  // Ottsel A1.1 (evidence captured): the real KERNEL.CGO slice proof runs
  // first.  Disabled while the A1.0 call-trace probe is active (the offline
  // slice linker does not resolve the trace symbol); re-enable for product
  // builds.
  // ottsel_run_a11_slice_proof();

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
