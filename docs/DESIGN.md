# TwodayNote — Design plan

Ghi chú nhanh task, ý tưởng, ghi chú cho hôm nay và 1–2 ngày tới, sống trên
thanh menu macOS.

## Archetype

Menu bar extra + popover + cửa sổ Cài đặt. Không có cửa sổ chính, không có
icon trên Dock (`LSUIElement`). Popover là một bảng "quick capture": nó là
nơi duy nhất để gõ, nên ô nhập được focus ngay khi mở.

## Information architecture

Một trang, ba ngày: **Hôm nay · Ngày mai · Thứ X** (ngày kia) chọn bằng
segmented control. Mỗi ngày là một danh sách khối (block):

| Loại | Hiển thị | Gõ nhanh |
| --- | --- | --- |
| Task | checkbox | mặc định, hoặc `[] ` |
| Ghi chú | biểu tượng văn bản | `- ` |
| Ý tưởng | bóng đèn | `* ` |
| Tiêu đề | chữ đậm, không thẻ | `# ` |

Task chưa xong của những ngày trước tự chuyển sang hôm nay (bật/tắt trong
Cài đặt) và ghi "từ T4" để biết nó bị dời.

## Command map

| Hành động | Ở đâu | Phím tắt |
| --- | --- | --- |
| Mở / đóng TwodayNote | icon thanh menu | ⌃⌥N (toàn cục) |
| Thêm khối | ô nhập | Return |
| Đổi loại khối mới | menu cạnh ô nhập | gõ tiền tố |
| Chọn ngày | segmented control | ⌘1 ⌘2 ⌘3 |
| Đánh dấu xong | checkbox | — |
| Sửa nội dung | bấm vào chữ | Return để xong |
| Đổi loại / dời ngày / xoá | menu chuột phải | — |
| Sắp xếp lại | kéo thả | — |
| Xoá việc đã xong | menu ••• | — |
| Hoàn tác xoá | thông báo nhỏ dưới đáy | — |
| Cài đặt | menu ••• | ⌘, |
| Thoát | menu ••• | ⌘Q |

## Empty states

- Hôm nay trống: "Hôm nay chưa có gì" + gợi ý gõ ở ô phía trên.
- Ngày mai / ngày kia trống: "Ngày mai còn trống" + cùng gợi ý.

## Feeling

**Nhanh và nhẹ.** Mở bằng một phím tắt, gõ, Return, đóng bằng Esc. Không
spinner, không hỏi xác nhận: xoá có Hoàn tác ngay tại chỗ.
