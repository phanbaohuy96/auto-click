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

**Đã chạy ngày 11/09/2026 — 11/11 mục đạt.** Cách chạy ở [phần cuối](#cách-phiên-a-được-chạy).

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| A1 | Chế độ đơn giản, theo con trỏ, 5 lần, cách 500 ms | Đếm ngược 3 giây rồi click đúng 5 lần tại chỗ con trỏ | `UI-1` `UI-6` `EX-3` | **Đạt** — 5 cặp down/up tại `(500,550)`, cách 530/508/527/524 ms, click đầu 3,0 s sau khi bấm |
| A2 | Như A1 nhưng huỷ trong lúc đếm ngược | **Không** phát click nào | `EX-3` | **Đạt** — 0 sự kiện |
| A3 | Kiểm tra `Scenarios/` sau A1 | Không có thư mục nào mới | `UI-7` | **Đạt** — `AutoClick/` còn chưa từng được tạo |
| A4 | Kịch bản 1 bước, lặp 20 vòng, cách 200 ms | Click đúng chỗ, bảng nổi đếm lên | `UI-2` `UI-13` `EX-4` | **Đạt** — đúng 20 cặp, tổng 3.993 ms |
| A5 | Giữa lúc A4 chạy, bấm `⌥⌘S` | Dừng ngay, trạng thái ghi "người dùng dừng" | `EX-13` `EX-15` `SF-9` | **Đạt** — 10/40 sự kiện rồi dừng; trạng thái "Đã dừng" |
| A6 | Một Bước `click` với `số lần = 3` | Ba cặp liền nhau, hệ điều hành hiểu là triple click | `EX-16` `EX-17` | **Đạt** — `clickState` đúng 1, 2, 3; cách nhau 30 và 32 ms |
| A7 | `giữMs = 1500`, lặp 3 vòng | Nút giữ đúng ~1,5 giây rồi nhả | `EX-18` | **Đạt** — giữ 1566/1589/1548 ms; nghỉ giữa vòng 532/529 ms |
| A8 | **Trong lúc A7 đang giữ**, bấm `⌥⌘S` | Nút **được nhả**; chuột vẫn dùng bình thường | `SF-1` `SF-2` `EX-14` | **Đạt** — `leftDown` 4390 → `leftUp` 5424 (cắt còn 1034/1500 ms); rê chuột sau đó không sinh `leftDrag` nào |
| A9 | Lặp không giới hạn, chạy rồi `⌥⌘S` | Bảng nổi đếm vòng, không hiện tổng; dừng được | `UI-14` `SF-9` | **Đạt** — chạy liên tục ~316 ms/click; sau `⌥⌘S` im hẳn 4 giây; popover ghi "lặp đến khi dừng" |
| A10 | Sửa tên Kịch bản | Tên mới còn đó, không có nút Lưu nào phải bấm | `UI-11` `ST-11` | **Đạt** — `scenario.json` đổi tên ngay khi gõ xong |
| A11 | Chạy rồi thử sửa | Không sửa được khi đang chạy | `UI-12` | **Đạt** — hiện khoá "Đang chạy — không sửa được", nút xoá biến mất, control mờ |

### Phát hiện ngoài checklist

Cài đè bản mới lên bản đã được cấp quyền làm **quyền Accessibility hết hiệu lực, nhưng System
Settings vẫn hiện toggle đang bật**. Thông báo cũ — "Hãy cấp quyền Accessibility rồi thử lại" —
đẩy người dùng tới đúng cái màn hình nói rằng quyền đã bật. Đã sửa, xem `SF-10`.

Chỉ lộ ra khi cài đè lên một bản đã có quyền. Viết đặc tả không thấy được.

## Phiên B — Ứng dụng khoá, neo cửa sổ, kéo thả, bàn phím

> **B2 đã được đổi.** Bản đầu — *di chuyển cửa sổ rồi chạy lại* — **không thể trượt**: `EX-6` bắt giải Vị trí
> trước **mỗi lần lặp**, và `ScenarioRunner` đọc lại khung cửa sổ trong `applyPointer`, nên bất kỳ lần chạy mới
> nào cũng đọc khung mới. Chỉ **di chuyển giữa lúc đang chạy** mới phân biệt được "đọc lại mỗi vòng" với
> "chụp một lần rồi cache". Một test xanh mà không thể đỏ thì không phải bằng chứng.

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| B1 | Đặt **Ứng dụng khoá** = TextEdit, Bước `click`/`lệchCửaSổ`, chạy | Click đúng vị trí tương đối trong cửa sổ TextEdit | `EX-7` | **Đạt** — 3 click tại đúng `(500,450)` = góc `(200,200)` + lệch `(300,250)`, pid=Auto Click |
| B2 | Lặp 10 vòng cách 800 ms; **sang vòng 3–4 thì kéo cửa sổ TextEdit sang chỗ khác trong lúc đang chạy** | Click **đi theo cửa sổ ngay từ vòng kế tiếp** — hai cụm toạ độ, cụm sau khớp vị trí mới | `EX-6` `DM-9` | **Đạt** — 4 click tại `(500,450)`; kéo cửa sổ sang `(400,350)` lúc t+6,2 s; **click ngay kế tiếp đã ở `(700,600)`**, 6 click còn lại đều vậy |
| B2b | Dừng hẳn, di chuyển cửa sổ, **chạy lại** | Vẫn trúng cùng một điểm trên giao diện | test khói, **không** tính là bằng chứng `EX-6` | **Đạt** — cửa sổ ở `(400,350)`, chạy lại ra `(700,600)` |
| B3 | Kéo một cửa sổ khác (Finder) đè lên đúng điểm đó rồi chạy | Kịch bản **không** click vào Finder | `EX-10` | **Đạt** — 4 click rồi đưa Finder lên trước: **im hẳn**, 0 click vào Finder; trạng thái *"Điểm thao tác không nằm trong ứng dụng…"* |
| B4 | Đóng TextEdit giữa lúc Kịch bản đang chạy | Dừng, trạng thái nêu ứng dụng khoá đã đóng | `EX-11` | **Đạt** — 6 click rồi `quit` TextEdit: dừng ngay; trạng thái *"TextEdit hiện không chạy"* + *"Ứng dụng đích đã đóng"*, nút Bắt đầu bị vô hiệu |
| B5 | Thu nhỏ TextEdit xuống Dock rồi chạy Bước `lệchCửaSổ` | Dừng có báo, **không** bắn ra toạ độ rác | `EX-7` | **Đạt có điều kiện** — 0 click, có dừng và có báo. Nhưng **báo sai nguyên nhân**: nói *"điểm nằm ngoài ứng dụng khoá"* trong khi thật ra cửa sổ đang thu nhỏ. Xem `EX-25` |
| B6 | Bước `kéoThả` từ điểm A tới điểm B trong TextEdit (bôi đen chữ) | Chữ được bôi đen liên tục, không nhảy cóc | `EX-20` | **Đạt** — 1 `leftDown`, **24** `leftDrag`, 1 `leftUp`; TextEdit bôi đen liên tục 40 ký tự `"AAA BBBB … HHHH I"` |
| B7 | **Trong lúc B6 đang kéo**, bấm `⌥⌘S` | Chuột được nhả, không kẹt ở trạng thái đang kéo | `SF-1` `EX-23` | **Đạt** — 7 `leftDown` / **165** `leftDrag` / 7 `leftUp`. Trọn vẹn phải là 168, nên lần kéo thứ 7 bị cắt ở bước 21/24 và nhả tại `x=464` chứ không phải đích `x=500`. Rê chuột sau đó: 0 `leftDrag` |
| B8 | Bước `gõChuỗi` với `Xin chào 123 — ăn` | Ra đúng chữ, đúng dấu tiếng Việt và dấu gạch dài | `EX-21` | **Đạt sau khi sửa** — bản cũ ra `"Aa chào 123 — ăn"`, không báo lỗi. Sau khi gửi theo khối (`EX-24`, [ADR-0007]): **8/8 lần đúng** qua chính app |
| B9 | Bước `nhấnPhím` `⌘A` rồi Bước `nhấnPhím` `⌫` | Chọn hết rồi xoá hết | `EX-22` | **Đạt** — tài liệu từ `"Xin chào 123 — ăn"` về rỗng |
| B10 | Chạy Kịch bản hai Bước gõ, **cướp focus sang Finder giữa hai Bước** | TextEdit **được đưa lên trước** rồi mới gõ; chữ không lọt sang Finder | `SF-4` `EX-12` | **Hỏng** — `SF-4` có chạy (Finder bị cướp focus lúc t+4 s, TextEdit trở lại lúc t+7,3 s), nhưng chữ ra `"â"` thay vì `"[B10b]"`. Cùng kiểu hỏng với `EX-24` nhưng **chưa lần ra nguyên nhân** |

### Phát hiện ngoài checklist — phiên B

Ba lỗi thật, không mục nào trong checklist nhắm vào chúng. Cả ba chỉ lộ khi chạy trên máy thật.

**`EX-24` — gõ chuỗi ra sai chữ, im lặng.** Nặng nhất. Gửi từng ký tự một thì payload Unicode bị
mất và macOS rơi về `virtualKey` (số 0 = phím `a`), chèn chữ `a` thay cho chữ thật mà không báo
gì: `"Xin chào 123 — ăn"` ra `"Aa chào 123 — ăn"`. Đã sửa bằng cách gửi theo khối 20 đơn vị
UTF-16 → **8/8 lần đúng** qua chính app. **Nguyên nhân gốc vẫn chưa biết**, và không có tỉ lệ
hỏng nào đáng tin — xem [ADR-0007] để biết những gì đã loại được và vì sao bộ đo không đủ tin.

**`UI-16` — lỗi hiện kèm dấu tích.** `statusIcon` trả `checkmark.circle` cho mọi trạng thái
không-đang-chạy, nên dòng *"Có lỗi: …"* mang đúng biểu tượng của thành công, lại bị cắt ở một
dòng nên không đọc hết được nguyên nhân. Đã sửa: tam giác cảnh báo màu cam, và cho xuống dòng.

**`EX-25` — cửa sổ thu nhỏ vẫn được dùng làm gốc toạ độ.** Accessibility trả về vị trí cũ của cửa
sổ đã thu nhỏ như thể nó còn trên màn hình. `EX-10` chặn được cú click nên không có thiệt hại,
nhưng đó là may: nếu ứng dụng khoá có cửa sổ thứ hai đè lên đúng điểm đó thì click sẽ bắn ra theo
toạ độ của một cửa sổ không còn hiện. Đã sửa: bỏ qua cửa sổ thu nhỏ.

### Bẫy đo lường: bộ gõ tiếng Việt giữ chữ trong bộ đệm soạn thảo

Máy này chạy EVKey. Chữ do Auto Click gõ ra có thể **đã đúng nhưng chưa được chốt** vào tài liệu,
và khi đó `get text of document 1` trả về **rỗng** — không phân biệt được với mất chữ. Chứng
minh: gõ `"abc"` đọc ra `""`; bấm mũi tên phải để chốt rồi đọc lại ra `"abc"`.

Hệ quả: mọi phép đo bàn phím phải **chốt trước khi đọc**, và mọi tỉ lệ đo trước khi biết điều này
đều đã bị rút lại. Kết quả còn đổi theo cách dọn tài liệu giữa hai lượt — đặt lại bằng AppleScript
cho kết quả khác hẳn dọn bằng `⌘A` + `xoá`.

### Ghi chú cách chạy phiên B

Dùng lại bộ đo và bộ bấm của phiên A, thêm ba thứ:

- **Chốt chặn cửa sổ** — popover **đóng lại mỗi khi Kịch bản chạy**, vì `ScenarioRunner` gọi
  `activate` ứng dụng khoá. Lần đầu tôi không biết, cú bấm tiếp theo rơi vào cửa sổ terminal và
  chuỗi phím điều hướng menu **gửi nhầm một lệnh cũ vào phiên làm việc**. Từ đó mọi thao tác gõ
  phím đều phải qua kiểm tra popover có đang mở không.
- **Neo giao diện theo màu, không theo toạ độ** — popover đổi chiều cao theo nội dung nên offset
  cứng bị trượt, và tôi đã chạy nhầm Kịch bản một lần vì thế. Giờ tìm mảng màu nhấn để định vị.
- **Tự kiểm sau khi chọn** — đọc `selectedScenarioID` trong UserDefaults để xác nhận đúng Kịch
  bản, sau khi ghi một giá trị canh `PENDING` để một lần chọn trượt không thể ăn nhờ giá trị cũ.

Bàn phím được kiểm bằng cách đọc lại nội dung tài liệu TextEdit qua AppleScript, chứ không nhìn
màn hình.

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

---

## Cách phiên A được chạy

Không quan sát bằng mắt. Dựng hai công cụ nhỏ:

- **Bộ đo** — `CGEventTap` chỉ nghe, ghi mọi sự kiện chuột ra TSV kèm thời điểm, toạ độ,
  `clickState` và **pid nguồn**. `pid=0` là chuột thật của người dùng, `pid=<n>` là sự kiện do tiến
  trình đó tổng hợp, nên tách được chính xác cái gì do Auto Click phát ra.
- **Bộ bấm** — phát `mouseMoved` + `mouseDown`/`mouseUp` tại một toạ độ, để điều khiển giao diện
  như người dùng.

Hai chỗ phải đi đường vòng, và kết quả phiên A phải đọc kèm hai giới hạn này:

- **Cây AX của popover SwiftUI không đọc được thuộc tính** — 63 phần tử, `role`/`name`/`value` đều
  rỗng. Nên phải bấm theo toạ độ đo từ ảnh chụp. Cửa sổ soạn thảo thì ngược lại, là `NSWindow`
  thật nên AX dùng tốt.
- **Kịch bản của A4…A9 được ghi thẳng thành `scenario.json`** bằng chính bộ mã hoá của app, thay
  vì dựng trong cửa sổ soạn thảo. Cách này kiểm luôn `ST-2`, `ST-5`…`ST-8`, nhưng **không** kiểm
  `UI-9` (kéo thả đổi thứ tự, thêm/nhân bản/xoá Bước) và `UI-10` (panel chi tiết). Hai mục đó mới
  chỉ được **nhìn thấy** là có, chưa được bấm thử.
