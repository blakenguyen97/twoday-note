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

Mỗi khối có thể kèm ảnh dán bằng ⌘V, hiện thành hàng thumbnail dưới chữ.
Khối chỉ có ảnh, không chữ, vẫn được giữ.

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
| Dán ảnh | vào khối đang sửa, hoặc chờ dưới ô nhập tới khi Return; menu chuột phải > Dán ảnh | ⌘V |
| Xem ảnh lớn | bấm vào thumbnail; phủ kín popover | Esc đóng, ← → chuyển ảnh |
| Phóng to / thu nhỏ ảnh | pinch trên trackpad, ⌃ + lăn chuột (quanh con trỏ), nhấp đúp vào ảnh, nút − % + dưới ảnh | ⌘= ⌘- ⌘0 (vừa khung) |
| Kéo ảnh khi đã phóng to | kéo bằng chuột, hoặc cuộn hai ngón | — |
| Sao chép / xoá ảnh / mở bằng Xem trước | menu chuột phải trên ảnh, thanh trên trình xem ảnh | — |
| Đổi loại / dời ngày / xoá | menu chuột phải | — |
| Sắp xếp lại | kéo thả | — |
| Xoá việc đã xong | menu ••• | — |
| Hoàn tác xoá | thông báo nhỏ trên thanh Focus | — |
| Tập trung (Pomodoro) | thanh Focus dưới đáy: chọn 15/25/45/60 phút, Bắt đầu, Tạm dừng, Tiếp tục, Dừng | — |
| Cài đặt | menu ••• | ⌘, |
| Thoát | menu ••• | ⌘Q |

## Focus

Đếm ngược kiểu Pomodoro ở đáy popover. Thời gian còn lại chạy cạnh icon
trên thanh menu (mờ khi tạm dừng), nên không cần mở popover. Hết giờ: tiếng
"Glass", thanh menu ghi "Hết giờ" cho tới khi bắt đầu phiên mới hoặc đóng.
Không lưu qua lần mở lại app.

## Ảnh

Ảnh lưu thành file trong `Images/` cạnh `notes.json`; khối chỉ giữ tên file.
Đánh dấu xong một task là xoá ảnh của nó, có Hoàn tác. File chỉ bị xoá thật
khi không còn khối, ảnh chờ, hay Hoàn tác nào dùng tới.

## Empty states

- Hôm nay trống: "Hôm nay chưa có gì" + gợi ý gõ ở ô phía trên.
- Ngày mai / ngày kia trống: "Ngày mai còn trống" + cùng gợi ý.

## Feeling

**Nhanh và nhẹ.** Mở bằng một phím tắt, gõ, Return, đóng bằng Esc. Không
spinner, không hỏi xác nhận: xoá có Hoàn tác ngay tại chỗ.
