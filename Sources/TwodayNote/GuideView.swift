import AppKit
import SwiftUI
import TwodayNoteKit

/// The walkthrough over the popover: pages that slide sideways, each with a
/// small live demo made of the app's own controls (the add field typing,
/// checkboxes ticking, the day tabs switching, the Focus clock counting).
/// Opens by itself on first launch, and from ••• > Hướng dẫn sử dụng.
/// Swipe, ← →, or Tiếp to page; Esc or the close button to leave.
struct GuideView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let page = model.guidePage ?? 0
        let last = GuidePage.allCases.count - 1
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Text(L("Hướng dẫn sử dụng"))
                    .font(.headline)
                Spacer(minLength: Space.sm)
                Button(L("Đóng hướng dẫn"), systemImage: "xmark") { model.closeGuide() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                    .help(L("Đóng hướng dẫn (Esc)"))
            }
            .frame(height: Space.section)
            .gridProbe("guide-header", area: "guide")
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(GuidePage.allCases) { item in
                        GuidePageView(page: item, active: item.rawValue == page)
                            .containerRelativeFrame(.horizontal)
                            .id(item.rawValue)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $model.guidePage)
            .scrollIndicators(.never)

            HStack(spacing: Space.sm) {
                Button(L("Trang trước"), systemImage: "chevron.left") { go(page - 1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(page == 0)
                    .help(L("Trang trước (←)"))
                Spacer(minLength: Space.sm)
                Button(page == last ? L("Bắt đầu dùng") : L("Tiếp")) {
                    if page == last { model.closeGuide() } else { go(page + 1) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .overlay { PageDots(count: last + 1, current: page) { go($0) } }
            .frame(height: Space.section)
            .gridProbe("guide-footer", area: "guide")
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Content over content, not a floating control: a plain background.
        .background(.background)
        .background { arrowKeys }
        .gridArea("guide", inset: Space.lg)
        // Nothing types into the add field underneath while the guide is open.
        .onAppear { AppDelegate.shared.popoverWindow?.makeFirstResponder(nil) }
    }

    /// The guide's page now, read when an action runs: a keyboard shortcut
    /// can keep the action from an earlier render.
    private var current: Int { model.guidePage ?? 0 }

    private func go(_ page: Int) {
        let target = min(max(page, 0), GuidePage.allCases.count - 1)
        withAnimation(Motion.page) { model.guidePage = target }
    }

    /// ← → page. Invisible buttons, like the day shortcuts.
    private var arrowKeys: some View {
        HStack {
            Button(L("Trang trước")) { go(current - 1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button(L("Trang sau")) { go(current + 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One dot per page; the current one is a wider accent capsule. Click a dot to go there.
private struct PageDots: View {
    let count: Int
    let current: Int
    let go: (Int) -> Void

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.tertiary))
                    .frame(width: index == current ? Space.lg : Space.sm, height: Space.sm)
                    .contentShape(.rect)
                    .onTapGesture { go(index) }
            }
        }
        .animation(Motion.change, value: current)
        .accessibilityElement()
        .accessibilityLabel(L("Trang {} trên {}", current + 1, count))
    }
}

// MARK: Pages

enum GuidePage: Int, CaseIterable, Identifiable {
    case welcome, typing, tabs, finish, menu, media, focus, ready

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: L("Chào mừng đến TwodayNote")
        case .typing: L("Gõ, rồi nhấn Return")
        case .tabs: L("Hôm nay, Ngày mai, Xem sau")
        case .finish: L("Xong việc, hay để mai")
        case .menu: L("Chuột phải để làm thêm")
        case .media: L("Dán ảnh, lưu link")
        case .focus: L("Tập trung từng phiên")
        case .ready: L("Thế là xong!")
        }
    }

    var text: String {
        switch self {
        case .welcome:
            L("Việc, ghi chú và ý tưởng cho hôm nay và ngày mai, ngay trên thanh menu. Bấm vào icon, hoặc nhấn ⌃⌥N ở bất kỳ app nào.")
        case .typing:
            L("Mỗi dòng thành một khối, mặc định là task. Gõ # ở đầu dòng để có tiêu đề, - ghi chú, * ý tưởng.")
        case .tabs:
            L("Ghi trước cho ngày mai, hoặc cất link, đoạn trích, ảnh chụp màn hình vào Xem sau để xem khi rảnh. Chuyển nhanh bằng ⌘1 ⌘2 ⌘3.")
        case .finish:
            L("Tick khi xong. Task chưa xong của hôm trước tự sang hôm nay, có dấu quá hạn màu cam. Xoá không hỏi lại, vì luôn có Hoàn tác.")
        case .menu:
            L("Đổi loại, dời sang ngày khác hay Xem sau, dán ảnh, hoặc xoá. Kéo thả để sắp xếp lại.")
        case .media:
            L("⌘V dán ảnh chụp màn hình vào khối đang sửa. Dán link GitHub hay YouTube vào Xem sau, nó tự vào nhóm của mình và hiện thành thẻ.")
        case .focus:
            L("Chọn 15, 25, 45 hay 60 phút rồi Bắt đầu. Thời gian còn lại chạy cạnh icon trên thanh menu, nên cứ đóng TwodayNote mà làm.")
        case .ready:
            L("Mở lại hướng dẫn này trong ••• > Hướng dẫn sử dụng. Đổi màu nhấn, ngôn ngữ và phím tắt trong Cài đặt (⌘,).")
        }
    }
}

/// A page: the live demo on top, the title and the words under it.
private struct GuidePageView: View {
    let page: GuidePage
    /// True while the page is on screen: only then does its demo play.
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Stage { demo }
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(page.title)
                    .font(.title2.weight(.semibold))
                Text(page.text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var demo: some View {
        switch page {
        case .welcome: WelcomeDemo(active: active)
        case .typing: TypingDemo(active: active)
        case .tabs: TabsDemo(active: active)
        case .finish: FinishDemo(active: active)
        case .menu: MenuDemo(active: active)
        case .media: MediaDemo(active: active)
        case .focus: FocusDemo(active: active)
        case .ready: ReadyDemo(active: active)
        }
    }
}

/// The demo's frame: a quiet, rounded panel of a fixed height, so the words
/// under it stay put from page to page. Look, don't touch.
private struct Stage<Content: View>: View {
    static var height: CGFloat { 296 }
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: Self.height)
            .background(.fill.quinary)
            .clipShape(.rect(cornerRadius: Space.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Space.md, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .allowsHitTesting(false)
            // Decoration: the title and text say the same in words.
            .accessibilityHidden(true)
    }
}

// MARK: Demo clock

/// Plays a demo's steps in a loop while its page is on screen: step i holds
/// for `beats[i]`, then the next one animates in. Reduce Motion, snapshots,
/// and pages off screen show the `poster` step, still.
private struct DemoClock<Content: View>: View {
    let beats: [Duration]
    let poster: Int
    let active: Bool
    let content: (Int) -> Content
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let step: State<Int>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(beats: [Duration], poster: Int, active: Bool, @ViewBuilder content: @escaping (Int) -> Content) {
        self.beats = beats
        self.poster = poster
        self.active = active
        self.content = content
        step = State(initialValue: poster)
    }

    var body: some View {
        content(step.wrappedValue)
            .task(id: active) {
                guard active, !reduceMotion, !Guide.isStill else {
                    step.wrappedValue = poster
                    return
                }
                var index = 0
                step.wrappedValue = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: beats[index])
                    guard !Task.isCancelled else { return }
                    index = (index + 1) % beats.count
                    withAnimation(Motion.change) { step.wrappedValue = index }
                }
            }
    }
}

enum Guide {
    /// Snapshots show each demo's poster step, so the shots are the same each run.
    /// APP_GUIDE_MOTION=1 lets the demos play, to catch them mid-motion.
    static let isStill = ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil
        && ProcessInfo.processInfo.environment["APP_GUIDE_MOTION"] != "1"
}

// MARK: Pieces

/// A key on the keyboard. Down: pressed in, in the accent color.
private struct Keycap: View {
    let label: String
    var down = false

    var body: some View {
        Text(label)
            .font(.callout.weight(.medium))
            .foregroundStyle(down ? AnyShapeStyle(Palette.onAccent) : AnyShapeStyle(.primary))
            .padding(.horizontal, Space.sm)
            .frame(minWidth: Space.xxl + Space.xs, minHeight: Space.xxl + Space.xs)
            .background(down ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.background),
                        in: RoundedRectangle(cornerRadius: Space.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .scaleEffect(down ? 0.9 : 1)
            .animation(Motion.press, value: down)
    }
}

/// A block as the popover draws it, from plain values.
private struct DemoBlock: Identifiable, Equatable {
    let id: Int
    var kind: EntryKind
    var text: String
    var done = false
    /// "từ T4": carried over from an earlier day.
    var late: String?
    /// The day a Xem sau block was saved.
    var saved: String?
    var images = 0
    var symbol: String?
}

private struct DemoRow: View {
    let block: DemoBlock
    var lifted = false

    /// A one-line card's height.
    static let height: CGFloat = 36

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            leading
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(block.text)
                    .font(block.kind == .heading ? .title3.weight(.semibold) : .body)
                    .strikethrough(block.done)
                    .foregroundStyle(block.done ? .secondary : .primary)
                    .lineLimit(1)
                if block.images > 0 {
                    HStack(spacing: Space.sm) {
                        ForEach(0..<block.images, id: \.self) { _ in
                            Screenshot()
                                .transition(.scale(scale: 0.4, anchor: .topLeading).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let late = block.late, !block.done {
                Label(late, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            if let saved = block.saved {
                Text(saved)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, block.kind == .heading ? Space.xs : Space.md)
        .padding(.top, block.kind == .heading ? Space.md : Space.sm)
        .padding(.bottom, block.kind == .heading ? Space.xs : Space.sm)
        // A known height, so a demo menu can hang right under the row.
        .frame(minHeight: block.kind == .heading ? 0 : Self.height)
        .background {
            if block.kind != .heading {
                RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                    .fill(.fill.quaternary)
            }
        }
        .overlay {
            if lifted {
                RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                    .strokeBorder(Palette.accent, lineWidth: 2)
            }
        }
        .scaleEffect(lifted ? 1.04 : 1)
    }

    @ViewBuilder
    private var leading: some View {
        switch block.kind {
        case .task:
            Toggle(L("Đã xong"), isOn: .constant(block.done))
                .toggleStyle(.checkbox)
                .labelsHidden()
        case .note:
            Image(systemName: block.symbol ?? block.kind.symbol)
                .foregroundStyle(.secondary)
                .frame(width: Space.lg)
        case .idea:
            Image(systemName: block.kind.symbol)
                .foregroundStyle(.orange)
                .frame(width: Space.lg)
        case .heading:
            EmptyView()
        }
    }
}

/// A tiny pasted screenshot: a note window, drawn, not an image file.
private struct Screenshot: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Capsule().fill(Palette.accent).frame(width: Space.lg, height: Space.xs)
            Capsule().fill(.tertiary).frame(width: Space.xxl, height: Space.xs)
            Capsule().fill(.tertiary).frame(width: Space.xl, height: Space.xs)
        }
        .frame(width: 48, height: 48)
        .background(.background)
        .clipShape(.rect(cornerRadius: Space.xs))
        .overlay { RoundedRectangle(cornerRadius: Space.xs).strokeBorder(.separator, lineWidth: 1) }
    }
}

/// A menu as macOS draws one, for the demos: rows, dividers, and the row
/// the pointer is on in the accent color.
private struct DemoMenu: View {
    struct Item {
        var title = ""
        var symbol: String?
        var submenu = false
        var divider = false
    }

    let items: [Item]
    var highlighted: Int?
    var width: CGFloat = 160

    static let rowHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                if item.divider {
                    Divider().padding(.vertical, Space.xs).padding(.horizontal, Space.sm)
                } else {
                    let on = index == highlighted
                    HStack(spacing: Space.sm) {
                        if let symbol = item.symbol {
                            Image(systemName: symbol).frame(width: Space.lg)
                        }
                        Text(item.title).lineLimit(1)
                        Spacer(minLength: Space.sm)
                        if item.submenu {
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(on ? AnyShapeStyle(Palette.onAccent) : AnyShapeStyle(.primary))
                    .padding(.horizontal, Space.sm)
                    .frame(height: Self.rowHeight)
                    .background(on ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: Space.xs, style: .continuous))
                }
            }
        }
        .padding(Space.xs)
        .frame(width: width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Space.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .shadow(color: .primary.opacity(0.15), radius: Space.sm, y: Space.xs)
        .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
    }
}

/// A slice of the menu bar: the TwodayNote icon, then the system's.
private struct MenuBarStrip: View {
    var count = 2
    /// The Focus time beside the icon.
    var title: String?
    var highlighted = false

    var body: some View {
        HStack(spacing: Space.md) {
            Spacer()
            HStack(spacing: Space.xs) {
                Image(nsImage: StatusIcon.make(count: count))
                    .renderingMode(.template)
                if let title {
                    Text(title)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .padding(.horizontal, Space.sm)
            .frame(height: Space.xl)
            .background(highlighted ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: Space.xs, style: .continuous))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text(verbatim: "9:41")
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, Space.md)
        .frame(height: Space.section - Space.xs)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: Demos

/// ⌃⌥N, key by key, then the popover drops from the menu bar icon.
private struct WelcomeDemo: View {
    @Environment(AppModel.self) private var model
    let active: Bool

    var body: some View {
        DemoClock(beats: [Motion.beat, Motion.keyDown, Motion.keyDown, Motion.beat, Motion.hold],
                  poster: 4, active: active) { step in
            let open = step == 4
            VStack(spacing: 0) {
                MenuBarStrip(count: 2, highlighted: open)
                ZStack(alignment: .top) {
                    HStack(spacing: Space.sm) {
                        Keycap(label: "⌃", down: step >= 1 && step <= 3)
                        Keycap(label: "⌥", down: step >= 2 && step <= 3)
                        Keycap(label: "N", down: step == 3)
                    }
                    .frame(maxHeight: .infinity)
                    .opacity(open ? 0 : 1)
                    if open {
                        miniPopover
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, Space.lg)
                            .padding(.top, Space.sm)
                            .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var miniPopover: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(verbatim: "TwodayNote")
                .font(.headline)
            Text(Day.long(model.today))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DemoRow(block: DemoBlock(id: 0, kind: .task, text: L("Gửi bản thiết kế")))
            DemoRow(block: DemoBlock(id: 1, kind: .idea, text: L("Quà sinh nhật mẹ")))
        }
        .padding(Space.md)
        .frame(width: 216)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Space.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Space.md, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .shadow(color: .primary.opacity(0.15), radius: Space.md, y: Space.xs)
    }
}

/// The add field types four lines, one per kind, and each Return turns the
/// line into a block. The kind symbol in the field follows the prefix.
private struct TypingDemo: View {
    let active: Bool
    // State as stored properties: the @State macro needs Xcode (see CLAUDE.md).
    private let typed = State(initialValue: "")
    private let blocks = State<[DemoBlock]>(initialValue: [])
    private let returnDown = State(initialValue: false)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(active: Bool) {
        self.active = active
    }

    private static var lines: [String] {
        [L("# Dự án mới"), L("Gửi bản thiết kế"), L("- Họp lúc 3 giờ chiều"), L("* Thêm chế độ tối")]
    }

    private static func block(_ index: Int) -> DemoBlock {
        let parsed = EntryInput.parse(lines[index], defaultKind: .task) ?? (.task, lines[index])
        return DemoBlock(id: index, kind: parsed.kind, text: parsed.text)
    }

    var body: some View {
        let text = typed.wrappedValue
        let kind = EntryInput.parse(text, defaultKind: .task, allowEmpty: true)?.kind ?? .task
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Image(systemName: kind.symbol)
                    .foregroundStyle(Palette.accentText)
                    .contentTransition(.symbolEffect(.replace))
                HStack(spacing: 0) {
                    Text(text.isEmpty ? kind.placeholder : text)
                        .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                    if !text.isEmpty { Caret() }
                }
                Spacer(minLength: Space.sm)
                Keycap(label: "↩", down: returnDown.wrappedValue)
            }
            .padding(.leading, Space.md)
            .padding(.trailing, Space.xs)
            .frame(height: Space.section + Space.xs)
            .background(.background, in: RoundedRectangle(cornerRadius: Space.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                    .strokeBorder(Palette.accent.opacity(0.6), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(blocks.wrappedValue) { block in
                    DemoRow(block: block)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
        }
        .padding(Space.lg)
        .task(id: active) { await play() }
    }

    private func play() async {
        guard active, !reduceMotion, !Guide.isStill else {
            typed.wrappedValue = ""
            blocks.wrappedValue = Self.lines.indices.map(Self.block)
            return
        }
        while !Task.isCancelled {
            typed.wrappedValue = ""
            withAnimation(Motion.change) { blocks.wrappedValue = [] }
            do {
                try await Task.sleep(for: Motion.beat)
                for index in Self.lines.indices {
                    for letter in Self.lines[index] {
                        typed.wrappedValue.append(letter)
                        try await Task.sleep(for: Motion.keystroke)
                    }
                    try await Task.sleep(for: Motion.keyDown)
                    returnDown.wrappedValue = true
                    try await Task.sleep(for: Motion.keyDown)
                    returnDown.wrappedValue = false
                    withAnimation(Motion.change) {
                        typed.wrappedValue = ""
                        blocks.wrappedValue.append(Self.block(index))
                    }
                    try await Task.sleep(for: Motion.beat)
                }
                try await Task.sleep(for: Motion.hold)
            } catch {
                return
            }
        }
    }
}

/// The text cursor, blinking.
private struct Caret: View {
    var body: some View {
        PhaseAnimator([true, false]) { on in
            Rectangle()
                .fill(Palette.accent)
                .frame(width: 2, height: Space.lg)
                .opacity(on ? 1 : 0)
        } animation: { _ in Motion.blink }
    }
}

/// The day tabs switch with ⌘2, ⌘3, ⌘1, and the list under them follows.
private struct TabsDemo: View {
    @Environment(AppModel.self) private var model
    let active: Bool

    var body: some View {
        // Even steps hold a tab; odd steps press the key for the next one.
        DemoClock(beats: [Motion.hold, Motion.keyDown, Motion.hold, Motion.keyDown, Motion.hold, Motion.keyDown],
                  poster: 2, active: active) { step in
            let tab = step / 2
            let pressing = step % 2 == 1 ? (tab + 1) % 3 : nil
            VStack(alignment: .leading, spacing: Space.md) {
                Text(tab == AppModel.laterTab ? L("Xem sau") : Day.long(Day.adding(tab, to: model.today)))
                    .font(.headline)
                    .contentTransition(.opacity)
                Picker(L("Ngày"), selection: .constant(tab)) {
                    ForEach(0...AppModel.laterTab, id: \.self) { Text(model.label(offset: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(blocks(tab)) { DemoRow(block: $0) }
                }
                .id(tab)
                .transition(.push(from: .trailing))
                Spacer(minLength: 0)
                HStack(spacing: Space.sm) {
                    ForEach(0...AppModel.laterTab, id: \.self) { offset in
                        Keycap(label: "⌘\(offset + 1)", down: pressing == offset)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Space.lg)
        }
    }

    private func blocks(_ tab: Int) -> [DemoBlock] {
        switch tab {
        case 0:
            [DemoBlock(id: 0, kind: .task, text: L("Gửi bản thiết kế")),
             DemoBlock(id: 1, kind: .task, text: L("Gọi cho Lan"))]
        case 1:
            [DemoBlock(id: 2, kind: .task, text: L("Đặt vé xe về quê")),
             DemoBlock(id: 3, kind: .idea, text: L("Quà sinh nhật mẹ"))]
        default:
            [DemoBlock(id: 4, kind: .note, text: "github.com/apple/swift", saved: Day.short(model.today),
                       symbol: LinkSite.github.symbol),
             DemoBlock(id: 5, kind: .note, text: L("Bài viết về thiết kế"), saved: Day.short(model.today))]
        }
    }
}

/// Two tasks tick off, one of them overdue; Xoá việc đã xong clears them,
/// and the Undo bar brings them back.
private struct FinishDemo: View {
    @Environment(AppModel.self) private var model
    let active: Bool

    var body: some View {
        DemoClock(beats: [Motion.beat, Motion.beat, Motion.beat, Motion.hold, Motion.beat],
                  poster: 1, active: active) { step in
            let cleared = step == 3
            VStack(alignment: .leading, spacing: Space.xs) {
                if !cleared {
                    DemoRow(block: DemoBlock(id: 0, kind: .task, text: L("Gửi bản thiết kế"), done: step >= 1))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    DemoRow(block: DemoBlock(id: 1, kind: .task, text: L("Trả lời email của Minh"), done: step >= 2,
                                             late: Day.lateLabel(from: Day.adding(-1, to: model.today), today: model.today)))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                DemoRow(block: DemoBlock(id: 2, kind: .note, text: L("Phòng họp tầng 3")))
                DemoRow(block: DemoBlock(id: 3, kind: .task, text: L("Mua sữa")))
                Spacer(minLength: 0)
            }
            .padding(Space.lg)
            .overlay(alignment: .bottom) {
                if cleared {
                    HStack(spacing: Space.sm) {
                        Text(L("Đã xoá {} việc đã xong", 2))
                            .lineLimit(1)
                        Spacer(minLength: Space.sm)
                        Text(L("Hoàn tác"))
                            .foregroundStyle(Palette.accentText)
                    }
                    .font(.callout)
                    .padding(.horizontal, Space.lg)
                    .frame(height: Space.section)
                    .floatingBackground(in: Capsule())
                    .padding(Space.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

/// Right-click a block, Chuyển thành > Ý tưởng, then drag another block to the top.
private struct MenuDemo: View {
    let active: Bool

    var body: some View {
        DemoClock(beats: Array(repeating: Motion.beat, count: 7) + [Motion.hold],
                  poster: 3, active: active) { step in
            let blocks = [
                DemoBlock(id: 0, kind: .task, text: L("Mua quà sinh nhật")),
                DemoBlock(id: 1, kind: step >= 4 ? .idea : .task, text: L("Ứng dụng đọc sách")),
                DemoBlock(id: 2, kind: .note, text: L("Ghi chú họp sáng")),
            ]
            let order = step >= 6 ? [2, 0, 1] : [0, 1, 2]
            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(order, id: \.self) { index in
                    DemoRow(block: blocks[index], lifted: index == 2 && (step == 5 || step == 6))
                        .overlay(alignment: .topLeading) {
                            if index == 1, (1...3).contains(step) { menus(step) }
                        }
                        .zIndex(index == 1 ? 1 : 0)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.lg)
        }
    }

    /// The block menu under the row, with Chuyển thành's submenu beside it.
    private func menus(_ step: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            DemoMenu(items: [
                .init(title: L("Dán ảnh"), symbol: "photo.badge.plus"),
                .init(title: L("Chuyển thành"), submenu: true),
                .init(title: L("Dời sang"), submenu: true),
                .init(divider: true),
                .init(title: L("Xoá")),
            ], highlighted: step >= 2 ? 1 : nil, width: 152)
            if step >= 2 {
                DemoMenu(items: [EntryKind.note, .idea, .heading].map { .init(title: $0.title, symbol: $0.symbol) },
                         highlighted: step == 3 ? 1 : nil, width: 120)
                    // Level with Chuyển thành, the second row.
                    .padding(.top, DemoMenu.rowHeight)
            }
        }
        // Hangs from the row's bottom edge.
        .padding(.top, DemoRow.height)
        .padding(.leading, Space.section)
    }
}

/// ⌘V drops a screenshot into a block; a GitHub link in Xem sau becomes a card.
private struct MediaDemo: View {
    let active: Bool

    var body: some View {
        DemoClock(beats: [Motion.beat, Motion.keyDown, Motion.beat, Motion.beat, Motion.hold],
                  poster: 4, active: active) { step in
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .top, spacing: Space.sm) {
                    DemoRow(block: DemoBlock(id: 0, kind: .idea, text: L("Màn hình chính mới"), images: step >= 2 ? 1 : 0))
                    Keycap(label: "⌘V", down: step == 1)
                }
                Text(L("Xem sau"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, Space.xs)
                if step == 3 {
                    DemoRow(block: DemoBlock(id: 1, kind: .note, text: Self.url))
                        .transition(.opacity)
                } else if step >= 4 {
                    DemoRow(block: DemoBlock(id: 2, kind: .heading, text: LinkSite.github.heading))
                        .transition(.opacity)
                    card
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(Space.lg)
        }
    }

    private static let url = "https://github.com/apple/swift"

    /// The card the popover shows for a repo, with the app's own LinkInfo.
    private var card: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Image(systemName: LinkSite.github.symbol)
                .foregroundStyle(.secondary)
                .frame(width: Space.lg)
            LinkInfo(link: Self.preview, isDone: false) {}
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: Space.sm, style: .continuous))
    }

    private static var preview: LinkPreview {
        // A fixed, valid link: parse always finds the repo.
        var preview = LinkPreview(LinkRef.parse(url)!)
        preview.title = "swift"
        preview.summary = L("Ngôn ngữ lập trình Swift")
        preview.stars = 69_000
        preview.language = "C++"
        preview.checked = true
        return preview
    }
}

/// Bắt đầu, the clock counts down beside the menu bar icon, time passes, Hết giờ.
private struct FocusDemo: View {
    let active: Bool

    /// Seconds left at each step: idle, pressed, started, ticking, later, finished.
    private static let left: [TimeInterval] = [1500, 1500, 1500, 1499, 1498, 750, 0]

    var body: some View {
        DemoClock(beats: [Motion.beat, Motion.keyDown, Motion.beat, Motion.beat, Motion.beat, Motion.hold, Motion.hold],
                  poster: 5, active: active) { step in
            let running = (2...5).contains(step)
            let finished = step == 6
            let left = Self.left[step]
            VStack(spacing: 0) {
                MenuBarStrip(count: 2, title: running ? FocusClock.format(left) : finished ? L("Hết giờ") : nil)
                Spacer(minLength: 0)
                HStack(spacing: Space.sm) {
                    Image(systemName: finished ? "checkmark.circle.fill" : "timer")
                        .foregroundStyle(running || finished ? AnyShapeStyle(Palette.accentText) : AnyShapeStyle(.secondary))
                        .contentTransition(.symbolEffect(.replace))
                    if running {
                        Text(FocusClock.format(left))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .contentTransition(.numericText(countsDown: true))
                        ProgressView(value: 1 - left / 1500)
                            .progressViewStyle(.linear)
                            .frame(width: 64)
                    } else if finished {
                        Text(L("Hết giờ! Nghỉ chút nhé."))
                            .lineLimit(1)
                    } else {
                        Text(L("Tập trung"))
                        Text(L("{} phút", 25))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Space.sm)
                    controls(step: step, running: running, finished: finished)
                }
                .padding(.horizontal, Space.md)
                .frame(height: 44)
                .background(.background, in: RoundedRectangle(cornerRadius: Space.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Space.sm, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                }
                .padding(.horizontal, Space.lg)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func controls(step: Int, running: Bool, finished: Bool) -> some View {
        if running {
            Image(systemName: "pause.fill").foregroundStyle(.secondary)
            Image(systemName: "stop.fill").foregroundStyle(.secondary)
        } else {
            Button(finished ? L("Phiên mới") : L("Bắt đầu"),
                   systemImage: finished ? "arrow.clockwise" : "play.fill") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .scaleEffect(step == 1 ? 0.9 : 1)
                .animation(Motion.press, value: step)
        }
    }
}

/// ••• opens, and the pointer lands on Hướng dẫn sử dụng.
private struct ReadyDemo: View {
    let active: Bool

    private static let button: CGFloat = 28

    var body: some View {
        DemoClock(beats: [Motion.beat, Motion.beat, Motion.hold], poster: 2, active: active) { step in
            let open = step >= 1
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: "TwodayNote")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: Self.button, height: Self.button)
                        .background(open ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear), in: .circle)
                        .overlay(alignment: .topTrailing) {
                            if open {
                                DemoMenu(items: [
                                    .init(title: L("Xoá việc đã xong"), symbol: "checkmark.circle.badge.xmark"),
                                    .init(divider: true),
                                    .init(title: L("Hướng dẫn sử dụng"), symbol: "questionmark.circle"),
                                    .init(title: L("Cài đặt…")),
                                    .init(title: L("Thoát TwodayNote")),
                                ], highlighted: step == 2 ? 2 : nil, width: 200)
                                // Hangs from the button, a little below it.
                                .padding(.top, Self.button + Space.xs)
                            }
                        }
                }
                .padding(Space.lg)
                // The menu hangs over the seal below.
                .zIndex(1)
                Spacer(minLength: 0)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.accent)
                    .symbolEffect(.bounce, value: step == 0)
                    .padding(.bottom, Space.section)
            }
        }
    }
}
