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

- **RG-4** Người dùng kéo một khung trên lớp phủ toàn màn hình, mở rộng từ `ClickPointSelector`;
  vùng bên trong khung được chụp ngay thành **Ảnh mẫu**. Việc này **độc lập hoàn toàn** với
  **Ứng dụng khoá**: khoanh được ở bất cứ đâu trên bất cứ màn hình nào.

  Điều đó là có chủ ý chứ không phải sự tiện tay. Mục tiêu cần nhắm thường **chưa hiện trên màn
  hình** lúc soạn Kịch bản — hộp thoại chưa bật, nút chỉ xuất hiện sau khi trang tải. Người dùng
  khi đó mở một ảnh chụp màn hình cũ trong Preview và khoanh **Ảnh mẫu** từ chính ảnh đó. Bắt
  khoanh trong cửa sổ của **Ứng dụng khoá** sẽ làm đúng cách dùng này bất khả thi.
- **RG-5** Lớp phủ **phải được ẩn trước khi chụp**. Lớp phủ đang tô `black.withAlphaComponent(0.10)`
  lên toàn màn hình; chụp lúc nó còn hiện sẽ cho ra **Ảnh mẫu** ám đen 10% và không bao giờ khớp
  lại được lúc chạy.
- **RG-6** Vùng tìm cũng do người dùng khoanh, và **không bắt buộc** phải có (`DM-17`). Cách lưu
  được chọn tự động theo thứ tự ưu tiên:

  1. **Kịch bản** có **Ứng dụng khoá** và lấy được **Cửa sổ neo** lúc khoanh → lưu lệch so với
     góc gần nhất của cửa sổ đó, cùng quy tắc `DM-13`.
  2. Ngược lại → lưu toạ độ tuyệt đối trên màn hình.

  Cách 1 tốt hơn hẳn: cửa sổ dịch 40 pt thì vùng tìm đi theo, còn vùng tuyệt đối sẽ báo
  "không thấy" dù **Ảnh mẫu** vẫn nằm trên màn hình. Nhưng nó **không được** trở thành điều kiện
  bắt buộc, vì như vậy sẽ chặn cách dùng ở `RG-4`. Khi phải rơi về cách 2, giao diện nói rõ vùng
  tìm là tuyệt đối và sẽ trượt nếu cửa sổ dịch chuyển.

- **RG-17** **Vị trí** `theoẢnh` và `theoChữ` dùng được **không cần Ứng dụng khoá**. Khoá ứng dụng
  chỉ làm việc tìm nhanh hơn và bớt nhiễu (`RG-7`), không phải điều kiện tiên quyết.
- **RG-7** Không khoanh vùng tìm thì phạm vi tìm là: **Cửa sổ neo** nếu có **Ứng dụng khoá** và
  lấy được cửa sổ, ngược lại là toàn bộ các màn hình.

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
