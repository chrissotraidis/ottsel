// Ottsel A1.1 — execute the real KERNEL.CGO slice from signed Mach-O __TEXT
// on the iPad Simulator.  The slice (string=, name=, ref, last, nmember) is
// emitted offline by tools/ottsel_a1_1 and linked into this app's __TEXT.
// The offline linker resolved instruction relocations; only the writable
// function/type-pointer tables are filled at runtime (allowed by A1.2).
//
// Address model: offset (x22) = 0x100000000 so u32 GOAL pointers =
// host - 0x100000000.  st (x21) = data base + 0xa - off (GOAL-relative), so
// the slot math slot + st + off yields the target host address.

#import <Foundation/Foundation.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>

#include "a11_slice_map.h"

extern "C" void ottsel_a11_slice_code();
extern "C" void ottsel_a11_slice_data();

using u8 = unsigned char;
using u32 = unsigned int;
using u64 = unsigned long long;

// The game's proven GOAL-entry bridge (asm_funcs_arm64.s): sets x21=st,
// x22=offset, blr to the function, restores the caller's regs.
extern "C" u64 _call_goal_asm_arm64(u64 a, u64 b, u64 c, void* fptr, void* st, void* offset) asm(
    "_call_goal_asm_arm64");

static u64 goal_call(void* fn, u64 a0, u64 a1, u64 st, u64 off) {
  return _call_goal_asm_arm64(a0, a1, 0, fn, (void*)st, (void*)off);
}

extern "C" int ottsel_run_a11_slice_proof() {
  u8* code = (u8*)&ottsel_a11_slice_code;
  u8* data = (u8*)&ottsel_a11_slice_data;
  u64 off = A11_OFFSET_BASE;
  u8* st = data + A11_ST_OFF - A11_IMG_DATA - off;
  NSLog(@"[A1.1] code=%p data=%p st=%p off=0x%llx", code, data, st, (unsigned long long)off);

  auto gp = [&](void* host) -> u32 { return (u32)((u64)host - off); };
  auto img = [&](u64 img_off) -> u8* {
    return img_off >= A11_IMG_DATA ? data + (img_off - A11_IMG_DATA) : code + img_off;
  };
  auto put = [&](u64 img_off, u32 v) { *(u32*)img(img_off) = v; };

  // Test objects must live at host addresses < 2^33 so GOAL pointers
  // (host - 0x100000000) fit in u32: allocate them inside the slice's own
  // writable __DATA instead of the heap (Simulator malloc lands at
  // 0x600000000000+, which overflows the u32 model).
  u8* heap_next = data + 0x2000;
  auto balloc = [&](size_t n) -> u8* {
    u8* p = heap_next;
    heap_next += (n + 15) & ~15u;
    return p;
  };

  // Runtime function/type-pointer tables (writable data, allowed).
  put(A11_SYM_STRING_EQ, gp(img(A11_FN_STRING_EQ)));
  put(A11_SYM_NAME, gp(img(A11_FN_NAME)));
  put(A11_SYM_STRING, gp(img(A11_TYPE_STRING)));
  put(A11_SYM_SYMBOL, gp(img(A11_TYPE_SYMBOL)));
  put(A11_SYM_STS, gp(img(A11_TYPE_SYMBOL)));  // placeholder; never called by the checks

  // Test objects.
  auto make_string = [&](const char* s) -> u8* {
    size_t n = strlen(s) + 1;
    u8* buf = balloc(n + 8);
    memset(buf, 0, n + 8);
    u32 tag = gp(img(A11_TYPE_STRING));
    std::memcpy(buf, &tag, 4);
    u32 size = (u32)n;
    std::memcpy(buf + 4, &size, 4);
    std::memcpy(buf + 8, s, n);
    return buf + 4;
  };
  auto make_pair = [&](void* car_host, void* cdr_host) -> u32 {
    u8* buf = balloc(8);
    memset(buf, 0, 8);
    u32 car = gp(car_host);
    u32 cdr = gp(cdr_host);
    std::memcpy(buf + 0, &car, 4);
    std::memcpy(buf + 4, &cdr, 4);
    return gp(buf + 2);  // pair value = data + PAIR_OFFSET(2)
  };

  u8* sa = make_string("jak");
  u8* sb = make_string("jak");
  u8* sc = make_string("daxter");
  NSLog(@"[A1.1] dbg sa=%p sb=%p sc=%p gp(sa)=0x%x tag=0x%x size=%u chars='%s'",
        sa, sb, sc, gp(sa), *(u32*)(sa - 4), *(u32*)sa, (char*)(sa + 4));
  u8* sbuf = (u8*)((u64)gp(sa) + off);
  NSLog(@"[A1.1] dbg sa_host=%p sa_host-4=0x%x sa_host+4=0x%08x 0x%08x 0x%08x",
        sbuf, *(u32*)(sbuf - 4), *(u32*)(sbuf + 4), *(u32*)(sbuf + 8), *(u32*)(sbuf + 12));
  void* empty = data;
  u32 pairB = make_pair(sa, empty);
  u32 pairA = make_pair(sc, (void*)((u64)pairB + off));

  int fails = 0;
  auto check = [&](bool ok, const char* what) {
    NSLog(@"[A1.1] %s %s", ok ? "ok  " : "FAIL", what);
    if (!ok) fails++;
  };

  u64 r1 = goal_call((void*)img(A11_FN_STRING_EQ), gp(sa), gp(sb), (u64)st, off);
  check(r1 != (u64)st, "string=(jak jak) == #t");
  u64 r2 = goal_call((void*)img(A11_FN_STRING_EQ), gp(sa), gp(sc), (u64)st, off);
  check(r2 == (u64)st, "string=(jak daxter) == #f");
  u64 r3 = goal_call((void*)img(A11_FN_NAME), gp(sa), gp(sb), (u64)st, off);
  check(r3 != (u64)st, "name=(jak jak) == #t (type dispatch -> string=)");
  u64 r4 = goal_call((void*)img(A11_FN_REF), (u64)pairA, 0, (u64)st, off);
  check(r4 == gp(sc), "ref(list,0) == sc");
  u64 r5 = goal_call((void*)img(A11_FN_REF), (u64)pairA, 1, (u64)st, off);
  check(r5 == gp(sa), "ref(list,1) == sa");
  u64 r6 = goal_call((void*)img(A11_FN_LAST), (u64)pairA, 0, (u64)st, off);
  check(r6 == pairB, "last(list) == pairB");
  u64 r7 = goal_call((void*)img(A11_FN_NMEMBER), gp(sa), (u64)pairA, (u64)st, off);
  check(r7 == pairB, "nmember(sa, list) == pairB (dispatch -> name=)");

  if (fails == 0) {
    NSLog(@"[A1.1] SIMULATOR SLICE PASS (signed __TEXT)");
    return 0;
  }
  NSLog(@"[A1.1] SIMULATOR SLICE FAIL (%d)", fails);
  return 1;
}
