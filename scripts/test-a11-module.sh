#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo/out/jak-project"
output="${1:-/tmp/ottsel-recovery-2026-09-12/a11-module}"
mkdir -p "$output"
cat > "$output/module_layout.h" <<'EOF'
#include "game/kernel/common/memory_layout.h"
// Reserve the measured 320-byte module data span from the global heap's tail.
// Alignment is explicit; this is a required allocator carveout, not a free gap.
constexpr unsigned kModuleDataOffset = (GLOBAL_HEAP_END - 320u) & ~0x3fffu;
EOF
cat > "$output/layout_value.cpp" <<'EOF'
#include "module_layout.h"
#include <cstdio>
int main() { std::printf("%u", kModuleDataOffset); }
EOF
xcrun --sdk macosx clang++ -std=c++20 -I"$repo/out/jak-project" -I"$output" \
  "$output/layout_value.cpp" -o "$output/layout_value"
data_offset="$("$output/layout_value")"
# Compile the actual new CLI branch separately from the unchanged compiler-heavy
# slice path; this is the same parser/emitter used by the production entry point.
python3 - "$source_dir" "$output/module_cli.cpp" <<'PY'
import pathlib, sys
s=(pathlib.Path(sys.argv[1])/'tools/ottsel_a1_1/a11_slice_emitter.cpp').read_text()
start=s.index('int main(int argc, char** argv) {')
end=s.index('  lg::set_stdout_level', start)
pathlib.Path(sys.argv[2]).write_text('#include "a11_module_emitter.h"\n#include <iostream>\n'+s[start:end]+'return 99;\n}\n')
PY
xcrun --sdk macosx clang++ -std=c++20 -O2 -Wall -Wextra -Wno-deprecated-declarations \
  -I"$source_dir/tools/ottsel_a1_1" "$output/module_cli.cpp" -o "$output/module_cli"
"$output/module_cli" --module "$repo/out/jak-project/out/jak1/obj/gstate.o" gstate "$output/cli" 0x1bfec4 "$data_offset"
"$output/module_cli" --module "$repo/out/jak-project/out/jak1/obj/gstring.o" gstring "$output/cli-gstring" 0x1bfec4 "$data_offset"
"$output/module_cli" --module "$repo/out/jak-project/out/jak1/obj/merc-vu1.o" merc-vu1 "$output/cli-merc-vu1" 0x1bfec4 "$data_offset"
"$output/module_cli" --module "$repo/out/jak-project/out/jak1/obj/ocean-vu0.o" ocean-vu0 "$output/cli-ocean-vu0" 0x1bfec4 "$data_offset"
xcrun --sdk macosx clang++ -std=c++20 -O2 -Wall -Wextra -Wno-deprecated-declarations \
  -I"$source_dir/tools/ottsel_a1_1" -I"$repo/out/jak-project" -I"$output" \
  "$repo/test/a11_module_test.cpp" -o "$output/a11_module_test"
"$output/a11_module_test" "$repo/out/jak-project/out/jak1/obj/gstate.o" \
  "$repo/out/jak-project/out/jak1/obj/gstring.o" "$output" \
  "$repo/out/jak-project/out/jak1/obj/merc-vu1.o" \
  "$repo/out/jak-project/out/jak1/obj/ocean-vu0.o"
# emit_signed_module retains the exact parsed input as <name>.source.o. Feed that
# perturbed LDR Q object through the production CLI branch so its output must
# match what the direct emitter produced from the same bytes.
"$output/module_cli" --module "$output/gstring_quad.source.o" gstring_quad "$output/cli-gstring-quad" 0x1bfec4 "$data_offset"
for module in gstate gstate_unaligned gstring gstring_quad merc-vu1 ocean-vu0; do
  xcrun --sdk macosx clang -arch arm64 -c "$output/$module.s" -o "$output/$module.o"
  printf 'int main() { return 0; }\n' > "$output/link_only.cpp"
  xcrun --sdk macosx clang++ -arch arm64 "$output/link_only.cpp" "$output/$module-arena-layout.s" "$output/$module.o" \
    -Wl,-segprot,__ARENA,rw,rw -Wl,-segprot,__GOAL,rx,rx \
    -o "$output/$module-linked"
done
python3 - "$output" <<'PY'
import hashlib, json, pathlib, sys
p=pathlib.Path(sys.argv[1]);m=json.loads((p/'gstate.json').read_text())
assert m['source_sha256']==hashlib.sha256((p/'gstate.source.o').read_bytes()).hexdigest()
assert sum(s['size'] for s in m['segments'])==33080
assert len((p/'gstate-s0-data.bin').read_bytes())==280
assert len((p/'gstate-s2-data.bin').read_bytes())==32
print('PASS manifest/source SHA256 and complete data templates')
for name, cli in (('gstate','cli'),('gstring','cli-gstring'),
                  ('gstring_quad','cli-gstring-quad'),
                  ('merc-vu1','cli-merc-vu1'),('ocean-vu0','cli-ocean-vu0')):
 for file in (name+'.s',name+'.json',name+'-s0-data.bin',name+'-s2-data.bin'):
  assert (p/file).read_bytes()==(p/cli/file).read_bytes(), (name,file)
print('PASS actual emitter CLI branch and direct emission agree byte for byte for complete, perturbed-LDR-Q and data-only modules')
PY
python3 "$repo/test/a11_module_macho_check.py" "$output"
