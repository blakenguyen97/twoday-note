import Foundation

/// One block on one day, or on the Xem sau list: a task, a note, an idea,
/// or a heading.
public struct Entry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var kind: EntryKind
    public var isDone: Bool
    /// The start of the day the block belongs to.
    public var day: Date
    /// Position inside its day. Lower comes first.
    public var order: Double
    public var createdAt: Date
    public var doneAt: Date?
    /// The day an unfinished task first belonged to, before it carried over.
    public var carriedFrom: Date?
    /// Pasted images: file names in the store's image folder, in paste order.
    public var images: [String] {
        get { imageFiles ?? [] }
        set { imageFiles = newValue.isEmpty ? nil : newValue }
    }
    /// Optional, so notes saved before images existed still load.
    private var imageFiles: [String]?
    /// On the Xem sau list: kept for later, on no day, never carried over.
    /// `day` then keeps the day it was saved on.
    public var isLater: Bool {
        get { later ?? false }
        set { later = newValue ? true : nil }
    }
    /// Optional, so notes saved before Xem sau existed still load.
    private var later: Bool?
    /// A GitHub or YouTube link in the text, with what the site said about it.
    public var link: LinkPreview?

    public init(id: UUID = UUID(), text: String, kind: EntryKind, day: Date, order: Double,
                isDone: Bool = false, createdAt: Date = .now, images: [String] = [], isLater: Bool = false) {
        self.id = id
        self.text = text
        self.kind = kind
        self.day = Day.start(of: day)
        self.order = order
        self.isDone = isDone
        self.createdAt = createdAt
        self.images = images
        self.isLater = isLater
        link = kind == .heading ? nil : LinkRef.find(in: text).map(LinkPreview.init)
    }
}

extension EntryKind: Codable {}

/// Every block, and the rules that change them. The app keeps one Notebook
/// and saves it as JSON after each change.
public struct Notebook: Codable, Sendable {
    public var version = 1
    public var entries: [Entry] = []

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    // MARK: Reading

    public func entries(on day: Date) -> [Entry] {
        let start = Day.start(of: day)
        return sorted(entries.filter { !$0.isLater && $0.day == start })
    }

    /// The Xem sau list, in its own order.
    public var laterEntries: [Entry] {
        sorted(entries.filter(\.isLater))
    }

