# 07 — Nhận dạng mục tiêu

Lát 4. Xem [ADR-0001](../adr/0001-screencapturekit-va-min-macos-14.md).

## Chụp màn hình

- **RG-1** Dùng `SCScreenshotManager` (macOS 14+). `Package.swift` nâng `platforms` lên `.macOS(.v14)`.
- **RG-2** Ảnh chụp trả về **pixel**, còn `CGEvent` làm việc bằng **point**. Mọi toạ độ tìm được
  phải chia cho hệ số scale của **đúng màn hình** chứa nó trước khi phát sự kiện. Máy có màn
  hình retina và màn hình ngoài cùng lúc sẽ có hai hệ số khác nhau trong cùng một không gian toạ độ.
- **RG-3** Ảnh chụp không được cache giữa các lần thử lại của `EX-8` — mục đích của việc thử lại
  là thấy giao diện **đã thay đổi**.

## Chụp Ảnh mẫu

- **RG-4** Người dùng kéo một khung trên lớp phủ toàn màn hình, mở rộng từ `ClickPointSelector`.
- **RG-5** Lớp phủ **phải được ẩn trước khi chụp**. Lớp phủ đang tô `black.withAlphaComponent(0.10)`
  lên toàn màn hình; chụp lúc nó còn hiện sẽ cho ra **Ảnh mẫu** ám đen 10% và không bao giờ khớp
  lại được lúc chạy.
- **RG-6** Vùng tìm cũng do người dùng khoanh, và được lưu dưới dạng lệch so với một góc của
  **Cửa sổ neo** (`DM-17`). Vùng tìm tuyệt đối bị loại: cửa sổ dịch 40 pt là **Ảnh mẫu** trôi ra
  ngoài khung, engine báo "không thấy" dù ảnh vẫn ở trên màn hình — tức là cái sinh ra để chống
  mỏng manh lại tự trở thành chỗ mỏng manh nhất.
- **RG-7** Không khoanh vùng tìm thì phạm vi tìm là: **Cửa sổ neo** nếu có **Ứng dụng khoá**,
  ngược lại là toàn bộ các màn hình.

## Khớp Ảnh mẫu

- **RG-8** Thuật toán là tương quan chéo chuẩn hoá theo kim tự tháp: thu nhỏ 8 lần để quét thô,
  rồi tinh chỉnh trong bán kính ±8 pixel ở độ phân giải gốc.

  Quét thẳng ở độ phân giải gốc không dùng được: mẫu 120×48 trên màn hình 3024×1964 là khoảng
  5,56 triệu vị trí × 5.760 điểm ảnh ≈ **32 tỉ phép so sánh** cho **một** lần giải **Vị trí**.
  Kim tự tháp đưa xuống khoảng 9,5 triệu phép, tức 5–15 ms.

- **RG-9** Điểm khớp là số thực `0…1`. Ngưỡng mặc định `0.90`, chỉnh được từng **Bước**.
- **RG-10** Nhiều chỗ cùng vượt ngưỡng thì lấy chỗ điểm cao nhất. Bằng điểm thì lấy chỗ trên
  cùng, trái nhất, để kết quả tất định.
- **RG-11** **Vị trí** trả về là **tâm** vùng khớp.
- **RG-12** Apple không có API khớp mẫu — không có `matchTemplate`, MetalPerformanceShaders
  không có tương quan chéo, Vision chỉ localize được chữ. Đã kiểm tra SDK. Đừng đi tìm lại.

## Tìm theo chữ

- **RG-13** Dùng `VNRecognizeTextRequest` với `recognitionLevel = .accurate`, ngôn ngữ theo
  ngôn ngữ hệ thống cộng tiếng Anh.
- **RG-14** So khớp không phân biệt hoa thường và bỏ qua khoảng trắng thừa hai đầu.
- **RG-15** **Vị trí** trả về là tâm hộp bao của đoạn chữ khớp.
- **RG-16** Nhiều đoạn cùng khớp thì lấy đoạn có độ tin cậy cao nhất; bằng nhau thì theo quy tắc
  của `RG-10`.
