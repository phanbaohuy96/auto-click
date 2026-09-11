# SDD — Đặc tả thiết kế Auto Click

Tài liệu đặc tả đi **trước** code. Mọi hành vi có thể quan sát được của Auto Click phải
xuất hiện ở đây dưới dạng một yêu cầu có mã số, và code phải trích dẫn mã đó khi hành vi
không hiển nhiên từ chính code.

## Quan hệ với các tài liệu khác

| Tài liệu | Trả lời câu hỏi |
|---|---|
| [`../../CONTEXT.md`](../../CONTEXT.md) | Các khái niệm **tên là gì** và **nghĩa là gì** |
| [`../adr/`](../adr/) | **Vì sao** chọn phương án này thay vì phương án kia |
| `docs/sdd/` (tài liệu này) | Hệ thống **phải làm gì**, chính xác đến mức kiểm chứng được |

## Quy ước mã yêu cầu

| Tiền tố | Phạm vi | Tệp |
|---|---|---|
| `DM` | Mô hình dữ liệu | [02](./02-mo-hinh-du-lieu.md) |
| `EX` | Ngữ nghĩa thực thi | [03](./03-ngu-nghia-thuc-thi.md) |
| `ST` | Lưu trữ | [04](./04-luu-tru.md) |
| `UI` | Giao diện | [05](./05-giao-dien.md) |
| `RC` | Ghi thao tác | [06](./06-ghi-thao-tac.md) |
| `RG` | Nhận dạng mục tiêu | [07](./07-nhan-dang-muc-tieu.md) |
| `SF` | Quyền và an toàn | [08](./08-quyen-va-an-toan.md) |

Mã yêu cầu **không bao giờ được tái sử dụng**. Yêu cầu bị bỏ thì đánh dấu `~~DM-7~~ (đã bỏ)`,
không xoá và không đánh số lại.

## Trạng thái

Mỗi yêu cầu mang một nhãn trạng thái:

- **`[Lát 1]`…`[Lát 4]`** — thuộc lát cắt nào, xem [01](./01-pham-vi.md)
- **`[đã làm]`** — đã có code và test tương ứng

`[đã làm]` nghĩa là có code, **không** đồng nghĩa với đã chạy thử trên máy thật. Yêu cầu nào chỉ
kiểm chứng được bằng tay — vì cần quyền TCC hoặc màn hình thật — được liệt kê trong
[`../kiem-thu-e2e.md`](../kiem-thu-e2e.md) kèm cách chứng minh từng cái.
