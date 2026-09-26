#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/out/jak-project"
output_dir="${1:-/tmp/ottsel-recovery-2026-09-12/a11-export-slots}"
mkdir -p "$output_dir"
# Reuse actual-source extraction and bootstrap proof; no product build.
bash "$repo_root/scripts/test-a11-bootstrap-identity.sh" "$output_dir"
python3 - "$output_dir/slots.s" <<'PY'
import sys
s='.globl _ottsel_export_targets\n.zerofill __DATA,__bss,_ottsel_export_targets,64,3\n.globl _ottsel_export_selected\n.zerofill __DATA,__bss,_ottsel_export_selected,8,3\n.globl _ottsel_export_observed\n.zerofill __DATA,__bss,_ottsel_export_observed,144,4\n.section __GOAL,__text,regular,pure_instructions\n'
for i in range(4):
 s+=f'.balign 8\n.long 0x001bfec4\n.globl _ottsel_slot_{i}\n_ottsel_slot_{i}:\nadrp x16,_ottsel_export_targets@PAGE\nadd x16,x16,_ottsel_export_targets@PAGEOFF\nldr x17,[x16,#{i*16}]\nstr x17,[sp,#-16]!\n'
 if i==1:s+='mov x3,x20\n'
 if i==3:s+='ldr x17,[x16,#56]\nstr x17,[sp,#-16]!\n'
 helper=['arg','arg','stack','mips2c'][i]+'_call_arm64'
 s+=f'adrp x17,_{helper}@PAGE\nadd x17,x17,_{helper}@PAGEOFF\nbr x17\n'
s+='.globl _ottsel_slot_end\n_ottsel_slot_end:\n.balign 4\n.globl _ottsel_slot_driver\n_ottsel_slot_driver:\nstp x29,x30,[sp,#-16]!\nstp x19,x20,[sp,#-16]!\nmov x19,sp\nmov x20,#0x2340\nmovk x20,#1,lsl #16\n'
for i in range(8,16):s+=f'movi v{i}.16b,#{i}\n'
for i in range(8):s+=f'mov x{i},#{i+1}\n'
s+='adrp x16,_ottsel_export_selected@PAGE\nldr x16,[x16,_ottsel_export_selected@PAGEOFF]\nblr x16\nadrp x16,_ottsel_export_observed@PAGE\nadd x16,x16,_ottsel_export_observed@PAGEOFF\nstr x0,[x16]\nmov x9,sp\nsub x9,x9,x19\nstr x9,[x16,#8]\n'
for i in range(8,16):s+=f'str q{i},[x16,#{16+(i-8)*16}]\n'
s+='mov sp,x19\nldp x19,x20,[sp],#16\nldp x29,x30,[sp],#16\nret\n'
open(sys.argv[1],'w').write(s)
PY
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O2 -Wall -Wextra \
  -I"$source_dir" -I"$source_dir/third-party/fmt/include" -I"$output_dir" \
  "$repo_root/test/a11_export_slots_test.cpp" "$source_dir/game/kernel/common/kmalloc.cpp" \
  "$output_dir/bootstrap.s" "$output_dir/slots.s" "$source_dir/game/kernel/asm_funcs_arm64.s" \
  -Wl,-segprot,__ARENA,rw,rw -Wl,-segprot,__GOAL,rx,rx -o "$output_dir/a11_export_slots_test"
[ "$(stat -f%z "$output_dir/a11_export_slots_test")" -lt 100000000 ]
codesign --force --sign - "$output_dir/a11_export_slots_test"
codesign --verify --strict "$output_dir/a11_export_slots_test"
"$output_dir/a11_export_slots_test"
