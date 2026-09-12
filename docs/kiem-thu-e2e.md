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
| B10 | Chạy Kịch bản hai Bước gõ, **cướp focus sang Finder giữa hai Bước** | TextEdit **được đưa lên trước** rồi mới gõ; chữ không lọt sang Finder | `SF-4` `EX-12` | **Hỏng, để mở** — `SF-4` có chạy (Finder bị cướp focus lúc t+4 s, TextEdit trở lại lúc t+7,3 s), nhưng chữ ra `"â"` thay vì `"[B10b]"`. Chưa lần ra nguyên nhân. **Chủ dự án xếp gõ chuỗi là ưu tiên thấp**, nên dừng ở đây thay vì đào tiếp |

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
| C1 | Bước `click`/`theoẢnh` → **Chụp ảnh mẫu** → khoanh một nút trong TextEdit | Lớp phủ biến mất **trước khi** chụp; ảnh mẫu không dính lớp phủ hay cửa sổ Auto Click | `RG-5` `RG-20` | **Đạt** — ảnh mẫu app chụp **trùng từng pixel** với ảnh tham chiếu (`0.00/255`). Phép thử không vô nghĩa: lớp phủ có thật sự làm tối màn hình (`12,74/255`). `RG-20`: đưa chính cửa sổ Auto Click đè lên vùng chụp — ảnh mẫu vẫn ra TextEdit phía sau (`0.00/255`), khác hẳn thứ đang hiện (`65,74/255`) |
| C2 | Chạy Bước đó | **Click đúng tâm nút**, không lệch | `RG-2` `RG-11` | **Đạt** — click `(273,321)`, **khớp từng pixel** với tâm đo bằng Accessibility. Ảnh mẫu 272×86 **pixel** → vùng 136×43 **point**: `RG-2` đúng |
| C3 | **Nếu máy có màn hình ngoài không-Retina**: kéo TextEdit sang đó, lặp C1–C2 | Vẫn trúng tâm | `RG-2` | **Không chạy được** — máy chỉ có một màn hình Retina nội tại (1512×982 @2x) |
| C4 | **Nếu có nhiều màn hình**: đặt cửa sổ trên màn hình phụ, lặp C1–C2 | Vẫn trúng, không bắn sang màn hình chính | `RG-2` | **Không chạy được** — chỉ có một màn hình |
| C5 | Di chuyển nút đó đi chỗ khác (đổi kích thước cửa sổ), chạy lại | Tìm lại được ở vị trí mới | `RG-8` | **Đạt** — cửa sổ dời sang `(450,430)`, tìm lại được, click đúng `(523,551)` |
| C6 | Che nút đi (đè cửa sổ khác lên), chạy với `chờ = 5000ms`, `khiHếtGiờ = dừng` | Thử lại ~5 giây rồi dừng có báo | `EX-8` | **Đạt** — 0 click, Bước sau **không** chạy; đo được 8,44 s = 3 s đếm ngược + **5,44 s thử lại** (đặt 5000 ms) |
| C7 | Lặp C6 với `khiHếtGiờ = bỏQuaBước` và một Bước nữa phía sau | Bỏ Bước đó, **chạy tiếp** Bước sau | `EX-9` | **Đạt** — Bước 1 hết giờ không click, **Bước 2 vẫn chạy** và click đúng `(900,700)` |
| C8 | Lặp C6 nhưng bỏ che **trong lúc** đang chờ | Tìm thấy và click ngay, không đợi hết giờ | `EX-8` | **Đạt** — bỏ che lúc t+5,0 s, click ra lúc t+5,7 s: tìm thấy sau **714 ms**, không đợi hết 8 giây |
| C9 | Bước `click`/`theoChữ` với một từ đang hiện trên màn hình | Click đúng tâm đoạn chữ | `RG-13` `RG-15` | **Hỏng → đã sửa** — click `(356,551)` = tâm **cả dòng** `"ZUKAMI QWERTY"`, không phải `(273,551)` = tâm chữ cần tìm. Lệch 83 point. Xem `RG-15`. **Chờ chạy lại** |
| C10 | Lặp C9 với chữ viết hoa/thường khác đi | Vẫn tìm thấy | `RG-14` | **Chờ chạy lại** cùng bản sửa `RG-15` |
| C11 | **Khoanh vùng tìm** vào nửa trái màn hình, đặt mẫu ở nửa phải, chạy | **Không** tìm thấy — vùng tìm thật sự có tác dụng | `RG-4` `RG-6` | **Đạt cả hai chiều** — mục tiêu ngoài vùng tìm: báo *"Không tìm thấy Ảnh mẫu zukami.png (ngưỡng 0.90)"*; dời vào trong vùng: click đúng `(873,551)` |
| C12 | Bước `theoẢnh` **không** đặt Ứng dụng khoá | Vẫn chạy được, không bị chặn | `RG-17` (ADR-0006) | **Đạt** — Kịch bản không có Ứng dụng khoá vẫn chạy nhận dạng bình thường |
| C13 | Đo bằng mắt: một Bước `theoẢnh` mất bao lâu từ lúc bắt đầu tới lúc click | Ghi lại con số. Trên 1 giây là cần xem lại `RG-18` | `RG-18` `RG-21` | **Đạt** — 560–710 ms mỗi lần nhận dạng toàn màn hình. Dưới ngưỡng 1 giây |
| C14 | **Thu hồi** quyền Screen Recording trong System Settings rồi chạy Bước `theoẢnh` | Báo lỗi nêu **cả hai** khả năng (chưa cấp / cần khởi động lại), không sập | `SF-7` | |

