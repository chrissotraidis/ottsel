#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
python3 - "$repo_root/src/shell/metal_gfx.mm" "$test_output_dir/direct_coordinate_state.inc" <<'PY'
import hashlib
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()

def braced_at(start):
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

types = '\n'.join(braced_at(source.index('struct ' + name + ' {')) + ';'
                  for name in ['OttselVertex', 'OttselDrawState'])
vertex = braced_at(source.index('void on_vertex() {'))
ad = braced_at(source.index('void handle_ad(u64 value, u8 addr) {'))
needle = 'case GsRegisterAddress::RGBAQ:'
if needle in ad:
    start = ad.index(needle)
    end = ad.find('case GsRegisterAddress::', start + len(needle))
    if end < 0:
        raise RuntimeError('RGBAQ extraction requires a following case')
    ad_case = ad[start:end]
else:
    ad_case = ''  # Actual current switch falls through to its no-op default.
decoder = ('struct Decoder { OttselDrawState st; OttselVertex verts[8]; int vert_count=0;\n'
           'void record_ir(ottsel::DirectIrKind, u64) {}\n' + vertex + '\n'
           'void ad_rgbaq(u64 value) { (void)value; switch(GsRegisterAddress::RGBAQ) {\n'
           + ad_case + '\ndefault: break; } }\n};\n')
packed_st_case = braced_at(source.index('case GifTag::RegisterDescriptor::ST: {'))
packed_uv_case = braced_at(source.index('case GifTag::RegisterDescriptor::UV: {'))
writers = ''
for name, case in [('packed_st', packed_st_case), ('packed_uv', packed_uv_case)]:
    writers += 'void ' + name + '(Decoder& dec, const u8* rec) ' + case[case.index('{'):] + '\n'
reglist_start = source.index('case GifTag::RegisterDescriptor::ST:',
                             source.index('} else if (tag.flg() == GifTag::Format::REGLIST)'))
reglist_body = source[source.index('\n', reglist_start):source.index('break;', reglist_start)]
writers += 'void reglist_st(Decoder& dec, const u8* rec) {\n' + reglist_body + '\n}\n'
mapping_start = source.index('if (source.has_uv || source.has_st) {')
mapping = braced_at(mapping_start)
mapping_fn = ('OttselMetalSpriteVertex map_coordinates(const OttselVertex& source) {\n'
              'const unsigned int texture_width=256, texture_height=1;\n'
              '(void)texture_width; (void)texture_height;\n'
              'struct Prim { bool fst() const { return false; } } gp; (void)gp;\n'
              'OttselMetalSpriteVertex vertex{};\n' + mapping + '\nreturn vertex; }\n')
actual = types + '\n' + decoder + writers + mapping_fn
pathlib.Path(sys.argv[2]).write_text(actual)
print('actual coordinate state source sha256=' + hashlib.sha256(actual.encode()).hexdigest(), flush=True)
PY
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/direct_coordinate_state_test.cpp" \
  -o "$test_output_dir/direct_coordinate_state_test"
"$test_output_dir/direct_coordinate_state_test"
