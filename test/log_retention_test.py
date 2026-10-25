#!/usr/bin/env python3
"""Execute the shell's log-opening code against real files, without an app build.

Pass --ref <commit> to demonstrate the pre-fix failure. The runtime logger is
replaced by its documented append/truncate file behavior; the fault opener and
runtime setup are extracted unchanged from the selected shell sources.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ref')
args = parser.parse_args()


def source(path):
    if args.ref:
        return subprocess.check_output(
            ['git', 'show', f'{args.ref}:{path}'], cwd=ROOT, text=True)
    return (ROOT / path).read_text()


boot = source('src/shell/ios_boot.cpp')
start = boot.index('void ottsel_ios_set_writable_dir(')
end = boot.index('\nstd::string ottsel_ios_writable_dir()', start)
fault_opener = boot[start:end]
main = source('src/shell/main.cpp')
start = main.index('  // All runtime log output')
end = main.index('  lg::info("OTTSEL RUNTIME BOOT:', start)
runtime_opener = main[start:end]

code = r'''
#include "src/shell/log_retention.h"
#include <fcntl.h>
#include <unistd.h>
#include <filesystem>
#include <fstream>
#include <iostream>
namespace fs = std::filesystem;
std::string g_writable_dir;
int g_fault_log_fd = -1;
namespace lg {
void set_file(const std::string& name, bool rotate, bool append, const std::string& dir) {
  if (rotate) std::abort();
  FILE* f = std::fopen((dir + name).c_str(), append ? "a" : "w");
  if (!f) std::abort();
  std::fputs("new\n", f);
  std::fclose(f);
}
}
''' + fault_opener + r'''
void open_runtime(const std::string& writable) {
  const std::string g_log_path = writable + "ottsel-runtime.log";
''' + runtime_opener + r'''
}
void open_fault(const std::string& dir) {
  ottsel_ios_set_writable_dir(dir);
  if (g_fault_log_fd < 0 || write(g_fault_log_fd, "new\n", 4) != 4) std::abort();
  close(g_fault_log_fd);
  g_fault_log_fd = -1;
}
std::string read(const fs::path& p) {
  std::ifstream f(p);
  return std::string(std::istreambuf_iterator<char>(f), {});
}
int main(int argc, char** argv) {
  unsigned failures = 0, checks = 0;
  auto check = [&](bool ok, const std::string& label) {
    ++checks;
    if (!ok) { ++failures; std::cerr << "FAIL " << label << '\n'; }
  };
  for (const std::string kind : {"fault", "runtime"}) {
    fs::path dir = fs::path(argv[1]) / kind;
    fs::create_directories(dir);
    auto current = dir / ("ottsel-" + kind + ".log");
    auto previous = dir / ("ottsel-" + kind + ".previous.log");
    auto launch = [&] { (kind == "fault" ? open_fault : open_runtime)(dir.string() + "/"); };
    launch();
    check(read(current) == "new\n" && !fs::exists(previous), kind + " first launch");
    std::ofstream(current) << "crash evidence\n";
    launch();
    check(read(previous) == "crash evidence\n" && read(current) == "new\n",
          kind + " failed session survives relaunch");
    launch();
    check(read(previous) == "new\n" && read(current) == "new\n",
          kind + " retains only previous session");
    fs::remove(current);
    std::ofstream(previous) << "saved session\n";
    launch();
    check(read(previous) == "saved session\n" && read(current) == "new\n",
          kind + " missing current leaves previous intact");
    fs::remove(previous);
    fs::create_directory(previous); // Force rename failure without permission assumptions.
    std::ofstream(current) << "must survive\n";
    launch();
    check(read(current) == "must survive\nnew\n", kind + " rotation failure appends");
  }
  std::cout << checks << " log retention checks, " << failures << " failures\n";
  return failures ? 1 : 0;
}
'''
with tempfile.TemporaryDirectory(prefix='ottsel-log-retention-') as tmp:
    tmp = Path(tmp)
    (tmp / 'test.cpp').write_text(code)
    subprocess.run(['clang++', '-std=c++17', '-Wall', '-Wextra', '-Wno-unused-parameter',
                    '-I', str(ROOT), str(tmp / 'test.cpp'), '-o', str(tmp / 'test')], check=True)
    subprocess.run([str(tmp / 'test'), str(tmp / 'logs')], check=True)
