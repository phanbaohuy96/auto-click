# 05 — Giao diện

## Bề mặt

- **UI-1** `[Lát 1]` `[đã làm]` Popover trên menu bar là **bề mặt chạy**: chọn **Kịch bản**, Bắt đầu/Dừng,
  Ghi, mở cửa sổ soạn thảo, và **Chế độ đơn giản**. Nó không chứa trình sửa **Bước**.
- **UI-2** `[Lát 1]` `[đã làm]` Cửa sổ soạn thảo là **bề mặt cấu hình**: resize được, hai cột — danh sách
  **Bước** bên trái, chi tiết **Bước** đang chọn bên phải.
- **UI-3** `[Lát 1]` `[đã làm]` App là agent (`LSUIElement`), nên mở cửa sổ soạn thảo phải kèm
  `NSApp.activate` — không thì cửa sổ hiện lên mà không nhận bàn phím.
- **UI-4** `[Lát 1]` `[đã làm]` Popover đóng lại khi người dùng click ra ngoài. Mọi thao tác **bắt buộc**
  phải click ra ngoài (chọn điểm, chụp **Ảnh mẫu**) đều phải chạy từ cửa sổ soạn thảo hoặc từ
  một lớp phủ toàn màn hình, không phải từ popover.

## Chế độ đơn giản

- **UI-5** `[Lát 1]` `[đã làm]` Giữ nguyên các control của 1.2.0: khoảng thời gian, số lần lặp, vị trí
  (theo con trỏ / điểm cố định), khoá ứng dụng.
- **UI-6** `[Lát 1]` `[đã làm]` Bấm Bắt đầu ở **Chế độ đơn giản** dựng một **Kịch bản** một bước:
  `click(trái, 1, 0)` với **Vị trí** tương ứng, số lần lặp **Bước** = số lần lặp đã nhập,
  khoảng chờ = khoảng thời gian đã nhập, số lần lặp **Kịch bản** = 1.
- **UI-7** `[Lát 1]` `[đã làm]` **Kịch bản** dựng từ **Chế độ đơn giản** **không** được lưu vào đĩa. Nó là
  vật thể tạm, sinh ra mỗi lần bấm Bắt đầu.

## Trình sửa Bước

- **UI-8** `[Lát 1]` `[đã làm]` Mỗi dòng trong danh sách hiển thị: số thứ tự, tóm tắt **Hành động**, tóm tắt
  **Vị trí**, số lần lặp nếu `> 1`, và khoảng chờ nếu `> 0`.
- **UI-9** `[Lát 1]` `[đã làm]` Sắp xếp lại bằng kéo thả; thêm, nhân bản, xoá **Bước**.
- **UI-10** `[Lát 1]` `[đã làm]` Panel chi tiết bày hai picker tách bạch — **Hành động** và **Vị trí** —
  đúng theo mô hình trực giao, cộng các trường tham số phụ thuộc lựa chọn.
- **UI-11** `[Lát 1]` `[đã làm]` Mọi sửa đổi được lưu ngay, không có nút Lưu.
- **UI-12** `[Lát 1]` `[đã làm]` Không cho sửa khi **Kịch bản** đang chạy.

## Trạng thái khi chạy

- **UI-13** `[Lát 1]` `[đã làm]` Bảng nổi hiện khi đang chạy, luôn thấy được, có nút Dừng, hiển thị:
  vòng lặp **Kịch bản** thứ mấy trên tổng, và **Bước** thứ mấy trên tổng.
- **UI-14** `[Lát 1]` `[đã làm]` **Kịch bản** không giới hạn hiển thị số vòng đã chạy, không hiển thị tổng.
- **UI-15** `[Lát 1]` `[đã làm]` Nhắc phím tắt `⌥⌘S` luôn hiện trên bảng nổi — đó là lối thoát khi chuỗi
  click đang cướp con trỏ.
- **UI-16** `[Lát 2]` `[đã làm]` Dòng trạng thái phải **phân biệt được lỗi với thành công**, và
  thông báo lỗi **không được cắt cụt**. Trước đây mọi trạng thái không-đang-chạy đều vẽ bằng
  `checkmark.circle`, nên dòng *"Có lỗi: …"* hiện kèm đúng biểu tượng của thành công, lại còn bị
  cắt ở một dòng nên không đọc hết được nguyên nhân. Phát hiện khi chạy `B3` của kiểm thử tay.
