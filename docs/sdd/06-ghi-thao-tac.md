# 06 — Ghi thao tác

Lát 3. Xem [ADR-0003](../adr/0003-khong-ghi-ban-phim-khi-record.md) (không ghi bàn phím) và
[ADR-0004](../adr/0004-ban-ghi-giu-nguyen-thoi-gian-that.md) (không cắt trần thời gian).

## Phiên ghi

- **RC-1** Bắt đầu và kết thúc **Phiên ghi** bằng phím tắt toàn cục `⌥⌘R`, **không** bằng nút
  trên màn hình — click vào nút sẽ tự lọt vào bản ghi.
- **RC-2** Sự kiện nào có tiến trình đích là chính Auto Click thì bị loại khỏi bản ghi.
- **RC-3** Trong lúc ghi, bảng nổi hiển thị số **Bước** đã ghi và nhắc `⌥⌘R` để kết thúc.
- **RC-4** **Phiên ghi** chỉ quan sát chuột: `mouseDown`, `mouseUp`, `mouseDragged`, `scrollWheel`.

## Suy luận Hành động

- **RC-5** `down` rồi `up` trong vòng 400 ms, di chuyển ≤ 3 pt → `click(nút, 1, 0)`.
- **RC-6** `down` rồi `up` sau **hơn** 400 ms, di chuyển ≤ 3 pt → `click(nút, 1, giữMs = thời gian giữ thật)`.
- **RC-7** Hai `click` cùng nút, cách nhau dưới khoảng double-click của hệ thống và trong vòng
  5 pt → gộp thành `click(nút, 2, 0)`. Ba lần thì thành `count = 3`.
- **RC-8** `down` → `dragged` vượt 3 pt → `up` → `kéoThả`, giữ lại các điểm trung gian đã được
  giảm mẫu còn tối đa 32 điểm.
- **RC-9** Một tràng `scrollWheel` cùng hướng, các sự kiện cách nhau dưới 150 ms → gộp thành một
  `cuộn` duy nhất với tổng delta. Không gộp thì một lần cuộn trackpad thành khoảng 100 **Bước**.

## Thời gian

- **RC-10** Khoảng chờ của **Bước** là khoảng cách thật giữa lúc **Bước** đó kết thúc và lúc
  **Bước** kế tiếp bắt đầu, **không cắt trần, không làm tròn**.
- **RC-11** **Bước** cuối cùng có khoảng chờ `0`.

## Sinh Vị trí

- **RC-12** Với mỗi thao tác, hỏi Accessibility xem tiến trình nào sở hữu điểm đó.
- **RC-13** Mọi thao tác trong phiên thuộc **cùng một** ứng dụng → đặt ứng dụng đó làm
  **Ứng dụng khoá** và sinh **Vị trí** `lệchCửaSổ` (`DM-13`).
- **RC-14** Thao tác trải trên nhiều ứng dụng → sinh **Vị trí** `điểmMànHình`, không đặt
  **Ứng dụng khoá**, và hiện cảnh báo rằng toạ độ sẽ trượt nếu cửa sổ dịch chuyển.
- **RC-15** **Phiên ghi** không bao giờ tự sinh **Vị trí** theo **Ảnh mẫu**. Nâng cấp một
  **Bước** lên `theoẢnh` là hành động có chủ ý của người dùng trong cửa sổ soạn thảo.

## Kết quả

- **RC-16** Kết thúc **Phiên ghi** tạo một **Kịch bản** mới đã lưu, tên mặc định theo ứng dụng
  và thời điểm ghi, rồi mở cửa sổ soạn thảo với **Kịch bản** đó.
- **RC-17** **Phiên ghi** không ghi được **Bước** nào thì không tạo **Kịch bản**.
