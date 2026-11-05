import AppKit
import Observation
import TwodayNoteKit

/// App-wide state the popover, the menu bar icon, and Settings share.
/// The data is one Notebook saved as JSON (Store.url) after each change.
@Observable
final class AppModel {
    private(set) var book: Notebook
    /// 0 today, 1 tomorrow, 2 the day after, `laterTab` the Xem sau list.
    var dayOffset = 0
    /// The kind a new block on a day gets when it has no prefix.
    var dayKind: EntryKind = .task
    /// The same on Xem sau, where most things are notes, not tasks.
    var laterKind: EntryKind = .note
    /// Bumped each time the popover opens, so the add field takes focus.
    var focusTick = 0
    /// The last removal, while its Undo is on screen. Image files the
    /// notice no longer covers are deleted when it changes.
    var undo: UndoNotice? {
        didSet { if undo?.id != oldValue?.id { pruneImages() } }
    }
    /// The block whose text is being edited: ⌘V puts images there.
    var editingID: UUID?
    /// Images pasted into the add field, waiting for Return.
    var pendingImages: [String] = []
    /// The image shown large over the popover.
    var viewer: ImageViewer?
    private(set) var today = Day.start(of: .now)

    /// The Focus countdown at the bottom of the popover.
    var focus = FocusClock() {
        didSet { if focus != oldValue { onFocusChange?() } }
    }

    /// Called after every change, for the menu bar count.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Called when Focus starts, pauses, resumes, stops, or finishes.
    @ObservationIgnored var onFocusChange: (() -> Void)?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    static let dayCount = 3
    /// The tab after the days: things kept for later, on no day.
    static let laterTab = dayCount

    var isLater: Bool { dayOffset == Self.laterTab }

    /// The kind a new block gets when it has no prefix, on this tab.
    var newKind: EntryKind {
        get { isLater ? laterKind : dayKind }
        set { if isLater { laterKind = newValue } else { dayKind = newValue } }
    }

    init() {
        book = Store.load()
        pruneImages()
    }

    var selectedDay: Date { Day.adding(dayOffset, to: today) }
    var visible: [Entry] { isLater ? book.laterEntries : book.entries(on: selectedDay) }
    func label(offset: Int) -> String {
        offset == Self.laterTab ? "Xem sau" : Day.label(offset: offset, today: today)
    }
    var todayCounts: (remaining: Int, done: Int) { book.counts(on: today) }

    // MARK: Changes

    func add(_ raw: String) -> Bool {
        guard book.add(raw, defaultKind: newKind, day: isLater ? today : selectedDay,
                       images: pendingImages, later: isLater) != nil else { return false }
        pendingImages = []
        changed()
        return true
    }

    /// Finishing a task deletes its images, with Undo.
    func toggleDone(_ id: UUID) {
        if let before = book.toggleDone(id) {
            undo = UndoNotice(message: "Đã xong, xoá \(before.images.count) ảnh", entries: [before])
        }
        changed()
    }

    // MARK: Images

    /// ⌘V with an image: adds it to the block being edited, to `id`, or
    /// else to the add field until Return. False when the pasteboard holds
    /// no image, so the paste goes to the text field as usual.
    func pasteImages(from pasteboard: NSPasteboard = .general, into id: UUID? = nil) -> Bool {
        guard let names = ImageStore.save(from: pasteboard) else { return false }
        let target = id ?? editingID
        if let target, let entry = book.entries.first(where: { $0.id == target }), !entry.isDone {
            book.attach(names, to: target)
            changed()
        } else {
            pendingImages += names
            focusTick += 1
        }
        return true
    }

    func removeImage(_ name: String, from id: UUID) {
        guard let before = book.detach(name, from: id) else { return }
        if viewer?.name == name { viewer = nil }
        undo = UndoNotice(message: "Đã xoá ảnh", entries: [before])
        changed()
    }

    func removePendingImage(_ name: String) {
        pendingImages.removeAll { $0 == name }
        if viewer?.name == name { viewer = nil }
        pruneImages()
    }

    /// The images the viewer pages through: its block's, or the pending ones.
    var viewerImages: [String] {
        guard let viewer else { return [] }
        guard let id = viewer.entryID else { return pendingImages }
        return book.entries.first { $0.id == id }?.images ?? []
    }

    /// Deletes image files that no block, pending paste, or Undo uses.
    private func pruneImages() {
        // The images of an unreadable notes file may still be wanted.
        guard !Store.loadFailed else { return }
        var keep = book.imageNames.union(pendingImages)
        keep.formUnion(undo?.entries.flatMap(\.images) ?? [])
        ImageStore.prune(keeping: keep)
    }

    func setKind(_ id: UUID, _ kind: EntryKind) {
        book.setKind(id, kind)
        changed()
    }

    func move(_ id: UUID, toOffset offset: Int) {
        book.move(id, to: Day.adding(offset, to: today))
        changed()
    }

    /// Xem sau: off every day, until moved back to one.
    func moveToLater(_ id: UUID) {
        book.moveToLater(id)
        changed()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        if isLater {
            book.reorderLater(from: source, to: destination)
        } else {
            book.reorder(on: selectedDay, from: source, to: destination)
        }
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
        undo = nil
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

/// The image shown large: one of a block's images, or a pending one (no block).
struct ImageViewer: Equatable {
    var entryID: UUID?
    var name: String
}

struct UndoNotice: Identifiable {
    let id = UUID()
    let message: String
    let entries: [Entry]
}

/// Settings, in UserDefaults. Views use @AppStorage with the same keys.
enum Prefs {
    static let focusMinutesKey = "focusMinutes"
    static let carryOverKey = "carryOver"
    static let showCountKey = "showCountInMenuBar"
    static let hotKeyKey = "globalHotKey"

    static var carryOver: Bool { UserDefaults.standard.object(forKey: carryOverKey) as? Bool ?? true }
    static var showCount: Bool { UserDefaults.standard.object(forKey: showCountKey) as? Bool ?? true }
    static var hotKey: Bool { UserDefaults.standard.object(forKey: hotKeyKey) as? Bool ?? true }
    static var focusMinutes: Int { UserDefaults.standard.object(forKey: focusMinutesKey) as? Int ?? 25 }
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

    /// True when the notes file existed but could not be read.
    private(set) static var loadFailed = false

    static func load() -> Notebook {
        guard let data = try? Data(contentsOf: url) else { return Notebook() }
        do {
            return try decoder.decode(Notebook.self, from: data)
        } catch {
            // Keep the unreadable file next to the new one instead of losing it.
            let backup = url.deletingPathExtension().appendingPathExtension("broken-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: backup)
            print("Could not read \(url.path), saved a copy at \(backup.path): \(error)")
            loadFailed = true
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
