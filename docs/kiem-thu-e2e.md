# Kiểm thử đầu-cuối bằng tay

Bộ test tự động dừng ở ranh giới hệ điều hành: mọi seam thật đều bị thay bằng giả
(`TestSupport.swift`). Nó chứng minh được logic, **không** chứng minh được rằng ứng dụng thật
click đúng chỗ trên màn hình thật.

Tài liệu này là phần còn lại. Mỗi mục ghi rõ làm gì, chờ thấy gì, và **chứng minh yêu cầu nào**
trong [SDD](sdd/). Cột cuối để bạn điền.

## Vì sao những mục này không tự động hoá được

| Rào cản | Hệ quả |
|---|---|
| Accessibility và Screen Recording cấp qua TCC cho **bundle đã ký**, không cấp cho binary test của SwiftPM | Không phát được sự kiện, không chụp được màn hình trong `swift test` |
| Toạ độ màn hình thật, tỉ lệ Retina, nhiều màn hình | Bộ giả chỉ trả lại đúng con số do test đặt vào, nên lỗi lật trục hay quên chia tỉ lệ vẫn xanh |
| SwiftUI không có seam kiểm thử ở dự án này | 2.182 dòng giao diện chỉ người bấm mới biết |

## Chuẩn bị

```bash
./scripts/build-app.sh && ./scripts/install.sh
```

Mở **System Settings → Privacy & Security** và cấp cho Auto Click:
**Accessibility** (bắt buộc, `SF-3`) và **Screen Recording** (chỉ cần cho phiên C, `SF-5`).

> Cấp quyền xong **phải thoát hẳn và mở lại** Auto Click. macOS không trao quyền cho tiến trình
> đang chạy. Đây chính là chỗ `SF-7` không phân biệt được "chưa cấp" với "đã cấp mà chưa khởi
> động lại".

Chuẩn bị một ứng dụng đích vô hại để bắn vào — TextEdit với một tài liệu trống là đủ.
**Đừng lấy Terminal, trình duyệt đang đăng nhập, hay cửa sổ có nút xoá làm bia tập bắn.**

Luôn nhớ lối thoát: **`⌥⌘S` dừng mọi thứ** (`UI-15`). Thử bấm nó một lần trước khi bắt đầu.

---

## Phiên A — Đường cơ bản (không cần Screen Recording)

Hỏng ở đây thì dừng lại, các phiên sau không có ý nghĩa.

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| A1 | Mở popover, **Chế độ đơn giản**, chọn vị trí con trỏ, 5 lần, cách 500 ms, Bắt đầu | Đếm ngược 3 giây rồi click đúng 5 lần tại chỗ con trỏ | `UI-1` `UI-6` `EX-3` | |
| A2 | Lặp A1 nhưng bấm Dừng trong lúc đếm ngược | **Không** phát click nào | `EX-3` | |
| A3 | Kiểm tra `~/Library/Application Support/AutoClick/Scenarios/` sau A1 | Không có thư mục nào mới | `UI-7` | |
| A4 | Soạn thảo → Kịch bản mới → Bước `click` / `điểmMànHình` vào TextEdit, 20 lần, cách 200 ms, chạy | Click đúng chỗ, bảng nổi đếm lên | `UI-2` `UI-13` `EX-4` | |
| A5 | Giữa lúc A4 chạy, bấm `⌥⌘S` | Dừng ngay, trạng thái ghi "người dùng dừng" | `EX-13` `EX-15` `SF-9` | |
| A6 | Đổi Bước sang `số lần = 3` trong một Bước, chạy | Ba cặp nhấn/nhả liền nhau, ứng dụng đích hiểu là **triple click** (TextEdit bôi đen cả dòng) | `EX-16` `EX-17` | |
| A7 | Đặt `giữMs = 1500`, chạy, quan sát | Nút giữ đúng ~1,5 giây rồi nhả | `EX-18` | |
| A8 | **Trong lúc A7 đang giữ**, bấm `⌥⌘S` | Nút **được nhả**. Sau đó kéo thả cửa sổ bằng tay vẫn bình thường | `SF-1` `SF-2` `EX-14` | |
| A9 | Đặt số lần lặp = không giới hạn, chạy, để yên 30 giây, rồi `⌥⌘S` | Bảng nổi đếm vòng, không hiện tổng; dừng được | `UI-14` `SF-9` | |
| A10 | Sửa tên Kịch bản, đóng cửa sổ soạn thảo, mở lại | Tên mới còn đó, không có nút Lưu nào phải bấm | `UI-11` `ST-11` | |
| A11 | Chạy một Kịch bản rồi thử mở cửa sổ soạn thảo | Không sửa được khi đang chạy | `UI-12` | |

