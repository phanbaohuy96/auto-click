# Mỗi Kịch bản một thư mục, Ảnh mẫu được nhân bản

Mỗi **Kịch bản** là một thư mục `~/Library/Application Support/AutoClick/Scenarios/<id>/`
chứa `scenario.json` và `templates/`. Hai **Kịch bản** dùng cùng một nút sẽ có **hai bản sao**
của cùng một **Ảnh mẫu** — cố ý, không phải thiếu sót.

Kho ảnh dùng chung (đặt tên theo hash nội dung) tiết kiệm đĩa hơn nhưng buộc phải đếm tham
chiếu khi xoá: xoá **Kịch bản** A mà xoá luôn ảnh thì B hỏng, không xoá thì kho phình mãi.
Đó là loại lỗi lặng lẽ và hầu như không ai viết test cho nó. Đổi lấy vài trăm KB trùng lặp,
ta được: xoá = xoá thư mục, nhân bản = copy thư mục, xuất/nhập = zip thư mục.

`UserDefaults` chỉ còn giữ id **Kịch bản** đang chọn và cấu hình **Chế độ đơn giản**.
