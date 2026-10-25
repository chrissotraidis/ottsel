#!/usr/bin/env python3
"""Execute the shipped ARM64 swizzle lowering for every mask and alias case.

No game data or upstream checkout is needed. Compile the actual IR method from
the distribution patch against a small assembly-emission adapter, assemble its
output with Apple's compiler, then execute the resulting ARM64 functions. This
checks lowering semantics, not the emitter's separate instruction encodings.
"""

import argparse
import pathlib
import platform
import re
import subprocess
import tempfile


def patched_source(patch, path):
    start = patch.index("+++ b/" + path + "\n")
    end = patch.find("\ndiff --git ", start)
    section = patch[start:end if end != -1 else None]
    return "\n".join(line[1:] for line in section.splitlines()
                     if line.startswith(("+", " ")) and not line.startswith("+++"))


def method(source, name):
    start = source.index("void " + name)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


ADAPTER = r'''
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>
using u8 = uint8_t;
namespace emitter {
struct Register { int value; int id() const { return value; } };
constexpr Register X16{16}, X17{17}, V31{63};
struct IR_Record {};
struct ObjectGenerator {
  std::vector<std::string> instructions;
  void add_instr(std::string instruction, IR_Record) {
    instructions.push_back(instruction);
  }
};
}
struct AllocationResult {};
struct RegVal { emitter::Register reg; };
emitter::Register get_reg_asm(const RegVal* value, const AllocationResult&,
                            emitter::IR_Record, bool) { return value->reg; }
namespace IGen {
namespace ARM64 {
std::string mov_vf_vf(emitter::Register dst, emitter::Register src) {
  auto d = std::to_string(dst.id() & 31), s = std::to_string(src.id() & 31);
  return "orr v" + d + ".16b, v" + s + ".16b, v" + s + ".16b";
}
std::string umov_gpr32_vf_element(emitter::Register dst, emitter::Register src, int lane) {
  return "umov w" + std::to_string(dst.id()) + ", v" + std::to_string(src.id() & 31) +
         ".s[" + std::to_string(lane) + "]";
}
std::string ins_vf_element_gpr32(emitter::Register dst, int lane, emitter::Register src) {
  return "ins v" + std::to_string(dst.id() & 31) + ".s[" + std::to_string(lane) +
         "], w" + std::to_string(src.id());
}
}
std::string mov_gpr64_gpr64(emitter::ObjectGenerator&, emitter::Register dst,
                          emitter::Register src) {
  return "mov x" + std::to_string(dst.id()) + ", x" + std::to_string(src.id());
}
}
struct IR_SwizzleVF {
  const RegVal* m_dst;
  const RegVal* m_src;
  bool m_use_coloring;
  u8 m_controlBytes;
  void do_codegen_arm64(emitter::ObjectGenerator*, const AllocationResult&, emitter::IR_Record);
};
'''

GENERATE = r'''
int main() {
  std::puts(".text\n.p2align 2");
  for (int alias = 0; alias != 2; ++alias) {
    for (int mask = 0; mask != 256; ++mask) {
      RegVal src{{33}}, dst{{alias ? 33 : 34}};
      IR_SwizzleVF ir{&dst, &src, false, static_cast<u8>(mask)};
      emitter::ObjectGenerator gen;
      ir.do_codegen_arm64(&gen, {}, {});
      std::printf(".globl _swizzle_%d_%d\n_swizzle_%d_%d:\n", alias, mask, alias, mask);
      std::puts("ldr q1, [x0]\nldr q2, [x2]");
      for (const auto& instruction : gen.instructions) std::puts(instruction.c_str());
      std::printf("str q%d, [x1]\nret\n", alias ? 1 : 2);
    }
  }
}
'''

RUNNER = r'''
int main() {
  const uint32_t patterns[][4] = {
    {11, 22, 33, 44}, {0, 0x80000000, 0x7fc12345, 0xffffffff},
    {0x3f800000, 0xc0200000, 0x7f800000, 0xff800000},
    {0x01234567, 0x89abcdef, 0xfedcba98, 0x76543210},
  };
  const uint32_t sentinel[4] = {101, 202, 303, 404};
  unsigned failures = 0, checks = 0;
  for (int alias = 0; alias != 2; ++alias) {
    for (int mask = 0; mask != 256; ++mask) {
      for (const auto& source : patterns) {
        uint32_t output[4]{};
        functions[alias * 256 + mask](source, output, sentinel);
        bool ok = true;
        for (int lane = 0; lane != 4; ++lane)
          ok &= output[lane] == source[(mask >> (2 * lane)) & 3];
        ++checks;
        if (!ok) {
          if (failures < 8)
            std::printf("FAIL alias=%d mask=0x%02x got=[%x,%x,%x,%x]\n",
                        alias, mask, output[0], output[1], output[2], output[3]);
          ++failures;
        }
      }
    }
  }
  std::printf("%s: %u swizzles executed on ARM64; %u failures (all 256 masks, "
              "aliased/distinct registers, four bit patterns)\n",
              failures ? "FAIL" : "PASS", checks, failures);
  return failures ? 1 : 0;
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = pathlib.Path(__file__).resolve().parents[1]
    parser.add_argument("--patch", type=pathlib.Path,
                        default=root / "patches/ottsel-jak-project.patch")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This execution regression requires an Apple Silicon Mac and Xcode.")
    patch = args.patch.read_text()
    registers = patched_source(patch, "goalc/emitter/Register.cpp")
    arm = registers[registers.index("RegisterInfo RegisterInfo::make_register_info_arm64"):]
    arrays = re.findall(r"info\.m_xmm_\w*alloc_order\s*=\s*\{([^}]+)\}", arm)
    assert len(arrays) == 3, "check every ARM64 SIMD allocation order"
    assert all(not re.search(r"\bV31\b", array) for array in arrays), "V31 must stay unallocated"
    lowering = method(patched_source(patch, "goalc/compiler/IR.cpp"),
                      "IR_SwizzleVF::do_codegen_arm64")
    names = [f"swizzle_{alias}_{mask}" for alias in range(2) for mask in range(256)]
    declarations = "\n".join(f'extern "C" void {name}(const uint32_t*, uint32_t*, const uint32_t*);'
                             for name in names)
    runner = ("#include <cstdint>\n#include <cstdio>\n" + declarations +
              "\nusing Fn = void (*)(const uint32_t*, uint32_t*, const uint32_t*);\n" +
              "Fn functions[] = {" + ",".join(names) + "};\n" + RUNNER)
    compiler = ["xcrun", "--sdk", "macosx", "clang++", "-std=c++17", "-arch", "arm64"]
    with tempfile.TemporaryDirectory(prefix="ottsel-swizzle-") as temp:
        out = pathlib.Path(temp)
        (out / "generate.cpp").write_text(ADAPTER + lowering + GENERATE)
        subprocess.run(compiler + [str(out / "generate.cpp"), "-o", str(out / "generate")], check=True)
        with (out / "swizzles.s").open("w") as assembly:
            subprocess.run([str(out / "generate")], stdout=assembly, check=True)
        (out / "runner.cpp").write_text(runner)
        subprocess.run(compiler + [str(out / "runner.cpp"), str(out / "swizzles.s"),
                                   "-o", str(out / "runner")], check=True)
        return subprocess.run([str(out / "runner")], timeout=10).returncode


if __name__ == "__main__":
    raise SystemExit(main())
