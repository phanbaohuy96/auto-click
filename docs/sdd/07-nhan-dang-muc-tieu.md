# 07 — Nhận dạng mục tiêu

Lát 4. Xem [ADR-0001](../adr/0001-screencapturekit-va-min-macos-14.md).

## Chụp màn hình

- **RG-1** `[đã làm]` Dùng `SCScreenshotManager` (macOS 14+). `Package.swift` nâng `platforms` lên `.macOS(.v14)`.
- **RG-2** `[đã làm]` Ảnh chụp trả về **pixel**, còn `CGEvent` làm việc bằng **point**. Mọi toạ độ tìm được
  phải chia cho hệ số scale của **đúng màn hình** chứa nó trước khi phát sự kiện. Máy có màn
  hình retina và màn hình ngoài cùng lúc sẽ có hai hệ số khác nhau trong cùng một không gian toạ độ.
- **RG-3** `[đã làm]` Ảnh chụp không được cache giữa các lần thử lại của `EX-8` — mục đích của việc thử lại
  là thấy giao diện **đã thay đổi**.

- **RG-20** `[đã làm]` Ảnh chụp **loại trừ cửa sổ của chính Auto Click**. Bảng nổi lúc chạy nằm ở giữa trên
  màn hình và hoàn toàn có thể che mất mục tiêu cần tìm.

## Chụp Ảnh mẫu

- **RG-4** `[đã làm]` Người dùng kéo một khung trên lớp phủ toàn màn hình, mở rộng từ `ClickPointSelector`;
  vùng bên trong khung được chụp ngay thành **Ảnh mẫu**. Việc này **độc lập hoàn toàn** với
  **Ứng dụng khoá**: khoanh được ở bất cứ đâu trên bất cứ màn hình nào.

  Điều đó là có chủ ý chứ không phải sự tiện tay. Mục tiêu cần nhắm thường **chưa hiện trên màn
  hình** lúc soạn Kịch bản — hộp thoại chưa bật, nút chỉ xuất hiện sau khi trang tải. Người dùng
  khi đó mở một ảnh chụp màn hình cũ trong Preview và khoanh **Ảnh mẫu** từ chính ảnh đó. Bắt
  khoanh trong cửa sổ của **Ứng dụng khoá** sẽ làm đúng cách dùng này bất khả thi.
- **RG-5** `[đã làm]` Lớp phủ **phải được ẩn trước khi chụp**, và phải chờ khoảng 120 ms cho window server
  thật sự gỡ nó xuống — `orderOut` chỉ là yêu cầu. Lớp phủ đang tô `black.withAlphaComponent(0.10)`
  lên toàn màn hình; chụp lúc nó còn hiện sẽ cho ra **Ảnh mẫu** ám đen 10% và không bao giờ khớp
  lại được lúc chạy.
- **RG-6** `[đã làm]` Vùng tìm cũng do người dùng khoanh, và **không bắt buộc** phải có (`DM-17`). Cách lưu
  được chọn tự động theo thứ tự ưu tiên:

  1. **Kịch bản** có **Ứng dụng khoá** và lấy được **Cửa sổ neo** lúc khoanh → lưu lệch so với
     góc gần nhất của cửa sổ đó, cùng quy tắc `DM-13`.
  2. Ngược lại → lưu toạ độ tuyệt đối trên màn hình.

  Cách 1 tốt hơn hẳn: cửa sổ dịch 40 pt thì vùng tìm đi theo, còn vùng tuyệt đối sẽ báo
  "không thấy" dù **Ảnh mẫu** vẫn nằm trên màn hình. Nhưng nó **không được** trở thành điều kiện
  bắt buộc, vì như vậy sẽ chặn cách dùng ở `RG-4`. Khi phải rơi về cách 2, giao diện nói rõ vùng
  tìm là tuyệt đối và sẽ trượt nếu cửa sổ dịch chuyển.

- **RG-17** `[đã làm]` **Vị trí** `theoẢnh` và `theoChữ` dùng được **không cần Ứng dụng khoá**. Khoá ứng dụng
  chỉ làm việc tìm nhanh hơn và bớt nhiễu (`RG-7`), không phải điều kiện tiên quyết.
- **RG-7** `[đã làm]` Không khoanh vùng tìm thì phạm vi tìm là: **Cửa sổ neo** nếu có **Ứng dụng khoá** và
  lấy được cửa sổ, ngược lại là toàn bộ các màn hình.

## Khớp Ảnh mẫu

- **RG-8** `[đã làm]` Thuật toán là tương quan chéo chuẩn hoá theo kim tự tháp: quét thô ở mức đã thu nhỏ,
  rồi tinh chỉnh trong bán kính ±8 pixel ở độ phân giải gốc.

  Quét thẳng ở độ phân giải gốc không dùng được: mẫu 120×48 trên màn hình 3024×1964 là khoảng
  5,56 triệu vị trí × 5.760 điểm ảnh ≈ **32 tỉ phép so sánh** cho **một** lần giải **Vị trí**.

