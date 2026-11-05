import Foundation
import Testing
@testable import TwodayNoteKit

@Test("Every L(\"…\") in Sources has English")
func everyTextHasEnglish() throws {
    let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources")
    let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
    #expect(files.count > 10)
    // L("…"), with the escapes as they are in the source, like the table keys.
    let pattern = try Regex(#"\bL\("((?:[^"\\]|\\.)*)""#)
    var missing: [String] = []
    var used = 0
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        for match in text.matches(of: pattern) {
            guard let key = match.output[1].substring.map(String.init) else { continue }
            used += 1
            // The source has \n where the key has a line break.
            let unescaped = key.replacingOccurrences(of: "\\n", with: "\n")
            if Strings.en[unescaped] == nil { missing.append("\(file.lastPathComponent): \(key)") }
        }
    }
    #expect(used > 100)
    #expect(missing.isEmpty, "No English for:\n\(missing.joined(separator: "\n"))")
}

@Test("{} takes the arguments in order")
func fillsArguments() {
    #expect(Strings.text("Còn {} việc · xong {}", [3, 2], lang: .vi) == "Còn 3 việc · xong 2")
    #expect(Strings.text("Còn {} việc · xong {}", [3, 2], lang: .en) == "3 to do · 2 done")
    #expect(Strings.text("Đã xoá “{}”", ["Mua sữa"], lang: .en) == "Deleted “Mua sữa”")
    #expect(Strings.text("Chưa dịch", [], lang: .en) == "Chưa dịch")
}

@Test("Day labels in English")
func englishLabels() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    // Thursday, 5 November 2026.
    let thursday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!
    #expect(Day.label(offset: 0, today: thursday, calendar: calendar, lang: .en) == "Today")
    #expect(Day.label(offset: 1, today: thursday, calendar: calendar, lang: .en) == "Tomorrow")
    #expect(Day.label(offset: 3, today: thursday, calendar: calendar, lang: .en) == "Sunday")
    #expect(Day.long(thursday, calendar: calendar, lang: .en) == "Thursday, November 5")
    #expect(Day.short(thursday, calendar: calendar, lang: .en) == "11/5")
    let tuesday = Day.adding(-2, to: thursday, calendar: calendar)
    let wednesday = Day.adding(-1, to: thursday, calendar: calendar)
    #expect(Day.lateLabel(from: wednesday, today: thursday, calendar: calendar, lang: .en) == "since Wed")
    #expect(Day.lateLabel(from: tuesday, today: thursday, calendar: calendar, lang: .en) == "2 days late")
    #expect(Day.lateLabel(from: tuesday, today: thursday, calendar: calendar, lang: .vi) == "trễ 2 ngày")
}
