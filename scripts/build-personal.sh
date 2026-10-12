#!/bin/bash
# Build your own Ottsel from your own disc, one stage at a time. PadMint runs these stages from
# padmint.json; you can run them by hand in the same order.
#
#   scripts/build-personal.sh preflight ios|macos
#   scripts/build-personal.sh source             # OpenGOAL at the pinned commit, plus Ottsel's patch
#   scripts/build-personal.sh tools [jobs]       # goalc and the extractor for this Mac
#   scripts/build-personal.sh extract DISC.iso   # your disc's levels, art, sound and text
#   scripts/build-personal.sh compile            # the game's GOAL code, compiled to ARM64
#   scripts/build-personal.sh pack FOLDER        # the game-data folder you import in the app
#   scripts/build-personal.sh app ios|macos      # the app (iPhone/iPad: unsigned, for Sideloadly)
#   scripts/build-personal.sh package ios|macos OUTPUT.ipa|OUTPUT.zip
#
# Everything generated stays in the ignored out/ folder. The app and the game-data folder hold
# files made from your disc: they are for your own devices, never to share.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
game="$repo/out/jak-project"
pin=641fb572e876750d8618434d9f7c1a531b43b366   # the same pin as scripts/snapshot-jak-project.sh
black_label_elf=7280758013604870207            # SCUS-97124 Black Label, OpenGOAL's ntsc_v1

die() { echo "Ottsel: $*" >&2; exit 1; }
platform_of() {
  case "${1:-}" in ios|macos) echo "$1" ;; *) die "say ios or macos" ;; esac
}

stage="${1:-}"
[ "$#" -gt 0 ] && shift
case "$stage" in
preflight)
  platform="$(platform_of "${1:-}")"
  [ "$(uname -s)-$(uname -m)" = Darwin-arm64 ] || die "Ottsel builds on a Mac with Apple Silicon"
  missing=""
  for tool in git cmake ninja rg clang python3 curl glslangValidator spirv-cross; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  [ -z "$missing" ] || die "missing:$missing. Install them with: brew install cmake ninja ripgrep glslang spirv-cross"
  sdk=iphoneos
  [ "$platform" = macos ] && sdk=macosx
  xcrun --sdk "$sdk" --show-sdk-path >/dev/null 2>&1 ||
    die "Xcode's $sdk SDK is missing. Install Xcode (and its iOS platform), then choose it in Xcode Settings > Locations"
  echo "Ottsel: tools found for $platform"
  ;;
source)
  patch="$repo/patches/ottsel-jak-project.patch"
  if [ ! -d "$game/.git" ]; then
    rm -rf "$game.partial"
    git init -q "$game.partial"
    git -C "$game.partial" fetch -q --depth 1 https://github.com/open-goal/jak-project "$pin"
    git -C "$game.partial" -c advice.detachedHead=false checkout -q FETCH_HEAD
    git -C "$game.partial" apply --binary --whitespace=nowarn "$patch"
    mv "$game.partial" "$game"
    echo "Ottsel: OpenGOAL $pin with Ottsel's patch is in $game"
  elif [ "$(git -C "$game" rev-parse HEAD)" = "$pin" ] &&
    git -C "$game" apply --reverse --check --binary --whitespace=nowarn "$patch" 2>/dev/null; then
    echo "Ottsel: OpenGOAL $pin with Ottsel's patch is already in $game"
  else
    die "$game is not OpenGOAL $pin with this checkout's patch. Move it aside and run this again"
  fi
  ;;
tools)
  jobs="${1:-$(sysctl -n hw.ncpu)}"
  cmake -S "$game" -B "$game/build/h1" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF -DOTTSEL_NO_EMIT=ON
  ninja -C "$game/build/h1" -j "$jobs" goalc extractor ottsel-a11-slice
  ;;
extract)
  disc="${1:?usage: $0 extract DISC.iso}"
  [ -f "$disc" ] || die "no disc image at $disc"
  extractor="$game/build/h1/decompiler/extractor"
  # Extract and check the disc first: a bad dump stops here, before the long decompile.
  "$extractor" --extract --validate "$disc" ||
    die "OpenGOAL's extractor could not read $disc as a good Jak and Daxter disc image"
  info="$game/iso_data/jak1/buildinfo.json"
  elf="$(sed -n 's/.*"elf_hash": *\([0-9]*\).*/\1/p' "$info")"
  serial="$(sed -n 's/.*"serial": *"\([^"]*\)".*/\1/p' "$info")"
  [ "$serial" = SCUS-97124 ] && [ "$elf" = "$black_label_elf" ] || die "this is not the disc Ottsel builds from. Ottsel needs \
Jak and Daxter: The Precursor Legacy for PS2, USA, SCUS-97124, the original Black Label release \
(OpenGOAL ntsc_v1). Greatest Hits, PAL, Japanese and Korean discs are not supported yet"
  "$extractor" --decompile "$disc"
  ;;
compile)
  (cd "$game" && ./build/h1/goalc/goalc --game jak1 --isa arm64 -c '(mi)')
  for built in KERNEL.CGO GAME.CGO; do
    [ -s "$game/out/jak1/iso/$built" ] || die "goalc did not produce $built"
  done
  ;;
pack)
  folder="${1:?usage: $0 pack FOLDER}"
  rm -rf "$folder"
  "$repo/scripts/prepare-user-data-pack.sh" "$game/iso_data/jak1" "$folder" "$game/out/jak1/fr3"
  "$repo/scripts/validate-user-data-pack.sh" "$folder"
  ;;
app)
  platform="$(platform_of "${1:-}")"
  build_platform=device
  [ "$platform" = macos ] && build_platform=macos
  # Unsigned (ad hoc): Sideloadly or Xcode signs the iPhone/iPad app with your own Apple ID.
  OTTSEL_PLATFORM="$build_platform" OTTSEL_SIGN_IDENTITY="" OTTSEL_PROVISIONING_PROFILE="" \
  OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json \
  OTTSEL_SIGNED_EXPORT_BANKS=1 "$repo/scripts/build-ios.sh"
  ;;
package)
  platform="$(platform_of "${1:-}")"
  output="${2:?usage: $0 package ios|macos OUTPUT}"
  mkdir -p "$(dirname "$output")"
  output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
  rm -f "$output"
  if [ "$platform" = macos ]; then
    ditto -c -k --keepParent "$game/out/macos/app/Ottsel.app" "$output"
  else
    staging="$(mktemp -d "${TMPDIR:-/tmp}/ottsel-ipa.XXXXXX")"
    mkdir "$staging/Payload"
    ditto "$game/out/ios-device/app/OttselShell.app" "$staging/Payload/OttselShell.app"
    (cd "$staging" && zip -qry "$output" Payload)
    rm -rf "$staging"
  fi
  echo "Ottsel: $output"
  ;;
*)
  sed -n '2,15p' "$0" >&2
  exit 2
  ;;
esac
