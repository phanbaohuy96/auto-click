# Gõ chuỗi theo khối, không theo từng phím

Cách hiển nhiên để tự động gõ một chuỗi là bắt chước gõ thật: mỗi ký tự một cặp nhấn/nhả, mang
theo chuỗi Unicode của nó. Đó là cách `KeyboardEventEmitter` làm lúc đầu. Chạy kiểm thử tay `B8`
mới lộ ra là nó **không hoạt động**.

Gõ `"Xin chào 123 — ăn"` vào TextEdit ra `"Aa chào 123 — ăn"`. Lặp lại được, kể cả khi TextEdit đã
ở trước sẵn nên không phải đua với việc đưa ứng dụng lên trước. Ký tự thay thế luôn là `a` — đúng
ký tự của `virtualKey: 0` mà sự kiện mang theo, tức payload Unicode bị mất và hệ thống rơi về mã
phím. Không có lỗi nào được báo. Một công cụ gõ sai chữ mà im lặng tệ hơn một công cụ không gõ
được.

Chốt: cắt chuỗi thành khối tối đa 20 đơn vị UTF-16, mỗi khối một cặp phím, không cắt giữa một cặp
thay thế. Số sự kiện giảm khoảng 20 lần, và cùng đó là số lần chạm vào cái đang làm mất payload.
Đo qua chính app, cùng một cách đo trước và sau: trước khi sửa hỏng mọi lần, sau khi sửa **8/8
lần đúng**.

## Nguyên nhân gốc: chưa biết

Phần này ghi lại những gì đã **loại được bằng thực nghiệm**, để người sau không đi lại:

- **Bộ gõ tiếng Việt** (máy này chạy EVKey, nằm giữa dòng sự kiện bàn phím và phát lại phím bằng
  pid của chính nó) — tắt hẳn rồi gõ từng ký tự **vẫn hỏng 0/5**.
- **Nhịp gửi** — 30 ms đúng, 60 ms vẫn hỏng. Không phải vấn đề tốc độ.
- **Đích gửi** — `cghidEventTap`, `cgSessionEventTap`, `cgAnnotatedSessionEventTap` như nhau.
- **`virtualKey` khác 0** (F13, fn) để khi mất payload thì chèn ra *không gì* thay vì chữ sai —
  **0/12, không gõ ra gì cả**. Số 0 là bắt buộc chứ không phải lựa chọn.
- **Cả chuỗi trong một cặp phím** — không gõ được gì.
- **Đua với `activate`** — dựng một công cụ mô phỏng đúng đường `bringLockedApplicationToFront`
  rồi gõ ngay khi `frontmost` khớp, không nghỉ chút nào: **6/6 đúng**.

## Không có tỉ lệ hỏng đáng tin

Bản đầu của ADR này ghi những con số như "đúng ~1/5", "≈94%", "còn ~6%". **Đã rút lại toàn bộ.**
Cách đo là gõ vào TextEdit rồi đọc tài liệu bằng AppleScript, mà máy này có bộ gõ tiếng Việt giữ
chữ trong **bộ đệm soạn thảo**: chữ đã gõ đúng nhưng chưa chốt thì AppleScript đọc ra **rỗng**,
không phân biệt được với mất chữ. Chứng minh: gõ `"abc"` đọc ra `""`, bấm mũi tên phải để chốt
thì đọc ra `"abc"`. Kết quả đo còn đổi hẳn theo cách dọn tài liệu giữa hai lượt — đặt lại bằng
AppleScript cho kết quả khác hẳn dọn bằng `⌘A` + `xoá`.

Nói cách khác: bộ đo không đủ tin để phát biểu tỉ lệ. Chỉ hai điều đứng vững, vì được đo **cùng
một cách** trước và sau: bản cũ hỏng lặp lại được, bản mới đúng 8/8.

## Consequences

- Ứng dụng đích thấy **một** phím mang 20 ký tự chứ không phải 20 phím. Ứng dụng nào phản ứng
  theo từng phím — game, ô lọc-khi-gõ — sẽ hành xử khác so với người gõ thật.
- `type` trở thành `async`: nó phải nghỉ giữa các khối. Kéo theo `applyKeyboard` của
  `ScenarioRunner` cũng vậy, và `⌥⌘S` giờ cắt được giữa chừng một chuỗi đang gõ.
- **`B10` vẫn hỏng.** Một Kịch bản có hai Bước `gõChuỗi` (`"["` rồi `"B10b]"`) ra `"â"`. Cùng kiểu
  hỏng: payload mất, rơi về `a`, rồi bộ gõ Telex gộp `aa` thành `â`. Thay đổi này không chạm tới
  nó. Còn mở.
- Đường **dán qua clipboard** (lưu clipboard, đặt chuỗi, gửi `⌘V`, trả lại) là cách duy nhất
  không đi qua cơ chế đang hỏng. Đã cân và chưa chọn: nó cướp clipboard của người dùng ngay giữa
  lúc họ đang làm việc khác, và ứng dụng nào chặn dán thì vẫn chịu.
- **Dừng ở đây theo quyết định của chủ dự án:** gõ chuỗi là tính năng ưu tiên thấp, kiểm thử cơ
  bản là đủ. Nguyên nhân gốc và `B10` được để mở có chủ ý, không phải bỏ sót. Nếu sau này gõ chuỗi
  lên ưu tiên, hướng clipboard là chỗ xét lại đầu tiên.
