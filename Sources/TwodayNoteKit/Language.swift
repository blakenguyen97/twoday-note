import Foundation

/// The language of the app's own text. People pick it in Settings > Chung.
/// Notes stay as people wrote them.
public enum Lang: String, CaseIterable, Identifiable, Sendable {
    case vi, en

    public var id: String { rawValue }

    /// Each language's name in itself, as language menus show them.
    public var name: String {
        switch self {
        case .vi: "Tiếng Việt"
        case .en: "English"
        }
    }

    public var locale: Locale { Locale(identifier: self == .vi ? "vi_VN" : "en_US") }

    /// The UserDefaults key Settings writes.
    public static let key = "language"

    /// Set by the self-test, which checks the Vietnamese text.
    nonisolated(unsafe) public static var override: Lang?

    /// APP_LANG=en (snapshots), then the self-test's choice, then Settings.
    public static var current: Lang {
        if let env = ProcessInfo.processInfo.environment["APP_LANG"], let lang = Lang(rawValue: env) { return lang }
        if let override { return override }
        return UserDefaults.standard.string(forKey: key).flatMap(Lang.init) ?? .vi
    }
}

/// The app's text in the current language. The key is the Vietnamese text;
/// each `{}` takes the next argument: `L("Còn {} việc", 3)`.
public func L(_ vi: String, _ args: any CustomStringConvertible...) -> String {
    Strings.text(vi, args, lang: .current)
}

public enum Strings {
    static func text(_ vi: String, _ args: [any CustomStringConvertible], lang: Lang) -> String {
        let template = lang == .en ? en[vi] ?? vi : vi
        guard !args.isEmpty else { return template }
        var out = ""
        var rest = args[...]
        var remaining = Substring(template)
        while let range = remaining.range(of: "{}"), let arg = rest.popFirst() {
            out += remaining[..<range.lowerBound] + arg.description
            remaining = remaining[range.upperBound...]
        }
        return out + remaining
    }

