#!/usr/bin/env bash
# Validate a user-owned Jak 1 data pack before an app-side Files import.
# This script never copies, packages, or embeds the pack.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/user-data-pack" >&2
  exit 2
fi

pack=$(cd "$1" 2>/dev/null && pwd) || {
  echo "F1: pack directory does not exist: $1" >&2
  exit 1
}

manifest="$pack/manifest.txt"
if [[ ! -f "$manifest" ]]; then
  echo "F1: missing manifest.txt" >&2
  exit 1
fi

read -r header < "$manifest"
if [[ "$header" != "OTTSEL_USER_DATA_V1" ]]; then
  echo "F1: unsupported manifest header: $header" >&2
  exit 1
fi

pack_version=""
data_version=""
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  case "$key" in
    pack-version) pack_version="$value" ;;
    data-version) data_version="$value" ;;
    *) echo "F1: unknown manifest key: $key" >&2; exit 1 ;;
  esac
done < <(tail -n +2 "$manifest")

if [[ "$pack_version" != "1" || "$data_version" != "jak1" ]]; then
  echo "F1: expected pack-version=1 and data-version=jak1" >&2
  exit 1
fi

# These families are required by the real title-to-Village1 route and the
# playback-only audio boundary. The validator checks presence and non-empty
# contents only; the user-supplied SHA256SUMS file below provides the exact
# content contract without exposing protected data to this repository.
# Keep the derived FR3 directory spelling aligned with the runtime's
# case-sensitive lookup (`root / "fr3"`).  The extracted disc families retain
# their conventional uppercase directory names.
required_families=(CGO DGO fr3 MUS SBK STR TEXT VAG VIS)
for family in "${required_families[@]}"; do
  dir="$pack/$family"
  if [[ ! -d "$dir" || -L "$dir" ]] || ! find -P "$dir" -type f -print -quit | grep -q .; then
    echo "F1: required family is missing or empty: $family" >&2
    exit 1
  fi
done

hashes="$pack/SHA256SUMS"
if [[ ! -f "$hashes" ]]; then
  echo "F1: missing SHA256SUMS" >&2
  exit 1
fi
if ! awk '
  length($1) != 64 { exit 1 }
  { path = $0; sub(/^[^[:space:]]+[[:space:]]+/, "", path)
    if (path ~ /^\// || path ~ /(^|\/)\.\.(\/|$)/) exit 1 }
' "$hashes"; then
  echo "F1: SHA256SUMS contains an invalid or escaping path" >&2
  exit 1
fi
if ! awk 'NF >= 2 { found = 1 } END { exit found ? 0 : 1 }' "$hashes"; then
  echo "F1: SHA256SUMS is empty" >&2
  exit 1
fi
if ! (cd "$pack" && shasum -a 256 -c SHA256SUMS >/dev/null); then
  echo "F1: SHA256SUMS verification failed" >&2
  exit 1
fi

hash_paths=$(awk 'NF >= 2 { print $2 }' "$hashes" | sed 's#^\./##' | sort -u)
while IFS= read -r file; do
  relative=${file#"$pack"/}
  if ! grep -Fqx "$relative" <<<"$hash_paths"; then
    echo "F1: SHA256SUMS does not cover $relative" >&2
    exit 1
  fi
done < <(find -P "$pack" \( -path "$pack/CGO/*" -o -path "$pack/DGO/*" -o -path "$pack/fr3/*" \
  -o -path "$pack/MUS/*" -o -path "$pack/SBK/*" -o -path "$pack/STR/*" \
  -o -path "$pack/TEXT/*" -o -path "$pack/VAG/*" -o -path "$pack/VIS/*" \) \
  -type f -print)

if [[ -e "$pack/iso" ]] || compgen -G "$pack/*.iso" >/dev/null; then
  echo "F1: pass must contain extracted families, not an ISO" >&2
  exit 1
fi

if ! command -v df >/dev/null; then
  echo "F1: df is required for available-space validation" >&2
  exit 1
fi
available_kb=$(df -Pk "$pack" | awk 'NR==2 {print $4}')
if [[ -z "$available_kb" || "$available_kb" -lt 1048576 ]]; then
  echo "F1: less than 1 GiB is available at the pack volume" >&2
  exit 1
fi

echo "F1: manifest/data-family/space validation passed: $pack"
