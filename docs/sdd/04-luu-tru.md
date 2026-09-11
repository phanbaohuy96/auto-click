# 04 — Lưu trữ

Bố cục thư mục và lý do nhân bản **Ảnh mẫu**: [ADR-0005](../adr/0005-moi-kich-ban-mot-thu-muc.md).

## Bố cục

- **ST-1** `[Lát 1]` `[đã làm]` Gốc lưu trữ là `~/Library/Application Support/AutoClick/`.
- **ST-2** `[Lát 1]` `[đã làm]` Mỗi **Kịch bản** là một thư mục `Scenarios/<uuid>/` chứa `scenario.json`,
  và (từ Lát 4) một thư mục con `templates/`.
- **ST-3** `[Lát 1]` `[đã làm]` Xoá **Kịch bản** là xoá cả thư mục. Không có bộ đếm tham chiếu ở đâu cả.
  Mặt kia của cùng lựa chọn ([ADR-0005]): **nhân bản là copy cả thư mục**, kể cả `templates/`. Chỉ
  copy `scenario.json` thì bản sao trỏ vào những tệp không tồn tại — mọi Bước nhận dạng của nó hỏng
  ngay, dù trên giao diện trông vẫn như một Kịch bản bình thường.
- **ST-4** `[Lát 1]` `[đã làm]` `UserDefaults` chỉ còn giữ: cấu hình **Chế độ đơn giản** (các khoá đã có
  từ 1.2.0, giữ nguyên tên) và định danh **Kịch bản** đang chọn.

## Định dạng `scenario.json`

- **ST-5** `[Lát 1]` `[đã làm]` JSON có `schemaVersion` là số nguyên, bắt đầu từ `1`.
- **ST-6** `[Lát 1]` `[đã làm]` **Hành động** và **Vị trí** được mã hoá với trường phân biệt `kind`, không
  dùng Codable tổng hợp sẵn của Swift cho enum có giá trị đi kèm — JSON phải đọc và sửa tay được.
- **ST-7** `[Lát 1]` `[đã làm]` Toạ độ mã hoá thành `x`/`y` rời, không phải mảng. `CGPoint` mặc định mã hoá
  thành `[1,2]`, không chấp nhận được cho một định dạng có đặc tả.

```json
{
  "schemaVersion": 1,
  "id": "6A1F…",
  "name": "Xoá hàng loạt",
  "repeat": 50,
  "lockedApplication": { "bundleIdentifier": "com.google.Chrome", "name": "Google Chrome" },
  "steps": [
    {
      "id": "0C22…",
      "action": { "kind": "click", "button": "left", "count": 2, "holdMilliseconds": 0 },
      "target": { "kind": "screenPoint", "x": 820, "y": 410 },
      "repeat": 1,
      "delayMillisecondsAfter": 200
    },
    {
      "id": "91B7…",
      "action": { "kind": "scroll", "deltaX": 0, "deltaY": -3 },
      "target": { "kind": "cursor" },
      "repeat": 5,
      "delayMillisecondsAfter": 100
    }
  ]
}
```

- **ST-8** `[Lát 1]` `[đã làm]` `"repeat"` nhận số nguyên, hoặc chuỗi `"until-stopped"` cho **Kịch bản**
  chạy không giới hạn (`DM-2`). Số lần lặp của **Bước** luôn là số nguyên.

## Đọc và ghi

- **ST-9** `[Lát 1]` `[đã làm]` Thư mục con nào không đọc được `scenario.json` thì **bỏ qua và ghi log**,
  không làm hỏng việc nạp các **Kịch bản** còn lại.
- **ST-10** `[Lát 1]` `[đã làm]` Trường không nhận ra thì bỏ qua; trường thiếu thì dùng giá trị mặc định;
  trường ngoài khoảng thì kẹp lại (`DM-20`).
- **ST-11** `[Lát 1]` `[đã làm]` Ghi bằng cách ghi ra tệp tạm rồi thay thế nguyên tử, để tắt máy giữa
  chừng không để lại `scenario.json` cụt.
- **ST-12** `[Lát 1]` `[đã làm]` `schemaVersion` lớn hơn phiên bản app hiểu được thì **Kịch bản** đó được
  nạp ở chế độ chỉ đọc và không cho chạy, thay vì đọc sai. Bản nạp chỉ có tên và mã, **không có
  Bước nào** — các Bước nằm trong phần app này không giải mã được. Vì vậy **nhân bản cũng bị chặn**:
  bản sao sẽ mang tên bản gốc, `schemaVersion` hiện tại và không Bước nào, tức là đúng thứ yêu cầu
  này sinh ra để tránh. Xoá thì vẫn cho, vì đó là việc người dùng cố ý làm.
