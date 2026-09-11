#!/bin/zsh
# Tạo một chứng chỉ ký mã tự ký, dùng lại mãi, và nạp vào login keychain.
#
# Vì sao cần: ký ad-hoc (`codesign --sign -`) cho yêu cầu định danh là `cdhash H"…"`, mà cdhash
# đổi theo **mỗi lần build**. Nên mỗi lần cài lại là Accessibility và Screen Recording hết hiệu
# lực, phải vào System Settings bật lại — giữa lúc đang kiểm thử thì cực kỳ tốn thời gian.
#
# Ký bằng một chứng chỉ cố định cho yêu cầu định danh là
# `identifier "com.local.AutoClick" and certificate leaf = H"…"`, không phụ thuộc bản build. Cấp
# quyền một lần là xong.
#
# Chứng chỉ này **chỉ để dùng ở máy này**. Nó không phải Developer ID, không phân phối được, và
# không làm app đáng tin hơn với bất kỳ ai khác.

set -euo pipefail

name="Auto Click Local Signing"

if security find-identity -p codesigning | grep -q "$name"; then
    printf '%s\n' "Đã có sẵn: $name"
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $name
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -keyout "$work/key.pem" -out "$work/cert.pem" \
    -days 3650 -nodes -config "$work/cert.cnf" >/dev/null 2>&1

openssl pkcs12 -export -out "$work/bundle.p12" -inkey "$work/key.pem" -in "$work/cert.pem" \
    -passout pass:autoclick -name "$name" >/dev/null 2>&1

security import "$work/bundle.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P autoclick -T /usr/bin/codesign -T /usr/bin/security

printf '%s\n' "Đã tạo $name."
printf '%s\n' "Chạy ./scripts/install.sh rồi cấp lại Accessibility + Screen Recording MỘT lần nữa."
printf '%s\n' "Từ lần sau cài lại sẽ không mất quyền."
