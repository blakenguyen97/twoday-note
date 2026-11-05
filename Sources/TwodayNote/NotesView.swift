import AppKit
import SwiftUI
import TwodayNoteKit

/// The popover: a date header, three day tabs, the add field, the day's
/// blocks, and the Focus timer at the bottom. A quick-capture panel, so the
/// add field takes focus.
struct NotesView: View {
    @Environment(AppModel.self) private var model

    static let size = CGSize(width: 360, height: 560)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            DayHeader()
                .gridProbe("header", area: "popover")
                .padding(.horizontal, Space.lg)
            AddField()
                .gridProbe("add", area: "popover")
                .padding(.horizontal, Space.lg)
            EntryList()
                .overlay(alignment: .bottom) { UndoBar() }
                .animation(.snappy, value: model.undo?.id)
            VStack(spacing: 0) {
                Divider()
                FocusBar()
                    .padding(.horizontal, Space.lg)
            }
        }
        .padding(.top, Space.lg)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background { DayShortcuts() }
        .onExitCommand { AppDelegate.shared.closePopover() }
        .gridArea("popover", inset: Space.lg)
    }
}

// MARK: Header

private struct DayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let counts = model.book.counts(on: model.selectedDay)
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .center) {
                Wordmark()
                Spacer()
                MoreMenu(hasDone: counts.done > 0)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Day.long(model.selectedDay))
                    .font(.title3.weight(.semibold))
                Text(Progress.summary(remaining: counts.remaining, done: counts.done))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Picker("Ngày", selection: $model.dayOffset) {
                ForEach(0..<AppModel.dayCount, id: \.self) { offset in
                    Text(model.label(offset: offset)).tag(offset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

/// The TwodayNote wordmark from Brand/, light or dark to match the popover.
/// Text stands in when the SVGs are missing (a bare `swift run`).
private struct Wordmark: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let image = Brand.wordmark(dark: scheme == .dark) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: Space.xxl)
                .accessibilityLabel("TwodayNote")
        } else {
            Text("TwodayNote").font(.headline)
        }
    }
}

enum Brand {
    private static let light = load("TwodayNote-wordmark-light")
    private static let dark = load("TwodayNote-wordmark-dark")

    static func wordmark(dark isDark: Bool) -> NSImage? { isDark ? dark : light }

    private static func load(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "svg").flatMap(NSImage.init(contentsOf:))
    }
}

private struct MoreMenu: View {
    @Environment(AppModel.self) private var model
    let hasDone: Bool

    var body: some View {
        Menu {
            Button("Xoá việc đã xong", systemImage: "checkmark.circle.badge.xmark") { model.clearDone() }
                .disabled(!hasDone)
            Divider()
            Button("Cài đặt…") { AppDelegate.shared.showSettings(nil) }
            Button("Thoát TwodayNote") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Thêm tuỳ chọn")
        .accessibilityLabel("Thêm tuỳ chọn")
    }
}

// MARK: Add field

private struct AddField: View {
    @Environment(AppModel.self) private var model
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let text = State(initialValue: "")
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        let text = text.projectedValue
        HStack(spacing: Space.sm) {
            Menu {
                Picker("Loại khối mới", selection: $model.newKind) {
                    ForEach(EntryKind.allCases) { kind in
                        Label("\(kind.title)   \(kind.prefix)", systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: model.newKind.symbol)
                    .foregroundStyle(Palette.accentText)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Loại khối mới. Gõ nhanh: “# ” tiêu đề, “- ” ghi chú, “* ” ý tưởng, “[] ” task")
            .accessibilityLabel("Loại khối mới: \(model.newKind.title)")

            TextField(model.newKind.placeholder, text: text)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit {
                    if model.add(text.wrappedValue) { text.wrappedValue = "" }
                    focused = true
                }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 32)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(focused ? AnyShapeStyle(Palette.accent.opacity(0.6)) : AnyShapeStyle(.separator), lineWidth: 1)
        }
        .onChange(of: model.focusTick) { focused = true }
        .onAppear { focused = true }
    }
}

// MARK: List

private struct EntryList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.visible
        List {
            // ForEach over values: rows find their entry by id, never by index.
            ForEach(entries) { entry in
                EntryRow(entry: entry)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // The plain List adds 8 pt on each side; 8 more lines the cards up with the header.
                    .listRowInsets(EdgeInsets(top: 2, leading: Space.sm, bottom: 2, trailing: Space.sm)) // grid: ok 4 pt gap between cards
            }
            .onMove { model.reorder(from: $0, to: $1) }
            // Room for the Undo bar over the last row.
            Color.clear.frame(height: Space.section)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label(model.dayOffset == 0 ? "Hôm nay chưa có gì" : "\(model.label(offset: model.dayOffset)) còn trống",
                          systemImage: model.dayOffset == 0 ? "sun.max" : "calendar")
                } description: {
                    Text("Gõ vào ô phía trên rồi nhấn Return.\nBắt đầu bằng # để tạo tiêu đề, - ghi chú, * ý tưởng.")
                }
            }
        }
    }
}

/// One block. Tasks have a checkbox, notes and ideas a symbol, headings
/// none. Click the text to edit it; Return or clicking away saves.
private struct EntryRow: View {
    @Environment(AppModel.self) private var model
    let entry: Entry
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let draftState: State<String>
    @FocusState private var editing: Bool

    init(entry: Entry) {
        self.entry = entry
        draftState = State(initialValue: entry.text)
    }

