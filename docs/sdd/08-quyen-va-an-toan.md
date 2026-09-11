# 08 — Quyền và an toàn

## Nhả nút chuột

- **SF-1** `[Lát 1]` `[đã làm]` Bộ chạy **phải** nhả mọi nút chuột đang giữ khi kết thúc vì bất kỳ lý do gì:
  hoàn tất, người dùng dừng, lỗi, hay tác vụ bị huỷ.

  Đây không phải chuyện lý thuyết. Từ Lát 1 đã có `giữMs`, và từ Lát 2 có kéo thả — cả hai đều
  để lại `mouseDown` chưa có `mouseUp` nếu bị cắt giữa chừng. Hệ điều hành khi đó tin rằng nút
  chuột đang bị giữ, và người dùng **mất khả năng thao tác** cho tới khi tự click một cái.
  Vì `⌥⌘S` là lối thoát hiểm duy nhất khi kịch bản đang chạy, nó tuyệt đối không được đẩy máy
  vào trạng thái đó.

- **SF-2** `[Lát 1]` `[đã làm]` Việc nhả nút phải chạy được cả khi tác vụ đã bị huỷ — tức là không nằm sau
  bất kỳ điểm `await` nào có thể ném `CancellationError`.

## Quyền hệ thống

- **SF-3** `[Lát 1]` `[đã làm]` **Accessibility** — cần để phát sự kiện và để hỏi tiến trình tại một điểm.
  Xin lúc bấm Bắt đầu lần đầu.
- **SF-5** `[Lát 4]` `[đã làm]` **Screen Recording** — cần cho **Ảnh mẫu** và tìm theo chữ. Chỉ xin khi
  người dùng dùng tới, không xin lúc khởi động.
- **SF-6** `[đã làm]` Auto Click **không bao giờ** xin **Input Monitoring**, và bộ ghi **không bao
  giờ** nghe bàn phím. Xem [ADR-0003](../adr/0003-khong-ghi-ban-phim-khi-record.md).

  Ba tầng kiểm chứng, tầng đầu là tầng duy nhất **tự động chặn được người sửa code sau này**:

  1. `ScenarioRecorder.recordedEventTypes` chỉ có chuột và cuộn, và có test canh — thêm `.keyDown`
     vào là test đỏ ngay. Trước đây mặt nạ nằm trong thân `startSession`, chỉ `CGEventTap` thật mới
     chạm tới, nên ràng buộc an toàn mạnh nhất của dự án **không có test nào giữ**.
  2. Bơm thẳng một `keyDown` mang chuỗi vào `ScenarioRecorder.handle` thì không ra Bước nào — kể cả
     khi mặt nạ bị nới ra, phần giải mã cũng không biến phím thành dữ liệu.
  3. Không có lời gọi `IOHIDRequestAccess`/`IOHIDCheckAccess` nào trong mã nguồn, và `Info.plist`
     không có khoá xin quyền này.

  Hai chỗ dùng `keyDown` còn lại là `NSEvent.addLocalMonitorForEvents` trong hai lớp phủ khoanh
  vùng: **local** monitor chỉ thấy phím gửi tới cửa sổ của chính app, không cần quyền gì, và chỉ để
  bắt phím Esc.
- **SF-10** `[đã làm]` Thông báo khi thiếu **Accessibility** phải nêu **cả hai** khả năng: chưa
  cấp bao giờ, và đã cấp nhưng quyền hết hiệu lực sau khi cập nhật app. Cài đè một bản mới làm
  đổi chữ ký, macOS vô hiệu hoá quyền cũ **nhưng vẫn hiển thị toggle đang bật**; người dùng mở
  System Settings ra, thấy Auto Click đã bật, và kết luận app hỏng. Cách chữa là tắt rồi bật lại
  mục đó. Không có API nào đọc được trạng thái thật để phân biệt, nên phải nói ra cả hai — cùng
  lối với `SF-7`. Phát hiện khi chạy phiên A của [kiểm thử tay](../kiem-thu-e2e.md), không phải
  khi viết đặc tả: chỉ cài đè lên một bản đã được cấp quyền mới lộ ra.
- **SF-7** `[Lát 4]` `[đã làm]` Thông báo lỗi khi chụp màn hình thất bại phải nêu **cả hai** khả
  năng: chưa cấp quyền, và đã cấp nhưng cần thoát rồi mở lại app.

  Đặc tả ban đầu đòi *phân biệt* hai trường hợp. Không làm được: `CGPreflightScreenCaptureAccess()`
  trả `false` ở cả hai, và không có API nào đọc được trạng thái TCC thật. Bản build ký ad-hoc bị
  macOS coi là ứng dụng khác sau mỗi lần cập nhật nên rơi vào trường hợp thứ hai rất thường xuyên,
  vì vậy nêu ra cả hai vẫn hữu ích hơn là im lặng.

## Gõ phím và focus

- **SF-4** `[Lát 2]` `[đã làm]` Trước mỗi **Bước** gõ phím, nếu có **Ứng dụng khoá** và nó không phải ứng
  dụng đang ở trước, thì gọi `activate` và chờ tối đa 500 ms để nó lên trước. Vẫn không lên được
  thì **dừng Kịch bản**.

  Lý do: sự kiện bàn phím không mang toạ độ nên `EX-10` không bảo vệ được nó. Không kiểm tra thì
  một thông báo cướp focus giữa chừng sẽ khiến kịch bản gõ vào nhầm ứng dụng.

## Giới hạn

- **SF-8** `[Lát 1]` `[đã làm]` Bộ chạy luôn nhường ít nhất 10 ms giữa hai sự kiện liên tiếp, kể cả khi
  khoảng chờ của **Bước** bằng 0, để một **Kịch bản** cấu hình sai không làm treo giao diện hệ
  thống. Đây là chặn dưới đã có từ 1.2.0, chuyển từ ràng buộc nhập liệu thành ràng buộc lúc chạy.
- **SF-9** `[Lát 1]` `[đã làm]` **Kịch bản** không giới hạn vẫn phải kiểm tra huỷ ở mỗi **Bước**, để `⌥⌘S`
  có tác dụng trong vòng một **Bước**.
