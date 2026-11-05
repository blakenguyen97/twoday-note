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
