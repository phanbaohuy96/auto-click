# Auto Click cho macOS

Ứng dụng native nằm trên menu bar. Có hai mặt giao diện, nhưng chỉ **một** bộ chạy bên dưới:

- **Đơn giản** — một thao tác lặp lại, đúng như các phiên bản trước.
- **Kịch bản** — chuỗi thao tác có thứ tự, mỗi bước có hành động, vị trí, số lần lặp và
  khoảng chờ riêng.

## Kịch bản

Một **Bước** là một cặp **Hành động** × **Vị trí**, hai trục độc lập nhau:

| Hành động | Vị trí |
|---|---|
| Click (trái/phải/giữa, n lần, giữ N ms) | Theo con trỏ |
| Cuộn (ngang, dọc) | Điểm cố định trên màn hình |
| Di chuột | Lệch theo góc gần nhất của cửa sổ ứng dụng |
| Kéo thả | |
| Gõ chuỗi ký tự | |
| Nhấn tổ hợp phím | Tâm ảnh mẫu tìm thấy trên màn hình |
| | Tâm đoạn chữ tìm thấy trên màn hình |

Nhờ tách hai trục, "double-click theo ảnh mẫu" hay "cuộn tại chỗ có chữ Đồng ý" không phải là
loại bước mới nào cả — chúng có sẵn từ 6 hành động × 5 vị trí.

Neo theo cửa sổ bám vào **góc gần điểm nhất**, không phải luôn góc trên-trái: nút ở góc phải-dưới
nhờ vậy vẫn đúng khi bạn phóng to cửa sổ.

Kịch bản lưu ở `~/Library/Application Support/AutoClick/Scenarios/<id>/scenario.json`,
mỗi kịch bản một thư mục. Xoá kịch bản là xoá cả thư mục.

## Nhận dạng ảnh và chữ

Một Bước có thể nhắm vào **ảnh mẫu** hoặc **đoạn chữ** thay vì toạ độ cố định.

Khoanh một vùng bất kỳ trên màn hình để cắt ảnh mẫu. Không cần khoá ứng dụng, và **không cần mục
tiêu đang hiển thị**: nút bạn muốn bấm thường chỉ xuất hiện sau khi trang tải, nên cứ mở một ảnh
chụp màn hình cũ trong Preview rồi cắt từ chính ảnh đó.

Mỗi bước theo ảnh có **thời gian chờ** và **việc phải làm khi hết giờ**:

```
Bước 2  click @ ảnh "nút Lưu"     chờ tối đa 10s  → hết giờ: Dừng kịch bản
Bước 5  click @ ảnh "đóng quảng cáo"  chờ tối đa 0s  → hết giờ: Bỏ qua bước
```

Bước 2 là "đợi nút hiện ra rồi bấm". Bước 5 là "có thì đóng, không có thì chạy tiếp". Cả hai chỉ
là hai con số — kịch bản không có `if`, không có rẽ nhánh.

**Tìm theo chữ** bền hơn ảnh mẫu khi đổi giao diện sáng/tối hay cỡ chữ hệ thống, nhưng chỉ nhắm
được thứ có chữ. Ảnh mẫu nhắm được icon và phần tử đồ hoạ.

Tính năng này cần thêm quyền **Screen Recording**, chỉ hỏi khi bạn thật sự dùng tới.

## Ghi thao tác

Nhấn `⌥⌘R` để bắt đầu và kết thúc một phiên ghi. Auto Click quan sát chuột của bạn rồi dựng
thành Kịch bản: nhận ra double click, giữ nhấn, kéo thả, và gộp cả tràng cuộn trackpad thành
một bước.

Hai điều cố ý:

- **Không ghi bàn phím.** Ghi phím buộc phải xin quyền Input Monitoring và biến app thành
  keylogger toàn hệ thống. Bước gõ phím thêm tay sau khi ghi.
- **Không cắt trần thời gian chết.** Bạn chờ 8 giây thì bản ghi chờ 8 giây. Recorder không phân
  biệt được "đợi trang tải" với "đi pha cà phê", nên cắt trần sẽ hỏng đúng lúc quan trọng nhất.

Nếu cả phiên ghi nằm trong một ứng dụng, Auto Click tự khoá vào ứng dụng đó và neo mọi bước theo
cửa sổ — bản ghi dùng lại được cả khi cửa sổ đã dịch chuyển. Trải trên nhiều ứng dụng thì giữ
toạ độ tuyệt đối và nói rõ điều đó.

## Các tính năng khác

