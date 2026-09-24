#include "game/kernel/common/ottsel_signed_gstate.h"
#include "game/kernel/common/ottsel_signed_exports.h"
// Ottsel S1.3 — no-emit runtime boot driver for iOS.
//
// Mirrors the host boot (runtime.cpp + jak1::kboot) minus the subsystems the
// headless shell does not have: no IOP/OVERLORD, no graphics, no listener/REPL.
// Playback output is owned by the SDL-backed sound substrate in the shell;
// KERNEL.CGO is read from the app bundle and linked by the
// no-emit linker; code pages flip RW -> RX exactly like the host H3 proof.

#include "ios_boot.h"
#include "goal_pointer_policy.h"
#include "game/sound/sdshim.h"
#include "ottsel_fault_state.h"

// Ottsel A1.7b diagnostic: counters written by the GOAL->C++ trampolines in
// out/jak-project/game/kernel/asm_funcs_arm64.s.  A GOAL->C++ call that returns with a
// different x19 has clobbered GOAL's register file; the fault handler prints the last one
// so the offending C++ target can be named.
extern "C" {
volatile unsigned long long ottsel_cbridge_calls;
volatile unsigned long long ottsel_cbridge_in;
volatile unsigned long long ottsel_cbridge_out;
volatile unsigned long long ottsel_cbridge_target;
volatile unsigned long long ottsel_cbridge_leaks;
volatile unsigned long long ottsel_cbridge_leak_in;
volatile unsigned long long ottsel_cbridge_leak_out;
volatile unsigned long long ottsel_cbridge_leak_target;
}

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <csignal>
#include <algorithm>
#include <array>
#include <execinfo.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach-o/dyld.h>
#include <filesystem>
#include <fstream>
#include <map>
#include <fcntl.h>
#include <cstdlib>
#include <pthread.h>
#include <set>
#include <string>
#include <thread>
#include <sys/mman.h>
#include <ucontext.h>
#include <unistd.h>
#include <vector>

#include <CommonCrypto/CommonDigest.h>

#include "common/common_types.h"
#include "common/goal_constants.h"
#include "common/log/log.h"
#include "common/symbols.h"
#include "common/util/FileUtil.h"
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
#include "game/overlord/common/fake_iso.h"
#include "game/overlord/common/sbank.h"
#include "game/overlord/jak1/fake_iso.h"
#include "game/runtime.h"
#include "game/sce/sif_ee.h"
#include "game/sound/sndshim.h"

// Ottsel A1.0 bounded trace (TEMPORARY): ring buffer written by the goalc
// IR_FunctionCall shim via the 'ottsel-goal-call-trace' C export.
extern "C" {
extern volatile u64 g_ottsel_call_trace[];
extern volatile u64 g_ottsel_call_idx;
}

void ottsel_ios_start_iop();  // game/ottsel_ios_iop.cpp

