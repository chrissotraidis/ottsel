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
#include <array>
#include <limits>
#include <stdexcept>
#include <mach/mach.h>
#include <mach/vm_map.h>

#include "a11_slice_map.h"

extern "C" void ottsel_a11_slice_code();
extern "C" void ottsel_a11_slice_data();

using u8 = unsigned char;
using u32 = unsigned int;
using u64 = unsigned long long;

namespace {
// Match Jak 1's symbol->string macro; the slice declares it as a function
// specifically to exercise a GOAL-to-C call, unlike the production macro.
constexpr size_t kSymbolStringOffset = 0x20000;
alignas(16) std::array<u8, kSymbolStringOffset + 0x1000> fixture_storage{};
u64 export_offset = 0;
unsigned export_calls = 0;
unsigned rebound_calls = 0;

u32 checked_goal_pointer(uintptr_t host, u64 offset) {
  if (host < offset || host - offset > std::numeric_limits<u32>::max()) {
    throw std::runtime_error("A1.1 address does not fit the 32-bit GOAL window");
  }
  return static_cast<u32>(host - offset);
}

u64 symbol_string(u64 symbol) {
  ++export_calls;
  // Only the fixture's bounded symbol storage is accepted by this proof.
  const uintptr_t begin = reinterpret_cast<uintptr_t>(fixture_storage.data());
  if (symbol > std::numeric_limits<u32>::max() || symbol + export_offset < begin ||
      symbol + export_offset - begin > fixture_storage.size() - kSymbolStringOffset - 4) {
    std::abort();
  }
  u32 result = 0;
  std::memcpy(&result, reinterpret_cast<const void*>(symbol + export_offset + kSymbolStringOffset), 4);
  return result;
}

u64 rebound_symbol_string(u64 symbol) {
  ++rebound_calls;
  return symbol_string(symbol);
}

bool has_permissions(const void* pointer, vm_prot_t required, vm_prot_t forbidden) {
  vm_address_t address = reinterpret_cast<vm_address_t>(pointer);
  vm_size_t size = 0;
  vm_region_basic_info_data_64_t info{};
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object = MACH_PORT_NULL;
  const auto result = vm_region_64(mach_task_self(), &address, &size,
      VM_REGION_BASIC_INFO_64, reinterpret_cast<vm_region_info_t>(&info), &count, &object);
  if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
  return result == KERN_SUCCESS && address <= reinterpret_cast<uintptr_t>(pointer) &&
         (info.protection & required) == required && (info.protection & forbidden) == 0;
}
}  // namespace

// The C target alone is mutable. The shim is assembled into signed __TEXT,
// using the same target-stack convention as make_function_from_c_systemv.
extern "C" {
u64 (*ottsel_a11_export_target)(u64) = nullptr;
void ottsel_a11_export_shim();
}
asm(".text\n.balign 4\n.globl _ottsel_a11_export_shim\n"
    "_ottsel_a11_export_shim:\n"
    "adrp x16, _ottsel_a11_export_target@PAGE\n"
    "ldr x16, [x16, _ottsel_a11_export_target@PAGEOFF]\n"
    "str x16, [sp, #-16]!\n"
    "b _arg_call_arm64\n");

// The game's proven GOAL-entry bridge (asm_funcs_arm64.s): sets x21=st,
// x22=offset, blr to the function, restores the caller's regs.
extern "C" u64 _call_goal_asm_arm64(u64 a, u64 b, u64 c, void* fptr, void* st, void* offset) asm(
    "_call_goal_asm_arm64");

static u64 goal_call(void* fn, u64 a0, u64 a1, u64 st, u64 off) {
  return _call_goal_asm_arm64(a0, a1, 0, fn, (void*)st, (void*)off);
}

