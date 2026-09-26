#!/usr/bin/env bash
# Plays Ottsel on the booted Simulator through its real touch controls (XCUITest taps on the UIKit
# overlay): START, D-pad and Cross through the menus into LOAD GAME slot 1, the move stick in Training,
# then the three-dot menu. The app must be installed, have a pack imported and a save in slot 1.
# Screenshots: /tmp/ottsel-uitest-*.png.   Usage: scripts/test-ios-touch.sh <simulator-udid>
set -euo pipefail
udid="${1:?usage: $0 <simulator-udid>}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
work="${TMPDIR:-/tmp}/ottsel-ios-touch"
mkdir -p "$work"
cp -R "$repo/test/ios-touch/." "$work/"
(cd "$work" && xcodegen generate --quiet)
data="$(xcrun simctl get_app_container "$udid" com.ottsel.shell data)"
log="$data/Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log"
xcrun simctl terminate "$udid" com.ottsel.shell 2>/dev/null || true
xcrun simctl launch "$udid" com.ottsel.shell >/dev/null
for _ in $(seq 60); do grep -q title-wait-ready "$log" 2>/dev/null && break; sleep 3; done
TEST_RUNNER_OTTSEL_LOG="$log" xcodebuild test -project "$work/OttselUITest.xcodeproj" \
  -scheme OttselUITests -destination "id=$udid" -derivedDataPath "$work/build" -quiet
