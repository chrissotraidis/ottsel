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
#include <fcntl.h>
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
#include "game/mips2c/mips2c_table.h"
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
int g_fault_log_fd = -1;

// The gated fault handler may only use async-signal-safe operations.  Keep
// its formatting local and write directly to the app's fault log and stderr.
void raw_write(const char* data, size_t size) {
  write(2, data, size);
  if (g_fault_log_fd >= 0) {
    write(g_fault_log_fd, data, size);
  }
}

void raw_write_lit(const char* text) {
  size_t size = 0;
  while (text[size]) {
    size++;
  }
  raw_write(text, size);
}

void raw_write_hex(uintptr_t value) {
  char buf[2 + sizeof(value) * 2];
  static constexpr char hex[] = "0123456789abcdef";
  buf[0] = '0';
  buf[1] = 'x';
  for (size_t i = 0; i < sizeof(value) * 2; i++) {
    buf[2 + i] = hex[(value >> ((sizeof(value) * 2 - i - 1) * 4)) & 0xf];
  }
  raw_write(buf, sizeof(buf));
}

void raw_write_dec(unsigned value) {
  char buf[10];
  size_t count = 0;
  do {
    buf[count++] = char('0' + (value % 10));
    value /= 10;
  } while (value);
  for (size_t i = 0; i < count / 2; i++) {
    char tmp = buf[i];
    buf[i] = buf[count - i - 1];
    buf[count - i - 1] = tmp;
  }
  raw_write(buf, count);
}

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
  uintptr_t sp = uc->uc_mcontext->__ss.__sp;
  raw_write_lit("OTTSEL_IOS: fault pc=");
  raw_write_hex(pc);
  raw_write_lit(" lr=");
  raw_write_hex(lr);
  raw_write_lit("\nOTTSEL_IOS: fault sp=");
  raw_write_hex(sp);
  raw_write_lit("\nOTTSEL_IOS: regs x0=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[0]);
  raw_write_lit(" x1=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[1]);
  raw_write_lit(" x2=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[2]);
  raw_write_lit(" x3=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[3]);
  raw_write_lit(" x16=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[16]);
  raw_write_lit(" x20=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[20]);
  raw_write_lit(" x21=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[21]);
  raw_write_lit(" x22=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[22]);
  raw_write_lit("\n");
  // These broad stack/probe dumps were useful during the earlier rfn fault,
  // but are not async-signal-safe enough for arbitrary later faults.
#if 0
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
  // S2.1 debug (TEMPORARY): these probes dereference GOAL-only addresses.
  // A host-native fault (for example SDL renderer setup) must not re-fault
  // inside this handler before its own backtrace can be captured.
  const uintptr_t ee_for_probe = (uintptr_t)g_ee_main_mem;
  // The original trace4-specific probes assume a process-spawn parameter
  // layout.  They are not valid for arbitrary GAME faults and can re-fault
  // while dereferencing a small non-pointer register value.
  if (false && pc >= ee_for_probe && pc < ee_for_probe + 0x08000000) {
  // Dump the process-spawn func-slot chain so the
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
    u32 rfn = 0;
    if (safe_read_u32((volatile u32*)(ee + 0x19627c), &rfn)) {
      rawlog("OTTSEL probe: run-function-in-process sym value@0x19627c = 0x%08x\n", rfn);
    }
    // The func-lookup ADRP+ADD in the no-trace time-of-day main (offset 0x12e0).
    u32 la0 = 0, la1 = 0, la2 = 0, la3 = 0;
    if (safe_read_u32((volatile u32*)(ee + 0x23792e0), &la0) &&
        safe_read_u32((volatile u32*)(ee + 0x23792e4), &la1) &&
        safe_read_u32((volatile u32*)(ee + 0x23792e8), &la2) &&
        safe_read_u32((volatile u32*)(ee + 0x23792ec), &la3)) {
      rawlog("OTTSEL probe: func-lookup adrp+add @0x23792e0 = 0x%08x 0x%08x 0x%08x 0x%08x\n", la0,
             la1, la2, la3);
    } else {
      rawlog("OTTSEL probe: func-lookup adrp read FAILED\n");
    }
    // param-array contents (the func-call args) at the fault's s2 (x23).
    u32 p0 = 0, p1 = 0, p2 = 0;
    uintptr_t par = (uintptr_t)uc->uc_mcontext->__ss.__x[23];
    if (safe_read_u32((volatile u32*)(ee + par + 0), &p0) &&
        safe_read_u32((volatile u32*)(ee + par + 8), &p1) &&
        safe_read_u32((volatile u32*)(ee + par + 16), &p2)) {
      rawlog("OTTSEL probe: param-block@0x%lx = 0x%08x 0x%08x 0x%08x\n",
             (unsigned long)par, p0, p1, p2);
    }
    // The catch-frame chain: pp (x20) -> stack-frame-top (+0x58) -> the
    // catch-frame; dump its ra (+0xc) and sp (+8) fields.
    uintptr_t ppv = (uintptr_t)uc->uc_mcontext->__ss.__x[20];
    u32 cfr = 0;
    if (safe_read_u32((volatile u32*)(ee + ppv + 0x58), &cfr)) {
      u32 ra = 0, sp8 = 0, nm = 0;
      safe_read_u32((volatile u32*)(ee + cfr + 0x0), &nm);
      safe_read_u32((volatile u32*)(ee + cfr + 0x8), &sp8);
      safe_read_u32((volatile u32*)(ee + cfr + 0xc), &ra);
      rawlog("OTTSEL probe: pp=0x%lx catch-frame=0x%08x name=0x%08x sp=0x%08x ra=0x%08x\n",
             (unsigned long)ppv, cfr, nm, sp8, ra);
    }
  }
  // S2.1 debug (TEMPORARY): dump the code around the faulting blr and the
  // run-function-in-process catch-frame-new func-lookup chain so the
  // x16-vs-pp corruption at the real call can be pinned down.
  {
    const uintptr_t ee2 = (uintptr_t)g_ee_main_mem;
    // S2.1 (asr fix): the caller's epilogue now pops its saved x30 (the
    // run-function-in-process GOAL-relative value 0x1e7004) and rets to it
    // raw.  Dump the code at the ret target and the return-address chain
    // found on the stack so the x30 source can be identified.
    rawlog("OTTSEL probe: ret-target code @ee+0x1e7004:\n");
    for (u32 a = 0x1e6fe0; a < 0x1e7040; a += 4) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(ee2 + a), &wt)) {
        rawlog("OTTSEL probe:   0x%08x: 0x%08x\n", a, wt);
      }
    }
    rawlog("OTTSEL probe: rfn+0x118 @ee+0x1e711c:\n");
    for (u32 a = 0x1e70f0; a < 0x1e7150; a += 4) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(ee2 + a), &wt)) {
        rawlog("OTTSEL probe:   0x%08x: 0x%08x\n", a, wt);
      }
    }
    // The faulting site: lr-4 is the blr; dump lr-0x30 .. lr+0x10.
    const uintptr_t lrv = (uintptr_t)lr;
    rawlog("OTTSEL probe: fault-site code around lr=0x%lx:\n", (unsigned long)lrv);
    for (int i = -0x30; i < 0x20; i += 4) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(lrv + i), &wt)) {
        rawlog("OTTSEL probe:   [%+d] 0x%08x\n", (int)i, wt);
      }
    }
    // The full run-function-in-process catch-frame-new shim region:
    // func-lookup at 0x1f2730 .. real call at 0x1f284c.
    rawlog("OTTSEL probe: shim region 0x1f2720-0x1f2860:\n");
    for (u32 a = 0x1f2720; a < 0x1f2860; a += 4) {
      u32 wt = 0;
      if (safe_read_u32((volatile u32*)(ee2 + a), &wt)) {
        rawlog("OTTSEL probe:   0x%08x: 0x%08x\n", a, wt);
      }
    }
    // catch-frame-new call func chain: slot@0x1f529c -> sym -> value ->
    // new-method at value+0x10 (kernel base 0x1e4000, st = x21).
    const uintptr_t st2 = (uintptr_t)uc->uc_mcontext->__ss.__x[21];
    u32 slot = 0, symval = 0, method = 0;
    if (safe_read_u32((volatile u32*)(ee2 + 0x1f529c), &slot)) {
      rawlog("OTTSEL probe: cfn slot@0x1f529c = 0x%08x st=0x%lx\n", slot, (unsigned long)st2);
      if (safe_read_u32((volatile u32*)(ee2 + slot + st2 + 0), &symval)) {
        rawlog("OTTSEL probe: cfn sym@0x%lx value=0x%08x\n", (unsigned long)(slot + st2), symval);
        if (safe_read_u32((volatile u32*)(ee2 + symval + 0x10), &method)) {
          rawlog("OTTSEL probe: cfn new-method@0x%lx = 0x%08x\n",
                 (unsigned long)(symval + 0x10), method);
        }
      }
    }
    // The GAME-side chain that corrupted pp: 0x1f21794 / 0x1f21870 /
    // 0x1f219c0 (init-time-of-day -> ... -> gcommon 0x1c5f64 -> stub).
    const u32 game_sites[] = {0x1f21794, 0x1f21870, 0x1f219c0, 0x1c5f64, 0x1c6014};
    for (u32 gs : game_sites) {
      rawlog("OTTSEL probe: code @0x%08x:\n", gs);
      for (int i = 0; i < 0x60; i += 4) {
        u32 wt = 0;
        if (safe_read_u32((volatile u32*)(ee2 + gs + i), &wt)) {
          rawlog("OTTSEL probe:   [%02x] 0x%08x\n", i, wt);
        }
      }
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
        rawlog("OTTSEL_IOS: trace[%d] site=0x%08x target=0x%08x caller-lr=0x%08x pp=0x%08x\n",
               i - 40, (unsigned)(v >> 32), (unsigned)(v & 0xffffffff),
               (unsigned)(lr & 0xffffffff), (unsigned)(lr >> 32));
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
#endif
  raw_write_lit("OTTSEL_IOS BOOT FAILED (gated): signal ");
  raw_write_dec((unsigned)sig);
  raw_write_lit(" at pc=");
  raw_write_hex(pc);
  raw_write_lit(" fault addr=");
  raw_write_hex((uintptr_t)info->si_addr);
  raw_write_lit("\n");
#if 0
  u32 fw[4] = {0, 0, 0, 0};
  for (int i = 0; i < 4; i++) {
    safe_read_u32((volatile u32*)(pc + i * 4), &fw[i]);
  }
  rawlog("OTTSEL_IOS: faulting words: 0x%08x 0x%08x 0x%08x 0x%08x\n", fw[0], fw[1], fw[2], fw[3]);
#endif
  // S2.1 debug: hold the process alive at the fault so lldb can attach and
  // unwind the faulting thread (the jump source is one step behind pc).
  raw_write_lit("OTTSEL_IOS: HELD AT FAULT for lldb attach (pid ");
  raw_write_dec((unsigned)getpid());
  raw_write_lit(")\n");
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
  if (g_fault_log_fd >= 0) {
    close(g_fault_log_fd);
  }
  g_fault_log_fd = open((g_bundle_dir + "ottsel-fault.log").c_str(),
                        O_WRONLY | O_CREAT | O_TRUNC, 0644);
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

  // This replaces the host's load_and_link_dgo_from_c path, which holds
  // *enable-method-set* for the entire package load.  A CGO can define a
  // parent method after child types have been linked; keep inheritance
  // propagation enabled until every top-level has run.
  *EnableMethodSet += 1;
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
  *EnableMethodSet -= 1;
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
    // Match the native boot order: linking GAME invokes Mips2C callbacks,
    // so register their C exports while arena B is writable, then seal it
    // before any GAME top-level can call one.
    Mips2C::register_all_jak1();
    jak1::ottsel_stub_flip_phase_b();
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
