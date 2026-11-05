import Foundation
import Testing
@testable import TwodayNoteKit

@Test("Clean text", arguments: [
    ("Mua sữa", "Mua sữa"),
    ("  Mua   sữa \n", "Mua sữa"),
    ("Dòng 1\n  dòng   2 ", "Dòng 1\ndòng 2"),
])
func cleans(_ input: String, expected: String) {
    #expect(EntryText.clean(input) == expected)
}

@Test("Empty text is nil", arguments: ["", "   ", "\n\n"])
func cleansEmpty(_ input: String) {
    #expect(EntryText.clean(input) == nil)
}

@Test("Prefixes pick the kind")
func parsesPrefixes() {
    #expect(EntryInput.parse("# Sáng nay", defaultKind: .task)! == (.heading, "Sáng nay"))
    #expect(EntryInput.parse("* Widget mới", defaultKind: .task)! == (.idea, "Widget mới"))
    #expect(EntryInput.parse("- Wifi đổi rồi", defaultKind: .task)! == (.note, "Wifi đổi rồi"))
    #expect(EntryInput.parse("[] Gọi Lan", defaultKind: .note)! == (.task, "Gọi Lan"))
    #expect(EntryInput.parse("Gọi Lan", defaultKind: .idea)! == (.idea, "Gọi Lan"))
    #expect(EntryInput.parse("#hashtag", defaultKind: .task)! == (.task, "#hashtag"))
    #expect(EntryInput.parse("# ", defaultKind: .task) == nil)
    #expect(EntryInput.parse("   ", defaultKind: .task) == nil)
}

@Test("Day labels in Vietnamese")
func labels() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    // Thursday, 5 November 2026.
    let thursday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!
    #expect(Day.label(offset: 0, today: thursday, calendar: calendar) == "Hôm nay")
    #expect(Day.label(offset: 1, today: thursday, calendar: calendar) == "Ngày mai")
    #expect(Day.label(offset: 2, today: thursday, calendar: calendar) == "Thứ Bảy")
    #expect(Day.label(offset: 3, today: thursday, calendar: calendar) == "Chủ Nhật")
    #expect(Day.long(thursday, calendar: calendar) == "Thứ Năm, 5 tháng 11")
    #expect(Day.shortWeekday(thursday, calendar: calendar) == "T5")
    #expect(Day.short(thursday, calendar: calendar) == "5/11")
}

@Test("Only unfinished tasks from earlier days carry over")
func carries() {
    let today = Day.start(of: .now)
    let yesterday = Day.adding(-1, to: today)
    #expect(Day.shouldCarry(kind: .task, isDone: false, day: yesterday, today: .now))
    #expect(!Day.shouldCarry(kind: .task, isDone: true, day: yesterday, today: .now))
    #expect(!Day.shouldCarry(kind: .note, isDone: false, day: yesterday, today: .now))
    #expect(!Day.shouldCarry(kind: .task, isDone: false, day: today, today: .now))
}

@Test("Progress summary")
func summary() {
    #expect(Progress.summary(remaining: 0, done: 0) == "Chưa có việc nào")
    #expect(Progress.summary(remaining: 3, done: 0) == "Còn 3 việc")
    #expect(Progress.summary(remaining: 0, done: 2) == "Xong hết 2 việc")
    #expect(Progress.summary(remaining: 3, done: 2) == "Còn 3 việc · xong 2")
    #expect(Progress.later(count: 2) == "2 mục để xem khi rảnh")
}

@Suite("Notebook")
struct NotebookTests {
    let today = Day.start(of: .now)

    @Test func addsToTheEndOfADay() {
        var book = Notebook()
        let first = book.add("Mua sữa", defaultKind: .task, day: today)
        let second = book.add("# Buổi chiều", defaultKind: .task, day: today)
        #expect(book.add("   ", defaultKind: .task, day: today) == nil)
        #expect(book.entries(on: today).map(\.id) == [first!.id, second!.id])
        #expect(second?.kind == .heading)
        #expect(second?.text == "Buổi chiều")
    }

    @Test func togglesOnlyTasks() {
        var book = Notebook()
        let task = book.add("Gọi Lan", defaultKind: .task, day: today)!
        let note = book.add("- Wifi", defaultKind: .task, day: today)!
        book.toggleDone(task.id)
        book.toggleDone(note.id)
        #expect(book.entries.first { $0.id == task.id }!.isDone)
        #expect(book.entries.first { $0.id == task.id }!.doneAt != nil)
        #expect(!book.entries.first { $0.id == note.id }!.isDone)
        #expect(book.counts(on: today) == (0, 1))
    }

