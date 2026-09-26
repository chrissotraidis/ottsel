#!/usr/bin/env bash
# Build a game-data pack with texture replacements, leaving your normal pack untouched.
#
#   scripts/apply-texture-pack.sh <texture_replacements folder> <output pack folder>
#
# The folder holds <texture page>/<texture name>.png, the layout OpenGOAL texture packs use (see
# docs/MODS.md). The script copies it into OpenGOAL's custom_assets, re-extracts your disc's level data
# (about 20 seconds), builds the pack, then puts the original level data and custom_assets back.
# Install the result with scripts/import-ios-user-data.sh or scripts/install-ios-device.sh.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "usage: $0 <texture_replacements folder> <output pack folder>" >&2
  exit 2
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
jak="$repo/out/jak-project"
pack_src="$(cd "$1" && pwd)"
output="$2"
extractor="$jak/build/h1/decompiler/extractor"
assets="$jak/custom_assets/jak1/texture_replacements"
[[ -x "$extractor" ]] || { echo "build the extractor first: ninja -C out/jak-project/build/h1 extractor" >&2; exit 1; }
[[ -d "$jak/iso_data/jak1" ]] || { echo "no extracted disc at out/jak-project/iso_data/jak1" >&2; exit 1; }
count=$(find "$pack_src" -name '*.png' | wc -l | tr -d ' ')
[[ "$count" -gt 0 ]] || { echo "no PNG files under $pack_src" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/ottsel-texpack.XXXXXX")"
log="${TMPDIR:-/tmp}/ottsel-texpack-extract.log"
cp -R "$jak/out/jak1/fr3" "$work/fr3-original"
if [[ -e "$assets" ]]; then mv "$assets" "$work/replacements-original"; fi
restore() {
  cp -R "$work/fr3-original/." "$jak/out/jak1/fr3/"
  if [[ -e "$assets" ]]; then mv "$assets" "$work/replacements-used"; fi
  if [[ -e "$work/replacements-original" ]]; then mv "$work/replacements-original" "$assets"; fi
  echo "restored the original level data and custom_assets"
  # Keep only the extractor log; the level-data copies are several hundred MB.
  cp "$work/extract.log" "$log" 2>/dev/null || true
  rm -rf "$work"
}
trap restore EXIT

mkdir -p "$(dirname "$assets")"
cp -R "$pack_src" "$assets"
echo "extracting with $count replacement textures..."
(cd "$jak" && "$extractor" --folder --decompile iso_data/jak1 > "$work/extract.log" 2>&1) ||
  { tail -5 "$work/extract.log" >&2; exit 1; }
replaced=$(grep -c 'Replacing ' "$work/extract.log" || true)
echo "the extractor replaced $replaced textures (log: $log)"
cp -R "$jak/out/jak1/fr3" "$work/fr3-modded"
"$repo/scripts/prepare-user-data-pack.sh" "$jak/iso_data/jak1" "$output" "$work/fr3-modded"
