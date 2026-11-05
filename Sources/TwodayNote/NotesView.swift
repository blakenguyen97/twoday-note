import AppKit
import SwiftUI
import TwodayNoteKit

/// The popover: a date header, two day tabs and Xem sau, the add field,
/// the tab's blocks, and the Focus timer at the bottom. A quick-capture panel, so the
/// add field takes focus.
struct NotesView: View {
    @Environment(AppModel.self) private var model

    // Taller by the header's breathing room, so as many blocks fit.
    static let size = CGSize(width: 360, height: 584)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
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
        .padding(.top, Space.xl)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background { DayShortcuts() }
        .overlay {
            if let viewer = model.viewer {
                ImageViewerView(viewer: viewer)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: model.viewer)
        .overlay {
            if model.showsGuide {
                GuideView()
                    .transition(.opacity)
            }
        }
        .animation(Motion.change, value: model.showsGuide)
        .onExitCommand {
            if model.showsGuide {
                model.closeGuide()
            } else if model.viewer != nil {
                model.viewer = nil
            } else {
                AppDelegate.shared.closePopover()
            }
        }
        .gridArea("popover", inset: Space.lg)
    }
}

// MARK: Header

private struct DayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let counts = model.book.counts(on: model.selectedDay)
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .center) {
                Lockup()
                Spacer()
                MoreMenu(hasDone: model.visible.contains(where: \.isDone))
            }
            // The brand stands apart from the day below it.
            .padding(.bottom, Space.xs)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(model.isLater ? L("Xem sau") : Day.long(model.selectedDay))
                    .font(.title3.weight(.semibold))
                Text(model.isLater ? Progress.later(count: model.visible.count { $0.kind != .heading })
                                   : Progress.summary(remaining: counts.remaining, done: counts.done))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Picker(L("Ngày"), selection: $model.dayOffset) {
                ForEach(0...AppModel.laterTab, id: \.self) { offset in
                    Text(model.label(offset: offset)).tag(offset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

/// The TwodayNote logo and name (the lockup in Brand/), light or dark to
/// match the popover.
/// Text stands in when the SVGs are missing (a bare `swift run`).
private struct Lockup: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let image = Brand.lockup(dark: scheme == .dark) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                // Taller than a text line: the name keeps its size beside the logo.
                .frame(height: Space.section)
                .accessibilityLabel("TwodayNote")
        } else {
            Text("TwodayNote").font(.headline)
        }
    }
}

enum Brand {
    private static let light = load("TwodayNote-lockup-light")
    private static let dark = load("TwodayNote-lockup-dark")

    static func lockup(dark isDark: Bool) -> NSImage? { isDark ? dark : light }

    private static func load(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "svg").flatMap(NSImage.init(contentsOf:))
    }
}

private struct MoreMenu: View {
    @Environment(AppModel.self) private var model
    let hasDone: Bool

    private var updater = Updater.shared

    init(hasDone: Bool) {
        self.hasDone = hasDone
    }

