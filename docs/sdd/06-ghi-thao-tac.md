# 06 — Ghi thao tác

Lát 3. Xem [ADR-0003](../adr/0003-khong-ghi-ban-phim-khi-record.md) (không ghi bàn phím) và
[ADR-0004](../adr/0004-ban-ghi-giu-nguyen-thoi-gian-that.md) (không cắt trần thời gian).

## Phiên ghi

- **RC-1** `[đã làm]` Bắt đầu và kết thúc **Phiên ghi** bằng phím tắt toàn cục `⌥⌘R`, **không** bằng nút
  trên màn hình — click vào nút sẽ tự lọt vào bản ghi.
- **RC-2** `[đã làm]` Sự kiện nào bấm vào chính Auto Click thì bị loại khỏi bản ghi, kể cả phần
  đuôi của cú thao tác đó (nhả chuột, kéo) chứ không riêng lúc nhấn xuống.

  Cần **hai** phép thử vì không phép nào đủ một mình:

  1. tiến trình đang ở trước là chính mình — bắt các cửa sổ thường;
  2. điểm bấm rơi vào một cửa sổ của chính mình — bắt **bảng nổi lúc ghi**, vốn là `NSPanel` kiểu
     `.nonactivatingPanel` nên bấm vào nó **không** làm Auto Click lên trước. Chỉ có phép thử 1
     thì cú bấm nút "Kết thúc" lọt vào bản ghi thành một Bước click thừa ngay chỗ cái nút.
- **RC-3** `[đã làm]` Trong lúc ghi, bảng nổi hiển thị số **Bước** đã ghi và nhắc `⌥⌘R` để kết thúc.
- **RC-4** `[đã làm]` **Phiên ghi** chỉ quan sát chuột: `mouseDown`, `mouseUp`, `mouseDragged`, `scrollWheel`.

## Suy luận Hành động

- **RC-5** `[đã làm]` `down` rồi `up` trong vòng 400 ms, di chuyển ≤ 3 pt → `click(nút, 1, 0)`.
- **RC-6** `[đã làm]` `down` rồi `up` sau **hơn** 400 ms, di chuyển ≤ 3 pt → `click(nút, 1, giữMs = thời gian giữ thật)`.
- **RC-7** `[đã làm]` Hai `click` cùng nút, cách nhau dưới khoảng double-click của hệ thống và trong vòng
  5 pt → gộp thành `click(nút, 2, 0)`. Ba lần thì thành `count = 3`.
- **RC-8** `[đã làm]` `down` → `dragged` vượt 3 pt → `up` → `kéoThả`, **chỉ giữ điểm đầu và điểm cuối**.

  Đặc tả ban đầu nói giữ lại các điểm trung gian đã giảm mẫu. Đã bỏ: **Hành động** `kéoThả`
  không có chỗ nào lưu đường đi (`DM-9`), và bộ chạy vốn đã dựng lại đường đi bằng nội suy
  (`EX-20`) — thứ mà mọi ứng dụng cần. Lưu đường đi thật chỉ có ích cho vẽ tay, vốn ngoài phạm vi.
- **RC-9** `[đã làm]` Một tràng `scrollWheel` có các sự kiện cách nhau dưới 150 ms → gộp thành một `cuộn`
  duy nhất với tổng delta. Không gộp thì một lần cuộn trackpad thành khoảng 100 **Bước**.

  Điều kiện "cùng hướng" trong bản đầu đã bỏ: cuộn quán tính trên trackpad thường **đổi dấu** ở
  cuối tràng, nên xét hướng sẽ cắt một thao tác của người dùng thành hai **Bước**. Gộp theo
  khoảng cách thời gian đơn thuần vừa đơn giản hơn vừa đoán đúng hơn.

## Thời gian

- **RC-10** `[đã làm]` Khoảng chờ của **Bước** là khoảng cách thật giữa lúc **Bước** đó kết thúc và lúc
  **Bước** kế tiếp bắt đầu, **không cắt trần, không làm tròn**.