### Phát hiện ngoài checklist — phiên C

**`RG-15` — click vào giữa dòng thay vì vào từ cần nhắm.** `TextFinder` lấy
`observation.boundingBox`, mà Vision gộp **cả dòng** thành một observation. Tìm `"ZUKAMI"` trong
dòng `"ZUKAMI QWERTY"` cho ra tâm cả dòng, lệch **83 point**. Trong thực tế đó là tìm `"Lưu"`
trong dòng `"Lưu   ⌘S"` rồi bắn vào khoảng trống giữa hai thứ. Đã sửa bằng
`candidate.boundingBox(for: range)`, và có test hồi quy: hai từ trên cùng một dòng phải cho **hai
hộp khác nhau** — lật về code cũ thì hai hộp trùng khít và test đỏ.

### Hai mục treo từ phiên A đã làm xong

Cửa sổ **Soạn kịch bản** là `NSWindow` thật nên cây AX đọc được đầy đủ, khác hẳn popover.

- **`UI-9` đạt** — thêm Bước, **kéo thả đổi thứ tự** (Bước 1 kéo xuống cuối, thứ tự đổi thật),
  nhân bản (3→4 Bước, hai Bước ảnh mẫu liền nhau), xoá (4→3). Mọi thay đổi ghi thẳng vào
  `scenario.json`, không có nút Lưu nào (`UI-11`, `ST-11`).
- **`UI-10` đạt** — panel chi tiết bày đúng **hai picker tách bạch** Hành động và Vị trí, cộng các
  trường phụ thuộc lựa chọn (Nút, Số lần bấm, Giữ; Ngưỡng khớp, Chờ tối đa, Hết giờ thì, Vùng tìm).

## Bia tập bắn cho nhận dạng ảnh — `I1`…`I8`

Phiên C dùng TextEdit làm bia, và TextEdit **không lộ ra được** lớp lỗi nguy nhất với ca dùng
chính: trong game, vùng cần nhắm thường **không có chữ nào**, và hai nút gần giống nhau là chuyện
thường ngày. Nên dựng một trang bia riêng: `tools/testing/target-page.html` + `log-server.py`.

Trang tự khai báo **toạ độ màn hình của từng bia** và ghi lại **nó nhận được cú click nào**. Nhờ
vậy mỗi phép thử có **hai nguồn đo độc lập**: bộ đo pid ghi cái Auto Click phát ra, trang ghi cái
ứng dụng nhận được. Khu ảnh cố ý không có một chữ nào.

