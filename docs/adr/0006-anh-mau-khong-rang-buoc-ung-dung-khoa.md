# Ảnh mẫu và Vùng tìm không ràng buộc Ứng dụng khoá

Quyết định ban đầu là **Vùng tìm** luôn được lưu dưới dạng lệch so với **Cửa sổ neo**, kéo theo
việc mọi **Bước** dùng **Vị trí** theo **Ảnh mẫu** đều bắt buộc phải có **Ứng dụng khoá**. Đã đảo
lại: cả việc cắt **Ảnh mẫu** lẫn việc khoanh **Vùng tìm** đều độc lập với **Ứng dụng khoá**.

Lý do là một cách dùng mà ràng buộc cũ làm bất khả thi: mục tiêu cần nhắm thường **chưa hiện trên
màn hình** lúc soạn **Kịch bản** — hộp thoại chưa bật, nút chỉ xuất hiện sau khi trang tải. Người
dùng khi đó mở một ảnh chụp màn hình cũ trong Preview và cắt **Ảnh mẫu** từ chính ảnh đó. Ảnh mẫu
lúc ấy đến từ Preview, còn ứng dụng sẽ bị tự động hoá là một ứng dụng khác hẳn; bắt cả hai phải
trùng nhau là chặn đúng thao tác tự nhiên nhất.

Neo theo cửa sổ vẫn tốt hơn về độ bền, nên nó được giữ lại làm **lựa chọn ưu tiên khi có sẵn**:
có **Ứng dụng khoá** và lấy được cửa sổ thì lưu tương đối, không thì lưu tuyệt đối và nói rõ trên
giao diện rằng vùng tìm sẽ trượt nếu cửa sổ dịch chuyển.

## Consequences

- **Vùng tìm** có hai cách lưu, và giao diện phải cho biết mỗi **Bước** đang dùng cách nào —
  nếu không, "không tìm thấy" sẽ trở thành lỗi khó đoán.
- Ràng buộc `DM-18` (phải có **Ứng dụng khoá**) chỉ còn áp cho **Vị trí** `lệchCửaSổ`.
