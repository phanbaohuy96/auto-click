# Bước = Hành động × Vị trí, và chỉ có một bộ chạy

Cách hiển nhiên là một `enum Step` phẳng (`click`, `doubleClick`, `longPress`, `scroll`,
`imageClick`…). Ta không làm vậy: một **Bước** là một cặp **Hành động** × **Vị trí** trực giao.
Lý do là "theo ảnh" thuộc trục **Vị trí**, không thuộc trục **Hành động** — nếu trộn hai trục
vào một enum thì mỗi lần thêm một dạng Vị trí phải nhân bản toàn bộ danh sách Hành động
(`imageDoubleClick`, `imageScroll`, `imageDrag`…). Với 4 nhóm Hành động và 4 dạng Vị trí,
mô hình trực giao cho 16 tổ hợp từ 8 khái niệm.

Kèm theo: **Chế độ đơn giản** không phải bộ chạy thứ hai. Nó là một mặt giao diện dựng ra một
**Kịch bản** một bước rồi đưa cho cùng bộ chạy — để phần dễ sai nhất (phát CGEvent, kiểm tra
**Ứng dụng khoá**, quy đổi toạ độ) chỉ tồn tại một bản.

## Consequences

- Vài tổ hợp là vô nghĩa (`chờ` không dùng **Vị trí**). Chấp nhận, và không dựng thêm kiểu để chặn.
- Giao diện soạn thảo phải bày hai picker cho mỗi bước thay vì một danh sách phẳng.
