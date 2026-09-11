# Gõ chuỗi theo khối, không theo từng phím

Cách hiển nhiên để tự động gõ một chuỗi là bắt chước gõ thật: mỗi ký tự một cặp nhấn/nhả, mang
theo chuỗi Unicode của nó. Đó là cách `KeyboardEventEmitter` làm lúc đầu. Chạy kiểm thử tay `B8`
mới lộ ra là nó **không hoạt động**.

Gõ `"Xin chào 123 — ăn"` vào TextEdit ra `"Aa chào 123 — ăn"`. Ký tự thay thế luôn là `a`: payload
Unicode thỉnh thoảng bị mất trên đường qua hệ thống sự kiện, và khi đó macOS rơi về `virtualKey`
của sự kiện — số 0, tức phím `a`. Không có lỗi nào được báo. Một công cụ gõ sai chữ mà im lặng
tệ hơn một công cụ không gõ được.

Đo trên chuỗi 92 ký tự, mỗi cấu hình nhiều lượt:

| Cách gửi | Đúng |
|---|---|
| Từng ký tự, không nhịp (bản đầu) | 0/5 |
| Từng ký tự, nhịp 10 ms | 1/5 |
| Từng ký tự, nhịp 20 ms | 1/5 |
| Cả chuỗi trong một cặp phím | 0/3 — không gõ được gì |
| **Khối 20 đơn vị UTF-16, nhịp 10 ms** | **≈109/116** |

Ba hướng khác đã thử và loại bằng số đo, không phải bằng phỏng đoán:

- **Giãn nhịp** — 30 ms đúng 15/15 nhưng 60 ms vẫn hỏng 1/15. Không phải vấn đề tốc độ.
- **Đổi đích gửi** — `cghidEventTap`, `cgSessionEventTap`, `cgAnnotatedSessionEventTap` cho kết
  quả như nhau.
- **Đổi `virtualKey` sang phím không sinh chữ** (F13, fn) để khi mất payload thì chèn ra *không
  gì* thay vì chữ sai — **0/12, không gõ ra gì cả**. Số 0 là bắt buộc chứ không phải lựa chọn.

Chốt: cắt chuỗi thành khối tối đa 20 đơn vị UTF-16, mỗi khối một cặp phím, không cắt giữa một cặp
thay thế. Số sự kiện giảm 20 lần, và cùng đó là số lần chạm vào cái race gây mất payload.

Hướng duy nhất chắc chắn 100% là **dán qua clipboard** — lưu clipboard, đặt chuỗi, gửi `⌘V`, trả
clipboard về. Không chọn: nó cướp clipboard của người dùng ngay giữa lúc họ đang làm việc khác, và
ứng dụng nào chặn dán (một số ô mật khẩu) thì vẫn chịu. Đổi một lỗi hiếm lấy một tác dụng phụ
chắc chắn xảy ra mỗi lần chạy là lỗ.

## Consequences

- Ứng dụng đích thấy **một** phím mang 20 ký tự chứ không phải 20 phím. Ứng dụng nào phản ứng
  theo từng phím — game, ô lọc-khi-gõ — sẽ hành xử khác so với người gõ thật.
- **Còn khoảng 6% lượt gõ chuỗi dài mất nguyên một khối 20 ký tự.** Chia khối đổi "hỏng vặt rải
  khắp chuỗi" lấy "hỏng hiếm nhưng mất cả mảng". Giới hạn này được ghi thẳng ở `EX-24` thay vì
  giấu đi.
- `type` trở thành `async`: nó phải nghỉ giữa các khối. Kéo theo `applyKeyboard` của
  `ScenarioRunner` cũng vậy, và `⌥⌘S` giờ cắt được giữa chừng một chuỗi đang gõ.
