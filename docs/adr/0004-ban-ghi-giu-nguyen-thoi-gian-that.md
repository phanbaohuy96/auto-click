# Bản ghi giữ nguyên thời gian thật, không cắt trần

**Phiên ghi** suy luận sự kiện thô thành **Hành động** cấp cao (gộp một tràng `scrollWheel`
thành một bước cuộn, nhận ra double click / giữ nhấn / kéo thả), nhưng **không** đụng vào
khoảng thời gian giữa các thao tác — chờ 8 giây thì ghi 8 giây.

Cắt trần thời gian chết là tiện ích hiển nhiên và đã bị loại có chủ ý: recorder không phân biệt
được "đợi trang tải" với "đi pha cà phê", nên nó đoán sai đúng vào lúc quan trọng nhất và biến
thành lỗi "click khi giao diện chưa sẵn sàng" — loại lỗi khó lần ra nhất trong tự động hoá.
Muốn chạy nhanh hơn thì dùng hệ số tốc độ chung lúc phát lại, hoặc sửa tay từng delay; cả hai
đều là quyết định của người dùng, không phải phỏng đoán của recorder.
