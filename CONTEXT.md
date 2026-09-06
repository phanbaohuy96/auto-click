# Auto Click

Ứng dụng menu bar trên macOS phát sự kiện chuột giả lập để tự động hoá thao tác lặp lại.
Tài liệu này là **từ điển thuật ngữ** của dự án, không phải spec.

## Language

**Kịch bản (Scenario)**:
Một chuỗi thao tác có thứ tự mà người dùng đã đặt tên, chạy từ đầu đến cuối như một đơn vị.
_Avoid_: macro, workflow, script, profile

**Chế độ đơn giản (Simple mode)**:
Mặt giao diện rút gọn cho phép cấu hình nhanh một thao tác lặp lại, mà bên dưới vẫn dựng thành một **Kịch bản** một bước.
_Avoid_: chế độ cũ, basic mode, legacy mode

**Bước (Step)**:
Một đơn vị trong **Kịch bản**, gồm đúng một **Hành động** và đúng một **Vị trí**.
_Avoid_: action (khi đang nói về cả cặp), command, task

**Hành động (Action)**:
Thứ mà một **Bước** làm — click, giữ nhấn, cuộn, di chuột, kéo thả, gõ phím — tách rời khỏi việc làm ở đâu.
_Avoid_: event, thao tác, loại bước

**Vị trí (Target)**:
Nơi một **Hành động** diễn ra, chỉ được giải ra toạ độ cụ thể tại thời điểm chạy bước đó.
_Avoid_: đích, toạ độ, point, anchor

**Ảnh mẫu (Template)**:
Mảnh ảnh người dùng cắt từ màn hình, dùng để tìm lại mục tiêu lúc chạy khi toạ độ không đáng tin.
_Avoid_: hình mẫu, snapshot, pattern

**Cửa sổ neo (Anchor window)**:
Cửa sổ trước nhất của **Ứng dụng khoá** tại thời điểm chạy một **Bước**, dùng làm gốc cho **Vị trí** tương đối.
_Avoid_: cửa sổ chính, main window

**Phiên ghi (Recording session)**:
Khoảng thời gian Auto Click lắng nghe thao tác chuột thật của người dùng để dựng ra một **Kịch bản**.
_Avoid_: record, quay, capture

**Ứng dụng khoá (Locked application)**:
Ứng dụng duy nhất được phép nhận sự kiện khi người dùng bật giới hạn; khác hoàn toàn với **Vị trí**.
_Avoid_: ứng dụng đích, target app

## Relationships

- **Chế độ đơn giản** tạo ra đúng một **Kịch bản** một bước; nó không phải một cách chạy riêng.
- Mọi thao tác tự động, dù đến từ mặt giao diện nào, đều được thực thi qua cùng một bộ chạy **Kịch bản**.
- Một **Kịch bản** chứa một hay nhiều **Bước** có thứ tự.
- Một **Bước** kết hợp đúng một **Hành động** với đúng một **Vị trí**; hai trục này độc lập với nhau.
- Khoảng chờ là thuộc tính của **Bước**, không phải một **Hành động**. Không tồn tại **Hành động** "chờ".
- **Ứng dụng khoá** ràng buộc toàn bộ **Kịch bản**, không ràng buộc từng **Bước**.
- **Vị trí** có bốn dạng: theo con trỏ, điểm tuyệt đối trên màn hình, lệch so với một góc của **Cửa sổ neo**, và tâm của **Ảnh mẫu** tìm thấy.
- **Vị trí** tương đối cửa sổ chỉ giải được khi **Ứng dụng khoá** đang bật; thiếu nó thì **Kịch bản** không hợp lệ.
- Một **Phiên ghi** sinh ra đúng một **Kịch bản**; nó chỉ quan sát chuột, không quan sát bàn phím.
- **Vị trí** theo **Ảnh mẫu** hoặc theo chữ có thể **không giải được**; khi đó **Bước** thử lại đến hết thời gian chờ rồi hoặc dừng **Kịch bản** hoặc bị bỏ qua, do chính **Bước** đó quy định.

## Example dialogue

> **Dev:** "Giữ tab Đơn giản thì có phải viết vòng lặp click thứ hai không?"
> **Domain expert:** "Không. **Chế độ đơn giản** chỉ là cái phễu nhập liệu; nó dựng một **Kịch bản** một bước rồi đưa cho cùng bộ chạy."
>
> **Dev:** "Vậy 'click theo ảnh' là một **Hành động** mới chứ?"
> **Domain expert:** "Không, 'theo ảnh' là một **Vị trí**. **Hành động** vẫn là click. Nhờ vậy 'cuộn tại ảnh' hay 'double-click theo ảnh' không phải khái niệm mới nào cả."
>
> **Dev:** "Vậy 'đợi nút Lưu hiện ra rồi bấm' cần thêm vòng lặp có điều kiện chứ?"
> **Domain expert:** "Không. Đó là **Bước** click vào **Vị trí** theo **Ảnh mẫu** với thời gian chờ 10 giây. **Kịch bản** không có nhánh, không có điều kiện — chỉ có bộ đếm và thời gian chờ."

## Flagged ambiguities

- "hai chế độ song song" ban đầu hàm ý hai bộ chạy độc lập — đã chốt: hai mặt **giao diện**, một bộ chạy duy nhất.
- "target" trong code hiện tại mang hai nghĩa: `targetMode` (nơi click) và `targetProcessIdentifier` (ứng dụng được phép nhận click) — đã tách thành **Vị trí** và **Ứng dụng khoá**.
- "record" từng hàm ý ghi mọi thứ người dùng làm — đã thu hẹp: **Phiên ghi** chỉ ghi chuột; bước gõ phím do người dùng thêm tay.
- "chờ" từng được liệt kê như một **Hành động** — đã sửa: nó là thuộc tính của **Bước**.
- "long press" đã chốt là giữ nhấn tại chỗ; **kéo thả** là **Hành động** riêng.
- "chờ đến khi nút xuất hiện" không phải luồng điều khiển — nó là thời gian chờ khi giải **Vị trí** theo **Ảnh mẫu**.
- "điểm cố định" từng chỉ có nghĩa toạ độ tuyệt đối; nay là hai dạng **Vị trí** khác nhau — tuyệt đối và tương đối **Cửa sổ neo**.
