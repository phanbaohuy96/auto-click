# Dùng ScreenCaptureKit và nâng min macOS lên 14

Tính năng Vị trí "theo ảnh" cần chụp màn hình. `CGDisplayCreateImage` vẫn chạy được
trên macOS 26.5 khi binary target macOS 13 (đã kiểm chứng bằng chạy thật), nhưng SDK
đánh dấu nó `SCREEN_CAPTURE_OBSOLETE(10.6, 14.4, 15.0)` — build với target macOS 15
trở lên là **lỗi compile**, không phải cảnh báo. Chọn `SCScreenshotManager`
(macOS 14+) và nâng `platforms` trong Package.swift lên `.macOS(.v14)`, chấp nhận bỏ
macOS 13, để không phải viết lại nhánh chụp ảnh vào lần nâng min tiếp theo.

## Consequences

- Đường chụp ảnh là **async**; bộ chạy Kịch bản phải `await` mỗi lần giải một Vị trí theo ảnh.
- Cần quyền **Screen Recording**, tách biệt với quyền Accessibility đang có. App giờ có hai
  quyền phải xin, và người dùng có thể cấp một mà quên cái kia.