- **RC-11** `[đã làm]` **Bước** cuối cùng có khoảng chờ `0`.

## Sinh Vị trí

- **RC-12** `[đã làm]` Với mỗi thao tác, hỏi Accessibility xem tiến trình nào sở hữu điểm đó.
- **RC-13** `[đã làm]` Mọi thao tác trong phiên thuộc **cùng một** ứng dụng → đặt ứng dụng đó làm
  **Ứng dụng khoá** và sinh **Vị trí** `lệchCửaSổ` (`DM-13`).
- **RC-14** `[đã làm]` Thao tác trải trên nhiều ứng dụng → sinh **Vị trí** `điểmMànHình`, không đặt
  **Ứng dụng khoá**, và hiện cảnh báo rằng toạ độ sẽ trượt nếu cửa sổ dịch chuyển.
- **RC-15** `[đã làm]` **Phiên ghi** không bao giờ tự sinh **Vị trí** theo **Ảnh mẫu**. Nâng cấp một
  **Bước** lên `theoẢnh` là hành động có chủ ý của người dùng trong cửa sổ soạn thảo.

## Cơ chế bắt sự kiện

- **RC-18** `[đã làm]` `CGEventTap` được gắn vào **run loop chính**, không phải một luồng riêng. Nhờ vậy việc
  hỏi Accessibility ngay trong callback là hợp lệ. Đổi lại, callback phải nhanh: hệ thống sẽ tắt
  tap nếu nó chạy quá lâu, nên `tapDisabledByTimeout` phải được bắt và **bật lại tap**, thay vì
  im lặng ngừng ghi giữa phiên.
- **RC-19** `[đã làm]` Tiến trình sở hữu một cử chỉ được xác định bằng **ứng dụng đang ở trước**
  (`frontmostApplication`), không phải bằng `AXUIElementCopyElementAtPosition`. Hỏi AX theo toạ độ
  chính xác hơn về lý thuyết nhưng tốn hàng chục ms với một số ứng dụng, đủ để `RC-18` tắt tap.
  Click vào một cửa sổ thì đưa nó lên trước, nên hai cách cho cùng kết quả trong thực tế.
- **RC-20** `[đã làm]` Chỉ **điểm bắt đầu** của mỗi cử chỉ mới lấy mẫu tiến trình và khung **Cửa sổ neo**;
  các sự kiện `dragged` kế thừa giá trị của sự kiện trước. Lấy mẫu ở từng chặng kéo sẽ vi phạm `RC-18`.

## Kết quả

- **RC-16** `[đã làm]` Kết thúc **Phiên ghi** tạo một **Kịch bản** mới đã lưu, tên mặc định theo ứng dụng
  và thời điểm ghi, rồi mở cửa sổ soạn thảo với **Kịch bản** đó.
- **RC-17** `[đã làm]` **Phiên ghi** không ghi được **Bước** nào thì không tạo **Kịch bản**.

## Kiểm chứng

- **RC-21** `[đã làm]` Mọi thứ `ScenarioRecorder` hỏi hệ điều hành — tiến trình của chính mình,
  ứng dụng đang ở trước, khung **Cửa sổ neo**, tên ứng dụng, khoảng double-click, đồng hồ — đi qua
  `RecordingEnvironment`, cùng lối với `ScenarioSystemBridge`. Không có seam này thì `RC-2`,
  `RC-13`, `RC-14`, `RC-20` chỉ kiểm chứng được bằng tay với `CGEventTap` thật, tức là không
  kiểm chứng được trong `swift test`: tap đòi quyền Accessibility mà TCC không cấp cho binary
  test của SwiftPM. Test bơm `CGEvent` dựng sẵn thẳng vào `ScenarioRecorder.handle`.
  Việc **tạo** `CGEvent` không cần quyền; chỉ **phát** mới cần.
