import AppKit
import Observation
import TwodayNoteKit

/// App-wide state the popover, the menu bar icon, and Settings share.
/// The data is one Notebook saved as JSON (Store.url) after each change.
@Observable
final class AppModel {
    private(set) var book: Notebook
    /// 0 today, 1 tomorrow, `laterTab` the Xem sau list.
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
    /// The walkthrough over the popover (GuideView): on first launch, and
    /// from ••• > Hướng dẫn sử dụng.
    var showsGuide = false
    /// The guide's page. Optional for ScrollView's scroll position.
    var guidePage: Int? = 0
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
    /// Links being looked up now, and when a lookup last failed.
    @ObservationIgnored private var fetching: Set<String> = []
    @ObservationIgnored private var failedAt: [String: Date] = [:]

    static let dayCount = 2
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
        offset == Self.laterTab ? L("Xem sau") : Day.label(offset: offset, today: today)
    }
    var todayCounts: (remaining: Int, done: Int) { book.counts(on: today) }

    // MARK: Guide

    /// Opens the walkthrough at its first page.
    func openGuide() {
        viewer = nil
        guidePage = 0
        showsGuide = true
    }

    /// Closes it for good: it no longer opens by itself at launch.
    func closeGuide() {
        showsGuide = false
        // Tests and snapshots leave the real setting alone.
        if !Store.isOverridden { UserDefaults.standard.set(true, forKey: Prefs.guideSeenKey) }
        focusTick += 1
    }

    // MARK: Changes

    func add(_ raw: String) -> Bool {
        guard book.add(raw, defaultKind: newKind, day: isLater ? today : selectedDay,
                       images: pendingImages, later: isLater) != nil else { return false }
        pendingImages = []
        changed()
        fetchLinks()
        return true
    }

    // MARK: Links

    /// Asks GitHub or YouTube about links it has not answered for yet.
    /// A failed lookup waits a few minutes before the next try.
    func fetchLinks(now: Date = .now) {
        // The self-test checks the rules offline.
        guard !SelfTest.requested else { return }
        for entry in book.uncheckedLinks {
            guard let preview = entry.link, !fetching.contains(preview.url),
                  failedAt[preview.url].map({ now.timeIntervalSince($0) > 300 }) ?? true else { continue }
            fetching.insert(preview.url)
            Task { [weak self] in
                let result = await LinkFetcher.fetch(preview)
                guard let self else { return }
                self.fetching.remove(preview.url)
                guard let result else {
                    self.failedAt[preview.url] = .now
                    return
                }
                self.failedAt[preview.url] = nil
                if self.book.setPreview(result, for: entry.id) { self.changed(countsChanged: false) }
            }
        }
    }

    /// Opens a block's link in the browser.
    func openLink(_ entry: Entry) {
        guard let url = entry.link.flatMap({ URL(string: $0.url) }) else { return }
        NSWorkspace.shared.open(url)
    }

    func copyLink(_ entry: Entry) {
        guard let link = entry.link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.url, forType: .string)
    }

    /// Finishing a task deletes its images, with Undo.
    func toggleDone(_ id: UUID) {
        if let before = book.toggleDone(id) {
            undo = UndoNotice(message: L("Đã xong, xoá {} ảnh", before.images.count), entries: [before])
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
        undo = UndoNotice(message: L("Đã xoá ảnh"), entries: [before])
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
        keep.formUnion(undo?.entries.flatMap(\.files) ?? [])
        ImageStore.prune(keeping: keep)
    }

    func setKind(_ id: UUID, _ kind: EntryKind) {
        book.setKind(id, kind)
        changed()
        fetchLinks()
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
            undo = UndoNotice(message: L("Đã xoá khối trống"), entries: [removed])
        }
        changed()
        fetchLinks()
    }

    func delete(_ id: UUID) {
        let removed = book.remove([id])
        guard let first = removed.first else { return }
        undo = UndoNotice(message: L("Đã xoá “{}”", first.text.prefix(24)), entries: removed)
        changed()
    }

    func clearDone() {
        let done = Set(visible.filter(\.isDone).map(\.id))
        guard !done.isEmpty else { return }
        let removed = book.remove(done)
        undo = UndoNotice(message: L("Đã xoá {} việc đã xong", removed.count), entries: removed)
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
        fetchLinks(now: now)
    }

    /// For the self-test and seed data only.
    func replace(_ notebook: Notebook) {
        book = notebook
        undo = nil
        pruneImages()
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
    static let hotKeyKey = "globalHotKey"
    static let appearanceKey = "appearance.mode"
    /// Set once the guide was finished or closed, so it opens by itself only once.
    static let guideSeenKey = "guide.seen"

    static var carryOver: Bool { UserDefaults.standard.object(forKey: carryOverKey) as? Bool ?? true }
    static var hotKey: Bool { UserDefaults.standard.object(forKey: hotKeyKey) as? Bool ?? true }
    static var guideSeen: Bool { UserDefaults.standard.bool(forKey: guideSeenKey) }
    static var focusMinutes: Int { UserDefaults.standard.object(forKey: focusMinutesKey) as? Int ?? 25 }
    static var appearance: AppearanceMode {
        UserDefaults.standard.string(forKey: appearanceKey).flatMap(AppearanceMode.init) ?? .system
    }
}

/// Settings > Giao diện > Chế độ: follow the Mac, or always light or dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L("Theo hệ thống")
        case .light: L("Sáng")
        case .dark: L("Tối")
        }
    }

    /// Nil follows the Mac.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
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
