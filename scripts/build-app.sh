#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/Auto Click.app"
contents_dir="$app_dir/Contents"
binary_dir="$(cd "$project_dir" && swift build -c "$configuration" --show-bin-path)"
signing_identity="${AUTO_CLICK_SIGNING_IDENTITY:--}"

cd "$project_dir"
swift build -c "$configuration"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/AutoClick" "$contents_dir/MacOS/AutoClick"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

codesign --force --deep --sign "$signing_identity" "$app_dir"

echo "$app_dir"
