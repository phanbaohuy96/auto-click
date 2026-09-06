# 01 — Phạm vi và lát cắt

## Bài toán

Auto Click hiện chỉ phát được **một** loại thao tác (click trái) lặp lại N lần tại một điểm.
Mục tiêu là nâng nó thành công cụ chạy **Kịch bản** — chuỗi thao tác đa dạng có thứ tự — và
cho phép tạo Kịch bản bằng cách **ghi lại** thao tác thật của người dùng.

## Lát cắt

Mỗi lát để lại một ứng dụng chạy được và cài được. Thứ tự đã chốt, xem [ADR-0001](../adr/0001-screencapturekit-va-min-macos-14.md)
về lý do đẩy nhận dạng xuống cuối.

### Lát 1 — Khung Kịch bản

Thay bộ chạy nằm dưới nút Bắt đầu, không thay đổi thứ người dùng làm được.

- Mô hình **Kịch bản / Bước / Hành động / Vị trí**
- Bộ chạy Kịch bản duy nhất; **Chế độ đơn giản** dựng Kịch bản một bước
- **Vị trí**: theo con trỏ, điểm tuyệt đối
- **Hành động**: click(nút, số lần, giữ), cuộn, di chuột
- Lưu trữ theo thư mục; cửa sổ soạn thảo
- Nhả nút chuột khi dừng (`SF-1`)

Điều kiện hoàn thành: mọi thao tác làm được ở phiên bản 1.2.0 vẫn làm được, và chạy qua bộ chạy mới.

### Lát 2 — Neo cửa sổ, kéo thả, gõ phím

- **Vị trí** tương đối **Cửa sổ neo** theo góc gần nhất
- **Hành động** kéo thả và gõ phím
- Đưa **Ứng dụng khoá** lên trước khi gõ phím (`SF-4`)

### Lát 3 — Ghi thao tác

- Bắt sự kiện chuột toàn hệ thống, suy luận thành **Hành động**
- Tự nâng **Vị trí** lên tương đối **Cửa sổ neo** khi cả phiên nằm trong một ứng dụng

### Lát 4 — Nhận dạng mục tiêu

- Nâng min macOS lên 14, chụp màn hình bằng ScreenCaptureKit
- **Vị trí** theo **Ảnh mẫu** (khớp kim tự tháp) và theo chữ (Vision OCR)
- Vùng tìm, ngưỡng, thời gian chờ, hành vi khi không tìm thấy

## Ngoài phạm vi

Ghi rõ những cái **không** làm, để không bị đề xuất lại:

- **Luồng điều khiển trong Kịch bản.** Không có `if`, không có nhánh, không có vòng lặp theo
  điều kiện. "Chờ đến khi nút xuất hiện" là thời gian chờ khi giải **Vị trí**, không phải vòng lặp.
- **Ghi bàn phím.** Xem [ADR-0003](../adr/0003-khong-ghi-ban-phim-khi-record.md).
- **Cắt trần thời gian chết khi ghi.** Xem [ADR-0004](../adr/0004-ban-ghi-giu-nguyen-thoi-gian-that.md).
- **Chạy Kịch bản theo lịch** hoặc kích hoạt từ ứng dụng khác.
- **Đồng bộ Kịch bản giữa nhiều máy.**