- **RG-21** `[đã làm]` Mức thu nhỏ **không** cố định ở 8 như bản đặc tả đầu. Nó là mức rẻ nhất mà mẫu vẫn
  giữ được ít nhất một nửa tương phản gốc.

  Thu nhỏ cố định 8 lần **xoá sạch** hoạ tiết tần số cao — chữ, viền 1px, ô cờ nhỏ — biến mẫu thô
  thành một mảng gần như phẳng. Khi đó tương quan ở mức thô là vô nghĩa, đỉnh rơi vào chỗ ngẫu
  nhiên, và vùng tinh chỉnh còn không chứa vị trí đúng. Đây là lỗi đã thật sự xảy ra và có test
  chặn hồi quy.

- **RG-22** `[đã làm]` Quét thô giữ lại **8 ứng viên** tách rời nhau (triệt phi cực đại theo nửa kích thước
  mẫu) rồi tinh chỉnh tất cả, thay vì chỉ giữ đỉnh cao nhất. Giao diện thật đầy hoạ tiết lặp —
  một hàng nút giống nhau, đường kẻ bảng — nên chỗ tốt nhất ở mức thô hay không phải chỗ đúng ở
  mức gốc.

- **RG-23** `[Lát 2]` `[đã làm]` Chụp **Ảnh mẫu** xong thì **Vùng tìm** mặc định bám quanh chính vùng
  vừa khoanh, không phải cả màn hình. Đệm lấy nửa cạnh dài của Ảnh mẫu, chặn dưới 48 point và chặn
  trên 160 point, rồi cắt lại cho nằm trong màn hình.

  Lý do: ca dùng chính là game, nơi thứ cần nhắm gần như luôn nằm lại đúng chỗ vừa chụp. Quét cả
  màn hình vừa chậm hơn vừa dễ vớ phải một mảnh giống hệt ở chỗ khác — đúng kiểu hỏng mà `I2` của
  kiểm thử tay bày ra. Vùng gợi ý lưu theo cùng một đường với vùng khoanh tay (`RG-6`): tương đối
  **Cửa sổ neo** khi Kịch bản có khoá ứng dụng, tuyệt đối khi không. Bấm **Bỏ** là quay về tìm cả
  màn hình.

- **RG-18** `[đã làm]` Việc chọn mức thu nhỏ bị chặn trên bởi một **trần chi phí** khoảng 40 triệu phép so
  sánh cho một lần quét thô. Đây là ràng buộc đối nghịch với `RG-21`: giữ tương phản thì muốn thu
  nhỏ ít, còn quét thì muốn thu nhỏ nhiều. Khi không mức nào thoả cả hai, **trần thắng** — thà
  khớp kém chính xác còn hơn treo giao diện nhiều giây cho một **Bước**. Thu hẹp **Vùng tìm** là
  cách người dùng lấy lại độ chính xác đó.

- **RG-9** `[đã làm]` Điểm khớp là số thực `0…1`. Ngưỡng mặc định `0.90`, chỉnh được từng **Bước**.
- **RG-10** `[đã làm]` Nhiều chỗ cùng vượt ngưỡng thì lấy chỗ điểm cao nhất. Bằng điểm thì lấy chỗ trên
  cùng, trái nhất, để kết quả tất định.
- **RG-11** `[đã làm]` **Vị trí** trả về là **tâm** vùng khớp.
- **RG-12** `[đã làm]` Apple không có API khớp mẫu — không có `matchTemplate`, MetalPerformanceShaders
  không có tương quan chéo, Vision chỉ localize được chữ. Đã kiểm tra SDK. Đừng đi tìm lại.

## Tìm theo chữ

- **RG-13** `[đã làm]` Dùng `VNRecognizeTextRequest` với `recognitionLevel = .accurate`, ngôn ngữ theo
  ngôn ngữ hệ thống cộng tiếng Anh.
- **RG-14** `[đã làm]` So khớp không phân biệt hoa thường và bỏ qua khoảng trắng thừa hai đầu.
- **RG-15** `[đã làm]` **Vị trí** trả về là tâm hộp bao của **đoạn chữ khớp** — không phải của cả
  dòng Vision đọc được. Vision gộp cả dòng thành một observation, nên lấy `observation.boundingBox`
  là click vào giữa dòng: tìm `"Lưu"` trong dòng `"Lưu   ⌘S"` sẽ bắn vào khoảng trống. Phải lấy
  `candidate.boundingBox(for: range)` của đúng khoảng khớp. Phát hiện khi chạy `C9` của kiểm thử
  tay: click rơi đúng tâm cả dòng, lệch 83 point khỏi từ cần nhắm.
- **RG-16** `[đã làm]` Nhiều đoạn cùng khớp thì lấy đoạn có độ tin cậy cao nhất; bằng nhau thì theo quy tắc
  của `RG-10`.