| # | Bia | Chờ thấy | Kết quả |
|---|---|---|---|
| I1 | Một hình khối rõ ràng giữa các hình khác | Click đúng nó | **Đạt** |
| I2 | Hai ô gần giống nhau, chỉ khác chút màu (`#1e88e5` / `#2b93e8`) | Click đúng ô đưa ảnh mẫu | **Hỏng → đã sửa** — xem dưới. **Chờ chạy lại** |
| I3 | Một hình khác biệt giữa bầy giống nhau | Click đúng cái khác biệt | **Đạt** |
| I4 | Năm hình tròn giống hệt | Ghi lại cái nào thắng | **Chưa chạy** |
| I5 | Bia tí hon 26 px | Vẫn tìm ra | **Chưa chạy** |
| I6 | Bia đặt trên nền nhiễu | Vẫn tìm ra | **Chưa chạy** |
| I7 | Bia hiện muộn | Chờ rồi click | **Chưa chạy** |
| I8 | Bia đã dời chỗ | Tìm ở chỗ mới | **Chưa chạy** |

### Phát hiện ngoài checklist — khớp ảnh

**Khớp ảnh chọn nhầm mục tiêu gần giống.** Đưa ảnh mẫu ô **A**, Auto Click click vào ô **B**. Đo
bằng chính bộ khớp của app:

| | Điểm |
|---|---|
| ảnh mẫu A trên ô **A** (đúng) | `0,999498` |
| ảnh mẫu A trên ô **B** (sai) | **`1,001296`** ← thắng |

Điểm **vượt quá 1,0** là điều không thể với tương quan chuẩn hoá — dấu hiệu triệt tiêu chữ số.
Tính lại **cùng công thức** ở `Double`: ô A = `1,000000`, ô B = `0,999957`. Tức bộ khớp **phân biệt
được**, chênh lệch thật `4·10⁻⁵`; nhưng dạng `Σh² − n·h̄²` cộng dồn bằng `Float` sinh nhiễu
`~2·10⁻³` — **gấp 40 lần chênh lệch thật** — nên nó chọn bừa. Đối chứng: ảnh mẫu `S3` được
`1,0017` trên `S3` và `0,5841` trên `S2`, tức phép đo vẫn phân biệt được khi hai thứ khác hẳn nhau.

Đã đổi sang cộng dồn `Double`. Hai test hồi quy dựng đúng điều kiện mất chữ số tệ nhất (vùng sáng,
tương phản thấp, 124×124) và đều kiểm mutation: bản `Float` cho điểm `1,0148` và **chọn đúng cái
bia sai**.

Lỗi này cũng là lý do `RG-23` ra đời: vùng tìm mặc định bám quanh chỗ vừa chụp thì ngay từ đầu đã
không có cơ hội vớ phải mảnh giống hệt ở góc màn hình khác.

## Phiên D — Ghi thao tác

### Bia riêng thay cho Chrome, và vì sao phải đổi

`D10`…`D12` là những mục **chạy lại** một bản ghi. Trước khi chạy mục nào, phải biết bản ghi sẽ
bấm vào đâu — và hoá ra không biết được nếu bia là Chrome.

Bản ghi chỉ giữ **bundle id** của Ứng dụng khoá. Lúc chạy,
`ScenarioSystemBridge.processIdentifier` lấy `runningApplications.first { $0.bundleIdentifier == … }`,
rồi `WindowAnchor.focusedWindowFrame` lấy **cửa sổ đang focus** của tiến trình đó. Máy đang chạy
hai tiến trình Chrome — Chrome thường ngày của người dùng và phiên Chrome cách ly của bộ đo — nên
`first` trả về tiến trình của **người dùng**, và bản ghi sẽ bấm vào cửa sổ đang đăng nhập của họ.
Checklist cấm đúng điều đó, nên `D10` không được chạy như đang có.

Thay vào đó bộ đo dựng **bia riêng**: một ứng dụng AppKit nhỏ, đóng gói hai bản `com.local.biaA`
và `com.local.biaB`, mỗi cửa sổ là lưới 3×3 ô `T1`…`T9`, ghi mọi cú chuột nhận được ra tệp TSV
kèm toạ độ màn hình. Bia này vừa **chỉ đích danh được** bằng bundle id, vừa cho đo hai đầu chính
xác tới từng điểm, vừa dời cửa sổ được theo ý muốn cho `D12`.

