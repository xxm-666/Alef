#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodebuild >/dev/null || { echo "App Store archives require Xcode on macOS." >&2; exit 1; }
: "${ALEF_DEVELOPMENT_TEAM:?Set ALEF_DEVELOPMENT_TEAM to your Apple Developer Team ID}"
version=${ALEF_MARKETING_VERSION:-3.0.0}
build_number=${ALEF_BUILD_NUMBER:?Set ALEF_BUILD_NUMBER to an unused App Store Connect build number}
output=${ALEF_ARCHIVE_OUTPUT:-"$PWD/release/app-store"}
mkdir -p "$output"
output=$(cd "$output" && pwd)
archive="$output/Alef.xcarchive"
export_options="$output/ExportOptions.plist"

[[ "$ALEF_DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid Apple Developer Team ID." >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "Invalid App Store version." >&2; exit 1; }
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || { echo "Build number must be a positive integer." >&2; exit 1; }
if [[ -e "$archive" || -e "$output/export" ]]; then
    echo "Choose an unused ALEF_ARCHIVE_OUTPUT directory." >&2
    exit 1
fi

if [[ -n "${ALEF_APP_PROFILE:-}" || -n "${ALEF_WIDGET_PROFILE:-}" ]]; then
    : "${ALEF_APP_PROFILE:?Set the installed App Store profile for the main app}"
    : "${ALEF_WIDGET_PROFILE:?Set the installed App Store profile for the widget}"
    signing_args=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Apple Distribution"
                  "ALEF_APP_PROFILE=$ALEF_APP_PROFILE" "ALEF_WIDGET_PROFILE=$ALEF_WIDGET_PROFILE")
    export_args=()
else
    signing_args=(CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates)
    export_args=(-allowProvisioningUpdates)
fi

npm run prepare:ios -- --app-store
xcodebuild archive -project ios/App/App.xcodeproj -scheme App \
    -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" \
    "DEVELOPMENT_TEAM=$ALEF_DEVELOPMENT_TEAM" \
    "MARKETING_VERSION=$version" "CURRENT_PROJECT_VERSION=$build_number" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=ALEF_APP_STORE "${signing_args[@]}"

app="$archive/Products/Applications/App.app"
widget="$app/PlugIns/DailyLetterWidget.appex"
test -s "$app/PrivacyInfo.xcprivacy"
test -s "$app/StudyAssets/privacy.txt"
test -s "$app/StudyAssets/audio/CREDITS.md"
test -s "$widget/widget-words.json"
for bundle in "$app" "$widget"; do
    test "$(plutil -extract CFBundleShortVersionString raw -o - "$bundle/Info.plist")" = "$version"
    test "$(plutil -extract CFBundleVersion raw -o - "$bundle/Info.plist")" = "$build_number"
done
codesign --verify --deep --strict "$app"

ALEF_EXPORT_OPTIONS="$export_options" node --input-type=module <<'NODE'
import { writeFileSync } from 'node:fs';
const { ALEF_EXPORT_OPTIONS, ALEF_DEVELOPMENT_TEAM, ALEF_APP_PROFILE, ALEF_WIDGET_PROFILE } = process.env;
const options = {
  method: 'app-store-connect',
  destination: 'export',
  teamID: ALEF_DEVELOPMENT_TEAM,
  manageAppVersionAndBuildNumber: false,
  signingStyle: ALEF_APP_PROFILE ? 'manual' : 'automatic',
};
if (ALEF_APP_PROFILE) {
  options.signingCertificate = 'Apple Distribution';
  options.provisioningProfiles = {
    'com.xxm666.alef': ALEF_APP_PROFILE,
    'com.xxm666.alef.dailyletter': ALEF_WIDGET_PROFILE,
  };
}
writeFileSync(ALEF_EXPORT_OPTIONS, JSON.stringify(options));
NODE
plutil -convert xml1 "$export_options"

# macOS can still ship Bash 3.2, where an empty array trips nounset.
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output/export" \
    -exportOptionsPlist "$export_options" ${export_args[@]+"${export_args[@]}"}

printf 'App Store archive: %s\nUploadable IPA: %s\n' "$archive" "$output/export"
