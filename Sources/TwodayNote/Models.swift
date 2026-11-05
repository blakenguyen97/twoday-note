import Foundation
import Observation
import TwodayNoteKit

/// App-wide state the popover, the menu bar icon, and Settings share.
/// The data is one Notebook saved as JSON (Store.url) after each change.
@Observable
final class AppModel {
    private(set) var book: Notebook
    /// 0 today, 1 tomorrow, 2 the day after.
    var dayOffset = 0
    /// The kind a new block gets when it has no prefix.
    var newKind: EntryKind = .task
    /// Bumped each time the popover opens, so the add field takes focus.
    var focusTick = 0
    /// The last removal, while its Undo is on screen.
    var undo: UndoNotice?
    private(set) var today = Day.start(of: .now)

    /// Called after every change, for the menu bar count.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    static let dayCount = 3

    init() {
        book = Store.load()
    }

    var selectedDay: Date { Day.adding(dayOffset, to: today) }
    var visible: [Entry] { book.entries(on: selectedDay) }
    func label(offset: Int) -> String { Day.label(offset: offset, today: today) }
    var todayCounts: (remaining: Int, done: Int) { book.counts(on: today) }

    // MARK: Changes

    func add(_ raw: String) -> Bool {
        guard book.add(raw, defaultKind: newKind, day: selectedDay) != nil else { return false }
        changed()
        return true
    }

    func toggleDone(_ id: UUID) {
        book.toggleDone(id)
        changed()
    }

    func setKind(_ id: UUID, _ kind: EntryKind) {
        book.setKind(id, kind)
        changed()
    }

    func move(_ id: UUID, toOffset offset: Int) {
        book.move(id, to: Day.adding(offset, to: today))
        changed()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        book.reorder(on: selectedDay, from: source, to: destination)
        changed()
    }

    func setText(_ id: UUID, _ text: String) {
        guard let i = book.index(of: id), book.entries[i].text != text else { return }
        book.entries[i].text = text
        changed(countsChanged: false)
    }

    /// After editing: tidies the text, or removes the block when it is empty.
    func commitText(_ id: UUID) {
        if let removed = book.commitText(id) {
            undo = UndoNotice(message: "Đã xoá khối trống", entries: [removed])
        }
        changed()
    }

    func delete(_ id: UUID) {
        let removed = book.remove([id])
        guard let first = removed.first else { return }
        undo = UndoNotice(message: "Đã xoá “\(first.text.prefix(24))”", entries: removed)
        changed()
    }

    func clearDone() {
        let done = Set(visible.filter(\.isDone).map(\.id))
        guard !done.isEmpty else { return }
        let removed = book.remove(done)
        undo = UndoNotice(message: "Đã xoá \(removed.count) việc đã xong", entries: removed)
        changed()
    }

    func undoRemoval() {
        guard let undo else { return }
        book.restore(undo.entries)
        self.undo = nil
        changed()
    }

    /// Moves to a new day when the date changed, and carries unfinished
    /// tasks over when Settings allows it.
    func refreshDay(now: Date = .now) {
        today = Day.start(of: now)
        if Prefs.carryOver, book.rollOver(today: today) > 0 { changed() }
    }

    /// For the self-test and seed data only.
    func replace(_ notebook: Notebook) {
        book = notebook
        changed()
    }

    private func changed(countsChanged: Bool = true) {
        if countsChanged { onChange?() }
        // Typing saves half a second after the last key; everything else at once.
        saveTask?.cancel()
        let delay: Duration = countsChanged ? .zero : .milliseconds(500)
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            Store.save(self.book)
        }
    }

    /// Writes now, for quitting.
    func flush() {
        saveTask?.cancel()
        Store.save(book)
    }
}

struct UndoNotice: Identifiable {
    let id = UUID()
    let message: String
    let entries: [Entry]
}

/// Settings, in UserDefaults. Views use @AppStorage with the same keys.
enum Prefs {
    static let carryOverKey = "carryOver"
    static let showCountKey = "showCountInMenuBar"
    static let hotKeyKey = "globalHotKey"

    static var carryOver: Bool { UserDefaults.standard.object(forKey: carryOverKey) as? Bool ?? true }
    static var showCount: Bool { UserDefaults.standard.object(forKey: showCountKey) as? Bool ?? true }
    static var hotKey: Bool { UserDefaults.standard.object(forKey: hotKeyKey) as? Bool ?? true }
}

/// Where the data lives: ~/Library/Application Support/TwodayNote/notes.json
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "TwodayNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "notes.json")
    }

    static func load() -> Notebook {
        guard let data = try? Data(contentsOf: url) else { return Notebook() }
        do {
            return try decoder.decode(Notebook.self, from: data)
        } catch {
            // Keep the unreadable file next to the new one instead of losing it.
            let backup = url.deletingPathExtension().appendingPathExtension("broken-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: backup)
            print("Could not read \(url.path), saved a copy at \(backup.path): \(error)")
            return Notebook()
        }
    }

    static func save(_ book: Notebook) {
        do {
            try encoder.encode(book).write(to: url, options: .atomic)
        } catch {
            print("Could not save \(url.path): \(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
