#!/usr/bin/env bash
# Build a ROM-safe, user-owned Ottsel pack outside the repository.
# This helper never embeds the result in the app or adds it to git.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 /path/to/extracted-jak1 /path/to/output-pack [path/to/fr3]" >&2
  exit 2
fi

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir=$(cd "$1" 2>/dev/null && pwd) || {
  echo "F1: source directory does not exist: $1" >&2
  exit 1
}
output_dir=$(mkdir -p "$2" && cd "$2" && pwd)

case "$output_dir" in
  "$repo_dir"|"$repo_dir"/*)
    echo "F1: refusing to create a user pack inside the repository" >&2
    exit 1
    ;;
esac

if [[ "$output_dir" == "$source_dir" ]]; then
  echo "F1: output pack must differ from the source directory" >&2
  exit 1
fi
if [[ -n "$(find "$output_dir" -mindepth 1 -print -quit)" ]]; then
  echo "F1: output directory must be empty" >&2
  exit 1
fi

required_families=(CGO DGO MUS SBK STR TEXT VAG VIS)
for family in "${required_families[@]}"; do
  if [[ ! -d "$source_dir/$family" || -L "$source_dir/$family" ]]; then
    echo "F1: source family is missing: $family" >&2
    exit 1
  fi
  cp -R "$source_dir/$family" "$output_dir/$family"
done

# Retail DGOs carry PS2 code, which the runtime skips ("skip non-GOAL obj").
# Overlay the containers this machine compiled from the user's own disc, so
# every level ships its ARM64-compiled code alongside its art. Override the
# location with OTTSEL_BUILT_DGO_DIR.
built_dgo_dir="${OTTSEL_BUILT_DGO_DIR:-$repo_dir/out/jak-project/out/jak1/iso}"
built_count=0
for built in "$built_dgo_dir"/*.DGO; do
  [[ -f "$built" ]] || continue
  cp "$built" "$output_dir/DGO/"
  built_count=$((built_count + 1))
done
if [[ $built_count -eq 0 ]]; then
  echo "F1: no compiled DGOs in $built_dgo_dir; build the game with goalc first" >&2
  exit 1
fi
echo "F1: overlaid $built_count compiled DGOs from $built_dgo_dir"

fr3_source="${3:-$source_dir/fr3}"
if [[ ! -d "$fr3_source" || -L "$fr3_source" ]]; then
  echo "F1: derived fr3 directory is missing; pass it as the third argument" >&2
  exit 1
fi
cp -R "$fr3_source" "$output_dir/fr3"

printf '%s\n' \
  'OTTSEL_USER_DATA_V1' \
  'pack-version=1' \
  'data-version=jak1' > "$output_dir/manifest.txt"

(
  cd "$output_dir"
  : > SHA256SUMS
  find CGO DGO fr3 MUS SBK STR TEXT VAG VIS -type f -print | sort |
    while IFS= read -r file; do
      shasum -a 256 "$file"
    done > SHA256SUMS
)

echo "F1: user pack prepared at $output_dir"
echo "F1: validate with scripts/validate-user-data-pack.sh $output_dir"