## Phiên B — Ứng dụng khoá, neo cửa sổ, kéo thả, bàn phím

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| B1 | Đặt **Ứng dụng khoá** = TextEdit, Bước `click`/`lệchCửaSổ`, chạy | Click đúng vị trí tương đối trong cửa sổ TextEdit | `EX-7` | |
| B2 | **Di chuyển cửa sổ TextEdit sang chỗ khác**, chạy lại | Click **đi theo cửa sổ**, vẫn trúng cùng một điểm trên giao diện | `EX-6` `DM-9` | |
| B3 | Kéo một cửa sổ khác (Finder) đè lên đúng điểm đó rồi chạy | Kịch bản **không** click vào Finder | `EX-10` | |
| B4 | Đóng TextEdit giữa lúc Kịch bản đang chạy | Dừng, trạng thái nêu ứng dụng khoá đã đóng | `EX-11` | |
| B5 | Thu nhỏ TextEdit xuống Dock rồi chạy Bước `lệchCửaSổ` | Dừng có báo, **không** bắn ra toạ độ rác | `EX-7` | |
| B6 | Bước `kéoThả` từ điểm A tới điểm B trong TextEdit (bôi đen chữ) | Chữ được bôi đen liên tục, không nhảy cóc | `EX-20` | |
| B7 | **Trong lúc B6 đang kéo**, bấm `⌥⌘S` | Chuột được nhả, không kẹt ở trạng thái đang kéo | `SF-1` `EX-23` | |
| B8 | Bước `gõChuỗi` với `Xin chào 123 — ăn` | Ra đúng chữ, đúng dấu tiếng Việt và dấu gạch dài | `EX-21` | |
| B9 | Bước `nhấnPhím` `⌘A` rồi Bước `nhấnPhím` `⌫` | Chọn hết rồi xoá hết | `EX-22` | |
| B10 | Đưa **Finder** lên trước rồi chạy Kịch bản có Bước gõ phím, khoá TextEdit | TextEdit **được đưa lên trước** rồi mới gõ; chữ không lọt sang Finder | `SF-4` `EX-12` | |

## Phiên C — Nhận dạng ảnh và chữ (cần Screen Recording)

Đây là phiên quan trọng nhất: bốn rủi ro cấu trúc mà test tự động không thể chạm tới đều nằm ở đây.

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| C1 | Bước `click`/`theoẢnh` → **Chụp ảnh mẫu** → khoanh một nút trong TextEdit | Lớp phủ biến mất **trước khi** chụp; ảnh mẫu không dính lớp phủ hay cửa sổ Auto Click | `RG-5` `RG-20` | |
| C2 | Chạy Bước đó | **Click đúng tâm nút**, không lệch | `RG-2` `RG-11` | |
| C3 | **Nếu máy có màn hình ngoài không-Retina**: kéo TextEdit sang đó, lặp C1–C2 | Vẫn trúng tâm | `RG-2` | |
| C4 | **Nếu có nhiều màn hình**: đặt cửa sổ trên màn hình phụ, lặp C1–C2 | Vẫn trúng, không bắn sang màn hình chính | `RG-2` | |
| C5 | Di chuyển nút đó đi chỗ khác (đổi kích thước cửa sổ), chạy lại | Tìm lại được ở vị trí mới | `RG-8` | |
| C6 | Che nút đi (đè cửa sổ khác lên), chạy với `chờ = 5000ms`, `khiHếtGiờ = dừng` | Thử lại ~5 giây rồi dừng có báo | `EX-8` | |
| C7 | Lặp C6 với `khiHếtGiờ = bỏQuaBước` và một Bước nữa phía sau | Bỏ Bước đó, **chạy tiếp** Bước sau | `EX-9` | |
| C8 | Lặp C6 nhưng bỏ che **trong lúc** đang chờ | Tìm thấy và click ngay, không đợi hết giờ | `EX-8` | |
| C9 | Bước `click`/`theoChữ` với một từ đang hiện trên màn hình | Click đúng tâm đoạn chữ | `RG-13` `RG-15` | |
| C10 | Lặp C9 với chữ viết hoa/thường khác đi | Vẫn tìm thấy | `RG-14` | |
| C11 | **Khoanh vùng tìm** vào nửa trái màn hình, đặt mẫu ở nửa phải, chạy | **Không** tìm thấy — vùng tìm thật sự có tác dụng | `RG-4` `RG-6` | |
| C12 | Bước `theoẢnh` **không** đặt Ứng dụng khoá | Vẫn chạy được, không bị chặn | `RG-17` (ADR-0006) | |
| C13 | Đo bằng mắt: một Bước `theoẢnh` mất bao lâu từ lúc bắt đầu tới lúc click | Ghi lại con số. Trên 1 giây là cần xem lại `RG-18` | `RG-18` `RG-21` | |
| C14 | **Thu hồi** quyền Screen Recording trong System Settings rồi chạy Bước `theoẢnh` | Báo lỗi nêu **cả hai** khả năng (chưa cấp / cần khởi động lại), không sập | `SF-7` | |