namespace {

std::string g_bundle_dir;
std::string g_writable_dir;
std::string g_prepared_iso_data_dir;
bool g_has_user_data = false;
int g_fault_log_fd = -1;

namespace fs = std::filesystem;

bool generated_overlay_matches(const fs::path& pack, const std::string& relative) {
  const bool generated_dgo = relative == "DGO/TIT.DGO" || relative == "DGO/VI1.DGO";
  const bool generated_text = relative.rfind("TEXT/", 0) == 0 &&
                              fs::path(relative).extension() == ".TXT";
  if (!generated_dgo && !generated_text) {
    return false;
  }
  const fs::path source = fs::path(g_bundle_dir) / "iso_data" / relative;
  const fs::path candidate = pack / relative;
  std::error_code size_error;
  if (!fs::is_regular_file(source, size_error) || !fs::is_regular_file(candidate, size_error) ||
      fs::file_size(source, size_error) != fs::file_size(candidate, size_error) || size_error) {
    return false;
  }
  std::ifstream expected(source, std::ios::binary);
  std::ifstream actual(candidate, std::ios::binary);
  std::array<char, 64 * 1024> expected_buffer{};
  std::array<char, 64 * 1024> actual_buffer{};
  while (expected && actual) {
    expected.read(expected_buffer.data(), expected_buffer.size());
    actual.read(actual_buffer.data(), actual_buffer.size());
    const auto expected_count = expected.gcount();
    const auto actual_count = actual.gcount();
    if (expected_count != actual_count ||
        !std::equal(expected_buffer.begin(), expected_buffer.begin() + expected_count,
                    actual_buffer.begin())) {
      return false;
    }
  }
  return expected.eof() && actual.eof();
}

bool user_pack_hashes_ok(const fs::path& pack) {
  const fs::path hashes = pack / "SHA256SUMS";
  std::ifstream input(hashes);
  if (!input) {
    return false;
  }
  std::string expected;
  std::string relative;
  std::set<std::string> hashed_paths;
  size_t hash_count = 0;
  while (input >> expected >> relative) {
    const fs::path relative_path = fs::path(relative).lexically_normal();
    const std::string normalized = relative_path.generic_string();
    if (expected.size() != CC_SHA256_DIGEST_LENGTH * 2 || relative.empty() ||
        relative_path.is_absolute() || normalized.empty() || normalized == "." ||
        normalized == ".." || normalized.rfind("../", 0) == 0 ||
        normalized.find("/../") != std::string::npos ||
        !hashed_paths.insert(normalized).second) {
      return false;
    }
    std::ifstream file(pack / relative_path, std::ios::binary);
    if (!file) {
      return false;
    }
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    std::array<unsigned char, 64 * 1024> buffer{};
    while (file) {
      file.read(reinterpret_cast<char*>(buffer.data()), buffer.size());
      const auto count = file.gcount();
      if (count > 0) {
        CC_SHA256_Update(&context, buffer.data(), static_cast<CC_LONG>(count));
      }
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    std::string actual;
    static constexpr char hex[] = "0123456789abcdef";
    for (unsigned char value : digest) {
      actual.push_back(hex[value >> 4]);
      actual.push_back(hex[value & 0xf]);
    }
    if (actual != expected && !generated_overlay_matches(pack, normalized)) {
      return false;
    }
    hash_count++;
  }
  if (input.bad() || hash_count == 0) {
    return false;
  }
  constexpr const char* families[] = {"CGO", "DGO", "fr3", "MUS", "SBK", "STR", "TEXT", "VAG", "VIS"};
  for (const char* family : families) {
    const fs::path dir = pack / family;
    for (const auto& entry : fs::recursive_directory_iterator(dir)) {
      if (entry.is_symlink()) return false;
      if (entry.is_regular_file()) {
        const auto relative_file = entry.path().lexically_relative(pack).generic_string();
        if (!hashed_paths.contains(relative_file) && !generated_overlay_matches(pack, relative_file)) {
          return false;
        }
      }
    }
  }
  return true;
}

bool user_pack_valid(const fs::path& pack) {
  std::ifstream manifest(pack / "manifest.txt");
  std::string header;
  std::string line;
  if (!manifest || !std::getline(manifest, header) || header != "OTTSEL_USER_DATA_V1") {
    return false;
  }
  bool version_ok = false;
  bool data_ok = false;
  while (std::getline(manifest, line)) {
    if (line == "pack-version=1") version_ok = true;
    if (line == "data-version=jak1") data_ok = true;
  }
  if (!version_ok || !data_ok) {
    return false;
  }
  // The derived FR3 files are looked up as `root/fr3` by the runtime.  Keep
  // this spelling case-sensitive so a pack that validates here is actually
  // consumable on the iOS sandbox filesystem.
  constexpr const char* families[] = {"CGO", "DGO", "fr3", "MUS", "SBK", "STR", "TEXT", "VAG", "VIS"};
  for (const char* family : families) {
    const fs::path dir = pack / family;
    bool has_file = false;
    if (!fs::is_directory(dir)) return false;
    for (const auto& entry : fs::recursive_directory_iterator(dir)) {
      if (entry.is_symlink()) return false;
      if (entry.is_regular_file()) has_file = true;
    }
    if (!has_file) return false;
  }
  return user_pack_hashes_ok(pack);
}

std::string select_ios_iso_data_dir() {
  // Ottsel I0 (2026-09-22): the bundle iso_data is the diagnostic fallback and only ever
  // carries the build own TIT/VI1 DGOs and TEXT.  Name every missing family instead of
  // letting a consumer hit a missing directory and die with an uncaught filesystem error
  // (that is what made a fresh install look frozen).
  auto bundle_data_fallback = [&]() -> std::string {
    // Only the fallback clears the flag.  Resetting it up front made it oscillate: this function runs again
    // while a pack is re-imported, and during the remove/rename window a frame saw "no user data" and raised
    // the status screen - which is uploaded inside a branch that is skipped once the scene is live, so it then
    // stayed up over the game.
    g_has_user_data = false;
    const fs::path bundle = fs::path(g_bundle_dir) / "iso_data";
    static constexpr const char* bundle_families[] = {"CGO", "DGO", "fr3", "MUS",
                                                      "SBK", "STR", "TEXT", "VAG", "VIS"};
    std::error_code check_error;
    std::string missing;
    for (const char* family : bundle_families) {
      if (!fs::is_directory(bundle / family, check_error)) {
        if (!missing.empty()) missing += ", ";
        missing += family;
      }
    }
    if (!missing.empty()) {
      lg::error("OTTSEL F1: bundle data at {} is incomplete (missing: {}); import a user pack "
                "with scripts/import-ios-user-data.sh", bundle.string(), missing);
    }
    return bundle.string();
  };  const char* home = std::getenv("HOME");
  if (!home || !*home) {
    lg::info("OTTSEL F1: HOME unavailable; using diagnostic bundle data");
    return bundle_data_fallback();
  }
  const fs::path imported = fs::path(home) / "Documents" / "OttselUserData";
  const fs::path durable = fs::path(g_writable_dir) / "OttselUserData";
  const fs::path staging = fs::path(g_writable_dir) / "OttselUserData.staging";

  auto valid_pack = [](const fs::path& path) {
    try {
      return fs::is_directory(path) && user_pack_valid(path);
    } catch (const fs::filesystem_error& error) {
      lg::error("OTTSEL F1: user pack filesystem validation failed: {}", error.what());
      return false;
    }
  };

  // A previously promoted pack is the durable source of truth on relaunch.
  // A new Documents pack supersedes it only after full validation and a
  // successful staging/rename transaction.
  if (!fs::is_directory(imported)) {
    if (valid_pack(durable)) {
      g_has_user_data = true;
      lg::info("OTTSEL F1: using durable user pack at {}", durable.string());
      return durable.string();
    }
    lg::info("OTTSEL F1: no user pack at {}; using diagnostic bundle data", imported.string());
    return bundle_data_fallback();
  }
  if (!valid_pack(imported)) {
    if (valid_pack(durable)) {
      g_has_user_data = true;
      lg::error("OTTSEL F1: rejected user pack at {}; retaining durable pack", imported.string());
      return durable.string();
    }
    lg::error("OTTSEL F1: rejected user pack at {}; using diagnostic bundle data", imported.string());
    return bundle_data_fallback();
  }
  std::error_code error;
  fs::remove_all(staging, error);
  fs::create_directories(staging, error);
  fs::copy(imported, staging, fs::copy_options::recursive | fs::copy_options::overwrite_existing,
           error);
  if (error) {
    fs::remove_all(staging, error);
    lg::error("OTTSEL F1: durable user-pack copy failed: {}", error.message());
    return g_bundle_dir + "iso_data";
  }
  // TIT/VI1 are source-generated GOAL code containers. Overlay them after
  // copying the user pack so retail DGO files cannot replace the recompiled
  // title and New Game entry points required by the no-emit runtime.
  for (const char* generated : {"TIT.DGO", "VI1.DGO"}) {
    const fs::path source = fs::path(g_bundle_dir) / "iso_data" / "DGO" / generated;
    const fs::path destination = staging / "DGO" / generated;
    if (fs::is_regular_file(source)) {
      fs::create_directories(destination.parent_path(), error);
      fs::copy_file(source, destination, fs::copy_options::overwrite_existing, error);
      if (error) {
        fs::remove_all(staging, error);
        lg::error("OTTSEL F1: generated code overlay failed: {}", error.message());
        return g_bundle_dir + "iso_data";
      }
    }
  }
  const fs::path generated_text = fs::path(g_bundle_dir) / "iso_data" / "TEXT";
  if (fs::is_directory(generated_text)) {
    for (const auto& entry : fs::directory_iterator(generated_text)) {
      if (!entry.is_regular_file() || entry.path().extension() != ".TXT") continue;
      const fs::path destination = staging / "TEXT" / entry.path().filename();
      fs::create_directories(destination.parent_path(), error);
      fs::copy_file(entry.path(), destination, fs::copy_options::overwrite_existing, error);
      if (error) {
        fs::remove_all(staging, error);
        lg::error("OTTSEL F1: generated text overlay failed: {}", error.message());
        return g_bundle_dir + "iso_data";
      }
    }
  }
  fs::remove_all(durable, error);
  fs::rename(staging, durable, error);
  if (error) {
    fs::remove_all(staging, error);
    lg::error("OTTSEL F1: durable user-pack commit failed: {}", error.message());
    return g_bundle_dir + "iso_data";
  }
  g_has_user_data = true;
  lg::info("OTTSEL F1: imported validated user pack into {}", durable.string());
  return durable.string();
}

void prepare_user_data_impl() {
  if (!g_prepared_iso_data_dir.empty()) {
    return;
  }
  g_prepared_iso_data_dir = select_ios_iso_data_dir();
  // The renderer's level loader reads fr3 from this root as soon as it is created.
  ee::ottsel_set_iso_data_dir(g_prepared_iso_data_dir.c_str());
  lg::info("OTTSEL BOOT PHASE: user-data root prepared before the renderer");
}

bool has_user_data_impl() {
  return g_has_user_data;
}
// G2.3: the iOS sound path had no VAG dialogue player, so a voicebox hint - which plays a sound named
// "spool-<line>" - fell through to the sound-bank lookup and was dropped, and the cutscene str-play path never
// started a stream.  The voice lines are VAG entries in VAG/VAGWAD.<lang> indexed by VAG/VAGDIR.AYB (u32 count,
// then an 8-byte name and a u32 offset in 2048-byte sectors - measured: entry * 2048 lands exactly on the
// "VAGp" header for every entry).  The sound engine already knows how to play a VAG sample, so this reads the
// line and hands it over.  Called from the iOS sound RPC (game/overlord/jak1/srpc.cpp) for "spool-" names.
namespace {
}  // namespace



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
// S1.4 (2026-09-21, signed-GAME dispatch fault): classify an address by region
// and name the GOAL symbol slot that holds it. The pre-2026-09-21 scans accepted
// only the legacy RX code window (kOttselIosGoalCodeOffsetMin..Max), so in a
// signed-AOT build every query printed below=none even though the symbols
// existed: signed modules execute from the GOAL module window and their function
// symbols hold those addresses.
const char* goal_region_name(u32 off) {
  if (off == 0) {
    return " region=zero";
  }
  if (ottsel_ios_goal_code_offset_is_valid(off)) {
    return " region=legacy-code";
  }
  if (off < 0x08000000u) {
    return " region=goal-data";
  }
  if (off < 0x80000000u) {
    return " region=module-window";
  }
  return " region=host";
}

// Bounded symbol-name read for the fault classifier: slot is EE-relative, the
// name pointer sits at slot + 0x1fffc + 4 and its bytes are EE-relative too.
void goal_slot_name(u32 slot) {
  u32 strp = 0;
  if (!safe_read_u32((volatile u32*)(g_ee_main_mem + slot + 0x1fffc + 4), &strp)) {
    return;
  }
  if (!strp || strp >= 0x08000000) {
    return;
  }
  raw_write_lit(" name:");
  for (int i = 0; i < 0x20; i += 4) {
    u32 w = 0;
    if (safe_read_u32((volatile u32*)(g_ee_main_mem + strp + (uintptr_t)i), &w)) {
      raw_write_lit(" ");
      raw_write_hex(w);
    }
  }
}

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
  // Stability instrumentation (2026-09-23): a fault in the app's own host text used to leave only raw
  // addresses, which cannot be attributed after the fact because the run's slide is unknown.  Name the pc and
  // lr through dladdr and record the image slide, so a recurrence (or the dump of one already on disk, once
  // its slide is known) identifies its own site.
  {
    const uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(0);
    raw_write_lit("\nOTTSEL_IOS: slide=");
    raw_write_hex(slide);
    Dl_info info = {};
    if (dladdr((void*)pc, &info) && info.dli_sname) {
      raw_write_lit("\nOTTSEL_IOS: pc symbol=");
      raw_write_lit(info.dli_sname);
      raw_write_lit(" offset=");
      raw_write_hex(pc - (uintptr_t)info.dli_saddr);
      raw_write_lit(" image=");
      raw_write_lit(info.dli_fname ? info.dli_fname : "?");
    }
    info = {};
    if (dladdr((void*)lr, &info) && info.dli_sname) {
      raw_write_lit("\nOTTSEL_IOS: lr symbol=");
      raw_write_lit(info.dli_sname);
      raw_write_lit(" offset=");
      raw_write_hex(lr - (uintptr_t)info.dli_saddr);
    }
  }
  if (ottsel_ios_pc_is_in_spu_memory(pc, (uintptr_t)spu_memory, sizeof(spu_memory))) {
    raw_write_lit("\nOTTSEL_IOS: fault target is spu_memory offset=");
    raw_write_dec((unsigned)(pc - (uintptr_t)spu_memory));
  }
  const uintptr_t ee_base = (uintptr_t)g_ee_main_mem;
  if (pc >= ee_base && pc - ee_base <= UINT32_MAX) {
    const u32 pc_offset = (u32)(pc - ee_base);
    raw_write_lit("\nOTTSEL_IOS: fault GOAL offset=");
    raw_write_hex(pc_offset);
    raw_write_lit(" code-range=");
    raw_write_lit(ottsel_ios_goal_code_offset_is_valid(pc_offset) ? "valid" : "invalid");
  }
  raw_write_lit("\n");
  raw_write_lit("\nOTTSEL_IOS: regs x0=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[0]);
  raw_write_lit(" x1=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[1]);
  raw_write_lit(" x2=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[2]);
  raw_write_lit(" x3=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[3]);
  raw_write_lit(" x4=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[4]);
  raw_write_lit(" x5=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[5]);
  raw_write_lit(" x6=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[6]);
  raw_write_lit(" x7=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[7]);
  raw_write_lit(" x8=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[8]);
  raw_write_lit(" x9=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[9]);
  raw_write_lit(" x10=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[10]);
  raw_write_lit(" x11=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[11]);
  raw_write_lit(" x12=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[12]);
  raw_write_lit(" x19=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[19]);
  raw_write_lit(" x16=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[16]);
  raw_write_lit(" x20=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[20]);
  raw_write_lit(" x21=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[21]);
  raw_write_lit(" x22=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[22]);
  raw_write_lit(" x23=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[23]);
  raw_write_lit(" x24=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[24]);
  raw_write_lit(" x25=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[25]);
  raw_write_lit(" x26=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[26]);
  raw_write_lit(" x27=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[27]);
  raw_write_lit(" x28=");
  raw_write_hex(uc->uc_mcontext->__ss.__x[28]);
  raw_write_lit(" x30=");
  raw_write_hex(lr);
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
  // A1.6 (2026-09-22) ring auditor v2. A corrupt ring entry is indistinguishable
  // from a good one by eye, so this scans the WHOLE ring (up to 128 entries) and
  // classifies both implausibility criteria the strict-dispatch loop selected:
  //   target    -- a registered signed-module function entry
  //                (gstate::valid_function) or a signed export-bank entry
  //                (signed_exports::valid_function). Anything else is BAD-TARGET.
  //   caller-lr -- the truncated low half of some loaded module's host text. A
  //                literal 0 is counted separately: the bridge/synthetic-return
  //                contract leaves x30 clear on some trampoline frames. Anything
  //                else is BAD-CALLER, i.e. an EE-valued LR.
  // Measured note: "site" is a HOST address (the recorder ADR), not a GOAL
  // address, so it is classified as host text rather than as a module range.
  // Runs only when traced objects fed a ring (idx > 0); a product build never
  // reaches it and the counters are only printed on the fault path.
#ifdef OTTSEL_SIGNED_GSTATE_EXPERIMENT
  {
    const u64 idx = g_ottsel_call_idx;
    if (idx) {
      const size_t mod_count = ottsel::signed_gstate::module_count;
      const u32 ee_low = (u32)(uintptr_t)g_ee_main_mem;
      // True when the low 32 bits are the truncated address of some loaded
      // module's host text (modular so a text range may cross the 2^32 seam).
      auto hosted = [&](u32 low) {
        for (size_t m = 0; m < mod_count; m++) {
          const auto* module = ottsel::signed_gstate::modules[m];
          if (!module) continue;
          for (const auto& segment : module->segments) {
            if (!segment.code || !segment.text_size) continue;
            const u32 begin = (u32)(uintptr_t)segment.code;
            if ((u32)(low - begin) < segment.text_size) return true;
          }
        }
        return false;
      };
      // Name a GOAL address: module+offset, else export-bank, else its region.
      auto goal_owner = [&](u32 goal) {
        bool named = false;
        for (size_t m = 0; m < mod_count; m++) {
          const auto* module = ottsel::signed_gstate::modules[m];
          if (!module) continue;
          for (const auto& segment : module->segments) {
            if (!segment.code || !segment.text_size) continue;
            const uintptr_t begin = (uintptr_t)segment.code;
            const uintptr_t address = (uintptr_t)g_ee_main_mem + goal;
            if (address >= begin && address - begin < segment.text_size) {
              raw_write_lit(module->name);
              raw_write_lit("+0x");
              raw_write_hex((u32)(address - begin));
              named = true;
            }
          }
        }
        if (!named) {
          if (ottsel::signed_exports::valid_function(goal)) raw_write_lit("export-bank");
          else raw_write_lit(goal_region_name(goal));
        }
        return named;
      };
      const u64 first = idx > 128 ? idx - 128 : 0;
      u32 entries = 0, mod_fn = 0, bank_fn = 0, bad_target = 0;
      u32 caller_host = 0, caller_zero = 0, bad_caller = 0, pp_live = 0;
      for (u64 i = first; i < idx; i++) {
        const u64 v = g_ottsel_call_trace[(i * 2) & 255];
        const u64 lr = g_ottsel_call_trace[(i * 2 + 1) & 255];
        if (!v && !lr) continue;
        ++entries;
        const u32 target = (u32)(v & 0xffffffff);
        const u32 caller = (u32)(lr & 0xffffffff);
        const u32 pp = (u32)(lr >> 32);
        if (ottsel::signed_gstate::valid_function(target)) ++mod_fn;
        else if (ottsel::signed_exports::valid_function(target)) ++bank_fn;
        else ++bad_target;
        if (caller == 0) ++caller_zero;
        else if (hosted(caller)) ++caller_host;
        else ++bad_caller;
        if (pp) ++pp_live;
      }
      raw_write_lit("OTTSEL_IOS: ring-audit v2 ring=");
      raw_write_dec((unsigned)(idx > 128 ? 128 : idx));
      raw_write_lit(" entries=");
      raw_write_dec(entries);
      raw_write_lit(" target[mod-fn=");
      raw_write_dec(mod_fn);
      raw_write_lit(",bank-fn=");
      raw_write_dec(bank_fn);
      raw_write_lit(",BAD=");
      raw_write_dec(bad_target);
      raw_write_lit("] caller[host=");
      raw_write_dec(caller_host);
      raw_write_lit(",zero=");
      raw_write_dec(caller_zero);
      raw_write_lit(",BAD=");
      raw_write_dec(bad_caller);
      raw_write_lit("] pp-nonzero=");
      raw_write_dec(pp_live);
      raw_write_lit("\n");
      // Every implausible entry with raw values, bounded to 16 lines.
      u32 shown = 0;
      for (u64 i = first; i < idx && shown < 16; i++) {
        const u64 v = g_ottsel_call_trace[(i * 2) & 255];
        const u64 lr = g_ottsel_call_trace[(i * 2 + 1) & 255];
        if (!v && !lr) continue;
        const u32 site = (u32)(v >> 32);
        const u32 target = (u32)(v & 0xffffffff);
        const u32 caller = (u32)(lr & 0xffffffff);
        const u32 pp = (u32)(lr >> 32);
        const bool g_fn = ottsel::signed_gstate::valid_function(target);
        const bool b_fn = g_fn || ottsel::signed_exports::valid_function(target);
        const bool c_bad = caller != 0 && !hosted(caller);
        if (b_fn && !c_bad) continue;
        ++shown;
        raw_write_lit("  audit age=");
        raw_write_dec((unsigned)(idx - i));
        raw_write_lit(" site-host=0x");
        raw_write_hex(site);
        raw_write_lit("/goal=0x");
        raw_write_hex((u32)(site - ee_low));
        raw_write_lit(" target=0x");
        raw_write_hex(target);
        raw_write_lit(" <- ");
        goal_owner(target);
        raw_write_lit(" fn=");
        raw_write_lit(g_fn ? "module" : (b_fn ? "bank" : "NO"));
        raw_write_lit(" caller=0x");
        raw_write_hex(caller);
        raw_write_lit(c_bad ? " BAD-EE?" : (caller ? " host" : " zero"));
        raw_write_lit(" pp=0x");
        raw_write_hex(pp);
        raw_write_lit("\n");
      }
    }
  }
#endif
  // S2.1 (2026-08-10, corrupt-process-type probe): the faulting dispatch
  // A1.7/G1.13: the flag and the on-screen frame buffer slots read at the fault
  // itself. A post-fault snapshot is not trustworthy here: only the faulting thread
  // is held, so the streamed activation thread keeps mutating GOAL state.
  {
    static const char nl17[2] = {10, 0};
    const auto fs = ottsel_fault_state_read((const unsigned char*)g_ee_main_mem, &safe_read_u32);
    raw_write_lit("OTTSEL_IOS: a17 debug-segment=0x");
    raw_write_hex(fs.debug_segment);
    raw_write_lit(" (compare the x21 register above) display=0x");
    raw_write_hex(fs.display);
    raw_write_lit(nl17);
    raw_write_lit("OTTSEL_IOS: a17 sound-loader-rpc=0x");
    raw_write_hex(fs.sound_loader_rpc);
    raw_write_lit(" sound-player-rpc=0x");
    raw_write_hex(fs.sound_player_rpc);
    raw_write_lit(nl17);
    if (fs.display) {
      raw_write_lit("OTTSEL_IOS: a17 on-screen=");
      raw_write_dec((unsigned)fs.on_screen);
      raw_write_lit(" vframe=0x");
      raw_write_hex(fs.vframe);
      raw_write_lit(" +0x20=0x");
      raw_write_hex(fs.b20);
      raw_write_lit(" +0x24=0x");
      raw_write_hex(fs.b24);
      raw_write_lit(" +0x28=0x");
      raw_write_hex(fs.b28);
      raw_write_lit(nl17);
    }
  }
  // A1.7b: did any GOAL->C++ call fail to preserve GOAL's x19?  Name it.
  {
    static const char nl18[2] = {10, 0};
    raw_write_lit("OTTSEL_IOS: a18 cbridge calls=");
    raw_write_dec((unsigned)ottsel_cbridge_calls);
    raw_write_lit(" leaks=");
    raw_write_dec((unsigned)ottsel_cbridge_leaks);
    raw_write_lit(" leak-target=0x");
    raw_write_hex((uintptr_t)ottsel_cbridge_leak_target);
    raw_write_lit(" in=0x");
    raw_write_hex((uintptr_t)ottsel_cbridge_leak_in);
    raw_write_lit(" out=0x");
    raw_write_hex((uintptr_t)ottsel_cbridge_leak_out);
    raw_write_lit(nl18);
  }
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
        // The *listener-process* (0x1eb824 per the boot debug): dump its
        // main-thread + the thread's sp/stack-top, to see whether the ~20KB
        // stack that fills [0x202000..0x207000) belongs to it.
        {
          u32 lp = 0x1eb824;
          u32 lmt = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + lp + 0x28), &lmt) &&
              lmt < 0x08000000) {
            u32 lsp = 0, ltop = 0, lpc = 0;
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + lmt + 0x14), &lpc);
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + lmt + 0x18), &lsp);
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + lmt + 0x1c), &ltop);
            raw_write_lit("OTTSEL_IOS:   listener proc=0x");
            raw_write_hex(lp);
            raw_write_lit(" thread=0x");
            raw_write_hex(lmt);
            raw_write_lit(" pc=0x");
            raw_write_hex(lpc);
            raw_write_lit(" sp=0x");
            raw_write_hex(lsp);
            raw_write_lit(" stack-top=0x");
            raw_write_hex(ltop);
            raw_write_lit("\n");
          }
        }
        // The *default-dead-pool* (1 process, 16KB stack): find its process
        // via the *default-dead-pool* symbol (scanned by hash not possible;
        // dump the pool objects near the camera region instead).
        {
          // The region [0x202000..0x207000) is filled with frames; sample the
          // top of the region to see where the stack frames end.
          u32 w = 0;
          if (safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x2076f0), &w)) {
            raw_write_lit("OTTSEL_IOS:   [0x2076f0]=0x");
            raw_write_hex(w);
            raw_write_lit(" [0x207700]=0x");
            safe_read_u32((volatile u32*)((uintptr_t)g_ee_main_mem + 0x207700), &w);
            raw_write_hex(w);
            raw_write_lit("\n");
          }
        }
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
    if (node2 >= (uintptr_t)g_ee_main_mem + 0x80000 &&
        node2 < (uintptr_t)g_ee_main_mem + 0x08000000 &&
        safe_read_u32((volatile u32*)(node2 + 4), &name_ptr) && name_ptr &&
        name_ptr >= 0x80000 && name_ptr < 0x08000000) {
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
  // S1.4 (2026-09-21): classify the faulting addresses before the older dumps.
  // In a signed-AOT build the code that faults is often a jump to a GOAL address
  // that is data (app build 01480677: pc == lr == FAR == 0x181674 with s7 near
  // 0x18ff40), so the decisive facts are which region the target landed in,
  // which symbol slot holds it verbatim, and which signed module owns it when it
  // really is text.
  {
    const u32 s7_val = s7.offset;
    const uintptr_t fpc = uc->uc_mcontext->__ss.__pc;
    const uintptr_t flr = uc->uc_mcontext->__ss.__lr;
    const u32 probes[] = {(u32)fpc, (u32)flr, (u32)(fpc - (uintptr_t)g_ee_main_mem),
                          (u32)(flr - (uintptr_t)g_ee_main_mem)};
    for (u32 q : probes) {
      raw_write_lit("OTTSEL_IOS: classify 0x");
      raw_write_hex(q);
      raw_write_lit(goal_region_name(q));
      u32 best = 0;
      u32 best_slot = 0;
      u32 exact_slot = 0;
      u32 exact_value = 0;
      for (u32 slot = s7_val - 0x10000; slot < s7_val + 0x20000; slot += 8) {
        u32 v = 0;
        if (!safe_read_u32((volatile u32*)(g_ee_main_mem + slot), &v) || v < 0x1000) {
          continue;
        }
        if (v == q) {
          exact_slot = slot;
          exact_value = v;
        }
        if (v <= q && v > best) {
          best = v;
          best_slot = slot;
        }
      }
      if (best_slot) {
        raw_write_lit(" nearest=0x");
        raw_write_hex(best);
        goal_slot_name(best_slot);
      }
      if (exact_slot) {
        raw_write_lit(" exact=0x");
        raw_write_hex(exact_value);
        raw_write_lit(" slot=0x");
        raw_write_hex(exact_slot);
        goal_slot_name(exact_slot);
      }
      raw_write_lit("\n");
    }
#ifdef OTTSEL_SIGNED_GSTATE_EXPERIMENT
    for (size_t m = 0; m < ottsel::signed_gstate::module_count; m++) {
      const auto* module = ottsel::signed_gstate::modules[m];
      if (!module) {
        continue;
      }
      for (const auto& segment : module->segments) {
        if (!segment.code || !segment.text_size) {
          continue;
        }
        const uintptr_t begin = (uintptr_t)segment.code;
        if (fpc >= begin && fpc - begin < segment.text_size) {
          raw_write_lit("OTTSEL_IOS: pc is signed text of module=");
          raw_write_lit(module->name);
          raw_write_lit(" offset=0x");
          raw_write_hex(fpc - begin);
          raw_write_lit("\n");
        }
      }
    }
#endif
    // S1.4b (2026-09-21): the branch used pc as a host address, so if the value
    // was meant to be a GOAL/EE offset the real content is at g_ee_main_mem + pc.
    // A Symbol slot there names what the branch aimed at, which separates
    // "called a Symbol object instead of its value" from "called code without a
    // base". Print the base, the EE words, the name probe, and the table test.
    {
      const uintptr_t ee = (uintptr_t)g_ee_main_mem;
      const u32 target = (u32)fpc;
      raw_write_lit("OTTSEL_IOS: ee-base=0x");
      raw_write_hex(ee);
      raw_write_lit(" target=0x");
      raw_write_hex(target);
      raw_write_lit(" ee-words:");
      for (u32 i = 0; i < 16; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(ee + target + i), &w)) {
          raw_write_lit(" ");
          raw_write_hex(w);
        }
      }
      raw_write_lit("\n");
      raw_write_lit("OTTSEL_IOS: target-name-probe");
      goal_slot_name(target);
      raw_write_lit("\n");
      raw_write_lit("OTTSEL_IOS: s7=0x");
      raw_write_hex(s7.offset);
      raw_write_lit(" target-in-probed-table=");
      raw_write_lit(target >= s7.offset - 0x10000 && target < s7.offset + 0x20000 ? "yes" : "no");
      raw_write_lit("\n");
    }
    // S1.4c (2026-09-21): pc == x30 (the link register) at the fault, so the only
    // way to name the caller is the return chain. x21 is st (EE-relative, the GOAL
    // stack). Print the stack words that look like code addresses; resolving them
    // against the modules names the frame that returned into data.
    {
      const uintptr_t ee = (uintptr_t)g_ee_main_mem;
      const u32 st_val = (u32)uc->uc_mcontext->__ss.__x[21];
      raw_write_lit("OTTSEL_IOS: goal-stack st=0x");
      raw_write_hex(st_val);
      raw_write_lit(" code-words:");
      for (u32 i = 0; i < 0x200; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(ee + st_val + i), &w) && w >= 0x08000000u) {
          raw_write_lit(" +0x");
          raw_write_hex(i);
          raw_write_lit("=0x");
          raw_write_hex(w);
        }
      }
      raw_write_lit("\n");
      // S1.4e: where does the bad target sit on the GOAL stack? A copy in a
      // saved-link-register slot is the corruption; a copy in an argument slot
      // is a leaked argument.
      raw_write_lit("OTTSEL_IOS: target-on-goal-stack:");
      for (u32 i = 0; i < 0x400; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(ee + st_val + i), &w) && w == (u32)fpc) {
          raw_write_lit(" +0x");
          raw_write_hex(i);
        }
      }
      raw_write_lit("\n");
      // S1.4f: the CPU stack (sp) is the real frame stack; x21 is the symbol
      // table base in this port. Locate the bad target on the CPU stack.
      const uintptr_t csp = (uintptr_t)uc->uc_mcontext->__ss.__sp;
      raw_write_lit("OTTSEL_IOS: target-on-cpu-stack:");
      for (u32 i = 0; i < 0x1000; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(csp + i), &w) && w == (u32)fpc) {
          raw_write_lit(" +0x");
          raw_write_hex(i);
        }
      }
      raw_write_lit("\n");
      // S1.4g: the bad value sits at [sp], which is exactly where IR_AsmRet
      // reads its continuation (ldr x30, [sp]; ret). Dump the words there so the
      // entry path that left a non-continuation in that slot is identifiable:
      // vector-save data means the export bridge, code addresses mean a GOAL
      // frame, symbol/offset values mean a build-time record.
      raw_write_lit("OTTSEL_IOS: sp-words:");
      for (u32 i = 0; i < 0x40; i += 4) {
        u32 w = 0;
        if (safe_read_u32((volatile u32*)(csp + i), &w)) {
          raw_write_lit(" 0x");
          raw_write_hex(w);
        }
      }
      raw_write_lit("\n");
#ifdef OTTSEL_SIGNED_GSTATE_EXPERIMENT
      // S1.4h: name every CPU-stack word that lies inside signed module text, so
      // the frame that left the bad value in x30 is identifiable without lldb.
      for (u32 i = 0; i < 0x400; i += 4) {
        u32 w = 0;
        if (!safe_read_u32((volatile u32*)(csp + i), &w) || !w) {
          continue;
        }
        for (size_t m = 0; m < ottsel::signed_gstate::module_count; m++) {
          const auto* module = ottsel::signed_gstate::modules[m];
          if (!module) {
            continue;
          }
          bool hit = false;
          for (const auto& segment : module->segments) {
            if (!segment.code || !segment.text_size) {
              continue;
            }
            const uintptr_t begin = (uintptr_t)segment.code;
            const uintptr_t address = (uintptr_t)g_ee_main_mem + w;
            if (address >= begin && address - begin < segment.text_size) {
              raw_write_lit("OTTSEL_IOS: sp+0x");
              raw_write_hex(i);
              raw_write_lit(" in ");
              raw_write_lit(module->name);
              raw_write_lit("+0x");
              raw_write_hex(address - begin);
              raw_write_lit("\n");
              hit = true;
              break;
            }
          }
          if (hit) {
            break;
          }
        }
      }
      // S1.4i: walk the GOAL frame chain. The faulting frame has its previous sp
      // at [sp+0x10] (= sp+0x60 in the 2026-09-21 crash), so each link names the
      // caller; print per frame the first words (the slot IR_AsmRet reads is
      // [frame]), the saved-frame slot, and every code word resolved to a module.
      {
        uintptr_t frame = csp;
        const uintptr_t stack_top = (uintptr_t)g_ee_main_mem + 0x8000000;
        for (int depth = 0; depth < 24; depth++) {
          u32 w0 = 0, w1 = 0, w2 = 0, w3 = 0, saved = 0;
          if (!safe_read_u32((volatile u32*)(frame), &w0)) {
            break;
          }
          safe_read_u32((volatile u32*)(frame + 4), &w1);
          safe_read_u32((volatile u32*)(frame + 8), &w2);
          safe_read_u32((volatile u32*)(frame + 12), &w3);
          safe_read_u32((volatile u32*)(frame + 16), &saved);
          raw_write_lit("OTTSEL_IOS: frame[");
          raw_write_dec((unsigned)depth);
          raw_write_lit("] +0x");
          raw_write_hex(frame - csp);
          raw_write_lit(" [0]=0x");
          raw_write_hex(w0);
          raw_write_lit(" [4]=0x");
          raw_write_hex(w1);
          raw_write_lit(" [8]=0x");
          raw_write_hex(w2);
          raw_write_lit(" [c]=0x");
          raw_write_hex(w3);
          raw_write_lit(" prev=0x");
          raw_write_hex(saved);
          raw_write_lit("\n");
          // The GOAL frame stores its caller sp as the low 32 bits of the host
          // address, so rebuild it inside the current frame's 4 GiB region.
          const uintptr_t next = (frame & 0xffffffff00000000ull) | (uintptr_t)saved;
          if (next <= frame || next >= stack_top) {
            break;
          }
          frame = next;
        }
      }
#endif
    }
    // S1.4d (2026-09-21): name the C/C++ frames of the faulting thread. The seam
    // that loses the GOAL base lives in a hand-written shim, so the symbol name is
    // the answer; scan the host stack for words inside this app's image.
    {
      const uintptr_t sp0 = (uintptr_t)uc->uc_mcontext->__ss.__sp;
      int printed = 0;
      for (u32 i = 0; i < 0x1000 && printed < 16; i += 8) {
        u32 lo = 0;
        u32 hi = 0;
        if (!safe_read_u32((volatile u32*)(sp0 + i), &lo)) {
          continue;
        }
        if (!safe_read_u32((volatile u32*)(sp0 + i + 4), &hi)) {
          continue;
        }
        const uint64_t value = (uint64_t(hi) << 32) | lo;
        if (value < 0x100000000ull || value > 0x10ffffffffull) {
          continue;
        }
        // Only executable pages are return addresses; data pointers on the stack
        // (arenas, manifests, globals) are not part of the chain.
        {
          vm_address_t page = (vm_address_t)(value & ~0xffffull);
          vm_size_t size = 0;
          vm_region_basic_info_data_64_t info{};
          mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
          mach_port_t object = MACH_PORT_NULL;
          const kern_return_t result = vm_region_64(mach_task_self(), &page, &size,
                                                    VM_REGION_BASIC_INFO_64,
                                                    reinterpret_cast<vm_region_info_t>(&info),
                                                    &count, &object);
          if (object != MACH_PORT_NULL) {
            mach_port_deallocate(mach_task_self(), object);
          }
          if (result != KERN_SUCCESS || !(info.protection & VM_PROT_EXECUTE)) {
            continue;
          }
        }
        Dl_info info{};
        if (dladdr(reinterpret_cast<void*>(value), &info) && info.dli_fname &&
            std::strstr(info.dli_fname, "OttselShell")) {
          raw_write_lit("OTTSEL_IOS: host-frame 0x");
          raw_write_hex(value);
          raw_write_lit(" ");
          raw_write_lit(info.dli_sname ? info.dli_sname : "?");
          raw_write_lit("+0x");
          raw_write_hex(info.dli_saddr ? value - (uintptr_t)info.dli_saddr : 0);
          raw_write_lit("\n");
          printed++;
        }
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
  // S2.2 (2026-08-15, village-load null-call): resolve the faulting caller
  // (lr, a GOAL code address) to a symbol name by scanning the FULL interned
  // symbol table for the nearest-below AND nearest-above function symbols.
  // Also resolve other code-region values seen on the fault stack so the
  // caller chain (who passed the null function pointer) is named.
  {
    const uintptr_t flr = uc->uc_mcontext->__ss.__lr;
    const u32 lr_off = (u32)(flr - (uintptr_t)g_ee_main_mem);
    const u32 code_lo = kOttselIosGoalCodeOffsetMin;
    const u32 code_hi = kOttselIosGoalCodeOffsetMax;
    const u32 s7_val = s7.offset;
    const u32 queries[] = {lr_off,
                           (u32)uc->uc_mcontext->__ss.__x[0],
                           0x3ebf9a4,
                           0x46135c0,
                           0x43c4f80,
                           0x3fdc214,
                           0x3ed1c74,
                           0x46106f0,
                           0x4610004};
    for (u32 q : queries) {
      u32 best = 0;
      u32 best_slot = 0;
      u32 next = 0xffffffff;
      u32 next_slot = 0;
      for (u32 slot = s7_val - 0x10000; slot < s7_val + 0x20000; slot += 8) {
        u32 v = 0;
        if (!safe_read_u32((volatile u32*)(g_ee_main_mem + slot), &v)) {
          continue;
        }
        if (v >= code_lo && v < code_hi) {
          if (v <= q && v > best) {
            best = v;
            best_slot = slot;
          }
          if (v > q && v < next) {
            next = v;
            next_slot = slot;
          }
        }
      }
      raw_write_lit("OTTSEL_IOS: sym-scan q=0x");
      raw_write_hex(q);
      if (best_slot) {
        u32 strp = 0;
        raw_write_lit(" below=0x");
        raw_write_hex(best);
        raw_write_lit(" slot=0x");
        raw_write_hex(best_slot);
        if (safe_read_u32((volatile u32*)(g_ee_main_mem + best_slot + 0x1fffc + 4), &strp) &&
            strp && strp < 0x08000000) {
          raw_write_lit(" name:");
          for (int i = 0; i < 0x20; i += 4) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)(g_ee_main_mem + strp + (uintptr_t)i), &w)) {
              raw_write_lit(" ");
              raw_write_hex(w);
            }
          }
        }
      } else {
        raw_write_lit(" below=none");
      }
      if (next_slot) {
        u32 strp = 0;
        raw_write_lit(" above=0x");
        raw_write_hex(next);
        raw_write_lit(" slot=0x");
        raw_write_hex(next_slot);
        if (safe_read_u32((volatile u32*)(g_ee_main_mem + next_slot + 0x1fffc + 4), &strp) &&
            strp && strp < 0x08000000) {
          raw_write_lit(" name:");
          for (int i = 0; i < 0x20; i += 4) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)(g_ee_main_mem + strp + (uintptr_t)i), &w)) {
              raw_write_lit(" ");
              raw_write_hex(w);
            }
          }
        }
      }
      raw_write_lit("\n");
    }
  }
  // S2.2 (2026-08-15, village-load null-call): the faulting caller is
  // `enter-state` (lr resolved above).  Its compiled body reads the process's
  // new state from pp+0x34 (state) / pp+0x48 (next-state) and calls
  // (-> new-state enter) at new-state+0x18, which is 0 at the fault.  Dump
  // the process + state objects (type names included) from the app's own
  // memory so the null state/enter can be identified without lldb (which
  // cannot read the EE mapping reliably).
  // 2026-09-21 correction: this block used to name the caller enter-state
  // unconditionally because the S2.2 fault (2026-08-15) had lr inside the legacy
  // code window. In app build 01480677 the same wording was printed for an lr of
  // 0x181674, which resolves to no symbol at all and is not legacy code, so the
  // evidence was read as an enter-state dispatch that never happened. Only claim
  // enter-state when lr really is legacy GOAL code; otherwise dump the raw
  // x20/pp register alone.
  {
    const u32 ee = 0;
    const u32 pp_val = (u32)uc->uc_mcontext->__ss.__x[20];
    const u32 lr_off = (u32)(uc->uc_mcontext->__ss.__lr - (uintptr_t)g_ee_main_mem);
    if (ottsel_ios_goal_code_offset_is_valid(lr_off)) {
      raw_write_lit("OTTSEL_IOS: enter-state pp=x20=0x");
      raw_write_hex(pp_val);
      raw_write_lit("\n");
    } else {
      raw_write_lit("OTTSEL_IOS: fault x20(pp)=0x");
      raw_write_hex(pp_val);
      raw_write_lit(" (lr is not legacy GOAL code: this is not an enter-state dispatch)\n");
    }
    // Helper lambdas are not async-signal-safe; inline the reads.
    const u32 slots[] = {0x34, 0x48, 0x28, 0x2c};
    for (u32 off : slots) {
      u32 v = 0;
      if (safe_read_u32((volatile u32*)(g_ee_main_mem + pp_val + off), &v)) {
        raw_write_lit("OTTSEL_IOS:   pp+0x");
        raw_write_hex(off);
        raw_write_lit("=0x");
        raw_write_hex(v);
        raw_write_lit("\n");
      }
    }
    u32 pp_type = 0;
    if (safe_read_u32((volatile u32*)(g_ee_main_mem + pp_val - 4), &pp_type)) {
      raw_write_lit("OTTSEL_IOS:   pp type-tag=0x");
      raw_write_hex(pp_type);
      raw_write_lit("\n");
      u32 t_sym = 0;
      if (safe_read_u32((volatile u32*)(g_ee_main_mem + pp_type), &t_sym)) {
        raw_write_lit("OTTSEL_IOS:   type sym slot=0x");
        raw_write_hex(t_sym);
        u32 strp = 0;
        if (safe_read_u32((volatile u32*)(g_ee_main_mem + t_sym + 0x1fffc + 4), &strp) && strp &&
            strp < 0x08000000) {
          raw_write_lit(" name:");
          for (int i = 0; i < 0x20; i += 4) {
            u32 w = 0;
            if (safe_read_u32((volatile u32*)(g_ee_main_mem + strp + (uintptr_t)i), &w)) {
              raw_write_lit(" ");
              raw_write_hex(w);
            }
          }
        }
        raw_write_lit("\n");
      }
    }
    u32 nst = 0;
    if (safe_read_u32((volatile u32*)(g_ee_main_mem + pp_val + 0x48), &nst)) {
      const u32 objs[] = {nst, 0};
      for (u32 obj : objs) {
        if (!obj || obj >= 0x08000000) {
          continue;
        }
        raw_write_lit("OTTSEL_IOS: state obj 0x");
        raw_write_hex(obj);
        raw_write_lit(" fields:");
        for (int i = -4; i <= 0x28; i += 4) {
          u32 w = 0;
          if (safe_read_u32((volatile u32*)(g_ee_main_mem + obj + (uintptr_t)i), &w)) {
            raw_write_lit(" ");
            raw_write_hex(w);
          }
        }
        raw_write_lit("\n");
        u32 otype = 0;
        if (safe_read_u32((volatile u32*)(g_ee_main_mem + obj - 4), &otype)) {
          raw_write_lit("OTTSEL_IOS:   state type-tag=0x");
          raw_write_hex(otype);
          u32 ts = 0;
          if (safe_read_u32((volatile u32*)(g_ee_main_mem + otype), &ts) && ts &&
              ts < 0x08000000) {
            u32 strp = 0;
            if (safe_read_u32((volatile u32*)(g_ee_main_mem + ts + 0x1fffc + 4), &strp) && strp &&
                strp < 0x08000000) {
              raw_write_lit(" type-name:");
              for (int i = 0; i < 0x20; i += 4) {
                u32 w = 0;
                if (safe_read_u32((volatile u32*)(g_ee_main_mem + strp + (uintptr_t)i), &w)) {
                  raw_write_lit(" ");
                  raw_write_hex(w);
                }
              }
            }
          }
          raw_write_lit("\n");
        }
      }
    }
  }
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
  // A1.2/A1.5 (2026-09-22): the strict signed-GAME crash recurses into
  // execute-process-tree with 'this' = a module-data (arena) object address (the
  // static kernel-context), so a process-tree link fed the walk a cell whose
  // content cannot be a process.  The direct value scan is stable; the earlier
  // DFS chased a healthy *active-pool* tree and then walked the symbol table
  // through a "no child" link, so it is replaced by owner identification: for
  // each non-stack hit, print the 0x20-aligned block around it and resolve every
  // symbol-looking word, which names the object whose field holds that address.
  // Fault path only, bounded to eight hits and one mincore per page.
  {
    const u32 page_u32 = (u32)sysconf(_SC_PAGESIZE);
    auto rd = [&](u32 off, u32* out) {
      return safe_read_u32((volatile u32*)(g_ee_main_mem + off), out);
    };
    // GOAL basic name: the string pointer lives at symbol + SYM_TO_STRING_OFFSET.
    auto name_of = [&](u32 sym) {
      u32 strp = 0;
      if (!sym || sym >= 0x08000000u) { raw_write_lit("?"); return; }
      if (!rd(sym + 0x20000u, &strp) || !strp || strp >= 0x08000000u) {
        raw_write_lit("?");
        return;
      }
      u32 len = 0;
      if (!rd(strp, &len) || len == 0 || len > 40) { raw_write_lit("?"); return; }
      raw_write_lit("<<");
      for (u32 i = 0; i < len; i++) {
        u32 w = 0;
        if (!rd(strp + 4 + i, &w)) break;
        const char c = (char)(w & 0xff);
        if (c < 0x20 || c > 0x7e) break;
        char one[2] = {c, 0};
        raw_write_lit(one);
      }
      raw_write_lit(">>");
    };
    auto print_context = [&](u32 at) {
      for (int k = -4; k < 4; k++) {
        if (k < 0 && at < (u32)(-k * 4)) break;
        u32 v = 0;
        if (rd((u32)(at + k * 4), &v)) {
          raw_write_lit(k == 0 ? " [" : " ");
          raw_write_hex(v);
          if (k == 0) raw_write_lit("]");
        }
      }
    };
    auto scan_value = [&](u32 needle, const char* label) {
      if (!needle || needle >= 0x08000000u) return;
      int hits = 0;
      raw_write_lit("\nOTTSEL_IOS: scan ");
      raw_write_lit(label);
      raw_write_lit("=0x");
      raw_write_hex(needle);
      raw_write_lit(" hits:");
      for (u32 base = 0; base < 0x08000000u && hits < 8; base += page_u32) {
        char vec = 0;
        if (mincore((void*)(uintptr_t)(g_ee_main_mem + base), page_u32, &vec) != 0 ||
            (vec & 1) == 0) {
          continue;
        }
        for (u32 off = 0; off < page_u32; off += 4) {
          const u32 at = base + off;
          if (*(volatile u32*)(g_ee_main_mem + at) != needle) continue;
          raw_write_lit("\nOTTSEL_IOS:   hit@0x");
          raw_write_hex(at);
          raw_write_lit(" ctx:");
          print_context(at);
          if (at >= 0x20u) {
            const u32 blk = (at - 0x20u) & ~0x1fu;
            u32 w[8] = {0};
            for (int i = 0; i < 8; i++) rd(blk + (u32)i * 4, &w[i]);
            raw_write_lit("\nOTTSEL_IOS:     blk@0x");
            raw_write_hex(blk);
            raw_write_lit(":");
            for (int i = 0; i < 8; i++) {
              raw_write_lit(" 0x");
              raw_write_hex(w[i]);
            }
            for (int i = 0; i < 8; i++) {
              if (w[i] >= 0x180000u && w[i] < 0x200000u) {
                raw_write_lit("\nOTTSEL_IOS:       w[");
                raw_write_dec((unsigned)(i * 4));
                raw_write_lit("]=0x");
                raw_write_hex(w[i]);
                raw_write_lit(" name=");
                name_of(w[i]);
              }
            }
          }
          if (++hits >= 8) break;
        }
      }
      raw_write_lit("\n");
    };
    scan_value((u32)uc->uc_mcontext->__ss.__x[24], "this(x24)");
    scan_value((u32)uc->uc_mcontext->__ss.__x[0], "child(x0)");
  }
  raw_write_lit("OTTSEL_IOS BOOT FAILED (gated): signal ");
  raw_write_dec((unsigned)sig);
  raw_write_lit(" at pc=");
  raw_write_hex(pc);
  raw_write_lit(" fault addr=");
  raw_write_hex((uintptr_t)info->si_addr);
  raw_write_lit("\n");
#if 1
  u32 fw[4] = {0, 0, 0, 0};
  for (int i = 0; i < 4; i++) {
    safe_read_u32((volatile u32*)(pc + i * 4), &fw[i]);
  }
  raw_write_lit("OTTSEL_IOS: faulting words: 0x");
  raw_write_hex(fw[0]);
  raw_write_lit(" 0x");
  raw_write_hex(fw[1]);
  raw_write_lit(" 0x");
  raw_write_hex(fw[2]);
  raw_write_lit(" 0x");
  raw_write_hex(fw[3]);
  raw_write_lit("\n");
#endif
  // S2.1 debug: hold the process alive at the fault so lldb can attach and
  // unwind the faulting thread (the jump source is one step behind pc).
  // S1 (2026-09-15, VI1 oracle fault): capture the faulting thread's native
  // backtrace so the exact caller chain is named offline via atos. Raw
  // addresses only; resolved against the installed OttselShell image.
  {
    void* addrs[48];
    const int depth = backtrace(addrs, 48);
    raw_write_lit("OTTSEL_IOS: native backtrace depth=");
    raw_write_dec((unsigned)depth);
    raw_write_lit(depth > 0 ? "\n" : " (none)\n");
    for (int i = 0; i < depth; i++) {
      raw_write_lit("OTTSEL_IOS:   bt[");
      raw_write_dec((unsigned)i);
      raw_write_lit("]=0x");
      raw_write_hex((uintptr_t)addrs[i]);
      raw_write_lit("\n");
    }
    raw_write_lit("OTTSEL_IOS: fault thread=0x");
    raw_write_hex((uintptr_t)pthread_self());
    raw_write_lit("\n");
  }
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

bool ottsel_ios_has_user_data() {
  return has_user_data_impl();
}

void ottsel_ios_prepare_user_data() {
  prepare_user_data_impl();
}

void ottsel_ios_set_bundle_dir(const std::string& dir) {
  g_bundle_dir = dir;
}

std::string ottsel_ios_bundle_dir() {
  return g_bundle_dir;
}

void ottsel_ios_set_writable_dir(const std::string& dir) {
  g_writable_dir = dir;
  if (g_fault_log_fd >= 0) {
    close(g_fault_log_fd);
  }
  g_fault_log_fd = open((g_writable_dir + "ottsel-fault.log").c_str(),
                        O_WRONLY | O_CREAT | O_TRUNC, 0644);
}

std::string ottsel_ios_writable_dir() {
  return g_writable_dir;
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

static void ottsel_ios_run_boot_impl() {
  install_gated_signal_handlers();

  // ---- EE memory map (same as the host runtime, OTTSEL no-emit) ----
#ifdef OTTSEL_SIGNED_GSTATE_EXPERIMENT
  g_ee_main_mem = ottsel::signed_gstate::prepare_arena();
#else
  g_ee_main_mem = (u8*)mmap((void*)EE_MAIN_MEM_MAP, EE_MAIN_MEM_SIZE, PROT_READ | PROT_WRITE,
                            MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
#endif
  if (g_ee_main_mem == MAP_FAILED) {
    gated_fail("mmap of EE main memory failed");
  }
  lg::debug("OTTSEL_IOS: EE main memory mapped at 0x{:016x}", (u64)g_ee_main_mem);
  const uintptr_t ee_begin = (uintptr_t)g_ee_main_mem;
  const uintptr_t spu_begin = (uintptr_t)spu_memory;
  const uintptr_t spu_end = spu_begin + sizeof(spu_memory);
  lg::info("OTTSEL_IOS: address map ee=[0x{:016x},0x{:016x}) spu=[0x{:016x},0x{:016x}) overlap={}",
           (u64)ee_begin, (u64)(ee_begin + EE_MAIN_MEM_SIZE), (u64)spu_begin, (u64)spu_end,
           (ee_begin < spu_end && spu_begin < ee_begin + EE_MAIN_MEM_SIZE));
  memset(g_ee_main_mem, 0, EE_MAIN_MEM_SIZE);
  lg::info("OTTSEL BOOT PHASE: selecting iOS data root");
  // Resolve and durably promote a Files-imported pack before kernel setup.
  // Import is independent of the GOAL boot and must remain observable even
  // when a later renderer/runtime failure terminates the Simulator process.
  const std::string iso_data_dir = g_prepared_iso_data_dir.empty()
                                       ? select_ios_iso_data_dir()
                                       : g_prepared_iso_data_dir;
  lg::info("OTTSEL BOOT PHASE: selected iOS data root");
  ee::ottsel_set_iso_data_dir(iso_data_dir.c_str());
  // Ottsel S2.2 (BOT12): keep the low-EE region readable-zero instead of
  // PROT_NONE.  The PS2 has no MMU: game code legitimately reads low memory
  // through default-initialized/null pointers (e.g. vector<-cspace! reads
  // bone->transform via a null bone and relies on its `w == 0` guard to
  // return {0,0,0,1} -- see the swamp-blimp comment in process-drawable.gc).
  // PROT_NONE turned that same read into a fault.  Reads now see zeros
  // (matching the game's intended guard behavior); writes and execute
  // attempts still fault (SIGSEGV, caught by the gated handler), so null
  // pointer WRITES/CALLS are still diagnosed.
  mprotect(g_ee_main_mem, EE_MAIN_MEM_LOW_PROTECT, PROT_READ);
  lg::info("OTTSEL BOOT PHASE: low-EE protection installed");

  // ---- globals (kernel subset of the host init sequence) ----
  lg::info("OTTSEL BOOT PHASE: initializing kernel globals");
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
  // Ottsel BOT44: the desktop runtime calls this at game/runtime.cpp:563, but
  // the shell's kernel-subset init skipped it.  kprint_init_globals_common()
  // is what fills ConvertTable with "0123456789abcdef"; without it kitoa()
  // copies NUL bytes and strend() sees an empty string, so ~D/~X/~B silently
  // printed nothing while ~A/~S/~F were unaffected.  That defect made every
  // numeric OTTSEL diagnostic unreadable.
  kprint_init_globals_common();
  lg::info("OTTSEL BOOT PHASE: kernel globals initialized");
  // Keep raw Jak save banks inside the app-owned durable container. This is
  // the same writable root used by the validated user-data import and avoids
  // relying on the process working directory on iOS.
  file_util::override_user_config_dir(g_writable_dir, true);
  // Desktop resolves project-relative files (e.g. the IOP memory card's user/memcard.bin)
  // against its data folder; on iOS that is the app's writable container.
  file_util::setup_project_path(ghc::filesystem::path(g_writable_dir), true);
  lg::info("OTTSEL F1: save root={}", file_util::get_user_memcard_dir(GameVersion::Jak1).string());
  // Ottsel S2.1 (BOT11): the native boot (jak1/kboot.cpp goal_main) calls
  // init_crc() before InitMachine(); the iOS shell skips goal_main, so the
  // CRC table stayed all zeros.  Symbol interning is self-consistent with a
  // broken hash, BUT find_symbol_from_c("_empty_") special-cases the hardcoded
  // EMPTY_HASH constant -- with a zero table the hash never matches, "_empty_"
  // is interned dynamically with value 0, and static list terminators point at
  // that symbol instead of the fixed empty pair (s7-0xa).  GOAL `(null? x)`
  // compares against s7-0xa, so such lists never terminate and the walk runs
  // past the end into near-null (game-info get-continue-by-name fault).
  init_crc();

  // ---- boot the kernel (IOP/gfx/listener remain OTTSEL_IOS-stubbed) ----
  MasterDebug = 0;
  MasterUseKernel = 1;
  // Run the real IOP/OVERLORD thread before InitMachine sends it the start command.
  ottsel_ios_start_iop();
  lg::info("OTTSEL BOOT PHASE: IOP thread started");
  // Ottsel S2.1 (BOT11): serve DGO/CGO loads from the selected user pack or
  // the clean-install diagnostic bundle fallback.
  if (jak1::InitMachine() >= 0) {
    // Match the native boot order: linking GAME invokes Mips2C callbacks,
    // so register their C exports while arena B is writable, then seal it
    // before any GAME top-level can call one.
    Mips2C::register_all_jak1();
    jak1::ottsel_stub_flip_phase_b();
    // S2.1: load the full game engine after the kernel so the game's
    // top-levels run and (in the full boot) the game processes start.
    ottsel_ios_link_cgo_from_bundle("GAME.CGO");
    // Match the native DiskBoot path: GAME.CGO already contains the engine,
    // art, and common packages.  Register those package markers before play
    // allocates levels, otherwise alloc-levels! loads ART.CGO a second time
    // and relocates shared texture pages into a different heap region.
    jak1::kernel_packages->value =
        jak1::new_pair(s7.offset + jak1_symbols::FIX_SYM_GLOBAL_HEAP,
                       *((s7 + jak1_symbols::FIX_SYM_PAIR_TYPE).cast<u32>()),
                       jak1::make_string_from_c("engine"), jak1::kernel_packages->value);
    jak1::kernel_packages->value =
        jak1::new_pair(s7.offset + jak1_symbols::FIX_SYM_GLOBAL_HEAP,
                       *((s7 + jak1_symbols::FIX_SYM_PAIR_TYPE).cast<u32>()),
                       jak1::make_string_from_c("art"), jak1::kernel_packages->value);
    jak1::kernel_packages->value =
        jak1::new_pair(s7.offset + jak1_symbols::FIX_SYM_GLOBAL_HEAP,
                       *((s7 + jak1_symbols::FIX_SYM_PAIR_TYPE).cast<u32>()),
                       jak1::make_string_from_c("common"), jak1::kernel_packages->value);
    // Ottsel S2.1 (BOT11): the native boot (kmachine.cpp InitMachineScheme,
    // DiskBoot && MasterUseKernel) sets *kernel-boot-message* to
    // DebugBootMessage ('play) and then calls the GOAL `(play)` function,
    // which spawns the display-loop process via `(on #t)` and starts the
    // renderer/level path.  On iOS, DiskBoot = 0 (InitParms is never called),
    // so that block never ran: the process tree was fully built at link time
    // (verified: time-of-day, camera master/slave/combiner/list-keeper,
    // hud-battle-enemy, subtitle all parked, dispatcher healthy) but
    // *dproc*/*run* stayed #f and no display-loop process appeared.  Mirror
    // the native boot step here after the game link.
    jak1::intern_from_c("*kernel-boot-message*")->value =
        jak1::intern_from_c("play").offset;
    lg::info("OTTSEL_IOS: calling play (BOT11)");
    jak1::call_goal_function_by_name("play");
    jak1::KernelCheckAndDispatch();
    jak1::ShutdownMachine();
    lg::info("OTTSEL_IOS: kernel dispatch loop exited cleanly");
  } else {
    gated_fail("jak1::InitMachine returned an error");
  }
}

// Ottsel I0 (2026-09-22): the boot thread body runs inside a guard so a missing data
// family (or any other filesystem error) reports by name instead of terminating the
// process with an uncaught exception and no fault log.
void ottsel_ios_run_boot() {
  try {
    ottsel_ios_run_boot_impl();
  } catch (const std::exception& error) {
    lg::error("OTTSEL BOOT: uncaught exception (data or filesystem): {}", error.what());
    lg::error("OTTSEL BOOT: if a game-data family is missing, import a pack with "
              "scripts/import-ios-user-data.sh <udid> [pack]");
  }
}
