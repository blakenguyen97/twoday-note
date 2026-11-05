import Foundation

/// The four kinds of block a day holds.
public enum EntryKind: String, CaseIterable, Identifiable, Sendable {
    case task, note, idea, heading

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .task: "Task"
        case .note: "Ghi chú"
        case .idea: "Ý tưởng"
        case .heading: "Tiêu đề"
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
        case .task: "Thêm việc cần làm…"
        case .note: "Thêm ghi chú…"
        case .idea: "Thêm ý tưởng…"
        case .heading: "Thêm tiêu đề…"
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
    public static func parse(_ raw: String, defaultKind: EntryKind) -> (kind: EntryKind, text: String)? {
        // Only the leading spaces: "# " alone is a prefix with no text.
        let trimmed = String(raw.drop { $0 == " " || $0 == "\t" })
        for kind in EntryKind.allCases where trimmed.hasPrefix(kind.prefix) {
            guard let text = EntryText.clean(String(trimmed.dropFirst(kind.prefix.count))) else { return nil }
            return (kind, text)
        }
        guard let text = EntryText.clean(trimmed) else { return nil }
        return (defaultKind, text)
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

    /// "Hôm nay", "Ngày mai", then the weekday: "Thứ Bảy".
    public static func label(offset: Int, today: Date, calendar: Calendar = .current) -> String {
        switch offset {
        case 0: "Hôm nay"
        case 1: "Ngày mai"
        case -1: "Hôm qua"
        default: weekday(adding(offset, to: today, calendar: calendar), calendar: calendar)
        }
    }

    /// "Thứ Năm", "Chủ Nhật".
    public static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1: "Chủ Nhật"
        case let day: "Thứ \(["Hai", "Ba", "Tư", "Năm", "Sáu", "Bảy"][day - 2])"
        }
    }

    /// "T5", "CN": the short form next to a carried task.
    public static func shortWeekday(_ date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.weekday, from: date)
        return day == 1 ? "CN" : "T\(day)"
    }

    /// "Thứ Năm, 5 tháng 11".
    public static func long(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return "\(weekday(date, calendar: calendar)), \(parts.day ?? 1) tháng \(parts.month ?? 1)"
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
        case (0, 0): "Chưa có việc nào"
        case (0, _): "Xong hết \(done) việc"
        case (_, 0): "Còn \(remaining) việc"
        default: "Còn \(remaining) việc · xong \(done)"
        }
    }
}
