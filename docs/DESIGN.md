# TwodayNote — Design plan

Ghi chú nhanh task, ý tưởng, ghi chú cho hôm nay và ngày mai, sống trên
thanh menu macOS.

## Archetype

Menu bar extra + popover + cửa sổ Cài đặt. Không có cửa sổ chính, không có
icon trên Dock (`LSUIElement`). Popover là một bảng "quick capture": nó là
nơi duy nhất để gõ, nên ô nhập được focus ngay khi mở.

## Information architecture

Một trang, hai ngày: **Hôm nay · Ngày mai**, và **Xem sau**, chọn bằng
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
Cài đặt) và có dấu quá hạn màu cam bên phải: biểu tượng chấm than và "từ T4",
hoặc "trễ 3 ngày" khi đã dời hơn một ngày. Đánh dấu xong thì dấu đó mất.

## Xem sau

Tab thứ ba, sau hai ngày: chỗ để những thứ không quan trọng, vô tình gặp
(link, đoạn trích, ảnh chụp màn hình) và muốn xem lại khi rảnh. Không thuộc
ngày nào, không có hạn, không bao giờ tự chuyển sang hôm nay. Khối mới ở đây
mặc định là Ghi chú (ngày vẫn mặc định Task), và ghi ngày lưu ("5/11") ở bên
phải. Dời qua lại bằng menu chuột phải > Dời sang.

Dán link GitHub hoặc YouTube vào Xem sau thì khối tự vào dưới tiêu đề
"GitHub" hoặc "YouTube" (chưa có thì tự tạo, ở cuối danh sách; ghi chú thường
nằm phía trên các mục này). Khối link hiện thẻ thay cho chữ: repo GitHub có tên,
nhãn Repo, owner/repo, số sao, ngôn ngữ, mô tả và topic; video YouTube có
thumbnail ở đầu, tiêu đề và kênh. Thông tin lấy từ API công khai của GitHub
và oEmbed của YouTube (không cần key), lưu cùng khối nên vẫn hiện khi offline;
lỗi mạng thì thử lại khi mở popover. Ở các ngày, link cũng có thẻ nhưng không
gom nhóm.

## Command map

| Hành động | Ở đâu | Phím tắt |
| --- | --- | --- |
| Mở / đóng TwodayNote | icon thanh menu | ⌃⌥N (toàn cục) |
| Thêm khối | ô nhập | Return |
| Đổi loại khối mới | menu cạnh ô nhập | gõ tiền tố |
| Chọn ngày | segmented control | ⌘1 ⌘2 |
| Mở Xem sau | tab cuối của segmented control | ⌘3 |
| Đánh dấu xong | checkbox | — |
| Sửa nội dung | bấm vào chữ | Return để xong |
| Dán ảnh | vào khối đang sửa, hoặc chờ dưới ô nhập tới khi Return; menu chuột phải > Dán ảnh | ⌘V |
| Xem ảnh lớn | bấm vào thumbnail; phủ kín popover | Esc đóng, ← → chuyển ảnh |
| Phóng to / thu nhỏ ảnh | pinch trên trackpad, ⌃ + lăn chuột (quanh con trỏ), nhấp đúp vào ảnh, nút − % + dưới ảnh | ⌘= ⌘- ⌘0 (vừa khung) |
| Kéo ảnh khi đã phóng to | kéo bằng chuột, hoặc cuộn hai ngón | — |
| Sao chép / xoá ảnh / mở bằng Xem trước | menu chuột phải trên ảnh, thanh trên trình xem ảnh | — |
| Đổi loại / dời ngày / cất vào Xem sau / xoá | menu chuột phải | — |
| Mở link / sao chép link / sửa chữ của khối link | bấm vào tên hoặc thumbnail; menu chuột phải | — |
| Sắp xếp lại | kéo thả | — |
| Xoá việc đã xong | menu ••• | — |
| Hoàn tác xoá | thông báo nhỏ trên thanh Focus | — |
| Tập trung (Pomodoro) | thanh Focus dưới đáy: chọn 15/25/45/60 phút, Bắt đầu, Tạm dừng, Tiếp tục, Dừng | — |
| Hướng dẫn sử dụng | menu •••; tự mở lần đầu | ← → lật trang, Return tiếp, Esc đóng |
| Cài đặt | menu ••• | ⌘, |
| Thoát | menu ••• | ⌘Q |

## Hướng dẫn sử dụng

Lần đầu mở app, popover tự mở với phần hướng dẫn phủ lên trên: 8 trang trượt
ngang (vuốt trackpad, ← →, hoặc nút Tiếp), chấm trang ở dưới, nút đóng ở trên.
Mỗi trang có một demo nhỏ chạy lặp, dựng bằng chính các control của app,
không dùng ảnh tĩnh: ô nhập tự gõ và Return thành khối, Picker tự chuyển ngày,
checkbox tự tick, menu chuột phải mở ra, đồng hồ Focus đếm ngược cạnh icon.
Demo chỉ chạy khi trang đang hiện; Reduce Motion và snapshot thấy một khung
đứng yên. Đóng hay bấm "Bắt đầu dùng" ở trang cuối thì không tự mở lại nữa
(`guide.seen`); mở lại bằng ••• > Hướng dẫn sử dụng.

## Ngôn ngữ và giao diện

Cài đặt > Chung > Ngôn ngữ: Tiếng Việt (mặc định) hoặc English. Đổi là popover,
Cài đặt và menu đổi ngay, không cần mở lại app; ghi chú của người dùng giữ
nguyên. Mọi chữ của app đi qua `L("…")` (TwodayNoteKit/Language.swift): khoá là
câu tiếng Việt, bảng `Strings.en` có câu tiếng Anh, `{}` là chỗ điền số hoặc tên.
LanguageTests báo lỗi nếu một `L("…")` chưa có tiếng Anh.

Cài đặt > Giao diện > Chế độ: Theo hệ thống, Sáng, hoặc Tối, đổi ngay cho
popover và cửa sổ.

Cài đặt > Giao diện > Liquid Glass: tắt thì app dùng giao diện cổ điển như
trước macOS 26 (popover, tab, nút, menu), và thanh Hoàn tác là thanh thường
thay vì kính. macOS chọn giao diện lúc app mở (khoá
UIDesignRequiresCompatibility), nên đổi xong có nút "Mở lại" ngay dưới.

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
- Ngày mai trống: "Ngày mai còn trống" + cùng gợi ý.
- Xem sau trống: "Chưa có gì để xem sau" + nó dùng để làm gì.

## Feeling

**Nhanh và nhẹ.** Mở bằng một phím tắt, gõ, Return, đóng bằng Esc. Không
spinner, không hỏi xác nhận: xoá có Hoàn tác ngay tại chỗ.
