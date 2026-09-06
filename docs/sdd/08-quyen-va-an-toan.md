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
- **SF-6** Auto Click **không bao giờ** xin **Input Monitoring**.
  Xem [ADR-0003](../adr/0003-khong-ghi-ban-phim-khi-record.md).
- **SF-7** `[Lát 4]` `[một phần]` Màn hình trạng thái quyền phải phân biệt được "chưa cấp" với "đã cấp nhưng
  cần khởi động lại app" — bản build ký ad-hoc hay rơi vào trường hợp thứ hai sau mỗi lần cập nhật.

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