    @Test func movesBetweenDays() {
        var book = Notebook()
        let tomorrow = Day.adding(1, to: today)
        let task = book.add("Đặt vé", defaultKind: .task, day: today)!
        book.move(task.id, to: tomorrow)
        #expect(book.entries(on: today).isEmpty)
        #expect(book.entries(on: tomorrow).map(\.id) == [task.id])
    }

    @Test func reorders() {
        var book = Notebook()
        let a = book.add("A", defaultKind: .task, day: today)!
        let b = book.add("B", defaultKind: .task, day: today)!
        let c = book.add("C", defaultKind: .task, day: today)!
        book.reorder(on: today, from: [2], to: 0)
        #expect(book.entries(on: today).map(\.id) == [c.id, a.id, b.id])
        book.reorder(on: today, from: [0], to: 3)
        #expect(book.entries(on: today).map(\.id) == [a.id, b.id, c.id])
    }

    @Test func carriesUnfinishedTasksToTheTop() {
        var book = Notebook()
        let yesterday = Day.adding(-1, to: today)
        let old = book.add("Gọi Lan", defaultKind: .task, day: yesterday)!
        let done = book.add("Gửi báo cáo", defaultKind: .task, day: yesterday)!
        let idea = book.add("* Widget", defaultKind: .task, day: yesterday)!
        let fresh = book.add("Review PR", defaultKind: .task, day: today)!
        book.toggleDone(done.id)
        #expect(book.rollOver(today: today) == 1)
        #expect(book.entries(on: today).map(\.id) == [old.id, fresh.id])
        #expect(book.entries(on: today).first?.carriedFrom == yesterday)
        #expect(book.entries(on: yesterday).map(\.id) == [done.id, idea.id])
        #expect(book.rollOver(today: today) == 0)
    }

    @Test func emptyTextRemovesAndRestores() {
        var book = Notebook()
        let task = book.add("Gọi Lan", defaultKind: .task, day: today)!
        book.entries[0].text = "   "
        let removed = book.commitText(task.id)
        #expect(removed?.id == task.id)
        #expect(book.entries.isEmpty)
        book.restore([removed!])
        #expect(book.entries.count == 1)
    }

    @Test func survivesJSON() throws {
        var book = Notebook()
        book.add("Gọi Lan", defaultKind: .task, day: today)
        book.add("* Logo", defaultKind: .task, day: today, images: ["a.png"])
        let data = try JSONEncoder().encode(book)
        let back = try JSONDecoder().decode(Notebook.self, from: data)
        #expect(back.entries == book.entries)
        #expect(back.entries.last?.images == ["a.png"])
    }

    @Test func readsNotesSavedBeforeImages() throws {
        let json = #"{"version":1,"entries":[{"id":"6E1F8C2A-4B7D-4F0E-9C3A-2D5B8E7F1A40","text":"Gọi Lan","kind":"task","isDone":false,"day":0,"order":0,"createdAt":0}]}"#
        let book = try JSONDecoder().decode(Notebook.self, from: Data(json.utf8))
        #expect(book.entries.first?.images == [])
    }

    @Test func imageOnlyBlocks() {
        var book = Notebook()
        #expect(book.add("", defaultKind: .task, day: today) == nil)
        let shot = book.add("", defaultKind: .task, day: today, images: ["a.png"])
        #expect(shot?.text == "")
        #expect(shot?.kind == .task)
        #expect(book.add("* ", defaultKind: .task, day: today, images: ["b.png"])?.kind == .idea)
        // Clearing the text keeps a block that still has an image.
        #expect(book.commitText(shot!.id) == nil)
        #expect(book.imageNames == ["a.png", "b.png"])
    }

    @Test func finishingATaskDropsItsImages() {
        var book = Notebook()
        let task = book.add("Sửa logo", defaultKind: .task, day: today, images: ["a.png"])!
        book.attach(["b.png", "a.png"], to: task.id)
        #expect(book.entries[0].images == ["a.png", "b.png"])
        let before = book.toggleDone(task.id)
        #expect(before?.images == ["a.png", "b.png"])
        #expect(book.entries[0].isDone)
        #expect(book.imageNames.isEmpty)
        // Undo puts the task back unfinished, with its images.
        book.restore([before!])
        #expect(!book.entries[0].isDone)
        #expect(book.entries[0].images == ["a.png", "b.png"])
        // A task without images gives nothing to undo.
        let plain = book.add("Gọi Lan", defaultKind: .task, day: today)!
        #expect(book.toggleDone(plain.id) == nil)
    }

