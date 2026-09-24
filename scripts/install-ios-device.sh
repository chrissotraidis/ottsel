#!/usr/bin/env bash
# G2 in one command: build, sign and install Ottsel on a connected iPad (or iPhone), give it the
# player's game-data pack, and launch it.
#
#   scripts/install-ios-device.sh <pack-directory> [device-name-or-udid]
#
# Once, by hand (Apple requires a person for these): sign in to Xcode with an Apple ID
# (Xcode > Settings > Accounts; a free Personal Team works), connect the device by cable and trust
# this Mac, and turn on Developer Mode on the device (Settings > Privacy & Security). The pack comes
# from scripts/prepare-user-data-pack.sh. Needs: brew install xcodegen glslang spirv-cross
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
pack="${1:?usage: $0 <pack-directory> [device-name-or-udid]}"
device="${2:-}"
work="$repo/out/jak-project/out/ios-device/provision"
mkdir -p "$work"
"$repo/scripts/validate-user-data-pack.sh" "$pack" >/dev/null

# 1. The connected device (first paired iPad/iPhone unless one is named).
xcrun devicectl list devices --json-output "$work/devices.json" >/dev/null
ids="$(python3 - "$work/devices.json" "$device" <<'PY'
import json, sys
want = sys.argv[2]
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, props = d.get("hardwareProperties", {}), d.get("deviceProperties", {})
    names = {d.get("identifier"), hw.get("udid"), props.get("name")}
    if hw.get("platform") == "iOS" and (not want or want in names):
        print(d["identifier"], hw.get("udid", "")); break
PY
)"
device_id="${ids%% *}"
device_udid="${ids#* }"
if [ -z "${device_id:-}" ]; then
  echo "No connected iPad/iPhone. Connect it by cable, unlock it, trust this Mac, enable Developer Mode." >&2
  exit 1
fi

# 2. The signing identity and its team.
identity="${OTTSEL_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)}"
if [ -z "$identity" ]; then
  echo "No Apple Development identity. Xcode > Settings > Accounts: add your Apple ID, then" >&2
  echo "Manage Certificates > + > Apple Development. Rerun this script afterwards." >&2
  exit 1
fi
team="$(security find-certificate -c "$identity" -p | openssl x509 -noout -subject -nameopt multiline | sed -n 's/ *organizationalUnitName *= *//p')"
bundle_id="${OTTSEL_BUNDLE_ID:-com.ottsel.shell}"

# 3. A development profile for this team, bundle id and device. Xcode only makes one through automatic
#    signing, so a generated stub project asks it to (it also registers the device with the team).
find_profile() {
  python3 - "$team" "$bundle_id" "$device_udid" <<'PY'
import glob, os, plistlib, subprocess, sys, datetime
team, bundle, udid = sys.argv[1:]
best = None
for d in ["~/Library/Developer/Xcode/UserData/Provisioning Profiles", "~/Library/MobileDevice/Provisioning Profiles"]:
    for path in glob.glob(os.path.expanduser(d) + "/*.mobileprovision"):
        raw = subprocess.run(["security", "cms", "-D", "-i", path], capture_output=True).stdout
        try: p = plistlib.loads(raw)
        except Exception: continue
        app_id = p.get("Entitlements", {}).get("application-identifier", "")
        if team not in p.get("TeamIdentifier", []) or app_id not in (f"{team}.{bundle}", f"{team}.*"): continue
        if udid and udid not in p.get("ProvisionedDevices", [udid]): continue
        if p["ExpirationDate"] <= datetime.datetime.now(): continue
        if best is None or p["CreationDate"] > best[0]: best = (p["CreationDate"], path)
print(best[1] if best else "")
PY
}
profile="${OTTSEL_PROVISIONING_PROFILE:-$(find_profile)}"
if [ -z "$profile" ]; then
  echo "== creating a development profile for $bundle_id (team $team) through Xcode =="
  stub="$work/stub"
  mkdir -p "$stub"
  printf 'int main(void) { return 0; }\n' > "$stub/main.m"
  cat > "$stub/project.yml" <<YML
name: OttselProvision
targets:
  OttselProvision:
    type: application
    platform: iOS
    deploymentTarget: "18.5"
    sources: [main.m]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $bundle_id
      DEVELOPMENT_TEAM: $team
      CODE_SIGN_STYLE: Automatic
      GENERATE_INFOPLIST_FILE: YES
YML
  (cd "$stub" && xcodegen generate --quiet)
  xcodebuild -project "$stub/OttselProvision.xcodeproj" -scheme OttselProvision \
    -destination "id=$device_udid" -derivedDataPath "$stub/build" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration build >"$work/provision.log" 2>&1 ||
    { echo "Xcode could not provision $bundle_id; see $work/provision.log" >&2; exit 1; }
  profile="$(find_profile)"
  [ -n "$profile" ] || { echo "Xcode built the stub but no matching profile appeared" >&2; exit 1; }
fi
echo "identity: $identity"
echo "profile:  $profile"

# 4. Build the strict device app (every code module signed; runtime code loading is fatal).
OTTSEL_PLATFORM=device OTTSEL_SIGN_IDENTITY="$identity" OTTSEL_PROVISIONING_PROFILE="$profile" \
OTTSEL_BUNDLE_ID="$bundle_id" OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 \
OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json OTTSEL_SIGNED_EXPORT_BANKS=1 \
  bash "$repo/scripts/build-ios.sh"
app="$repo/out/jak-project/out/ios-device/app/OttselShell.app"
installed_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"

# 5. Install, hand over the pack (the app validates and promotes it on launch), launch.
xcrun devicectl device install app --device "$device_id" "$app"
xcrun devicectl device copy to --device "$device_id" --domain-type appDataContainer \
  --domain-identifier "$installed_id" --source "$pack" --destination Documents/OttselUserData
xcrun devicectl device process launch --device "$device_id" "$installed_id"
echo "Launched $installed_id. The first launch imports the pack (OTTSEL F1 in the app's runtime log)."
