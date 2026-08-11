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
  // S2.1 (2026-08-10, dispatcher pc=0 probe): dump the frame region ABOVE
  // the fault-time sp.  For a down-growing stack the caller frames (saved
  // x30 / continuation slots) live at sp + N*16; the all-zero memory at sp
  // itself means the transfer-to-zero happened on a fresh region, and the
  // nearest nonzero slots above identify the call chain.
  for (int i = 0; i < 96; i++) {
    uintptr_t addr = sp + i * 16;
    u32 w = 0, w2 = 0;
    if (safe_read_u32((volatile u32*)addr, &w) &&
        safe_read_u32((volatile u32*)(addr + 8), &w2)) {
      raw_write_lit("OTTSEL_IOS: above[");
      raw_write_dec((unsigned)i);
      raw_write_lit("] @0x");
      raw_write_hex(addr);
      raw_write_lit(" = 0x");
      raw_write_hex(w);
      raw_write_lit(" 0x");
      raw_write_hex(w2);
      raw_write_lit("\n");
    }
  }
  // S2.1 (2026-08-10, pc=0 entry-chain probe): also dump BELOW the fault sp
  // (the callee pushes / a pushed return trampoline from the thread-entry
  // machinery would sit at sp-0x..sp for a function entered via
  // reset-and-call / set-to-run-bootstrap).
  for (int i = 1; i <= 64; i++) {
    uintptr_t addr = sp - i * 16;
    u32 w = 0, w2 = 0;
    if (safe_read_u32((volatile u32*)addr, &w) &&
        safe_read_u32((volatile u32*)(addr + 8), &w2)) {
      raw_write_lit("OTTSEL_IOS: below[-");
      raw_write_dec((unsigned)i);
      raw_write_lit("] @0x");
      raw_write_hex(addr);
      raw_write_lit(" = 0x");
      raw_write_hex(w);
      raw_write_lit(" 0x");
      raw_write_hex(w2);
      raw_write_lit("\n");
    }
  }
  // S2.1 (2026-08-10, dispatcher pc=0 probe): the runtime keeps a bounded
  // GOAL->GOAL call ring ('ottsel-goal-call-trace'); dump the last entries so
  // the pc-prof C-export caller is identified without lldb (which cannot read
  // the EE mapping reliably).  Ring slot 2n: (site<<32)|target; 2n+1:
  // (caller_lr & 0xffffffff) | (pp << 32).
  {
    u64 idx = g_ottsel_call_idx;
    raw_write_lit("OTTSEL_IOS: trace-count=");
    raw_write_dec((unsigned)idx);
    raw_write_lit(" last 40 calls:\n");
    u64 first = idx > 40 ? idx - 40 : 0;
    for (u64 i = first; i < idx; i++) {
      u64 v = g_ottsel_call_trace[(i * 2) & 255];
      u64 lr = g_ottsel_call_trace[(i * 2 + 1) & 255];
      if (v || lr) {
        raw_write_lit("  site=0x");
        raw_write_hex(v >> 32);
        raw_write_lit(" target=0x");
        raw_write_hex(v & 0xffffffffu);
        raw_write_lit(" caller-lr=0x");
        raw_write_hex(lr & 0xffffffffu);
        raw_write_lit(" pp=0x");
        raw_write_hex(lr >> 32);
        raw_write_lit("\n");
      }
    }
  }
  // S2.1 (2026-08-10, corrupt-process-type probe): the faulting dispatch
  // (execute-process-tree's run-logic? call) read [this-4] as the type tag and
  // [type+0x40] as the method pointer (x1 at the fault).  Dump the node header
  // and the type object's method slot in-process -- lldb cannot read the
  // Simulator EE mapping reliably, so this is the only trustworthy read.
  {
    // x0 may be an EE-relative offset (method-dispatch faults, e.g. the
    // execute-process-tree run-logic? call) or an absolute EE-mapped pointer
    // (link-phase faults); normalize before reading.
    uintptr_t node = uc->uc_mcontext->__ss.__x[0];
    if (node < 0x8000000) {
      node = (uintptr_t)g_ee_main_mem + node;
    }
    raw_write_lit("OTTSEL_IOS: node probe this=0x");
    raw_write_hex(node);
    raw_write_lit("\n");
    // Skip the PROT_NONE low-EE guard region (first 512KB of the mapping).
      if (node >= (uintptr_t)g_ee_main_mem + 0x80000) {
        // The *active-pool* symbol (0x4f44d4 per the boot debug) and its
        // memory: is the pool a real process-tree or garbage?
        {
          u32 ap = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x4f44d4), &ap)) {
            raw_write_lit("OTTSEL_IOS:   [0x4f44d4]=0x");
            raw_write_hex(ap);
            raw_write_lit("\n");
          }
          u32 ap2 = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x4f44d0), &ap2)) {
            raw_write_lit("OTTSEL_IOS:   [0x4f44d0]=0x");
            raw_write_hex(ap2);
            raw_write_lit("\n");
          }
          // the camera's parent (0x20980c) - dump its header
          {
            raw_write_lit("OTTSEL_IOS:   parent 0x20980c hdr:");
            for (int i = -4; i <= 0x1c; i += 4) {
              u32 w = 0;
              if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x20980c + i), &w)) {
                raw_write_lit(" ");
                raw_write_hex(w);
              }
            }
            raw_write_lit("\n");
          }
        }
        // Camera thread full header: name(0) process(4) previous(8)
        // suspend-hook(C) resume-hook(10) pc(14) sp(18) stack-top(1c) size(20)
        {
          u32 mt = 0;
          if (safe_read_u32((volatile u32*)(node + 0x28), &mt) && mt &&
              mt < 0x08000000) {
            raw_write_lit("OTTSEL_IOS:   cam-thread hdr@0x");
            raw_write_hex(mt);
            raw_write_lit(":");
            for (int i = 0; i <= 0x24; i += 4) {
              u32 w = 0;
              if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + i), &w)) {
                raw_write_lit(" ");
                raw_write_hex(w);
              }
            }
            raw_write_lit("\n");
          }
        }
        // Camera thread details: pc(+0x14), sp(+0x18), stack-top(+0x1c),
        // stack-size(+0x20) -- does the camera's stack cover the pattern
        // region [0x202000..0x207000)?
        {
          u32 mt = 0;
          if (safe_read_u32((volatile u32*)(node + 0x28), &mt) && mt &&
              mt < 0x08000000) {
            u32 pc = 0, sp = 0, stop = 0, ssz = 0;
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + 0x14), &pc);
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + 0x18), &sp);
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + 0x1c), &stop);
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + 0x20), &ssz);
            raw_write_lit("OTTSEL_IOS:   cam-thread pc=0x");
            raw_write_hex(pc);
            raw_write_lit(" sp=0x");
            raw_write_hex(sp);
            raw_write_lit(" stack-top=0x");
            raw_write_hex(stop);
            raw_write_lit(" size=0x");
            raw_write_hex(ssz);
            raw_write_lit("\n");
          }
        }
        // Pattern extent: sample 0x202000..0x209000 every 0x1000 to see where
        // the {valid?,0x70,0,0} pattern ends.
        {
          raw_write_lit("OTTSEL_IOS:   pattern-extent:");
          for (u32 a = 0x202000; a < 0x20a000; a += 0x1000) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + a), &w)) {
              raw_write_lit(" ");
              raw_write_hex(a);
              raw_write_lit("=");
              raw_write_hex(w);
            }
          }
          raw_write_lit("\n");
        }
        // The camera's type = the time-of-day continuation.  The suspend
        // stores its continuation at [pp+0x14].  Find the time-of-day process
        // (via the *time-of-day-proc* static slot 0x2d8 in time-of-day's data)
        // and dump its top-thread + thread pc.
        {
          u32 td_sym_off = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x43cc2d8), &td_sym_off) &&
              td_sym_off < 0x8000000) {
            u32 tod_proc = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x18fe04 + td_sym_off),
                              &tod_proc)) {
              raw_write_lit("OTTSEL_IOS:   tod-proc=0x");
              raw_write_hex(tod_proc);
              raw_write_lit("\n");
              if (tod_proc < 0x08000000) {
                raw_write_lit("OTTSEL_IOS:   tod fields:");
                for (int i = 0x1c; i <= 0x58; i += 4) {
                  u32 w = 0;
                  if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + tod_proc + i),
                                    &w)) {
                    raw_write_lit(" ");
                    raw_write_hex(w);
                  }
                }
                raw_write_lit("\n");
              }
              if (tod_proc >= 0x80000 && tod_proc < 0x08000000) {
                raw_write_lit("OTTSEL_IOS:   tod-thread-region 0x20b880:");
                for (int i = 0; i < 0x60; i += 4) {
                  u32 w = 0;
                  if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x20b880 + i),
                                    &w)) {
                    raw_write_lit(" ");
                    raw_write_hex(w);
                  }
                }
                raw_write_lit("\n");
              }
              u32 tod_top = 0, tod_main = 0;
              if (tod_proc < 0x08000000) {
                if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + tod_proc + 0x2c),
                                  &tod_top)) {
                  raw_write_lit("OTTSEL_IOS:   tod top-thread=0x");
                  raw_write_hex(tod_top);
                  raw_write_lit("\n");
                  if (tod_top < 0x08000000) {
                    u32 pc = 0;
                    if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + tod_top + 0x14),
                                      &pc)) {
                      raw_write_lit("OTTSEL_IOS:   tod thread pc=0x");
                      raw_write_hex(pc);
                      raw_write_lit("\n");
                    }
                  }
                }
              }
            }
          }
        }
        // Confirm what the corrupt type-tag values are in the runtime: dump
        // the code words at 0x3ec0634 and 0x43c4f84 (are they continuations?).
        {
          const u32 sites[] = {0x3ec0630, 0x43c4f80};
          for (u32 site : sites) {
            raw_write_lit("OTTSEL_IOS:   code@0x");
            raw_write_hex(site);
            raw_write_lit(":");
            for (int i = 0; i < 16; i += 4) {
              u32 w = 0;
              if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + site + (uintptr_t)i), &w)) {
                raw_write_lit(" ");
                raw_write_hex(w);
              }
            }
            raw_write_lit("\n");
          }
        }
        // Wide dump: where does the repeating {X,0x70,0,0} pattern start/end?
        {
          raw_write_lit("OTTSEL_IOS:   region-wide 0x202000..0x202600:");
          for (u32 a = 0x202000; a < 0x202600; a += 0x10) {
            u32 w0 = 0, w1 = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + a), &w0) &&
                safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + a + 4), &w1)) {
              raw_write_lit("\n   ");
              raw_write_hex(a);
              raw_write_lit(": ");
              raw_write_hex(w0);
              raw_write_lit(" ");
              raw_write_hex(w1);
            }
          }
          raw_write_lit("\n");
        }
        // Wide dump around the pool (0x202480) and the faulting process
        // (0x206640) to see the overwrite shape (whole-region vs type slots).
        {
          const u32 bases[] = {0x202480, 0x206640};
          for (u32 base : bases) {
            raw_write_lit("OTTSEL_IOS:   region-dump @0x");
            raw_write_hex(base);
            raw_write_lit(":");
            for (int i = 0; i < 0x60; i += 4) {
              u32 w = 0;
              if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + base + (uintptr_t)i), &w)) {
                raw_write_lit(" ");
                raw_write_hex(w);
              }
            }
            raw_write_lit("\n");
          }
        }
        // Corrupt-type pattern: dump the type tag of the pool and every
        // process in the camera pool (0x2024a4 + 0x1070-spaced processes).
        {
          const u32 pool_base = 0x2024a0;
          const u32 procs[] = {0x2024c0, 0x203530, 0x2045a0, 0x205610, 0x206680};
          u32 pv = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + pool_base), &pv)) {
            raw_write_lit("OTTSEL_IOS:   region pool@0x2024a0 tag=0x");
            raw_write_hex(pv);
            raw_write_lit("\n");
          }
          for (u32 pb : procs) {
            u32 tv = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + pb), &tv)) {
              raw_write_lit("OTTSEL_IOS:   region proc@0x");
              raw_write_hex(pb);
              raw_write_lit(" tag=0x");
              raw_write_hex(tv);
              raw_write_lit("\n");
            }
          }
        }
        // The process's pool (proc+0x1c): identify it (type + name).
        {
          u32 pool2 = 0;
          if (safe_read_u32((volatile u32*)(node + 0x1c), &pool2) && pool2 &&
              pool2 < 0x08000000) {
            u32 pt = 0, pn = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + pool2 - 4), &pt)) {
              raw_write_lit("OTTSEL_IOS:   pool=0x");
              raw_write_hex(pool2);
              raw_write_lit(" type=0x");
              raw_write_hex(pt);
            }
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + pool2 + 4), &pn)) {
              raw_write_lit(" name=0x");
              raw_write_hex(pn);
            }
            raw_write_lit("\n");
          }
        }
        // The process's main-thread (proc+0x28): its pc slot (thread+0x14)
        // holds the suspended continuation.  If the process's type tag equals
        // the thread pc, the suspend/resume machinery wrote the continuation
        // into the wrong slot.
        {
          u32 mt = 0;
          if (safe_read_u32((volatile u32*)(node + 0x28), &mt) && mt &&
              mt < 0x08000000) {
            u32 mt_type = 0, mt_pc = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt - 4), &mt_type)) {
              raw_write_lit("OTTSEL_IOS:   main-thread=0x");
              raw_write_hex(mt);
              raw_write_lit(" type=0x");
              raw_write_hex(mt_type);
            }
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + mt + 0x14), &mt_pc)) {
              raw_write_lit(" pc=0x");
              raw_write_hex(mt_pc);
            }
            raw_write_lit("\n");
          }
        }
        // Process identity/state: pool(+0x1c), status(+0x20), pid(+0x24),
        // main-thread(+0x28), top-thread(+0x2c).
        for (int fi = 0x1c; fi <= 0x58; fi += 4) {
          u32 w = 0;
          if (safe_read_u32((volatile u32*)(node + (uintptr_t)fi), &w)) {
            raw_write_lit("OTTSEL_IOS:   proc[");
            raw_write_dec((unsigned)fi);
            raw_write_lit("+] = 0x");
            raw_write_hex(w);
            raw_write_lit("\n");
          }
        }
        for (int i = -8; i <= 0x20; i += 4) {
        u32 w = 0;
        uintptr_t addr = (uintptr_t)node + (uintptr_t)i;
        if (safe_read_u32((volatile u32*)addr, &w)) {
          raw_write_lit("OTTSEL_IOS:   node[");
          raw_write_dec(i >= 0 ? (unsigned)i : (unsigned)(-i));
          raw_write_lit(i >= 0 ? "+] = 0x" : "-] = 0x");
          raw_write_hex(w);
          raw_write_lit("\n");
        }
      }
      u32 type_tag = 0;
      if (node >= 4 && safe_read_u32((volatile u32*)(node - 4), &type_tag)) {
        raw_write_lit("OTTSEL_IOS: node type tag=0x");
        raw_write_hex(type_tag);
        raw_write_lit("\n");
        // Compare with the tree neighbors' type tags: if every pooled node
        // has a code-address tag, the pool init is broken; if only this one,
        // the spawn wrote it.
        for (int fi = 8; fi <= 0x10; fi += 4) {
          u32 nb = 0;
          if (safe_read_u32((volatile u32*)(node + (uintptr_t)fi), &nb) && nb &&
              nb < 0x08000000) {
            u32 nbt = 0;
            if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + nb - 4), &nbt)) {
              raw_write_lit("OTTSEL_IOS:   neighbor@");
              raw_write_dec((unsigned)fi);
              raw_write_lit("+0x");
              raw_write_hex(nb);
              raw_write_lit(" type=0x");
              raw_write_hex(nbt);
              raw_write_lit("\n");
            }
          }
        }
        // GOAL type pointers are EE-relative offsets; read through the EE map.
        const uintptr_t type_abs = (uintptr_t)g_ee_main_mem + type_tag;
        for (int i = 0; i <= 0x48; i += 4) {
          u32 w = 0;
          if (safe_read_u32((volatile u32*)(type_abs + (uintptr_t)i), &w)) {
            raw_write_lit("OTTSEL_IOS:   type[");
            raw_write_dec((unsigned)i);
            raw_write_lit("] = 0x");
            raw_write_hex(w);
            raw_write_lit("\n");
          }
        }
      }
    } else {
      raw_write_lit("OTTSEL_IOS:   (node in PROT_NONE low-EE region; skipped)\n");
    }
  }
  // S2.1 (2026-08-10, process-type source probe): the faulting process's type
  // tag points into the time-of-day code segment.  get-process writes the
  // type symbol's value into the node.  Dump the 'time-of-day-proc symbol's
  // value (s7 = x21 = 0x18fe04; symbol index 2746 -> s7 - 0xaa34 = 0x1853d0,
  // per test/all_jak1_symbols.cpp) and its name, plus the process's own name
  // string, to decide whether the SYMBOL or the WRITE is wrong.
  {
    const uintptr_t ee = (uintptr_t)g_ee_main_mem;
    // Process identity: [this+4] is the process name (a GOAL string).
    u32 name_ptr = 0;
    const uintptr_t node2 = uc->uc_mcontext->__ss.__x[0] < 0x8000000
                                ? (uintptr_t)g_ee_main_mem + uc->uc_mcontext->__ss.__x[0]
                                : uc->uc_mcontext->__ss.__x[0];
    if (node2 >= (uintptr_t)g_ee_main_mem + 0x80000 && safe_read_u32((volatile u32*)(node2 + 4), &name_ptr) && name_ptr &&
        name_ptr < 0x08000000) {
      raw_write_lit("OTTSEL_IOS: process name str=0x");
      raw_write_hex(name_ptr);
      raw_write_lit(" bytes:");
      for (int i = 0; i < 0x24; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(ee + name_ptr + (uintptr_t)i), &w)) {
          raw_write_lit(" ");
          raw_write_hex(w);
        }
      }
      raw_write_lit("\n");
    }
    u32 sym_val = 0;
    // Read the real s7 (GOAL symbol-table-mid register) from its global.
    const u32 s7_val = s7.offset;
    raw_write_lit("OTTSEL_IOS: s7=0x");
    raw_write_hex(s7_val);
    raw_write_lit("\n");
    // The time-of-day spawn (start-time-of-day in time-of-day.gc) loads its
    // pool/type/name/init args from static slots in time-of-day's data segment
    // (main seg 0x43c4000, code 0x8000).  Dump the slots and the symbol values
    // they resolve to.
    {
      const u32 static_base = 0x43c4000 + 0x8000;
      // The spawn's type object (0x14bfb84) fields.
      {
        u32 tv2 = 0;
        raw_write_lit("OTTSEL_IOS: spawn type 0x14bfb84 fields:");
        for (int i = 0; i <= 0x44; i += 4) {
          if (safe_read_u32((volatile u32*)(ee + 0x14bfb84 + (uintptr_t)i), &tv2)) {
            raw_write_lit(" ");
            raw_write_hex(tv2);
          }
        }
        raw_write_lit("\n");
      }
      // The faulting node's pool (0x2024a4): read its child process's type tag.
      {
        u32 pool_child = 0;
        if (safe_read_u32((volatile u32*)(ee + 0x2024a4 + 0x10), &pool_child) && pool_child &&
            pool_child < 0x08000000) {
          u32 child_type = 0;
          if (safe_read_u32((volatile u32*)(ee + pool_child - 4), &child_type)) {
            raw_write_lit("OTTSEL_IOS: pool sibling child=0x");
            raw_write_hex(pool_child);
            raw_write_lit(" type=0x");
            raw_write_hex(child_type);
            raw_write_lit("\n");
          }
        }
      }
      const u32 slots[] = {0x28c, 0x290, 0x294, 0x298, 0x29c, 0x2a0, 0x2a4, 0x2a8};
      for (u32 off : slots) {
        u32 sym_off = 0;
        if (safe_read_u32((volatile u32*)(ee + static_base + off), &sym_off)) {
          raw_write_lit("OTTSEL_IOS: spawn slot +0x");
          raw_write_hex(off);
          raw_write_lit(" sym_off=0x");
          raw_write_hex(sym_off);
          u32 sym_val = 0;
          if (sym_off < 0x8000000 && safe_read_u32((volatile u32*)(ee + s7_val + sym_off), &sym_val)) {
            raw_write_lit(" value=0x");
            raw_write_hex(sym_val);
          }
          raw_write_lit("\n");
        }
      }
      // The get-process receiver is *default-dead-pool* (slot +0x298 value).
      // Read its type and the get-process method it dispatches (type+0x48),
      // to tell the dead-pool (buggy store) path from dead-pool-heap (correct).
      u32 pool = 0;
      u32 pool_off = 0;
      if (safe_read_u32((volatile u32*)(ee + static_base + 0x298), &pool_off) &&
          safe_read_u32((volatile u32*)(ee + s7_val + pool_off), &pool)) {
        u32 pool_type = 0;
        if (pool < 0x08000000 && safe_read_u32((volatile u32*)(ee + pool - 4), &pool_type)) {
          raw_write_lit("OTTSEL_IOS: pool=0x");
          raw_write_hex(pool);
          raw_write_lit(" type=0x");
          raw_write_hex(pool_type);
          u32 gp_method = 0;
          if (pool_type < 0x08000000 &&
              safe_read_u32((volatile u32*)(ee + pool_type + 0x48), &gp_method)) {
            raw_write_lit(" get-process-method=0x");
            raw_write_hex(gp_method);
          }
          raw_write_lit("\n");
        }
      }
    }
    // Identify the get-process implementation the pool dispatches to: dump
    // the runtime words at the expected dead-pool (0x3ed2ef4) and
    // dead-pool-heap (0x3ed4208) sites and the actual method (0x3ed37e4).
    {
      const u32 sites[] = {0x3ed2ef4, 0x3ed37e4, 0x3ed4208};
      for (u32 site : sites) {
        raw_write_lit("OTTSEL_IOS: code@0x");
        raw_write_hex(site);
        raw_write_lit(":");
        for (int i = 0; i < 8; i += 4) {
          u32 w = 0;
          if (safe_read_u32((volatile u32*)(ee + site + (uintptr_t)i), &w)) {
            raw_write_lit(" ");
            raw_write_hex(w);
          }
        }
        raw_write_lit("\n");
      }
    }
    // The process's name field ([this+0] = 0x70) is the s7-relative offset of
    // the 'time-of-day-proc symbol (the `n` macro names the process after the
    // type).  Read that symbol's value + name directly.
    {
      const u32 tod_sym = s7_val + 0x70;
      u32 tv = 0;
      if (safe_read_u32((volatile u32*)(ee + tod_sym), &tv)) {
        raw_write_lit("OTTSEL_IOS: sym(time-of-day-proc@");
        raw_write_hex(tod_sym);
        raw_write_lit(") value=0x");
        raw_write_hex(tv);
        raw_write_lit("\n");
        u32 sym_hash = 0;
        if (safe_read_u32((volatile u32*)(ee + tod_sym + 0x1fffc), &sym_hash)) {
          raw_write_lit("OTTSEL_IOS:   symhash=0x");
          raw_write_hex(sym_hash);
          raw_write_lit(" (expect 0x4b64a867 for time-of-day-proc)\n");
        }
        u32 strp = 0;
        if (safe_read_u32((volatile u32*)(ee + tod_sym + 0x1fffc + 4), &strp) && strp &&
            strp < 0x08000000) {
          raw_write_lit("OTTSEL_IOS:   str=0x");
          raw_write_hex(strp);
          raw_write_lit("\n");
          raw_write_lit("OTTSEL_IOS:   name bytes:");
          for (int i = 0; i < 0x18; i += 4) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)(ee + strp + (uintptr_t)i), &w)) {
              raw_write_lit(" ");
              raw_write_hex(w);
            }
          }
          raw_write_lit("\n");
        }
        if (tv && tv < 0x08000000) {
          raw_write_lit("OTTSEL_IOS:   type fields:");
          for (int i = 0; i <= 0x44; i += 4) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)(ee + tv + (uintptr_t)i), &w)) {
              raw_write_lit(" ");
              raw_write_hex(w);
            }
          }
          raw_write_lit("\n");
        }
      }
    }
    // Sanity: the kernel symlink log bound 'array at s7 + 0xf8; dump slots
    // around there to confirm the table geometry.
    for (u32 slot = s7_val + 0xf0; slot < s7_val + 0x140; slot += 8) {
      u32 v = 0;
      if (safe_read_u32((volatile u32*)(ee + slot), &v)) {
        raw_write_lit("OTTSEL_IOS: near-s7 slot 0x");
        raw_write_hex(slot);
        raw_write_lit(" value=0x");
        raw_write_hex(v);
        raw_write_lit("\n");
      }
    }
    // 'time-of-day-proc: crc32c = 0x4b64a867 (ARM __crc32cw), sh2 =
    // s32(hash<<18)>>15 = -0xbd00 -> lower table, probe up from s7 - 0xbd00.
    const u32 tod_probe_start = s7_val - 0xbd00;
    for (u32 slot = tod_probe_start; slot < tod_probe_start + 0x100; slot += 8) {
      u32 v = 0;
      if (!safe_read_u32((volatile u32*)(ee + slot), &v)) {
        continue;
      }
      u32 str_ptr = 0;
      safe_read_u32((volatile u32*)(ee + slot + 0x1fffc + 4), &str_ptr);
      raw_write_lit("OTTSEL_IOS: sym slot 0x");
      raw_write_hex(slot);
      raw_write_lit(" value=0x");
      raw_write_hex(v);
      raw_write_lit(" str=0x");
      raw_write_hex(str_ptr);
      raw_write_lit("\n");
      if (str_ptr && str_ptr < 0x08000000) {
        raw_write_lit("OTTSEL_IOS:   name bytes:");
        for (int i = 0; i < 0x14; i += 4) {
          u32 w = 0;
          if (safe_read_u32((volatile u32*)(ee + str_ptr + (uintptr_t)i), &w)) {
            raw_write_lit(" ");
            raw_write_hex(w);
          }
        }
        raw_write_lit("\n");
      }
    }
  }
  // S2.1 (2026-08-10, link-phase fault probe): the fault pc is inside a
  // transient top-level segment; dump the runtime-patched code words around pc
  // and lr so the dispatch (ADRP/ADD/load/blr chain) can be decoded without
  // trusting the unpatched CGO file bytes.
  {
    // pc is the fault target (unmapped garbage); dump the caller's code around
    // lr instead (a mapped code address in the object/kernel region).
    const uintptr_t flr = uc->uc_mcontext->__ss.__lr;
    raw_write_lit("OTTSEL_IOS: code probe lr=0x");
    raw_write_hex(flr);
    raw_write_lit("\n");
    for (int i = -0x40; i <= 0x20; i += 4) {
      u32 w = 0;
      uintptr_t addr = flr + (uintptr_t)i;
      if (safe_read_u32((volatile u32*)addr, &w)) {
        raw_write_lit("OTTSEL_IOS:   pc[");
        raw_write_dec(i >= 0 ? (unsigned)i : (unsigned)(-i));
        raw_write_lit(i >= 0 ? "+] = 0x" : "-] = 0x");
        raw_write_hex(w);
        raw_write_lit("\n");
      }
    }
  }
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
  // S2.1 (2026-08-10, AND-encoder fix boot): object 323 `eichar` is
  // 1,349,024 bytes and `sidekick` 675,936 -- the old 512KB slot assumed
  // ~110KB max.  Sized from the actual GAME.CGO object list (max 1,349,024,
  // 16-byte aligned); 2MB covers every object with margin while the reusable
  // slot keeps the global heap top available for game allocations.
  const u32 STAGE_SLOT = 2 * 1024 * 1024;
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