    var body: some View {
        Menu {
            if let release = updater.release {
                // A newer TwodayNote on GitHub (Updater.swift).
                Button(updater.isAvailable ? L("Cập nhật lên bản {}", release.version?.description ?? release.tag)
                                           : L("Đang cập nhật…"),
                       systemImage: "arrow.down.circle") { updater.install() }
                    .disabled(!updater.isAvailable)
                Divider()
            }
            Button(L("Xoá việc đã xong"), systemImage: "checkmark.circle.badge.xmark") { model.clearDone() }
                .disabled(!hasDone)
            Divider()
            Button(L("Hướng dẫn sử dụng"), systemImage: "questionmark.circle") { model.openGuide() }
            Button(L("Cài đặt…")) { AppDelegate.shared.showSettings(nil) }
            Button(L("Thoát TwodayNote")) { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                // As bright as the title, not the faded borderless gray.
                .foregroundStyle(.primary)
                // A dot while a newer version waits.
                .overlay(alignment: .topTrailing) {
                    if updater.release != nil {
                        Circle()
                            .fill(Palette.accent)
                            // A ring in the background color cuts it out of the symbol.
                            .overlay { Circle().stroke(.background, lineWidth: 2) }
                            .frame(width: Space.sm, height: Space.sm)
                    }
                }
                .contentShape(.rect)
        }
        .menuStyle(.button)
        // Plain draws the label as is; borderless repaints it gray.
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(updater.release == nil ? L("Thêm tuỳ chọn") : L("Thêm tuỳ chọn. Có bản mới"))
        .accessibilityLabel(updater.release == nil ? L("Thêm tuỳ chọn") : L("Thêm tuỳ chọn. Có bản mới"))
    }
}

// MARK: Add field

private struct AddField: View {
    @Environment(AppModel.self) private var model
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let text = State(initialValue: "")
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            field
            if !model.pendingImages.isEmpty {
                ImageStrip(names: model.pendingImages, entryID: nil)
            }
        }
    }

    private var field: some View {
        @Bindable var model = model
        let text = text.projectedValue
        return HStack(spacing: Space.sm) {
            Menu {
                Picker(L("Loại khối mới"), selection: $model.newKind) {
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
            .help(L("Loại khối mới. Gõ nhanh: “# ” tiêu đề, “- ” ghi chú, “* ” ý tưởng, “[] ” task. ⌘V dán ảnh"))
            .accessibilityLabel(L("Loại khối mới: {}", model.newKind.title))

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
        // Not under the guide: its arrow keys would move the cursor instead.
        .onChange(of: model.focusTick) { if !model.showsGuide { focused = true } }
        .onChange(of: focused) { _, now in if now { model.editingID = nil } }
        .onAppear { if !model.showsGuide { focused = true } }
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
            if entries.isEmpty, model.isLater {
                ContentUnavailableView {
                    Label(L("Chưa có gì để xem sau"), systemImage: "tray")
                } description: {
                    Text(L("Link, đoạn trích, ảnh chụp màn hình vô tình gặp.\nKhông có hạn, không tự dời sang hôm nay."))
                }
            } else if entries.isEmpty {
                ContentUnavailableView {
                    Label(model.dayOffset == 0 ? L("Hôm nay chưa có gì") : L("{} còn trống", model.label(offset: model.dayOffset)),
                          systemImage: model.dayOffset == 0 ? "sun.max" : "calendar")
                } description: {
                    Text(L("Gõ vào ô phía trên rồi nhấn Return.\nBắt đầu bằng # để tạo tiêu đề, - ghi chú, * ý tưởng."))
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
    /// A link block hides its text, which is only the link, until Sửa chữ.
    private let showsFieldState = State(initialValue: false)
    @FocusState private var editing: Bool

    init(entry: Entry) {
        self.entry = entry
        draftState = State(initialValue: entry.text)
    }

    private var draft: String {
        get { draftState.wrappedValue }
        nonmutating set { draftState.wrappedValue = newValue }
    }

    /// The text field shows unless the text is only the link the card shows.
    private var showsText: Bool {
        guard let link = entry.link else { return true }
        return entry.text != link.url || showsFieldState.wrappedValue || editing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let link = entry.link, link.site == .youtube, link.key != nil {
                VideoThumbnail(link: link) { model.openLink(entry) }
            }
            row
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
        .contextMenu { EntryMenu(entry: entry, editText: editAction) }
        .onChange(of: draft) { _, new in model.setText(entry.id, new) }
        .onChange(of: editing) { _, now in
            if now {
                model.editingID = entry.id
            } else {
                showsFieldState.wrappedValue = false
                if model.editingID == entry.id { model.editingID = nil }
                model.commitText(entry.id)
            }
        }
        .onChange(of: entry.text) { _, new in if !editing, draft != new { draft = new } }
    }

    private var editAction: (() -> Void)? {
        showsText ? nil : { editText() }
    }

    /// Sửa chữ on a link block: shows its text and puts the cursor there.
    private func editText() {
        showsFieldState.wrappedValue = true
        Task { editing = true }
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            leading
            content
            if let from = entry.carriedFrom, !entry.isDone {
                // Overdue: carried over from an earlier day, still not done.
                Label(Day.lateLabel(from: from, today: model.today), systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize()
                    .help(L("Quá hạn: chưa xong từ {}, tự chuyển sang hôm nay", Day.long(from)))
            }
            if entry.isLater, entry.kind != .heading {
                Text(Day.short(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help(L("Lưu ngày {}", Day.long(entry.createdAt)))
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch entry.kind {
        case .task:
            Toggle(L("Đã xong"), isOn: Binding(get: { entry.isDone }, set: { _ in model.toggleDone(entry.id) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
        case .note:
            // A link note shows its site: code for GitHub, a video for YouTube.
            Image(systemName: entry.link?.site.symbol ?? entry.kind.symbol)
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

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let link = entry.link {
                LinkInfo(link: link, isDone: entry.isDone) { model.openLink(entry) }
            }
            if showsText { text }
            if !entry.images.isEmpty {
                ImageStrip(names: entry.images, entryID: entry.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var text: some View {
        if entry.isDone {
            // A task that was only an image keeps a word, not an empty line.
            Text(entry.text.isEmpty ? L("Ảnh") : entry.text)
                .strikethrough()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(entry.images.isEmpty ? entry.kind.title : L("Thêm mô tả…"),
                      text: draftState.projectedValue, axis: .vertical)
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
    /// Shows a link block's hidden text for editing. Nil when it shows.
    let editText: (() -> Void)?

    var body: some View {
        if entry.link != nil {
            Button(L("Mở link"), systemImage: "arrow.up.forward.app") { model.openLink(entry) }
            Button(L("Sao chép link"), systemImage: "link") { model.copyLink(entry) }
            if let editText, !entry.isDone {
                Button(L("Sửa chữ"), systemImage: "pencil", action: editText)
            }
            Divider()
        }
        if entry.kind == .task {
            Button(entry.isDone ? L("Đánh dấu chưa xong") : L("Đánh dấu đã xong")) { model.toggleDone(entry.id) }
        }
        if !entry.isDone {
            Button(L("Dán ảnh"), systemImage: "photo.badge.plus") {
                if !model.pasteImages(into: entry.id) { NSSound.beep() }
            }
        }
        Menu(L("Chuyển thành")) {
            ForEach(EntryKind.allCases.filter { $0 != entry.kind }) { kind in
                Button(kind.title, systemImage: kind.symbol) { model.setKind(entry.id, kind) }
            }
        }
        Menu(L("Dời sang")) {
            ForEach((0..<AppModel.dayCount).filter { entry.isLater || Day.adding($0, to: model.today) != entry.day }, id: \.self) { offset in
                Button(model.label(offset: offset)) { model.move(entry.id, toOffset: offset) }
            }
            if !entry.isLater {
                Divider()
                Button(L("Xem sau"), systemImage: "tray") { model.moveToLater(entry.id) }
            }
        }
        Divider()
        Button(L("Xoá"), role: .destructive) { model.delete(entry.id) }
    }
}

// MARK: Images

/// Pasted images in a row of thumbnails. Click one to see it large.
/// `entryID` nil: the add field's images, waiting for Return.
private struct ImageStrip: View {
    @Environment(AppModel.self) private var model
    let names: [String]
    let entryID: UUID?

    static let side: CGFloat = 48

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                ForEach(names, id: \.self) { name in
                    thumbnail(name)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func thumbnail(_ name: String) -> some View {
        Button {
            model.viewer = ImageViewer(entryID: entryID, name: name)
        } label: {
            Group {
                if let image = ImageStore.thumbnail(name) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .background(.fill.tertiary)
            .clipShape(.rect(cornerRadius: Space.xs))
            .overlay {
                RoundedRectangle(cornerRadius: Space.xs).strokeBorder(.separator, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(L("Bấm để xem lớn"))
        .accessibilityLabel(L("Ảnh, bấm để xem lớn"))
        .contextMenu {
            Button(L("Xem lớn"), systemImage: "arrow.up.left.and.arrow.down.right") {
                model.viewer = ImageViewer(entryID: entryID, name: name)
            }
            Button(L("Sao chép ảnh"), systemImage: "doc.on.doc") { ImageStore.copy(name) }
            Divider()
            Button(L("Xoá ảnh"), systemImage: "trash", role: .destructive) { remove(name) }
        }
    }

    private func remove(_ name: String) {
        if let entryID { model.removeImage(name, from: entryID) } else { model.removePendingImage(name) }
    }
}

/// One image, large, over the whole popover. Esc closes it, arrows page
/// through the block's other images. Pinch, ⌃ + scroll, double click, or ⌘= ⌘- ⌘0 zoom;
/// zoomed in, drag or scroll to move around.
private struct ImageViewerView: View {
    @Environment(AppModel.self) private var model
    let viewer: ImageViewer
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let zoom = State(initialValue: ZoomControl())

    var body: some View {
        let names = model.viewerImages
        let index = names.firstIndex(of: viewer.name) ?? 0
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                iconButton(L("Đóng"), "xmark") { model.viewer = nil }
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: Space.sm)
                if names.count > 1 {
                    iconButton(L("Ảnh trước"), "chevron.left") { step(-1) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled(index == 0)
                    Text("\(index + 1) / \(names.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    iconButton(L("Ảnh sau"), "chevron.right") { step(1) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled(index == names.count - 1)
                }
                Spacer(minLength: Space.sm)
                iconButton(L("Mở bằng Xem trước"), "arrow.up.forward.app") {
                    if let name = model.viewer?.name { NSWorkspace.shared.open(ImageStore.url(name)) }
                }
                iconButton(L("Sao chép ảnh"), "doc.on.doc") { if let name = model.viewer?.name { ImageStore.copy(name) } }
                iconButton(L("Xoá ảnh"), "trash") { removeShown() }
            }
            .frame(height: Space.section)
            .padding([.horizontal, .top], Space.lg)
            .padding(.bottom, Space.sm)

            ZoomArea(name: viewer.name, control: zoom.wrappedValue)
                // A new image starts fitted.
                .id(viewer.name)

            ZoomBar(control: zoom.wrappedValue)
                .padding(.vertical, Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Content, not a floating control: a plain background, no glass.
        .background(.background)
        // Nothing types underneath while the image is open.
        .onAppear { AppDelegate.shared.popoverWindow?.makeFirstResponder(nil) }
        .onDisappear { model.focusTick += 1 }
    }

    // The actions read the model when they run: a keyboard shortcut can
    // keep the action from an earlier render, with an old index.

    private func step(_ delta: Int) {
        let names = model.viewerImages
        guard let name = model.viewer?.name, let index = names.firstIndex(of: name),
              names.indices.contains(index + delta) else { return }
        model.viewer?.name = names[index + delta]
    }

    /// Deletes the shown image and moves to the next one, if any.
    private func removeShown() {
        let names = model.viewerImages
        guard let viewer = model.viewer, let index = names.firstIndex(of: viewer.name) else { return }
        let name = names[index]
        let rest = names.filter { $0 != name }
        let next = rest.isEmpty ? nil : rest[min(index, rest.count - 1)]
        if let id = viewer.entryID { model.removeImage(name, from: id) } else { model.removePendingImage(name) }
        model.viewer = next.map { ImageViewer(entryID: viewer.entryID, name: $0) }
    }

    private func iconButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(title)
    }
}

/// The image itself, read from disk once per image.
private struct ZoomArea: View {
    let name: String
    let control: ZoomControl

    var body: some View {
        if let image = NSImage(contentsOf: ImageStore.url(name)) {
            ZoomableImage(image: image, control: control)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(L("Không mở được ảnh"), systemImage: "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// − 100 % + under the image. The percentage fits the image back in.
private struct ZoomBar: View {
    let control: ZoomControl

    var body: some View {
        HStack(spacing: Space.md) {
            Button(L("Thu nhỏ"), systemImage: "minus.magnifyingglass") { control.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(control.isFitted)
                .help(L("Thu nhỏ (⌘-)"))
            Button("\(control.percent) %") { control.fit() }
                .keyboardShortcut("0", modifiers: .command)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .disabled(control.isFitted)
                .help(L("Vừa khung (⌘0)"))
            Button(L("Phóng to"), systemImage: "plus.magnifyingglass") { control.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!control.canZoomIn)
                .help(L("Phóng to (⌘=), hoặc ⌃ + lăn chuột, hoặc nhấp đúp vào ảnh"))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(height: Space.xxl)
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
            Text(L("Tập trung"))
            Menu {
                Picker(L("Thời lượng"), selection: $minutes) {
                    ForEach(FocusClock.choices, id: \.self) { Text(L("{} phút", $0)).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: Space.xs) {
                    Text(L("{} phút", minutes))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .menuStyle(.button)
            // Plain draws the label as is; borderless repaints it gray.
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("Thời lượng một phiên tập trung"))
            .accessibilityLabel(L("Thời lượng: {} phút", minutes))
        case .running, .paused:
            Text(FocusClock.format(model.focus.remaining(now: now) ?? 0))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(model.focus.isPaused ? .secondary : .primary)
                .contentTransition(.numericText(countsDown: true))
            ProgressView(value: model.focus.progress(now: now))
                .progressViewStyle(.linear)
                .frame(width: 64)
                .accessibilityLabel(L("Tiến độ phiên tập trung"))
            if model.focus.isPaused {
                Text(L("Tạm dừng")).font(.caption).foregroundStyle(.secondary)
            }
        case .finished:
            Text(L("Hết giờ! Nghỉ chút nhé."))
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.focus.phase {
        case .idle:
            Button(L("Bắt đầu"), systemImage: "play.fill") { model.focus.start(minutes: minutes) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .running:
            iconButton(L("Tạm dừng"), "pause.fill") { model.focus.pause() }
            iconButton(L("Dừng"), "stop.fill") { model.focus.stop() }
        case .paused:
            iconButton(L("Tiếp tục"), "play.fill") { model.focus.resume() }
            iconButton(L("Dừng"), "stop.fill") { model.focus.stop() }
        case .finished:
            Button(L("Phiên mới"), systemImage: "arrow.clockwise") { model.focus.start(minutes: minutes) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            iconButton(L("Đóng"), "xmark") { model.focus.stop() }
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
                Button(L("Hoàn tác")) { model.undoRemoval() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.accentText)
            }
            .font(.callout)
            .padding(.horizontal, Space.lg)
            .frame(height: 32)
            // A floating control over content: the one place for glass.
            .floatingBackground(in: Capsule())
            .padding(Space.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: undo.id) {
                try? await Task.sleep(for: .seconds(6))
                if model.undo?.id == undo.id { model.undo = nil }
            }
        }
    }
}

/// ⌘1, ⌘2 pick the day, ⌘3 Xem sau. Invisible buttons, so the shortcuts work while
/// the popover is key.
private struct DayShortcuts: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            ForEach(0...AppModel.laterTab, id: \.self) { offset in
                Button(model.label(offset: offset)) { model.dayOffset = offset }
                    .keyboardShortcut(KeyEquivalent(Character("\(offset + 1)")), modifiers: .command)
                    .disabled(model.showsGuide)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