- Chọn khoảng thời gian giữa hai lần click (10–3.600.000 ms).
- Chọn số lần lặp (1–1.000.000), ở cấp bước và cấp kịch bản.
- Kịch bản lặp đến khi bấm Dừng.
- Click theo vị trí con trỏ hoặc một điểm cố định đã lưu.
- Chọn điểm trực tiếp trên bất kỳ màn hình nào; nhấn `Esc` để hủy chọn.
- Khóa click vào một ứng dụng đang chạy và xác minh ứng dụng sở hữu điểm click.
- Tự dừng nếu ứng dụng đích bị đóng để không click nhầm ứng dụng khác.
- Đếm ngược 3 giây để đặt con trỏ vào đúng vị trí.
- Dừng nhanh từ icon trên menu bar.
- Hiện live activity nổi khi chạy, với nút **Dừng** luôn nhìn thấy.
- Phím tắt toàn cục `⌥⌘S` để dừng ngay cả khi đang dùng ứng dụng khác.
- Ghi nhớ cấu hình và tự khởi động khi đăng nhập macOS.
- Luôn nhả nút chuột khi dừng, kể cả đang giữa một thao tác giữ nhấn hay kéo thả.
- Trước mỗi bước gõ phím, đưa ứng dụng đã khoá lên trước; không đưa lên được thì dừng.

## Build và cài đặt

Yêu cầu macOS 14 trở lên và Xcode Command Line Tools.

```bash
./scripts/install.sh
# Hoặc:
sh ./scripts/install.sh
```

Script sẽ build bản release, đóng phiên bản cũ, cài vào `/Applications`, kiểm tra chữ ký và mở lại app. Để cài bundle đã build sẵn hoặc không tự mở app:

```bash
./scripts/install.sh --no-build
./scripts/install.sh --no-launch
```

Chỉ build bundle mà không cài đặt:

```bash
./scripts/build-app.sh
```

Lần đầu bấm **Bắt đầu**, macOS sẽ yêu cầu quyền Accessibility. Mở:

`System Settings → Privacy & Security → Accessibility`

Sau đó bật quyền cho **Auto Click**. Kịch bản dùng nhận dạng ảnh hoặc chữ cần thêm quyền
**Screen Recording** ở cùng màn hình đó — hai quyền tách biệt, cấp một cái không tự có cái kia. Nên chạy app từ `/Applications` trước khi bật “Khởi động cùng MacBook” để macOS đăng ký đúng vị trí ứng dụng.

Bản build local mặc định dùng chữ ký ad-hoc, vì vậy macOS có thể yêu cầu bật lại quyền Accessibility sau khi cập nhật. Nếu có certificate macOS ổn định, có thể chỉ định khi build/cài:

```bash
AUTO_CLICK_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
```

Để giới hạn click, bật **Chỉ click trong ứng dụng** và chọn một app đang chạy. Nút làm mới bên cạnh danh sách sẽ nhận các app vừa được mở. Auto Click đưa app đó lên trước khi chạy, kiểm tra UI tại tọa độ thuộc đúng PID đã chọn rồi mới phát click toàn hệ thống. App tự dừng nếu ứng dụng bị đóng hoặc điểm click nằm ngoài ứng dụng đó.

Ở chế độ **Theo con trỏ**, mỗi lần click sử dụng vị trí con trỏ tại đúng thời điểm đó. Ở chế độ **Điểm cố định**, app luôn click vào tọa độ đã lưu. Sau khi chọn một điểm mới, cửa sổ cấu hình sẽ tự hiện lại.

## Tài liệu

| Tài liệu | Trả lời câu hỏi |
|---|---|
| [`CONTEXT.md`](CONTEXT.md) | Các khái niệm tên là gì và nghĩa là gì |
| [`docs/adr/`](docs/adr/) | Vì sao chọn phương án này thay vì phương án kia |
| [`docs/sdd/`](docs/sdd/) | Hệ thống phải làm gì, chính xác đến mức kiểm chứng được |

Mọi hành vi quan sát được đều có một mã yêu cầu trong `docs/sdd/` (`DM-`, `EX-`, `ST-`, `UI-`,
`SF-`, `RC-`, `RG-`). Code trích dẫn mã đó ở những chỗ hành vi không hiển nhiên. Sửa hành vi thì
sửa đặc tả trước.

## Phát triển

```bash
swift test
swift run AutoClick
```

Khi chạy bằng `swift run`, tính năng click có thể cần cấp quyền cho Terminal. Bản `.app` trong `/Applications` là cách chạy khuyến nghị.
