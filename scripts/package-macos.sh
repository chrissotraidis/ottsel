#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
GAME_ROOT=${OTTSEL_JAK_PROJECT:-$ROOT/out/jak-project}
BUILD=${OTTSEL_GK_BINARY:-$GAME_ROOT/build/h1/game/gk}
OUT=${1:-$ROOT/out/Ottsel.app}

[[ -x "$BUILD" ]] || { print -u2 "missing executable: $BUILD"; exit 1; }
command -v sips >/dev/null || { print -u2 "sips is required"; exit 1; }
command -v iconutil >/dev/null || { print -u2 "iconutil is required"; exit 1; }

icon_source="$GAME_ROOT/game/assets/jak1/app256.png"
[[ -f "$icon_source" ]] || { print -u2 "missing icon source: $icon_source"; exit 1; }

icon_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ottsel-iconset.XXXXXX")
iconset="$icon_tmp/Ottsel.iconset"
mkdir -p "$iconset"
trap 'rm -rf "$icon_tmp"' EXIT
for spec in \
  "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
  "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
  "512:512x512" "1024:512x512@2x"; do
  size=${spec%%:*}
  name=${spec#*:}
  sips -s format png -z "$size" "$size" "$icon_source" --out "$iconset/icon_$name.png" >/dev/null
done

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
iconutil -c icns "$iconset" -o "$OUT/Contents/Resources/Ottsel.icns"
cat > "$OUT/Contents/MacOS/Ottsel" <<LAUNCHER
#!/bin/sh
set -e
cd "$GAME_ROOT"
export OTTSEL_ENABLE_KEYBOARD=1
export OTTSEL_TRACE_INPUT=1
export OTTSEL_AUDIO_OUTPUT_DEVICE="\${OTTSEL_AUDIO_OUTPUT_DEVICE:-MacBook Air Speakers}"
exec "$BUILD" -v --game jak1 -- -boot -fakeiso > /tmp/ottsel-wrapper-current.log 2>&1
LAUNCHER
chmod +x "$OUT/Contents/MacOS/Ottsel"

cat > "$OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>Ottsel — Jak 1</string>
  <key>CFBundleExecutable</key><string>Ottsel</string>
  <key>CFBundleIconFile</key><string>Ottsel.icns</string>
  <key>CFBundleIdentifier</key><string>com.ottsel.jak1</string>
  <key>CFBundleName</key><string>Ottsel</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

print "Packaged $OUT"