extern "C" int ottsel_run_a11_slice_proof() try {
  u8* code = (u8*)&ottsel_a11_slice_code;
  u8* data = (u8*)&ottsel_a11_slice_data;
  u64 off = A11_OFFSET_BASE;
  u64 st = checked_goal_pointer(reinterpret_cast<uintptr_t>(data) + A11_ST_OFF - A11_IMG_DATA, off);
  NSLog(@"[A1.1] code=%p data=%p st=0x%llx off=0x%llx", code, data, st, off);

  auto gp = [&](const void* host) -> u32 { return checked_goal_pointer(reinterpret_cast<uintptr_t>(host), off); };
  auto img = [&](u64 img_off) -> u8* {
    return img_off >= A11_IMG_DATA ? data + (img_off - A11_IMG_DATA) : code + img_off;
  };
  auto put = [&](u64 img_off, u32 v) {
    if (img_off < A11_IMG_DATA) throw std::runtime_error("A1.1 attempted text relocation");
    std::memcpy(img(img_off), &v, sizeof(v));
  };

  // Test objects must live at host addresses < 2^33 so GOAL pointers
  // (host - 0x100000000) fit in u32: allocate them inside the slice's own
  // writable __DATA instead of the heap (Simulator malloc lands at
  // 0x600000000000+, which overflows the u32 model).
  fixture_storage.fill(0);
  u8* heap_next = fixture_storage.data();
  auto balloc = [&](size_t n) -> u8* {
    if (n > 0x1000 || heap_next - fixture_storage.data() + ((n + 15) & ~size_t(15)) > 0x1000)
      throw std::runtime_error("A1.1 fixture storage exhausted");
    u8* p = heap_next;
    heap_next += (n + 15) & ~size_t(15);
    return p;
  };

  // Runtime function/type-pointer tables (writable data, allowed).
  put(A11_SYM_STRING_EQ, gp(img(A11_FN_STRING_EQ)));
  put(A11_SYM_NAME, gp(img(A11_FN_NAME)));
  put(A11_SYM_STRING, gp(img(A11_TYPE_STRING)));
  put(A11_SYM_SYMBOL, gp(img(A11_TYPE_SYMBOL)));
  put(A11_SYM_STS, gp(reinterpret_cast<void*>(&ottsel_a11_export_shim)));
  export_offset = off;
  export_calls = rebound_calls = 0;
  ottsel_a11_export_target = symbol_string;

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

  std::array<u8, A11_IMG_DATA> original_text{};
  std::array<u8, 16> original_shim{};
  std::memcpy(original_text.data(), code, original_text.size());
  std::memcpy(original_shim.data(), reinterpret_cast<void*>(&ottsel_a11_export_shim), original_shim.size());
  check(has_permissions(code, VM_PROT_READ | VM_PROT_EXECUTE, VM_PROT_WRITE), "slice text is RX, not writable");
  check(has_permissions(reinterpret_cast<void*>(&ottsel_a11_export_shim), VM_PROT_READ | VM_PROT_EXECUTE, VM_PROT_WRITE), "static shim is RX, not writable");
  check(has_permissions(&ottsel_a11_export_target, VM_PROT_READ | VM_PROT_WRITE, VM_PROT_EXECUTE), "target slot is RW, not executable");
  check(has_permissions(data, VM_PROT_READ | VM_PROT_WRITE, VM_PROT_EXECUTE), "slice data is RW, not executable");
  check(checked_goal_pointer(off, off) == 0 &&
        checked_goal_pointer(off + std::numeric_limits<u32>::max(), off) == std::numeric_limits<u32>::max(), "GOAL pointer window boundaries");
  for (uintptr_t invalid : {static_cast<uintptr_t>(off - 1), static_cast<uintptr_t>(off + (1ull << 32))}) {
    bool rejected = false;
    try { (void)checked_goal_pointer(invalid, off); } catch (const std::runtime_error&) { rejected = true; }
    check(rejected, "out-of-window GOAL pointer rejected");
  }

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

  u8* symbol_storage = balloc(8);
  u32 symbol_tag = gp(img(A11_TYPE_SYMBOL));
  std::memcpy(symbol_storage, &symbol_tag, 4);
  u8* symbol = symbol_storage + 4;
  u32 symbol_name = gp(sa);
  std::memcpy(symbol + kSymbolStringOffset, &symbol_name, 4);
  check(goal_call(img(A11_FN_NAME), gp(symbol), gp(sb), st, off) == st + 8,
        "name=(symbol jak, string jak) calls static C export");
  check(goal_call(img(A11_FN_NAME), gp(sc), gp(symbol), st, off) == st,
        "name=(string daxter, symbol jak) == #f through C export");
  check(export_calls == 2, "both symbol/string dispatch branches reached C");
  ottsel_a11_export_target = rebound_symbol_string;
  check(goal_call(img(A11_FN_NAME), gp(sb), gp(symbol), st, off) == st + 8,
        "name= works after data-only target rebinding");
  check(rebound_calls == 1 && export_calls == 3, "rebound target called exactly once");
  check(std::memcmp(original_text.data(), code, original_text.size()) == 0 &&
        std::memcmp(original_shim.data(), reinterpret_cast<void*>(&ottsel_a11_export_shim), original_shim.size()) == 0,
        "slice and static shim text unchanged after calls/rebinding");

  if (fails == 0) {
    NSLog(@"[A1.1] SLICE PASS (signed __TEXT, static export)");
    return 0;
  }
  NSLog(@"[A1.1] SLICE FAIL (%d)", fails);
  return 1;
} catch (const std::exception& error) {
  NSLog(@"[A1.1] SLICE FAIL: %s", error.what());
  return 1;
}
