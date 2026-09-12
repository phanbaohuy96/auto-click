#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/Auto Click.app"
contents_dir="$app_dir/Contents"
binary_dir="$(cd "$project_dir" && swift build -c "$configuration" --show-bin-path)"
# Ad-hoc signing ("-") produces a designated requirement of cdhash, and the cdhash changes with every build —
# so every granted permission is invalidated on each install. When a stable certificate exists, use it, so that
# granting the permission once is enough. Create one with ./scripts/create-local-signing-identity.sh
local_identity="Auto Click Local Signing"
if [ -n "${AUTO_CLICK_SIGNING_IDENTITY:-}" ]; then
    signing_identity="$AUTO_CLICK_SIGNING_IDENTITY"
elif security find-identity -p codesigning | grep -q "$local_identity"; then
    signing_identity="$local_identity"
else
    signing_identity="-"
fi

cd "$project_dir"
swift build -c "$configuration"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/AutoClick" "$contents_dir/MacOS/AutoClick"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

codesign --force --deep --sign "$signing_identity" "$app_dir"

echo "$app_dir"
