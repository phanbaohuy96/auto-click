# 03 — Ngữ nghĩa thực thi

Chỉ tồn tại **một** bộ chạy. **Chế độ đơn giản** dựng một **Kịch bản** một bước rồi giao cho
chính bộ chạy đó ([ADR-0002](../adr/0002-buoc-la-hanh-dong-nhan-vi-tri.md)).

## Vòng đời một lần chạy

- **EX-1** `[Lát 1]` `[đã làm]` Trình tự: kiểm tra hợp lệ → xin quyền nếu thiếu → đưa **Ứng dụng khoá**
  lên trước (nếu có) → đếm ngược 3 giây → chạy các vòng lặp → kết thúc.
- **EX-2** `[Lát 1]` `[đã làm]` Từ chối chạy khi: **Kịch bản** rỗng, vi phạm `DM-18`, **Ứng dụng khoá**
  không chạy, hoặc thiếu quyền Accessibility. Mỗi trường hợp có một thông báo riêng.
- **EX-3** `[Lát 1]` `[đã làm]` Đếm ngược 3 giây có thể huỷ; huỷ trong lúc đếm ngược thì **không** phát
  sự kiện nào.
- **EX-4** `[Lát 1]` `[đã làm]` Vòng lặp: `for mỗi lần lặp Kịch bản { for mỗi Bước { for mỗi lần lặp Bước } }`.
- **EX-5** `[Lát 1]` `[đã làm]` Khoảng chờ của **Bước** áp dụng sau **mỗi** lần lặp của **Bước** đó, kể cả
  lần cuối. Đây là điểm khác có chủ ý so với phiên bản 1.2.0 (vốn bỏ khoảng chờ sau lần click
  cuối cùng): nhờ vậy khoảng chờ giữa hai lần lặp **Kịch bản** không cần quy tắc riêng.

## Giải Vị trí

- **EX-6** `[Lát 1]` `[đã làm]` **Vị trí** được giải **ngay trước mỗi lần lặp của Bước**, không phải một
  lần cho cả **Bước**. `DM-19` phụ thuộc vào điều này.
- **EX-7** `[Lát 2]` `[đã làm]` Giải `lệchCửaSổ` cần **Cửa sổ neo**; không lấy được cửa sổ nào thì dừng
  **Kịch bản** với thông báo nêu rõ tên ứng dụng.
- **EX-8** `[Lát 4]` `[đã làm]` Giải `theoẢnh`/`theoChữ` thử lại theo nhịp bằng khoảng chờ của **Bước**,
  tối thiểu 150 ms, cho đến khi hết `chờTốiĐaMs`. Hết giờ thì làm theo `khiHếtGiờ` (`DM-16`).
- **EX-9** `[Lát 4]` `[đã làm]` `bỏQuaBước` bỏ **toàn bộ** các lần lặp còn lại của **Bước** đó, không phải
  chỉ lần lặp hiện tại.

## Ứng dụng khoá

- **EX-10** `[Lát 1]` `[đã làm]` Trước mỗi sự kiện **có toạ độ**, nếu có **Ứng dụng khoá** thì hỏi
  Accessibility xem điểm đó thuộc tiến trình nào; khác PID đã khoá thì dừng **Kịch bản**.
  Đây là hành vi đã có, giữ nguyên (`ClickRoutingPolicy`).
- **EX-11** `[Lát 1]` `[đã làm]` **Ứng dụng khoá** bị đóng giữa chừng thì dừng **Kịch bản**.
- **EX-12** `[Lát 2]` `[đã làm]` Sự kiện bàn phím không có toạ độ nên `EX-10` không áp dụng được; thay vào
  đó xem `SF-4`.

## Dừng

- **EX-13** `[Lát 1]` `[đã làm]` Dừng được kích hoạt từ: nút trong popover, nút trên bảng nổi, phím tắt
  `⌥⌘S`, hoặc do lỗi. Mọi đường đều đi qua cùng một chỗ.
- **EX-14** `[Lát 1]` `[đã làm]` Khi dừng vì bất kỳ lý do gì — kể cả huỷ tác vụ — bộ chạy **phải** nhả mọi
  nút chuột đang giữ trước khi thoát. Xem `SF-1`.
- **EX-15** `[Lát 1]` `[đã làm]` Sau khi dừng, trạng thái hiển thị nêu rõ lý do: hoàn tất, người dùng dừng,
  hay lỗi (kèm mô tả).

## Chi tiết phát sự kiện

- **EX-16** `[Lát 1]` `[đã làm]` Một `click` với `sốLần = n` phát `n` cặp `mouseDown`/`mouseUp` liên tiếp,
  đặt trường `mouseEventClickState` lần lượt `1, 2, … n`. Thiếu trường này thì AppKit coi đó là
  `n` cú click rời rạc, **không phải** double click.
- **EX-17** `[Lát 1]` `[đã làm]` Khoảng cách giữa hai cặp trong cùng một `click` là 30 ms, đủ nhỏ so với
  khoảng double-click của hệ thống.
- **EX-18** `[Lát 1]` `[đã làm]` `giữMs > 0` thì `mouseUp` phát sau `mouseDown` đúng `giữMs`; con trỏ không
  di chuyển giữa hai sự kiện.
- **EX-19** `[Lát 1]` `[đã làm]` Mọi sự kiện đều phát vào `.cghidEventTap` để ứng dụng đích xử lý như thao
  tác thật.
- **EX-20** `[Lát 2]` `[đã làm]` Kéo thả phát `mouseDown` tại điểm đầu, 24 sự kiện `mouseDragged`
  nội suy đều nhau cách nhau 8 ms, rồi `mouseUp` tại điểm cuối. Nhiều ứng dụng **bỏ qua** thao tác
  kéo nếu con trỏ nhảy thẳng từ đầu tới cuối mà không có điểm nào ở giữa.
- **EX-21** `[Lát 2]` `[đã làm]` `gõChuỗi` dùng `keyboardSetUnicodeString` chứ không tra mã phím,
  nên không phụ thuộc bố cục bàn phím và gõ được cả tiếng Việt lẫn emoji.
- **EX-22** `[Lát 2]` `[đã làm]` `nhấnPhím` phát mã phím vật lý kèm cờ phím bổ trợ gắn thẳng vào
  sự kiện. Phím bổ trợ **không** được phát thành sự kiện riêng, nên huỷ giữa chừng không để lại
  phím nào bị kẹt — khác hẳn với nút chuột ở `SF-1`.
- **EX-23** `[Lát 2]` `[đã làm]` Với kéo thả, chỉ **điểm đầu và điểm cuối** được kiểm tra theo
  `EX-10`. Hỏi Accessibility ở từng chặng sẽ làm thao tác kéo giật và có thể dừng giữa chừng, để
  lại nút chuột đang giữ cho `SF-1` dọn.
