#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || "$(uname -s)" != Darwin ]]; then
  echo 'Usage (macOS): tools/build-dmg.sh /path/to/DClutter.app [output-directory]' >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
application="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
info_plist="$application/Contents/Info.plist"
if [[ ! -f "$info_plist" || "$(basename "$application")" != DClutter.app ]]; then
  echo 'Expected a built DClutter.app with Contents/Info.plist.' >&2
  exit 1
fi
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
if [[ "$bundle_id" != dev.djenriquez.DClutter ]]; then
  echo 'The supplied app is not DClutter.' >&2
  exit 1
fi
release_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
if [[ ! "$release_version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
  echo 'Expected a numeric release version in the app bundle.' >&2
  exit 1
fi

packager="$project_root/build/dmg-tools/bin/dmgbuild"
if [[ ! -x "$packager" ]]; then
  echo 'Install the packaging tools first; see tools/dmg/README.md.' >&2
  exit 1
fi
output_directory="${2:-$project_root/build/releases/$release_version}"
mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"
output_file="$output_directory/DClutter-$release_version.dmg"
if [[ -e "$output_file" || -e "$output_file.sha256" ]]; then
  echo "Output already exists: $output_file. Choose a different output directory." >&2
  exit 1
fi

staging_directory="$(mktemp -d "$project_root/build/dmg.XXXXXX")"
trap 'rm -rf "$staging_directory"' EXIT
"$packager" -s "$project_root/tools/dmg/settings.py" -D "app=$application" -D "project=$project_root" \
  'DClutter' "$staging_directory/DClutter-$release_version.dmg"
hdiutil verify "$staging_directory/DClutter-$release_version.dmg"
mv "$staging_directory/DClutter-$release_version.dmg" "$output_file"
(cd "$output_directory" && shasum -a 256 "DClutter-$release_version.dmg" > "DClutter-$release_version.dmg.sha256")
echo "Created $output_file"