    /// English for every Vietnamese text the app shows. LanguageTests checks
    /// that each L call in Sources has a line here.
    public static let en: [String: String] = [
        // Kinds of block
        "Ghi chú": "Note",
        "Ý tưởng": "Idea",
        "Tiêu đề": "Heading",
        "Thêm việc cần làm…": "Add a task…",
        "Thêm ghi chú…": "Add a note…",
        "Thêm ý tưởng…": "Add an idea…",
        "Thêm tiêu đề…": "Add a heading…",

        // Header and tabs
        "Xem sau": "Later",
        "Ngày": "Day",
        "Chưa có việc nào": "No tasks yet",
        "Xong hết {} việc": "All {} done",
        "Còn {} việc": "{} to do",
        "Còn {} việc · xong {}": "{} to do · {} done",
        "Không gấp, không hạn, xem khi rảnh": "No rush, no deadline, for when you have time",
        "{} mục để xem khi rảnh": "{} saved for later",
        "Thêm tuỳ chọn": "More options",
        "Xoá việc đã xong": "Clear Finished Tasks",
        "Cài đặt…": "Settings…",
        "Thoát TwodayNote": "Quit TwodayNote",

        // Add field
        "Loại khối mới": "New block kind",
        "Loại khối mới: {}": "New block kind: {}",
        "Loại khối mới. Gõ nhanh: “# ” tiêu đề, “- ” ghi chú, “* ” ý tưởng, “[] ” task. ⌘V dán ảnh":
            "New block kind. Type “# ” for a heading, “- ” a note, “* ” an idea, “[] ” a task. ⌘V pastes an image",

        // List
        "Chưa có gì để xem sau": "Nothing saved for later",
        "Link, đoạn trích, ảnh chụp màn hình vô tình gặp.\nKhông có hạn, không tự dời sang hôm nay.":
            "Links, quotes, screenshots you came across.\nNo deadline, never moved to today.",
        "Hôm nay chưa có gì": "Nothing for today yet",
        "{} còn trống": "{} is empty",
        "Gõ vào ô phía trên rồi nhấn Return.\nBắt đầu bằng # để tạo tiêu đề, - ghi chú, * ý tưởng.":
            "Type above and press Return.\nStart with # for a heading, - a note, * an idea.",
        "Quá hạn: chưa xong từ {}, tự chuyển sang hôm nay": "Overdue: not done since {}, moved to today",
        "Lưu ngày {}": "Saved on {}",
        "Đã xong": "Done",
        "Ảnh": "Image",
        "Thêm mô tả…": "Add a description…",

        // Block menu
        "Mở link": "Open Link",
        "Sao chép link": "Copy Link",
        "Sửa chữ": "Edit Text",
        "Đánh dấu chưa xong": "Mark as Not Done",
        "Đánh dấu đã xong": "Mark as Done",
        "Dán ảnh": "Paste Image",
        "Chuyển thành": "Turn Into",
        "Dời sang": "Move To",
        "Xoá": "Delete",

        // Links
        "Mở video trên YouTube": "Open the video on YouTube",
        "Ảnh video, bấm để mở trên YouTube": "Video thumbnail, click to open on YouTube",
        "Mở {}": "Open {}",
        "Đang tải…": "Loading…",

        // Images
        "Bấm để xem lớn": "Click to view large",
        "Ảnh, bấm để xem lớn": "Image, click to view large",
        "Xem lớn": "View Large",
        "Sao chép ảnh": "Copy Image",
        "Xoá ảnh": "Delete Image",
        "Đóng": "Close",
        "Ảnh trước": "Previous Image",
        "Ảnh sau": "Next Image",
        "Mở bằng Xem trước": "Open in Preview",
        "Không mở được ảnh": "Couldn’t open the image",
        "Thu nhỏ": "Zoom Out",
        "Thu nhỏ (⌘-)": "Zoom out (⌘-)",
        "Vừa khung (⌘0)": "Fit (⌘0)",
        "Phóng to": "Zoom In",
        "Phóng to (⌘=), hoặc ⌃ + lăn chuột, hoặc nhấp đúp vào ảnh": "Zoom in (⌘=), or ⌃ + scroll, or double-click the image",

        // Focus
        "Tập trung": "Focus",
        "Thời lượng": "Length",
        "{} phút": "{} min",
        "Thời lượng một phiên tập trung": "Length of a focus session",
        "Thời lượng: {} phút": "Length: {} minutes",
        "Tiến độ phiên tập trung": "Focus session progress",
        "Tạm dừng": "Pause",
        "Hết giờ! Nghỉ chút nhé.": "Time’s up! Take a break.",
        "Bắt đầu": "Start",
        "Tiếp tục": "Resume",
        "Dừng": "Stop",
        "Phiên mới": "New Session",
        "Hết giờ": "Time’s up",

        // Undo
        "Hoàn tác": "Undo",
        "Đã xong, xoá {} ảnh": "Done, {} images removed",
        "Đã xoá ảnh": "Image deleted",
        "Đã xoá khối trống": "Empty block removed",
        "Đã xoá “{}”": "Deleted “{}”",
        "Đã xoá {} việc đã xong": "Cleared finished tasks: {}",

        // Guide
        "Hướng dẫn sử dụng": "User Guide",
        "Đóng hướng dẫn": "Close Guide",
        "Đóng hướng dẫn (Esc)": "Close the guide (Esc)",
        "Trang trước": "Previous Page",
        "Trang trước (←)": "Previous page (←)",
        "Trang sau": "Next Page",
        "Tiếp": "Next",
        "Bắt đầu dùng": "Get Started",
        "Trang {} trên {}": "Page {} of {}",
        "Chào mừng đến TwodayNote": "Welcome to TwodayNote",
        "Gõ, rồi nhấn Return": "Type, then press Return",
        "Hôm nay, Ngày mai, Xem sau": "Today, Tomorrow, Later",
        "Xong việc, hay để mai": "Done, or tomorrow",
        "Chuột phải để làm thêm": "Right-click for more",
        "Dán ảnh, lưu link": "Paste images, save links",
        "Tập trung từng phiên": "Focus in sessions",
        "Thế là xong!": "You’re all set!",
        "Việc, ghi chú và ý tưởng cho hôm nay và ngày mai, ngay trên thanh menu. Bấm vào icon, hoặc nhấn ⌃⌥N ở bất kỳ app nào.":
            "Tasks, notes, and ideas for today and tomorrow, right in the menu bar. Click the icon, or press ⌃⌥N in any app.",
        "Mỗi dòng thành một khối, mặc định là task. Gõ # ở đầu dòng để có tiêu đề, - ghi chú, * ý tưởng.":
            "Each line becomes a block, a task by default. Start a line with # for a heading, - for a note, * for an idea.",
        "Ghi trước cho ngày mai, hoặc cất link, đoạn trích, ảnh chụp màn hình vào Xem sau để xem khi rảnh. Chuyển nhanh bằng ⌘1 ⌘2 ⌘3.":
            "Plan tomorrow ahead, or keep links, quotes, and screenshots in Later for when you have time. Switch with ⌘1 ⌘2 ⌘3.",
        "Tick khi xong. Task chưa xong của hôm trước tự sang hôm nay, có dấu quá hạn màu cam. Xoá không hỏi lại, vì luôn có Hoàn tác.":
            "Tick a task when it’s done. Unfinished tasks from earlier days move to today with an orange overdue mark. Deleting never asks, because there’s always Undo.",
        "Đổi loại, dời sang ngày khác hay Xem sau, dán ảnh, hoặc xoá. Kéo thả để sắp xếp lại.":
            "Change the kind, move to another day or to Later, paste an image, or delete. Drag to reorder.",
        "⌘V dán ảnh chụp màn hình vào khối đang sửa. Dán link GitHub hay YouTube vào Xem sau, nó tự vào nhóm của mình và hiện thành thẻ.":
            "⌘V pastes a screenshot into the block you’re editing. Paste a GitHub or YouTube link into Later and it files itself under its heading, as a card.",
        "Chọn 15, 25, 45 hay 60 phút rồi Bắt đầu. Thời gian còn lại chạy cạnh icon trên thanh menu, nên cứ đóng TwodayNote mà làm.":
            "Pick 15, 25, 45, or 60 minutes and Start. The time left runs beside the menu bar icon, so you can close TwodayNote and get to work.",
        "Mở lại hướng dẫn này trong ••• > Hướng dẫn sử dụng. Đổi màu nhấn, ngôn ngữ và phím tắt trong Cài đặt (⌘,).":
            "Open this guide again from ••• > User Guide. Change the accent color, language, and shortcut in Settings (⌘,).",
        // Guide sample blocks
        "Gửi bản thiết kế": "Send the design",
        "Quà sinh nhật mẹ": "Mom’s birthday gift",
        "# Dự án mới": "# New project",
        "- Họp lúc 3 giờ chiều": "- Meeting at 3 pm",
        "* Thêm chế độ tối": "* Add a dark mode",
        "Gọi cho Lan": "Call Lan",
        "Đặt vé xe về quê": "Book the bus home",
        "Bài viết về thiết kế": "An article on design",
        "Trả lời email của Minh": "Reply to Minh’s email",
        "Phòng họp tầng 3": "Meeting room, 3rd floor",
        "Mua sữa": "Buy milk",
        "Mua quà sinh nhật": "Buy a birthday gift",
        "Ứng dụng đọc sách": "A reading app",
        "Ghi chú họp sáng": "Morning meeting notes",
        "Màn hình chính mới": "New home screen",
        "Ngôn ngữ lập trình Swift": "The Swift Programming Language",

        // Updates
        "Cập nhật": "Updates",
        "Phiên bản": "Version",
        "Tự kiểm tra bản mới mỗi ngày": "Check for updates every day",
        "Có bản mới trên GitHub thì cập nhật bằng một nút, không phải tải và cài lại.":
            "When GitHub has a newer version, update with one click, no download or reinstall.",
        "Chưa kiểm tra": "Not checked yet",
        "Đây là bản mới nhất": "You’re up to date",
        "Đang kiểm tra…": "Checking…",
        "Có bản {}": "Version {} is available",
        "Đang cài bản {}…": "Installing version {}…",
        "TwodayNote sẽ tự mở lại khi xong.": "TwodayNote opens again when it’s done.",
        "Kiểm tra lần cuối {}": "Last checked {}",
        "Có gì mới": "What’s New",
        "Cập nhật và mở lại": "Update and Relaunch",
        "Kiểm tra ngay": "Check Now",
        "Cập nhật lên bản {}": "Update to Version {}",
        "Đang cập nhật…": "Updating…",
        "Thêm tuỳ chọn. Có bản mới": "More options. An update is available",
        "Không kiểm tra được: {}": "Couldn’t check: {}",
        "Không cập nhật được": "Couldn’t update",
        "Mở trang tải": "Open Download Page",
        "GitHub trả lời mã {}.": "GitHub answered with code {}.",
        "TwodayNote đang chạy từ chỗ tạm của macOS. Kéo app vào thư mục Applications rồi mở lại.":
            "TwodayNote is running from a temporary place macOS made. Drag the app into Applications and open it again.",
        "Không có quyền ghi vào {}. Tải bản mới từ GitHub và cài bằng tay.":
            "No permission to write to {}. Download the new version from GitHub and install it by hand.",
        "Trong file tải về không có TwodayNote.": "The download has no TwodayNote in it.",
        "App trong file tải về không phải TwodayNote.": "The app in the download isn’t TwodayNote.",
        "File tải về là bản {}, không khớp với bản trên GitHub.": "The download is version {}, not the one on GitHub.",
        "Chữ ký của app tải về không hợp lệ.": "The downloaded app’s signature isn’t valid.",
        "App tải về được ký bởi người khác.": "The downloaded app is signed by someone else.",
        "{} báo lỗi: {}": "{} failed: {}",

        // Menu bar and menus
        "TwodayNote, còn {} việc": "TwodayNote, {} to do",
        "Sửa": "Edit",
        "Làm lại": "Redo",
        "Cắt": "Cut",
        "Sao chép": "Copy",
        "Dán": "Paste",
        "Chọn tất cả": "Select All",

        // Settings
        "Cài đặt TwodayNote": "TwodayNote Settings",
        "Chung": "General",
        "Ngôn ngữ": "Language",
        "Mở cùng macOS": "Open at login",
        "Không bật được: {}": "Couldn’t turn on: {}",
        "Phím tắt toàn cục ⌃⌥N": "Global shortcut ⌃⌥N",
        "Mở và đóng TwodayNote từ bất kỳ app nào.": "Open and close TwodayNote from any app.",
        "Hiện số việc còn lại trên thanh menu": "Show tasks left in the menu bar",
        "Chuyển việc chưa xong sang hôm nay": "Move unfinished tasks to today",
        "Task chưa tick của những ngày trước tự lên đầu danh sách hôm nay.": "Unchecked tasks from earlier days go to the top of today.",
        "Phím tắt và gõ nhanh": "Shortcuts and typing",
        "Mở / đóng TwodayNote": "Open / close TwodayNote",
        "Hôm nay · Ngày mai · Xem sau": "Today · Tomorrow · Later",
        "Thêm khối": "Add a block",
        "Gõ ở đầu dòng": "Type at the start of a line",
        "# tiêu đề  - ghi chú  * ý tưởng  [] task": "# heading  - note  * idea  [] task",
        "Giao diện": "Appearance",
        "Chế độ": "Mode",
        "Theo hệ thống": "System",
        "Sáng": "Light",
        "Tối": "Dark",
        "Màu nhấn": "Accent color",
        "Tắt để dùng giao diện cổ điển, như trước macOS 26.": "Turn off for the classic look from before macOS 26.",
        "Mở lại": "Relaunch",
        "Mở lại TwodayNote để áp dụng": "Relaunch TwodayNote to apply",
        "Xem trước màu nhấn": "Accent color preview",
        "Hôm nay": "Today",
        "Ngày mai": "Tomorrow",
        "còn 1": "1 left",
        "Chọn màu nhấn": "Pick an accent color",
        "Gửi bản build đầu tiên": "Send the first build",
        "Thêm task": "Add task",
    ]
}