Xem thêm `Phát hiện ngoài checklist — phiên D` bên dưới: chuyện hai tiến trình cùng bundle id
không phải chỉ là chuyện của bộ đo.

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| D1 | Bấm `⌥⌘R`, click vài chỗ trong TextEdit, bấm `⌥⌘R` lần nữa | Kịch bản mới xuất hiện, tên theo ứng dụng và thời điểm | `RC-1` `RC-16` | |
| D2 | Trong lúc ghi, quan sát bảng nổi | Hiện số Bước đã ghi và nhắc `⌥⌘R` | `RC-3` | |
| D3 | Bấm `⌥⌘R`, **chỉ click vào chính cửa sổ Auto Click**, kết thúc | Không tạo Kịch bản nào; báo "không ghi được thao tác nào" | `RC-2` `RC-17` | |
| D4 | Ghi một lần double click | Ra **một** Bước `sốLần = 2`, không phải hai Bước | `RC-7` | |
| D5 | Ghi một lần giữ nhấn ~2 giây | Ra `giữMs ≈ 2000` | `RC-6` | |
| D6 | Ghi một lần bôi đen bằng kéo thả | Ra một Bước `kéoThả`, không phải một tràng click | `RC-8` | |
| D7 | Ghi một tràng cuộn bằng trackpad, **cuộn tới cuối rồi thả cho quán tính chạy** | Ra **một** Bước cuộn, không bị cắt làm đôi lúc quán tính đổi dấu | `RC-9` | **Đạt** — dựng lại đúng hình dạng sự kiện của một cú vuốt trackpad (pha chạm `began/changed/ended`, rồi pha quán tính `begin/continue/end`, đuôi **đổi dấu** `-1 -2 -1`, 17 sự kiện cách nhau 16 ms) và bắn vào dòng sự kiện của phiên. Bộ ghi ra **1 Bước** `cuộn deltaY=11`. Con số 11 là **dòng**, không phải 92 điểm ảnh đã phát: bộ ghi đọc `scrollWheelEventDeltaAxis1`, còn `MouseEventEmitter.scroll` phát lại bằng `units: .line` — hai đầu cùng đơn vị nên đi vòng tròn không lệch |
| D8 | Ghi: click, **đợi 5 giây**, click | Bước đầu có khoảng chờ ≈ 5000 ms | `RC-10` (ADR-0004) | |
| D9 | Xem Bước cuối của mọi bản ghi | Khoảng chờ = 0 | `RC-11` | |
| D10 | **Chạy lại** bản ghi D1 | Lặp đúng thao tác vừa ghi | `RC-13` | **Đạt** — đo hai đầu, khớp từng điểm: Auto Click phát `(270,220) (720,420) (870,220)`, bia nhận đúng `T1 T6 T3` tại đúng ba toạ độ đó |
| D11 | Ghi một phiên chạm vào **hai** ứng dụng (TextEdit rồi Finder) | Có cảnh báo nói bản ghi trải trên 2 ứng dụng; Vị trí là toạ độ tuyệt đối | `RC-14` | **Đạt** — ghi 3 cú bấm trải trên hai bia. Kịch bản: khoá ứng dụng = *không có*, cả 3 Bước là `screenPoint` tuyệt đối, tên rơi về `Bản ghi 12/09 10:00` thay vì tên ứng dụng. Popover hiện đúng một dòng cam: *"Bản ghi trải trên 2 ứng dụng nên dùng toạ độ tuyệt đối; các bước sẽ trượt nếu cửa sổ dịch chuyển."* |
| D12 | Ghi xong, di chuyển cửa sổ TextEdit, chạy lại bản ghi một-ứng-dụng | Thao tác **đi theo cửa sổ** | `RC-13` | **Đạt** — dời cửa sổ bia từ `(120,88)` sang `(300,240)`, tức `+180/+152`, rồi chạy lại đúng Kịch bản của D10. Mọi cú bấm dịch đúng chừng ấy: `(450,372) (900,572) (1050,372)`, và bia vẫn nhận đúng `T1 T6 T3`. Ba Bước neo vào **ba góc khác nhau** (`topLeft`, `bottomRight`, `topRight`) nên đây cũng là phép thử cho `WindowAnchor.offset` chọn góc gần nhất |
| D13 | Gõ bàn phím trong lúc đang ghi | Phím **không** lọt vào Kịch bản | `RC-4` `SF-6` (ADR-0003) | |
| D14 | Mở System Settings → Privacy → **Input Monitoring** | Auto Click **không** có trong danh sách | `SF-6` | **Đạt** — `CGEvent.tapCreate` duy nhất của app đăng ký mặt nạ **chỉ có chuột và cuộn**; hai chỗ còn lại dùng `keyDown` là `addLocalMonitorForEvents` (chỉ thấy phím gửi tới cửa sổ của chính app, không cần quyền, để bắt Esc). `Info.plist` **không có** khoá xin Input Monitoring; binary đã cài **không tham chiếu** `IOHIDRequestAccess`/`IOHIDCheckAccess`. **Đã nhìn tận mắt**: sau trọn một phiên kiểm thử với hàng chục lần ghi thao tác, danh sách Input Monitoring vẫn là **`No Items`** — macOS chưa từng ghi nhận Auto Click là thứ theo dõi bàn phím |

