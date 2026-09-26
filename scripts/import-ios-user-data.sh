#!/usr/bin/env bash
# Import a validated Ottsel user data pack into a booted Simulator app container.
#
# The app imports a pack from $HOME/Documents/OttselUserData, validates it
# (manifest + family hashes) and promotes a durable copy into
# Library/Application Support/local.ottsel/OttselShell/OttselUserData.  The
# durable copy is what survives a rebuild, so this is the supported way to give
# the iPad lane its ROM-derived data after an install or a container reset.
#
# Usage: scripts/import-ios-user-data.sh <simulator-udid> [pack-directory]
# Default pack directory: /tmp/ottsel-user-pack (see scripts/prepare-user-data-pack.sh).
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <simulator-udid> [pack-directory]" >&2
  exit 2
fi

udid="$1"
pack="${2:-/tmp/ottsel-user-pack}"
repo_dir=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! -d "$pack" ]]; then
  echo "pack directory not found: $pack" >&2
  echo "build one with scripts/prepare-user-data-pack.sh <extracted-jak1> <out> [fr3]" >&2
  exit 1
fi
"$repo_dir/scripts/validate-user-data-pack.sh" "$pack" >/dev/null

booted=$(xcrun simctl list devices booted | grep -c "$udid" || true)
if [[ "$booted" -lt 1 ]]; then
  echo "booting $udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
fi

container=$(xcrun simctl get_app_container "$udid" com.ottsel.shell data)
destination="$container/Documents/OttselUserData"
mkdir -p "$container/Documents"
rm -rf "$destination"
cp -R "$pack" "$destination"
echo "imported $(du -sh "$destination" | cut -f1) into $destination"
echo "relaunch the app; it logs 'OTTSEL F1: imported validated user pack into ...' and promotes a durable copy."