    private var draft: String {
        get { draftState.wrappedValue }
        nonmutating set { draftState.wrappedValue = newValue }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            leading
            content
            if let from = entry.carriedFrom, !entry.isDone {
                Text("từ \(Day.shortWeekday(from))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Chưa xong từ \(Day.long(from)), tự chuyển sang hôm nay")
            }
        }
        .padding(.horizontal, entry.kind == .heading ? Space.xs : Space.md)
        .padding(.top, entry.kind == .heading ? Space.md : Space.sm)
        .padding(.bottom, entry.kind == .heading ? Space.xs : Space.sm)
        .background {
            // The block card. Content, so no glass: a quiet fill like Notes.
            if entry.kind != .heading {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.fill.quaternary)
            }
        }
        .contentShape(.rect)
        .contextMenu { EntryMenu(entry: entry) }
        .onChange(of: draft) { _, new in model.setText(entry.id, new) }
        .onChange(of: editing) { _, now in if !now { model.commitText(entry.id) } }
        .onChange(of: entry.text) { _, new in if !editing, draft != new { draft = new } }
    }

    @ViewBuilder
    private var leading: some View {
        switch entry.kind {
        case .task:
            Toggle("Đã xong", isOn: Binding(get: { entry.isDone }, set: { _ in model.toggleDone(entry.id) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
        case .note:
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityLabel(entry.kind.title)
        case .idea:
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.orange)
                .frame(width: 16)
                .accessibilityLabel(entry.kind.title)
        case .heading:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.isDone {
            Text(entry.text)
                .strikethrough()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(entry.kind.title, text: draftState.projectedValue, axis: .vertical)
                .textFieldStyle(.plain)
                .font(entry.kind == .heading ? .title3.weight(.semibold) : .body)
                .focused($editing)
                .onSubmit { editing = false }
        }
    }
}

private struct EntryMenu: View {
    @Environment(AppModel.self) private var model
    let entry: Entry

    var body: some View {
        if entry.kind == .task {
            Button(entry.isDone ? "Đánh dấu chưa xong" : "Đánh dấu đã xong") { model.toggleDone(entry.id) }
        }
        Menu("Chuyển thành") {
            ForEach(EntryKind.allCases.filter { $0 != entry.kind }) { kind in
                Button(kind.title, systemImage: kind.symbol) { model.setKind(entry.id, kind) }
            }
        }
        Menu("Dời sang") {
            ForEach((0..<AppModel.dayCount).filter { Day.adding($0, to: model.today) != entry.day }, id: \.self) { offset in
                Button(model.label(offset: offset)) { model.move(entry.id, toOffset: offset) }
            }
        }
        Divider()
        Button("Xoá", role: .destructive) { model.delete(entry.id) }
    }
}

// MARK: Focus

/// A Pomodoro countdown. The same time runs beside the menu bar icon, so
/// the popover can stay closed while it counts.
private struct FocusBar: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.focusMinutesKey) private var minutes = 25

    var body: some View {
        // Redraws once a second; the time itself comes from the clock's end date.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: Space.sm) {
                Image(systemName: model.focus.isFinished ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(model.focus.phase == .idle ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.accentText))
                    .accessibilityHidden(true)
                status(now: context.date)
                Spacer(minLength: Space.sm)
                controls
            }
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private func status(now: Date) -> some View {
        switch model.focus.phase {
        case .idle:
            Text("Tập trung")
            Menu("\(minutes) phút") {
                Picker("Thời lượng", selection: $minutes) {
                    ForEach(FocusClock.choices, id: \.self) { Text("\($0) phút").tag($0) }
                }
                .pickerStyle(.inline)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Thời lượng một phiên tập trung")
        case .running, .paused:
            Text(FocusClock.format(model.focus.remaining(now: now) ?? 0))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(model.focus.isPaused ? .secondary : .primary)
                .contentTransition(.numericText(countsDown: true))
            ProgressView(value: model.focus.progress(now: now))
                .progressViewStyle(.linear)
                .frame(width: 64)
                .accessibilityLabel("Tiến độ phiên tập trung")
            if model.focus.isPaused {
                Text("Tạm dừng").font(.caption).foregroundStyle(.secondary)
            }
        case .finished:
            Text("Hết giờ! Nghỉ chút nhé.")
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.focus.phase {
        case .idle:
            Button("Bắt đầu", systemImage: "play.fill") { model.focus.start(minutes: minutes) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .running:
            iconButton("Tạm dừng", "pause.fill") { model.focus.pause() }
            iconButton("Dừng", "stop.fill") { model.focus.stop() }
        case .paused:
            iconButton("Tiếp tục", "play.fill") { model.focus.resume() }
            iconButton("Dừng", "stop.fill") { model.focus.stop() }
        case .finished:
            Button("Phiên mới", systemImage: "arrow.clockwise") { model.focus.start(minutes: minutes) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            iconButton("Đóng", "xmark") { model.focus.stop() }
        }
    }

    private func iconButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(title)
    }
}

// MARK: Undo and shortcuts

/// Removal is instant; this bar offers Undo for a few seconds.
private struct UndoBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let undo = model.undo {
            HStack(spacing: Space.sm) {
                Text(undo.message)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Space.sm)
                Button("Hoàn tác") { model.undoRemoval() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.accentText)
            }
            .font(.callout)
            .padding(.horizontal, Space.lg)
            .frame(height: 32)
            // A floating control over content: the one place for glass.
            .glassEffect(.regular, in: .capsule)
            .padding(Space.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: undo.id) {
                try? await Task.sleep(for: .seconds(6))
                if model.undo?.id == undo.id { model.undo = nil }
            }
        }
    }
}

/// ⌘1, ⌘2, ⌘3 pick the day. Invisible buttons, so the shortcuts work while
/// the popover is key.
private struct DayShortcuts: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            ForEach(0..<AppModel.dayCount, id: \.self) { offset in
                Button(model.label(offset: offset)) { model.dayOffset = offset }
                    .keyboardShortcut(KeyEquivalent(Character("\(offset + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