### Phát hiện ngoài checklist — phiên D

#### Bản ghi chỉ gọi tên **ứng dụng**, không bao giờ gọi tên **cửa sổ**

Phát hiện lúc chuẩn bị `D10`, chưa sửa.

`Scenario.applicationBundleIdentifier` là toàn bộ những gì bản ghi biết về nơi nó sẽ bấm. Lúc
chạy có hai chỗ thu hẹp, và cả hai đều không đủ hẹp:

1. `ScenarioSystemBridge.processIdentifier` lấy `runningApplications.first` khớp bundle id. Hai
   tiến trình cùng bundle id — hai hồ sơ Chrome, hai bản game mở song song — thì lấy phải bản
   nào là chuyện may rủi theo thứ tự khởi động.
2. `WindowAnchor.focusedWindowFrame` lấy cửa sổ **đang focus** của tiến trình ấy. Một tiến trình
   mười cửa sổ thì Kịch bản bấm vào cửa sổ nào đang ở trước lúc chạy, không phải cửa sổ lúc ghi.

Hậu quả không nhẹ: một Kịch bản ghi trên cửa sổ nháp có thể chạy lại trên cửa sổ đang đăng nhập,
đúng các toạ độ ấy, với bất kỳ thứ gì đang nằm ở đó. `RC-14` đã cảnh báo khi bản ghi trải trên
**hai ứng dụng**; trải trên **hai cửa sổ của cùng một ứng dụng** thì không có gì cảnh báo, vì
bản ghi không phân biệt được.

Đây chính là lý do `D10` không chạy được với bia là Chrome (xem đầu phiên D).

Với trường hợp dùng chính — game — thường chỉ có một tiến trình và một cửa sổ, nên chỗ này im
lặng. Với trình duyệt và trình soạn thảo thì không.

Hướng sửa còn để ngỏ: ghi thêm **tiêu đề cửa sổ neo** lúc ghi, lúc chạy ưu tiên cửa sổ có tiêu đề
khớp (và ưu tiên tiến trình sở hữu cửa sổ ấy), không khớp thì lùi về cửa sổ đang focus như hiện
nay. Tiêu đề đổi theo thời gian nên không thể là điều kiện cứng.

#### Bảng nổi lúc ghi và ruột popover đều **không đọc được bằng Accessibility**

Không phải lỗi, nhưng là thứ làm chậm mọi phiên đo. `entire contents` của cả hai cửa sổ trả về
rỗng — nội dung SwiftUI trong `MenuBarExtra` và trong `NSPanel` không lộ ra cây AX. Mọi khẳng
định về chữ hiện trên hai bề mặt ấy trong tài liệu này đều dựa vào **ảnh chụp màn hình**, không
dựa vào cây AX.

#### Sự kiện cuộn đi theo **toạ độ ghi trong sự kiện**, không theo con trỏ thật

Đo trong `D7`, xác nhận chú thích trong `MouseEventEmitter.scroll` là đúng. Đặt con trỏ thật ra
chỗ không có cửa sổ nào, phát một sự kiện cuộn mang toạ độ nằm trong bia A: **bia A** nhận được,
bia B — ứng dụng vừa được đưa lên trước — không nhận gì. Nhờ vậy Bước cuộn chạy lại không cần
dời con trỏ của người dùng.

## Phiên E — Lưu trữ và hỏng dữ liệu