## Phiên D — Ghi thao tác

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| D1 | Bấm `⌥⌘R`, click vài chỗ trong TextEdit, bấm `⌥⌘R` lần nữa | Kịch bản mới xuất hiện, tên theo ứng dụng và thời điểm | `RC-1` `RC-16` | |
| D2 | Trong lúc ghi, quan sát bảng nổi | Hiện số Bước đã ghi và nhắc `⌥⌘R` | `RC-3` | |
| D3 | Bấm `⌥⌘R`, **chỉ click vào chính cửa sổ Auto Click**, kết thúc | Không tạo Kịch bản nào; báo "không ghi được thao tác nào" | `RC-2` `RC-17` | |
| D4 | Ghi một lần double click | Ra **một** Bước `sốLần = 2`, không phải hai Bước | `RC-7` | |
| D5 | Ghi một lần giữ nhấn ~2 giây | Ra `giữMs ≈ 2000` | `RC-6` | |
| D6 | Ghi một lần bôi đen bằng kéo thả | Ra một Bước `kéoThả`, không phải một tràng click | `RC-8` | |
| D7 | Ghi một tràng cuộn bằng trackpad, **cuộn tới cuối rồi thả cho quán tính chạy** | Ra **một** Bước cuộn, không bị cắt làm đôi lúc quán tính đổi dấu | `RC-9` | |
| D8 | Ghi: click, **đợi 5 giây**, click | Bước đầu có khoảng chờ ≈ 5000 ms | `RC-10` (ADR-0004) | |
| D9 | Xem Bước cuối của mọi bản ghi | Khoảng chờ = 0 | `RC-11` | |
| D10 | **Chạy lại** bản ghi D1 | Lặp đúng thao tác vừa ghi | `RC-13` | |
| D11 | Ghi một phiên chạm vào **hai** ứng dụng (TextEdit rồi Finder) | Có cảnh báo nói bản ghi trải trên 2 ứng dụng; Vị trí là toạ độ tuyệt đối | `RC-14` | |
| D12 | Ghi xong, di chuyển cửa sổ TextEdit, chạy lại bản ghi một-ứng-dụng | Thao tác **đi theo cửa sổ** | `RC-13` | |
| D13 | Gõ bàn phím trong lúc đang ghi | Phím **không** lọt vào Kịch bản | `RC-4` `SF-6` (ADR-0003) | |
| D14 | Mở System Settings → Privacy → **Input Monitoring** | Auto Click **không** có trong danh sách | `SF-6` | |

## Phiên E — Lưu trữ và hỏng dữ liệu

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| E1 | `echo "hỏng" > ~/Library/Application\ Support/AutoClick/Scenarios/<uuid>/scenario.json` rồi mở lại app | App vẫn chạy, chỉ thiếu Kịch bản đó | `ST-9` | |
| E2 | Sửa `"schemaVersion"` của một Kịch bản thành `99`, mở lại app | Kịch bản hiện ra nhưng **chỉ đọc**, không mất dữ liệu | `ST-12` | |
| E3 | Thêm một trường lạ vào `scenario.json`, mở lại | Bỏ qua, không lỗi | `ST-10` | |
| E4 | Xoá một Kịch bản dùng Ảnh mẫu, kiểm tra thư mục | Cả thư mục biến mất, kể cả `templates/` | `ST-3` | |
| E5 | Đổi Ảnh mẫu của một Bước vài lần, đếm tệp trong `templates/` | Tệp cũ bị dọn, thư mục không phình | `ST-12` | |

---

## Ghi kết quả

Mục nào hỏng thì ghi lại **số hiệu mục, thứ đã thấy, và mã yêu cầu**. Ba dữ kiện đó đủ để lần
thẳng từ triệu chứng về đoạn đặc tả và đoạn code tương ứng.
