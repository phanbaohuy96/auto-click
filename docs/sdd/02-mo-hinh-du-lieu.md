# 02 — Mô hình dữ liệu

Hình dạng cốt lõi và lý do chọn nó: [ADR-0002](../adr/0002-buoc-la-hanh-dong-nhan-vi-tri.md).

## Kịch bản

- **DM-1** `[Lát 1]` `[đã làm]` Một **Kịch bản** có: định danh không đổi, tên, danh sách **Bước** có thứ tự,
  số lần lặp, và **Ứng dụng khoá** tuỳ chọn.
- **DM-2** `[Lát 1]` `[đã làm]` Số lần lặp của **Kịch bản** là `1…1_000_000` hoặc **không giới hạn**
  (chạy đến khi người dùng dừng).
- **DM-3** `[Lát 1]` `[đã làm]` Danh sách **Bước** có thể rỗng. **Kịch bản** rỗng là hợp lệ để lưu nhưng
  không hợp lệ để chạy (`EX-2`).

## Bước

- **DM-4** `[Lát 1]` `[đã làm]` Một **Bước** có: định danh không đổi, đúng một **Hành động**, đúng một
  **Vị trí**, số lần lặp `1…1_000_000`, và khoảng chờ sau khi làm xong `0…3_600_000` ms.
- **DM-5** `[Lát 1]` `[đã làm]` Không tồn tại **Hành động** "chờ". Khoảng chờ là thuộc tính của **Bước**.
  Muốn chờ 5 giây trước khi làm gì đó thì đặt khoảng chờ lên **Bước** đứng trước.

## Hành động

- **DM-6** `[Lát 1]` `[đã làm]` `click(nút, sốLần, giữMs)` — `nút` ∈ {trái, phải, giữa}, `sốLần` `1…10`,
  `giữMs` `0…60_000`. `sốLần = 2` là double click; `giữMs > 0` là giữ nhấn.
- **DM-7** `[Lát 1]` `[đã làm]` `cuộn(dx, dy)` — đơn vị dòng, mỗi trục `-10_000…10_000`.
- **DM-8** `[Lát 1]` `[đã làm]` `diChuột` — chỉ đưa con trỏ tới **Vị trí**, không bấm gì.
- **DM-9** `[Lát 2]` `kéoThả(đến: Vị trí)` — nhấn giữ tại **Vị trí** của **Bước**, di chuyển
  qua các điểm trung gian, nhả tại **Vị trí** đích.
- **DM-10** `[Lát 2]` `gõPhím(chuỗi | tổHợp)` — gõ một chuỗi ký tự, hoặc một tổ hợp phím với
  các phím bổ trợ.

## Vị trí

- **DM-11** `[Lát 1]` `[đã làm]` `theoConTrỏ` — vị trí con trỏ tại đúng thời điểm chạy **Bước**.
- **DM-12** `[Lát 1]` `[đã làm]` `điểmMànHình(x, y)` — toạ độ tuyệt đối trong không gian `CGEvent`
  (gốc ở góc **trên-trái** màn hình chính, đơn vị **point**).
- **DM-13** `[Lát 2]` `lệchCửaSổ(góc, dx, dy)` — `góc` ∈ {trênTrái, trênPhải, dướiTrái, dướiPhải}
  của **Cửa sổ neo**. Góc được chọn **tự động lúc ghi điểm**: góc gần điểm nhất.
- **DM-14** `[Lát 4]` `theoẢnh(tênẢnhMẫu, ngưỡng, vùngTìm?, chờTốiĐaMs, khiHếtGiờ)`.
- **DM-15** `[Lát 4]` `theoChữ(chuỗi, vùngTìm?, chờTốiĐaMs, khiHếtGiờ)`.
- **DM-16** `[Lát 4]` `khiHếtGiờ` ∈ {dừngKịchBản, bỏQuaBước}.
- **DM-17** `[Lát 4]` `vùngTìm` là tuỳ chọn và **luôn** được biểu diễn dưới dạng lệch so với một
  góc của **Cửa sổ neo**, cùng quy tắc với `DM-13`. Không có vùng tìm tuyệt đối — xem
  ghi chú ở `RG-6`.

## Bất biến

- **DM-18** `[Lát 2]` **Kịch bản** chứa **Bước** có **Vị trí** `lệchCửaSổ` hoặc có `vùngTìm`
  thì **bắt buộc** phải có **Ứng dụng khoá**; nếu không, **Kịch bản** không hợp lệ để chạy.
- **DM-19** `[Lát 1]` `[đã làm]` `theoConTrỏ` kết hợp với số lần lặp `> 1` là hợp lệ: mỗi lần lặp đọc lại
  vị trí con trỏ, nên chuỗi click sẽ đi theo tay người dùng.
- **DM-20** `[Lát 1]` `[đã làm]` Mọi trường số đều được kẹp vào khoảng hợp lệ khi **đọc từ đĩa**, không
  báo lỗi. File hỏng một trường không được làm mất cả **Kịch bản**.
