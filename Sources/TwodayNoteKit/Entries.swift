import Foundation

/// The four kinds of block a day holds.
public enum EntryKind: String, CaseIterable, Identifiable, Sendable {
    case task, note, idea, heading

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .task: "Task"
        case .note: L("Ghi chú")
        case .idea: L("Ý tưởng")
        case .heading: L("Tiêu đề")
        }
    }

    public var symbol: String {
        switch self {
        case .task: "checkmark.square"
        case .note: "text.alignleft"
        case .idea: "lightbulb"
        case .heading: "textformat.size"
        }
    }

    /// What people type at the start of a line to pick this kind.
    public var prefix: String {
        switch self {
        case .task: "[] "
        case .note: "- "
        case .idea: "* "
        case .heading: "# "
        }
    }

    public var placeholder: String {
        switch self {
        case .task: L("Thêm việc cần làm…")
        case .note: L("Thêm ghi chú…")
        case .idea: L("Thêm ý tưởng…")
        case .heading: L("Thêm tiêu đề…")
        }
    }
}

/// Text rules for blocks.
public enum EntryText {
    /// Trims each line, collapses runs of spaces, drops empty lines at the
    /// ends. Returns nil when nothing is left.
    public static func clean(_ text: String) -> String? {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ") }
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}

/// Turns what people type into a block: "# Sáng nay" is a heading,
/// "* Widget" an idea, "- Wifi" a note, "[] Gọi Lan" a task.
public enum EntryInput {
    /// Nil when there is no text, unless `allowEmpty` (a block made of a
    /// pasted image): then the kind still comes from the prefix.
    public static func parse(_ raw: String, defaultKind: EntryKind, allowEmpty: Bool = false) -> (kind: EntryKind, text: String)? {
        // Only the leading spaces: "# " alone is a prefix with no text.
        var body = String(raw.drop { $0 == " " || $0 == "\t" })
        var kind = defaultKind
        if let match = EntryKind.allCases.first(where: { body.hasPrefix($0.prefix) }) {
            kind = match
            body = String(body.dropFirst(match.prefix.count))
        }
        if let text = EntryText.clean(body) { return (kind, text) }
        return allowEmpty ? (kind, "") : nil
    }
}

/// Day math and labels. Every block stores the start of its day.
public enum Day {
    public static let locale = Locale(identifier: "vi_VN")

    public static func start(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func adding(_ days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(of: date, calendar: calendar)) ?? date
    }

    /// "Hôm nay", "Ngày mai", then the weekday: "Thứ Bảy". In English
    /// "Today", "Tomorrow", "Saturday".
    public static func label(offset: Int, today: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        switch offset {
        case 0: lang == .en ? "Today" : "Hôm nay"
        case 1: lang == .en ? "Tomorrow" : "Ngày mai"
        case -1: lang == .en ? "Yesterday" : "Hôm qua"
        default: weekday(adding(offset, to: today, calendar: calendar), calendar: calendar, lang: lang)
        }
    }

    /// "Thứ Năm", "Chủ Nhật"; "Thursday".
    public static func weekday(_ date: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        let day = calendar.component(.weekday, from: date)
        if lang == .en {
            return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day - 1]
        }
        return day == 1 ? "Chủ Nhật" : "Thứ \(["Hai", "Ba", "Tư", "Năm", "Sáu", "Bảy"][day - 2])"
    }

    /// "T5", "CN"; "Thu": the short form next to a carried task.
    public static func shortWeekday(_ date: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        let day = calendar.component(.weekday, from: date)
        if lang == .en { return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][day - 1] }
        return day == 1 ? "CN" : "T\(day)"
    }

    /// "Thứ Năm, 5 tháng 11"; "Thursday, November 5".
    public static func long(_ date: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        let day = parts.day ?? 1, month = parts.month ?? 1
        if lang == .en {
            let months = ["January", "February", "March", "April", "May", "June", "July",
                          "August", "September", "October", "November", "December"]
            return "\(weekday(date, calendar: calendar, lang: lang)), \(months[month - 1]) \(day)"
        }
        return "\(weekday(date, calendar: calendar, lang: lang)), \(day) tháng \(month)"
    }

    /// Whole days from `day` to `today`: 1 for yesterday.
    public static func daysLate(from day: Date, today: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: start(of: day, calendar: calendar), to: start(of: today, calendar: calendar)).day ?? 0
    }

    /// Beside a carried task: "từ T4" a day late, "trễ 3 ngày" when longer;
    /// "since Wed", "3 days late".
    public static func lateLabel(from day: Date, today: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        let late = daysLate(from: day, today: today, calendar: calendar)
        let weekday = shortWeekday(day, calendar: calendar, lang: lang)
        switch lang {
        case .vi: return late > 1 ? "trễ \(late) ngày" : "từ \(weekday)"
        case .en: return late > 1 ? "\(late) days late" : "since \(weekday)"
        }
    }

    /// "5/11"; "11/5": the day a Xem sau block was saved.
    public static func short(_ date: Date, calendar: Calendar = .current, lang: Lang = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        let day = parts.day ?? 1, month = parts.month ?? 1
        return lang == .en ? "\(month)/\(day)" : "\(day)/\(month)"
    }

    /// A task that is not done and belongs to a day before today moves to today.
    public static func shouldCarry(kind: EntryKind, isDone: Bool, day: Date, today: Date) -> Bool {
        kind == .task && !isDone && day < start(of: today)
    }
}

/// Counts for the header and the menu bar.
public enum Progress {
    public static func summary(remaining: Int, done: Int) -> String {
        switch (remaining, done) {
        case (0, 0): L("Chưa có việc nào")
        case (0, _): L("Xong hết {} việc", done)
        case (_, 0): L("Còn {} việc", remaining)
        default: L("Còn {} việc · xong {}", remaining, done)
        }
    }

    /// The line under the Xem sau title.
    public static func later(count: Int) -> String {
        count == 0 ? L("Không gấp, không hạn, xem khi rảnh") : L("{} mục để xem khi rảnh", count)
    }
}
