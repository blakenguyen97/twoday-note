import Foundation

/// One block on one day: a task, a note, an idea, or a heading.
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

    public init(id: UUID = UUID(), text: String, kind: EntryKind, day: Date, order: Double,
                isDone: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.kind = kind
        self.day = Day.start(of: day)
        self.order = order
        self.isDone = isDone
        self.createdAt = createdAt
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
        return entries.filter { $0.day == start }.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    public func counts(on day: Date) -> (remaining: Int, done: Int) {
        let tasks = entries(on: day).filter { $0.kind == .task }
        let done = tasks.filter(\.isDone).count
        return (tasks.count - done, done)
    }

    public func index(of id: UUID) -> Int? {
        entries.firstIndex { $0.id == id }
    }

    // MARK: Changing

    /// Adds what people typed to the end of `day`. Nil when it is empty.
    @discardableResult
    public mutating func add(_ raw: String, defaultKind: EntryKind, day: Date) -> Entry? {
        guard let parsed = EntryInput.parse(raw, defaultKind: defaultKind) else { return nil }
        let entry = Entry(text: parsed.text, kind: parsed.kind, day: day,
                          order: (entries(on: day).last?.order ?? -1) + 1)
        entries.append(entry)
        return entry
    }

    public mutating func toggleDone(_ id: UUID, now: Date = .now) {
        guard let i = index(of: id), entries[i].kind == .task else { return }
        entries[i].isDone.toggle()
        entries[i].doneAt = entries[i].isDone ? now : nil
    }

    public mutating func setKind(_ id: UUID, _ kind: EntryKind) {
        guard let i = index(of: id) else { return }
        entries[i].kind = kind
        if kind != .task {
            entries[i].isDone = false
            entries[i].doneAt = nil
        }
    }

    /// Moves a block to the end of another day.
    public mutating func move(_ id: UUID, to day: Date) {
        let start = Day.start(of: day)
        guard let i = index(of: id), entries[i].day != start else { return }
        entries[i].order = (entries(on: start).last?.order ?? -1) + 1
        entries[i].day = start
        entries[i].carriedFrom = nil
    }

    /// Reorders the blocks of one day, like List's onMove.
    public mutating func reorder(on day: Date, from source: IndexSet, to destination: Int) {
        var list = entries(on: day)
        let moving = source.map { list[$0] }
        for offset in source.sorted(by: >) { list.remove(at: offset) }
        let target = destination - source.filter { $0 < destination }.count
        list.insert(contentsOf: moving, at: max(0, min(target, list.count)))
        for (position, entry) in list.enumerated() {
            if let i = index(of: entry.id) { entries[i].order = Double(position) }
        }
    }

    /// Tidies the text after editing. Removes the block when nothing is left
    /// and returns it, so the app can offer Undo.
    public mutating func commitText(_ id: UUID) -> Entry? {
        guard let i = index(of: id) else { return nil }
        if let clean = EntryText.clean(entries[i].text) {
            entries[i].text = clean
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

    /// Puts removed blocks back where they were (Undo).
    public mutating func restore(_ removed: [Entry]) {
        let present = Set(entries.map(\.id))
        entries.append(contentsOf: removed.filter { !present.contains($0.id) })
    }

    /// Moves unfinished tasks from earlier days to the top of today, oldest
    /// first. Returns how many moved.
    @discardableResult
    public mutating func rollOver(today: Date = .now) -> Int {
        let start = Day.start(of: today)
        let carried = entries.indices
            .filter { Day.shouldCarry(kind: entries[$0].kind, isDone: entries[$0].isDone, day: entries[$0].day, today: start) }
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