    @Test func keepsLaterBlocksOffEveryDay() {
        var book = Notebook()
        let yesterday = Day.adding(-1, to: today)
        let link = book.add("- Bài viết về SwiftUI layout", defaultKind: .note, day: today, later: true)!
        let task = book.add("Đọc thử thư viện mới", defaultKind: .task, day: yesterday, later: true)!
        #expect(book.entries(on: today).isEmpty)
        #expect(book.counts(on: yesterday) == (0, 0))
        #expect(book.laterEntries.map(\.id) == [link.id, task.id])
        // A task on Xem sau has no day to be late for.
        #expect(book.rollOver(today: today) == 0)
        #expect(book.laterEntries.count == 2)
        book.reorderLater(from: [1], to: 0)
        #expect(book.laterEntries.map(\.id) == [task.id, link.id])
    }

    @Test func movesBetweenADayAndLater() {
        var book = Notebook()
        let tomorrow = Day.adding(1, to: today)
        let old = book.add("Gọi Lan", defaultKind: .task, day: Day.adding(-1, to: today))!
        book.rollOver(today: today)
        let saved = book.add("- Link hay", defaultKind: .note, day: today, later: true)!
        book.moveToLater(old.id)
        #expect(book.entries(on: today).isEmpty)
        #expect(book.laterEntries.map(\.id) == [saved.id, old.id])
        #expect(book.laterEntries.last?.carriedFrom == nil)
        book.move(saved.id, to: today)
        book.move(old.id, to: tomorrow)
        #expect(book.laterEntries.isEmpty)
        #expect(book.entries(on: today).map(\.id) == [saved.id])
        #expect(book.entries(on: tomorrow).map(\.id) == [old.id])
    }

    @Test func laterSurvivesJSON() throws {
        var book = Notebook()
        book.add("Gọi Lan", defaultKind: .task, day: today)
        book.add("- Link", defaultKind: .note, day: today, later: true)
        let data = try JSONEncoder().encode(book)
        #expect(String(decoding: data, as: UTF8.self).components(separatedBy: "later").count == 2)
        let back = try JSONDecoder().decode(Notebook.self, from: data)
        #expect(back.entries == book.entries)
        #expect(back.laterEntries.count == 1)
    }

    @Test func detachesOneImage() {
        var book = Notebook()
        let idea = book.add("* Màn hình", defaultKind: .task, day: today, images: ["a.png", "b.png"])!
        let before = book.detach("a.png", from: idea.id)
        #expect(book.entries[0].images == ["b.png"])
        #expect(book.detach("x.png", from: idea.id) == nil)
        book.restore([before!])
        #expect(book.entries[0].images == ["a.png", "b.png"])
    }
}

@Suite("Focus clock")
struct FocusClockTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsDown() {
        var clock = FocusClock()
        clock.start(minutes: 25, now: start)
        #expect(clock.isRunning)
        #expect(clock.remaining(now: start) == TimeInterval(1_500))
        #expect(clock.remaining(now: start + 60) == TimeInterval(1_440))
        #expect(clock.progress(now: start + 750) == 0.5)
    }

    @Test func pausesAndResumes() {
        var clock = FocusClock()
        clock.start(minutes: 25, now: start)
        clock.pause(now: start + 100)
        #expect(clock.isPaused)
        // Time passes while paused; nothing is lost.
        #expect(clock.remaining(now: start + 9_999) == TimeInterval(1_400))
        clock.resume(now: start + 500)
        #expect(clock.remaining(now: start + 500) == TimeInterval(1_400))
    }

    @Test func finishesOnce() {
        var clock = FocusClock()
        clock.start(minutes: 1, now: start)
        let early = clock.tick(now: start + 59)
        let onTime = clock.tick(now: start + 60)
        let again = clock.tick(now: start + 61)
        #expect(!early)
        #expect(onTime)
        #expect(!again)
        #expect(clock.isFinished)
        clock.stop()
        #expect(clock.phase == .idle)
    }

    @Test("Format", arguments: [(1500.0, "25:00"), (245.0, "4:05"), (0.2, "0:01"), (0.0, "0:00"), (3600.0, "60:00")])
    func formats(_ seconds: Double, _ text: String) {
        #expect(FocusClock.format(seconds) == text)
    }
}
