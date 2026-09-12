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
- **DM-9** `[Lát 2]` `[đã làm]` `kéoThả(đến: Vị trí)` — nhấn giữ tại **Vị trí** của **Bước**, di chuyển
  qua các điểm trung gian, nhả tại **Vị trí** đích.
- **DM-10** `[Lát 2]` `[đã làm]` `gõChuỗi(văn bản)` và `nhấnPhím(tổ hợp)` là hai **Hành động**
  riêng, không phải một **Hành động** hai dạng: một cái nhập nội dung, một cái ra lệnh.
- **DM-21** `[Lát 2]` `[đã làm]` Tổ hợp phím lưu **tên phím** đọc được (`"c"`), không lưu mã số
  (`8`). Mã số là vị trí vật lý trên bàn phím — đúng, nhưng không ai đọc được khi mở
  `scenario.json` ra xem.
- **DM-22** `[Lát 2]` `[đã làm]` Danh sách phím bổ trợ được chuẩn hoá (bỏ trùng, sắp thứ tự) khi
  dựng, để hai tổ hợp giống nhau luôn so sánh bằng nhau và luôn ghi ra cùng một JSON.

## Vị trí

- **DM-11** `[Lát 1]` `[đã làm]` `theoConTrỏ` — vị trí con trỏ tại đúng thời điểm chạy **Bước**.
- **DM-12** `[Lát 1]` `[đã làm]` `điểmMànHình(x, y)` — toạ độ tuyệt đối trong không gian `CGEvent`
  (gốc ở góc **trên-trái** màn hình chính, đơn vị **point**).
- **DM-13** `[Lát 2]` `[đã làm]` `lệchCửaSổ(góc, dx, dy)` — `góc` ∈ {trênTrái, trênPhải, dướiTrái, dướiPhải}
  của **Cửa sổ neo**. Góc được chọn **tự động lúc ghi điểm**: góc gần điểm nhất.
- **DM-14** `[Lát 4]` `[đã làm]` `theoẢnh(tênẢnhMẫu, ngưỡng, vùngTìm?, chờTốiĐaMs, khiHếtGiờ)`.
- **DM-15** `[Lát 4]` `[đã làm]` `theoChữ(chuỗi, vùngTìm?, chờTốiĐaMs, khiHếtGiờ)`.
- **DM-16** `[Lát 4]` `[đã làm]` `khiHếtGiờ` ∈ {dừngKịchBản, bỏQuaBước}.
- **DM-17** `[Lát 4]` `[đã làm]` `vùngTìm` là tuỳ chọn và **không bao giờ** đòi hỏi **Ứng dụng khoá**.
  Nó được lưu ở dạng bền nhất còn khả dụng tại thời điểm khoanh: lệch so với một góc của
  **Cửa sổ neo** nếu **Kịch bản** có **Ứng dụng khoá** và lấy được cửa sổ, ngược lại là toạ độ
  tuyệt đối trên màn hình. Xem `RG-6`.

- **DM-21** `[đã làm]` **Ứng dụng khoá** nhớ thêm **tiêu đề Cửa sổ neo** lúc ghi.

  Chỉ nhớ bundle id thì không chỉ ra được một cửa sổ. Lúc chạy lại, `Ứng dụng khoá` được giải
  theo hai bước và trước đây cả hai đều quá rộng: lấy **tiến trình đầu tiên** khớp bundle id, rồi
  lấy **cửa sổ đang focus** của nó. Hai hồ sơ trình duyệt, hay hai bản game mở song song, là hai
  tiến trình cùng bundle id; và một tiến trình thì mở bao nhiêu cửa sổ tuỳ thích. Hậu quả: Kịch
  bản ghi trên cửa sổ nháp chạy lại trên cửa sổ đang đăng nhập, đúng những toạ độ ấy.

  Có tiêu đề thì ưu tiên tiến trình **đang mở cửa sổ mang tiêu đề đó**, rồi trong tiến trình ấy ưu
  tiên đúng cửa sổ đó. Tiêu đề là **ưu tiên, không phải điều kiện cứng** — nó đổi suốt (mở tệp
  khác, chuyển tab) — nên không khớp thì lùi về cách cũ chứ không từ chối chạy. Chọn ưu tiên thay
  vì từ chối vì ca dùng chính là game: cửa sổ game hay đổi tiêu đề theo màn chơi, mà từ chối chạy
  thì hỏng hẳn tính năng.

  Trường này **tuỳ chọn**: tệp cũ không có nó vẫn đọc được, và **Ứng dụng khoá** chọn tay trong
  cửa sổ soạn thảo thì không có tiêu đề nào để lưu. `RC-14` cảnh báo khi bản ghi trải trên hai
  **ứng dụng**; trải trên hai **cửa sổ** của cùng một ứng dụng thì không cảnh báo được, vì bản ghi
  chỉ neo vào một cửa sổ duy nhất.

  Phát hiện lúc chuẩn bị `D10` của [kiểm thử tay](../kiem-thu-e2e.md).

## Bất biến

- **DM-18** `[Lát 2]` `[đã làm]` **Kịch bản** chứa **Bước** có **Vị trí** `lệchCửaSổ` thì
  **bắt buộc** phải có **Ứng dụng khoá**; nếu không, **Kịch bản** không hợp lệ để chạy.
  Ràng buộc này **không** áp cho `vùngTìm` và **không** áp cho `theoẢnh` (`DM-17`, `RG-4`).
- **DM-19** `[Lát 1]` `[đã làm]` `theoConTrỏ` kết hợp với số lần lặp `> 1` là hợp lệ: mỗi lần lặp đọc lại
  vị trí con trỏ, nên chuỗi click sẽ đi theo tay người dùng.
- **DM-20** `[Lát 1]` `[đã làm]` Mọi trường số đều được kẹp vào khoảng hợp lệ khi **đọc từ đĩa**, không
  báo lỗi. File hỏng một trường không được làm mất cả **Kịch bản**.