    private func sorted(_ list: [Entry]) -> [Entry] {
        list.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    public func counts(on day: Date) -> (remaining: Int, done: Int) {
        let tasks = entries(on: day).filter { $0.kind == .task }
        let done = tasks.filter(\.isDone).count
        return (tasks.count - done, done)
    }

    public func index(of id: UUID) -> Int? {
        entries.firstIndex { $0.id == id }
    }

    /// Every image file a block uses, link thumbnails too.
    public var imageNames: Set<String> {
        Set(entries.flatMap(\.files))
    }

    /// Blocks whose link the site has not answered for yet.
    public var uncheckedLinks: [Entry] {
        entries.filter { $0.link?.checked == false }
    }

    // MARK: Changing

    /// Adds what people typed, and any pasted images, to the top of `day`,
    /// or of the Xem sau list when `later` (then `day` is the day it was saved).
    /// People drag it where it belongs from there.
    /// Nil when there is neither text nor an image.
    @discardableResult
    public mutating func add(_ raw: String, defaultKind: EntryKind, day: Date, images: [String] = [], later: Bool = false) -> Entry? {
        guard let parsed = EntryInput.parse(raw, defaultKind: defaultKind, allowEmpty: !images.isEmpty) else { return nil }
        let list = later ? laterEntries : entries(on: day)
        var entry = Entry(text: parsed.text, kind: parsed.kind, day: day,
                          order: (list.first?.order ?? 1) - 1, images: images, isLater: later)
        if later { entry.order = addedLaterOrder(for: entry) }
        entries.append(entry)
        return entry
    }

    /// Where a new block lands on Xem sau: a link at the top of its site's
    /// section, a heading named after a site at the end with the other
    /// sections, anything else at the top.
    private mutating func addedLaterOrder(for entry: Entry) -> Double {
        if entry.kind != .heading, let site = entry.link?.site { return orderUnderHeading(site, day: entry.day) }
        let list = laterEntries
        if entry.kind == .heading, LinkSite.allCases.contains(where: { Self.matches(entry.text, $0.heading) }) {
            return (list.last?.order ?? -1) + 1
        }
        return (list.first?.order ?? 1) - 1
    }

    /// Where a block moved to Xem sau lands: a link under its site's heading,
    /// anything else above the GitHub and YouTube sections at the end, or
    /// at the end when there are none.
    private mutating func laterOrder(for entry: Entry) -> Double {
        if entry.kind != .heading, let site = entry.link?.site { return orderUnderHeading(site, day: entry.day) }
        let list = laterEntries.filter { $0.id != entry.id }
        let end = (list.last?.order ?? -1) + 1
        if entry.kind == .heading, LinkSite.allCases.contains(where: { Self.matches(entry.text, $0.heading) }) { return end }
        // The run of site sections at the end of the list.
        var first: Int?
        for i in list.indices.reversed() where list[i].kind == .heading {
            guard LinkSite.allCases.contains(where: { Self.matches(list[i].text, $0.heading) }) else { break }
            first = i
        }
        guard let first else { return end }
        return first == 0 ? list[0].order - 1 : (list[first - 1].order + list[first].order) / 2
    }

    /// On Xem sau, a GitHub or YouTube link goes at the top of the section
    /// under its site's heading. Adds the heading at the end of the list
    /// when there is none. Returns the order for the new block.
    private mutating func orderUnderHeading(_ site: LinkSite, day: Date) -> Double {
        let list = laterEntries
        guard let top = list.firstIndex(where: { $0.kind == .heading && Self.matches($0.text, site.heading) }) else {
            let heading = Entry(text: site.heading, kind: .heading, day: day,
                                order: (list.last?.order ?? -1) + 1, isLater: true)
            entries.append(heading)
            return heading.order + 1
        }
        // Right under the heading, above the section's other links.
        guard top + 1 < list.count else { return list[top].order + 1 }
        return (list[top].order + list[top + 1].order) / 2
    }

    private static func matches(_ text: String, _ heading: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).compare(heading, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Saves what the site said about a block's link. Ignored when the
    /// block is gone or its link changed meanwhile.
    @discardableResult
    public mutating func setPreview(_ preview: LinkPreview, for id: UUID) -> Bool {
        guard let i = index(of: id), entries[i].link?.url == preview.url else { return false }
        entries[i].link = preview
        return true
    }

    /// Checks or unchecks a task. Finishing a task drops its images; then
    /// this returns the task as it was, so the app can offer Undo.
    @discardableResult
    public mutating func toggleDone(_ id: UUID, now: Date = .now) -> Entry? {
        guard let i = index(of: id), entries[i].kind == .task else { return nil }
        let before = entries[i]
        entries[i].isDone.toggle()
        entries[i].doneAt = entries[i].isDone ? now : nil
        guard entries[i].isDone, !entries[i].images.isEmpty else { return nil }
        entries[i].images = []
        return before
    }

    /// Adds pasted images to the end of a block's images.
    public mutating func attach(_ names: [String], to id: UUID) {
        guard let i = index(of: id), !names.isEmpty else { return }
        entries[i].images += names.filter { !entries[i].images.contains($0) }
    }

    /// Takes one image off a block and returns the block as it was, for Undo.
    public mutating func detach(_ name: String, from id: UUID) -> Entry? {
        guard let i = index(of: id), entries[i].images.contains(name) else { return nil }
        let before = entries[i]
        entries[i].images.removeAll { $0 == name }
        return before
    }

    public mutating func setKind(_ id: UUID, _ kind: EntryKind) {
        guard let i = index(of: id) else { return }
        entries[i].kind = kind
        // Headings are plain titles: no link card.
        if kind == .heading {
            entries[i].link = nil
        } else if entries[i].link == nil {
            entries[i].link = LinkRef.find(in: entries[i].text).map(LinkPreview.init)
        }
        if kind != .task {
            entries[i].isDone = false
            entries[i].doneAt = nil
        }
    }

    /// Moves a block to the end of another day, also from Xem sau.
    public mutating func move(_ id: UUID, to day: Date) {
        let start = Day.start(of: day)
        guard let i = index(of: id), entries[i].isLater || entries[i].day != start else { return }
        entries[i].order = (entries(on: start).last?.order ?? -1) + 1
        entries[i].day = start
        entries[i].isLater = false
        entries[i].carriedFrom = nil
    }

    /// Moves a block from its day to the end of the Xem sau list.
    public mutating func moveToLater(_ id: UUID) {
        guard let i = index(of: id), !entries[i].isLater else { return }
        let order = laterOrder(for: entries[i])
        guard let i = index(of: id) else { return }
        entries[i].order = order
        entries[i].isLater = true
        entries[i].carriedFrom = nil
    }

    /// Reorders the blocks of one day, like List's onMove.
    public mutating func reorder(on day: Date, from source: IndexSet, to destination: Int) {
        reorder(entries(on: day), from: source, to: destination)
    }

    /// Reorders the Xem sau list, like List's onMove.
    public mutating func reorderLater(from source: IndexSet, to destination: Int) {
        reorder(laterEntries, from: source, to: destination)
    }

    private mutating func reorder(_ list: [Entry], from source: IndexSet, to destination: Int) {
        var list = list
        let moving = source.map { list[$0] }
        for offset in source.sorted(by: >) { list.remove(at: offset) }
        let target = destination - source.filter { $0 < destination }.count
        list.insert(contentsOf: moving, at: max(0, min(target, list.count)))
        for (position, entry) in list.enumerated() {
            if let i = index(of: entry.id) { entries[i].order = Double(position) }
        }
    }

    /// Tidies the text after editing. Removes the block when no text and no
    /// image is left and returns it, so the app can offer Undo.
    public mutating func commitText(_ id: UUID) -> Entry? {
        guard let i = index(of: id) else { return nil }
        if let clean = EntryText.clean(entries[i].text) {
            entries[i].text = clean
            // A link added, changed, or taken out while editing.
            let ref = entries[i].kind == .heading ? nil : LinkRef.find(in: clean)
            if ref?.url != entries[i].link?.url { entries[i].link = ref.map(LinkPreview.init) }
            return nil
        }
        guard entries[i].images.isEmpty else {
            entries[i].text = ""
            return nil
        }
        return entries.remove(at: i)
    }

    @discardableResult
    public mutating func remove(_ ids: Set<UUID>) -> [Entry] {
        let removed = entries.filter { ids.contains($0.id) }
        entries.removeAll { ids.contains($0.id) }
        return removed
    }

    /// Puts blocks back as they were (Undo): removed ones return, changed
    /// ones get their old state back.
    public mutating func restore(_ saved: [Entry]) {
        for entry in saved {
            if let i = index(of: entry.id) { entries[i] = entry } else { entries.append(entry) }
        }
    }

    /// Moves unfinished tasks from earlier days to the top of today, oldest
    /// first. Returns how many moved.
    @discardableResult
    public mutating func rollOver(today: Date = .now) -> Int {
        let start = Day.start(of: today)
        let carried = entries.indices
            .filter { !entries[$0].isLater && Day.shouldCarry(kind: entries[$0].kind, isDone: entries[$0].isDone, day: entries[$0].day, today: start) }
            .sorted { (entries[$0].day, entries[$0].order) < (entries[$1].day, entries[$1].order) }
        guard !carried.isEmpty else { return 0 }
        let top = entries(on: start).first?.order ?? 0
        for (position, i) in carried.enumerated() {
            entries[i].carriedFrom = entries[i].carriedFrom ?? entries[i].day
            entries[i].day = start
            entries[i].order = top - Double(carried.count - position)
        }
        return carried.count
    }
}
