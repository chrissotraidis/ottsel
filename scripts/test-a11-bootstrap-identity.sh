#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/out/jak-project"
output_dir="${1:-/tmp/ottsel-recovery-2026-09-12/a11-bootstrap-identity}"
mkdir -p "$output_dir"
python3 - "$source_dir" "$output_dir" <<'PY'
import pathlib,re,sys,hashlib
root,out=map(pathlib.Path,sys.argv[1:])
scheme=(root/'game/kernel/jak1/kscheme.cpp').read_text()
printing=(root/'game/kernel/common/kprint.cpp').read_text()
def function(source, signature):
    start=source.index(signature); begin=source.index('{',start); depth=0
    # Ignore braces inside comments and quoted literals when locating the body.
    tokens=re.finditer(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[{}]',source[begin:],re.S)
    for token in tokens:
        if token.group()=='{':depth+=1
        if token.group()=='}':
            depth-=1
            if depth==0:return source[start:begin+token.end()]
    raise RuntimeError('unbalanced source: '+signature)
start=scheme.index('  // allocate memory for the symbol table',scheme.index('s32 InitHeapAndSymbol()'))
end=scheme.index('  // booleans',start)
code=function(printing,'void init_output()')+'\nnamespace jak1 {\n'
for sig in ('u64 alloc_from_heap(', 'u64 alloc_heap_object(', 'u32 size_of_type(', 'Ptr<Type> alloc_and_init_type('):
    code+=function(scheme,sig)+'\n'
code+='void fixture_bootstrap_prefix() {\n'+scheme[start:end]+'}\n}\n'
(out/'bootstrap-current-source.inc').write_text(code)
for rel in ('game/kernel/jak1/kscheme.cpp','game/kernel/common/kmalloc.cpp','game/kernel/common/kprint.cpp'):
    print(hashlib.sha256((root/rel).read_bytes()).hexdigest(),rel)
PY
{
  cat <<'ASM'
.globl _ottsel_bootstrap_arena
.zerofill __ARENA,__zero,_ottsel_bootstrap_arena,134217728,14
.section __GOAL,__text,regular,pure_instructions
.balign 8
.long 0x001bfec4
.globl _ottsel_bootstrap_release
_ottsel_bootstrap_release:
ASM
  sed -n '/^[[:space:]]*\.word /p' "$repo_root/docs/evidence/H2.5/add2.s"
  cat <<'ASM'
.balign 8
.long 0x0017fde4
.globl _ottsel_bootstrap_debug
_ottsel_bootstrap_debug:
ASM
  sed -n '/^[[:space:]]*\.word /p' "$repo_root/docs/evidence/H2.5/add2.s"
} > "$output_dir/bootstrap.s"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O2 -Wall -Wextra \
  -I"$source_dir" -I"$source_dir/third-party/fmt/include" -I"$output_dir" \
  "$repo_root/test/a11_bootstrap_identity_test.cpp" \
  "$source_dir/game/kernel/common/kmalloc.cpp" "$output_dir/bootstrap.s" \
  "$source_dir/game/kernel/asm_funcs_arm64.s" \
  -Wl,-segprot,__ARENA,rw,rw -Wl,-segprot,__GOAL,rx,rx \
  -o "$output_dir/a11_bootstrap_identity_test"
[ "$(stat -f%z "$output_dir/a11_bootstrap_identity_test")" -lt 100000000 ]
codesign --force --sign - "$output_dir/a11_bootstrap_identity_test"
codesign --verify --strict "$output_dir/a11_bootstrap_identity_test"
"$output_dir/a11_bootstrap_identity_test"