| # | Làm | Chờ thấy | Chứng minh | Kết quả |
|---|---|---|---|---|
| E1 | `echo "hỏng" > ~/Library/Application\ Support/AutoClick/Scenarios/<uuid>/scenario.json` rồi mở lại app | App vẫn chạy, chỉ thiếu Kịch bản đó | `ST-9` | **Đạt** — trước khi phá: app thấy đủ **9/9** Kịch bản, không cảnh báo. Sau: thấy **8**, đúng cái bị phá biến mất, và hiện *"1 kịch bản có vấn đề"*, tooltip nêu đích danh thư mục. Tệp hỏng và `templates/` của nó **còn nguyên** — app không tự dọn thứ nó không đọc được |
| E2 | Sửa `"schemaVersion"` của một Kịch bản thành `99`, mở lại app | Kịch bản hiện ra nhưng **chỉ đọc**, không mất dữ liệu | `ST-12` | **Đạt, nhưng lòi ra lỗi mất dữ liệu** — Kịch bản hiện đúng tên, panel sửa bị thay hẳn bằng thông báo khoá (không còn ô tên, ô số vòng, danh sách Bước), tệp trên đĩa không bị đụng. Nhưng nút **Sao Chép** vẫn bấm được → xem phần dưới |
| E3 | Thêm một trường lạ vào `scenario.json`, mở lại | Bỏ qua, không lỗi | `ST-10` | **Đạt cả ba vế** — thêm trường lạ ở gốc *và* trong Bước, bỏ `delayMillisecondsAfter`, đặt `repeat = 999.999.999` và `threshold = 7,5`. Kịch bản nạp bình thường, không cảnh báo; app bày `×1.000.000` và `ngưỡng 1.00` — kẹp đúng khoảng. Tệp trên đĩa **không bị ghi đè**: giá trị ngoài khoảng chỉ được kẹp trong bộ nhớ |
| E4 | Xoá một Kịch bản dùng Ảnh mẫu, kiểm tra thư mục | Cả thư mục biến mất, kể cả `templates/` | `ST-3` | **Đạt** — nhân bản `I6` (có `NOISYICON.png`) rồi xoá bản sao: cả thư mục biến mất, kể cả `templates/`. Dựng phép thử này mới lộ ra vế ngược lại của `ST-3` bị hỏng → xem phần dưới |
| E5 | Đổi Ảnh mẫu của một Bước vài lần, đếm tệp trong `templates/` | Tệp cũ bị dọn, thư mục không phình | `ST-12` | **Chưa chạy** — cần quyền Screen Recording để chụp lại Ảnh mẫu |

### Phát hiện ngoài checklist — phiên E

Hai lỗi **mất dữ liệu**, cùng một họ: Kịch bản trông bình thường nhưng rỗng ruột.

**Nhân bản một Kịch bản chỉ đọc đẻ ra bản rỗng.** Bản nạp của Kịch bản `schemaVersion` mới hơn chỉ
có `id` và `name` — các Bước nằm trong phần JSON bản app này không giải mã được. Nút Sao Chép vẫn
bấm được, và ghi thẳng xuống đĩa một Kịch bản mang **tên bản gốc**, `schemaVersion` **hiện tại**,
**không Bước nào**. Đo được: bấm một lần ra `"I6 tren nen nhieu (bản sao)"` với 0 bước, trình soạn
thảo bảo *"Kịch bản chưa có bước nào."* Nguy ở chỗ bản sao trông hoàn toàn bình thường: người dùng
tưởng đã cứu được dữ liệu khỏi cái khoá chỉ-đọc rồi xoá bản gốc là mất sạch. Đúng thứ `ST-12` sinh
ra để tránh. Đã chặn ở kho và tắt luôn nút; xoá thì vẫn cho vì đó là việc người dùng cố ý làm.

**Nhân bản bỏ quên Ảnh mẫu.** [ADR-0005] chọn *"mỗi Kịch bản một thư mục, Ảnh mẫu được nhân bản"*
đúng để xoá là xoá thư mục và **nhân bản là copy thư mục**. Vế xoá đã đúng (`E4`), vế nhân bản thì
chỉ copy `scenario.json`: bản sao giữ nguyên tên tệp Ảnh mẫu nhưng `templates/` của nó rỗng, nên
mọi Bước nhận dạng của nó hỏng ngay. Trước khi có `UI-19` thì trên giao diện chỉ thấy một cái tên
tệp, không cách nào biết là tệp không tồn tại. Đã sửa; kiểm lại trên app thật: bản sao của `I6` giờ
mang theo `NOISYICON.png` trong thư mục của chính nó.

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
