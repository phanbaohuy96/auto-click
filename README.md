# Auto Click cho macOS

Ứng dụng native nằm trên menu bar, hỗ trợ:

- Chọn khoảng thời gian giữa hai lần click (10–3.600.000 ms).
- Chọn số lần lặp (1–1.000.000).
- Click theo vị trí con trỏ hoặc một điểm cố định đã lưu.
- Chọn điểm trực tiếp trên bất kỳ màn hình nào; nhấn `Esc` để hủy chọn.
- Khóa click vào một ứng dụng đang chạy và xác minh ứng dụng sở hữu điểm click.
- Tự dừng nếu ứng dụng đích bị đóng để không click nhầm ứng dụng khác.
- Đếm ngược 3 giây để đặt con trỏ vào đúng vị trí.
- Dừng nhanh từ icon trên menu bar.
- Hiện live activity nổi khi chạy, với nút **Dừng** luôn nhìn thấy.
- Phím tắt toàn cục `⌥⌘S` để dừng ngay cả khi đang dùng ứng dụng khác.
- Ghi nhớ cấu hình và tự khởi động khi đăng nhập macOS.

## Build và cài đặt

Yêu cầu macOS 13 trở lên và Xcode Command Line Tools.

```bash
./scripts/install.sh
# Hoặc:
sh ./scripts/install.sh
```

Script sẽ build bản release, đóng phiên bản cũ, cài vào `/Applications`, kiểm tra chữ ký và mở lại app. Để cài bundle đã build sẵn hoặc không tự mở app:

```bash
./scripts/install.sh --no-build
./scripts/install.sh --no-launch
```

Chỉ build bundle mà không cài đặt:

```bash
./scripts/build-app.sh
```

Lần đầu bấm **Bắt đầu**, macOS sẽ yêu cầu quyền Accessibility. Mở:

`System Settings → Privacy & Security → Accessibility`

Sau đó bật quyền cho **Auto Click**. Nên chạy app từ `/Applications` trước khi bật “Khởi động cùng MacBook” để macOS đăng ký đúng vị trí ứng dụng.

Bản build local mặc định dùng chữ ký ad-hoc, vì vậy macOS có thể yêu cầu bật lại quyền Accessibility sau khi cập nhật. Nếu có certificate macOS ổn định, có thể chỉ định khi build/cài:

```bash
AUTO_CLICK_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
```

Để giới hạn click, bật **Chỉ click trong ứng dụng** và chọn một app đang chạy. Nút làm mới bên cạnh danh sách sẽ nhận các app vừa được mở. Auto Click đưa app đó lên trước khi chạy, kiểm tra UI tại tọa độ thuộc đúng PID đã chọn rồi mới phát click toàn hệ thống. App tự dừng nếu ứng dụng bị đóng hoặc điểm click nằm ngoài ứng dụng đó.

Ở chế độ **Theo con trỏ**, mỗi lần click sử dụng vị trí con trỏ tại đúng thời điểm đó. Ở chế độ **Điểm cố định**, app luôn click vào tọa độ đã lưu. Sau khi chọn một điểm mới, cửa sổ cấu hình sẽ tự hiện lại.

## Phát triển

```bash
swift test
swift run AutoClick
```

Khi chạy bằng `swift run`, tính năng click có thể cần cấp quyền cho Terminal. Bản `.app` trong `/Applications` là cách chạy khuyến nghị.
