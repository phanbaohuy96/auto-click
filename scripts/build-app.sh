#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/Auto Click.app"
contents_dir="$app_dir/Contents"
binary_dir="$(cd "$project_dir" && swift build -c "$configuration" --show-bin-path)"
# Ký ad-hoc ("-") cho yêu cầu định danh là cdhash, mà cdhash đổi theo mỗi lần build — nên mọi
# quyền đã cấp đều hết hiệu lực sau mỗi lần cài. Có chứng chỉ cố định thì dùng nó, để cấp quyền
# một lần là xong. Tạo bằng ./scripts/create-local-signing-identity.sh
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
