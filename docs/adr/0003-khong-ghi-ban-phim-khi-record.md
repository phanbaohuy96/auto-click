# Phiên ghi không ghi bàn phím

**Phiên ghi** chỉ lắng nghe chuột. Bước gõ phím phải do người dùng thêm tay sau khi ghi.

Phát sự kiện bàn phím đi thì chỉ cần quyền Accessibility đã có, nhưng *ghi lại* bàn phím buộc
phải xin **Input Monitoring** — quyền thứ ba — và về bản chất biến app thành keylogger toàn hệ
thống: gõ nhầm mật khẩu vào cửa sổ khác trong lúc ghi là chuỗi đó nằm trong `scenario.json`
dưới dạng chữ thường. Nhánh chuột không có rủi ro tương đương (toạ độ click không lộ gì đáng kể),
nên hai nhánh được quyết riêng thay vì đi kèm nhau.

Phương án "ghi nhưng che ô mật khẩu" (dựa vào AX báo secure text field) đã bị loại: không phải ô
mật khẩu nào cũng khai báo đúng, nên nó tạo cảm giác an toàn mà không bảo đảm được.
