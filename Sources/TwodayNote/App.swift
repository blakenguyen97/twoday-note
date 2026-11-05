import AppKit
import ServiceManagement
import SwiftUI
import TwodayNoteKit

// TwodayNote: a menu bar app. No Dock icon, no main window (LSUIElement).
//   TwodayNote                      the app
//   APP_STORE=<file> TwodayNote     use another notes file (tests, experiments)
//   APP_SNAPSHOT=<dir> TwodayNote   save a PNG of each day and Settings in light and dark, then quit
//   APP_SEED=1 TwodayNote           fill an empty /tmp store with sample blocks (tools/snap.sh)
//   TwodayNote --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> TwodayNote      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 TwodayNote           draw the 8 pt grid and the layout probes over the popover
//   APP_GUIDE=1 TwodayNote          open the guide at launch, as on first launch (with APP_STORE too)

@main
enum TwodayNoteMain {
    static func main() {
        // Before AppKit starts: it reads the design to use only once.
        LiquidGlass.applyAtLaunch()
        let app = NSApplication.shared
        app.delegate = AppDelegate.shared
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static let shared = AppDelegate()

    let model = AppModel()
    private var statusItem: NSStatusItem?
    let popover = NSPopover()
    private var hotKey: HotKey?
    private var settingsWindow: NSWindow?
    /// Hourly: lets the updater check GitHub once a day has passed.
    private var updateTimer: Timer?
    /// The number drawn in the menu bar icon, so it redraws only on change.
    private var shownCount = 0
    /// The language and mode last applied, so a Settings change is seen once.
    private var shownLang = Lang.current
    private var shownMode: AppearanceMode?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.make()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = StatusIcon.make(count: 0)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.toolTip = "TwodayNote (⌃⌥N)"
        statusItem = item

        let content = NotesView()
            .environment(model)
            .themed()
            .localized()
            .overlay { if GridOverlay.enabled { GridOverlay() } }
        let host = NSHostingController(rootView: content)
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        model.onChange = { [weak self] in self?.updateStatusTitle() }
        model.onFocusChange = { [weak self] in self?.focusChanged() }
        model.refreshDay()
        updateStatusTitle()
        applyPrefs()

        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged),
                                               name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)

        // First launch: the popover opens with the guide. Not for tests and snapshots.
        if !Prefs.guideSeen && !Store.isOverridden || ProcessInfo.processInfo.environment["APP_GUIDE"] == "1" {
            // After the menu bar has placed the icon, so the popover points at it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.showGuide(nil) }
        }

        // Updates: a few seconds after launch, then every hour and after sleep,
        // each time checking only when a day has passed (Updater.swift).
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { Updater.shared.checkIfDue() }
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { @Sendable _ in
            MainActor.assumeIsolated { Updater.shared.checkIfDue() }
        }
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
                                                          name: NSWorkspace.didWakeNotification, object: nil)

        SeedData.insertIfRequested(into: model)
        SelfTest.runIfRequested(model: model)
        Snapshot.runIfRequested(app: self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.flush()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }

    // MARK: Popover

    @objc func togglePopover(_ sender: Any?) {
        popover.isShown ? closePopover() : showPopover()
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        model.refreshDay()
        model.dayOffset = 0
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        model.focusTick += 1
    }

    /// ••• > Hướng dẫn sử dụng, and the first launch: the guide in the popover.
    @objc func showGuide(_ sender: Any?) {
        model.openGuide()
        if !popover.isShown { showPopover() }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    /// ⌘V: an image on the clipboard goes into the popover's blocks; text
    /// pastes into the focused field as usual.
    @objc func pasteNote(_ sender: Any?) {
        if NSApp.keyWindow === popoverWindow, model.viewer == nil, !model.showsGuide, model.pasteImages() { return }
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
    }

    var popoverWindow: NSWindow? { popover.contentViewController?.view.window }

    func popoverDidClose(_ notification: Notification) {
        model.undo = nil
        model.viewer = nil
        model.flush()
    }

    // MARK: Settings

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView().environment(model).themed().localized())
            host.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: host)
            window.title = L("Cài đặt TwodayNote")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        closePopover()
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    var settings: NSWindow? { settingsWindow }

    /// The text beside the menu bar icon, for the self-test.
    var statusTitle: String { statusItem?.button?.title ?? "" }

    // MARK: Menu bar title, preferences, day changes

    private func updateStatusTitle() {
        let remaining = model.todayCounts.remaining
        // The count sits inside the icon's front card; none when all is done.
        let shown = Prefs.showCount ? remaining : 0
        if shown != shownCount {
            shownCount = shown
            statusItem?.button?.image = StatusIcon.make(count: shown)
        }
        statusItem?.button?.setAccessibilityValue(Progress.summary(remaining: remaining, done: model.todayCounts.done))
        updateFocusTitle()
    }

    // MARK: Focus

    /// Ticks once a second while Focus runs, on the main run loop.
    private var ticker: Timer?

    private func focusChanged() {
        if model.focus.isRunning, ticker == nil {
            // Common modes: keeps ticking while a menu is open.
            let timer = Timer(timeInterval: 1, repeats: true) { @Sendable _ in
                MainActor.assumeIsolated { AppDelegate.shared.focusTick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else if !model.focus.isRunning {
            ticker?.invalidate()
            ticker = nil
        }
        updateFocusTitle()
    }

    func focusTick() {
        if model.focus.tick(), !Store.isOverridden {
            NSSound(named: "Glass")?.play()
        }
        updateFocusTitle()
    }

    /// The countdown beside the icon: "24:59", dimmed while paused, "Hết giờ" at the end.
    private func updateFocusTitle() {
        guard let button = statusItem?.button else { return }
        let text: String?
        if let remaining = model.focus.remaining() {
            text = FocusClock.format(remaining)
        } else {
            text = model.focus.isFinished ? L("Hết giờ") : nil
        }
        guard let text else {
            button.title = ""
            button.imagePosition = .imageOnly
            return
        }
        button.attributedTitle = NSAttributedString(string: " " + text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: model.focus.isPaused ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ])
        button.imagePosition = .imageLeading
    }

    @objc private func didWake() {
        Updater.shared.checkIfDue()
    }

    @objc private func dayChanged() {
        model.refreshDay()
        updateStatusTitle()
    }

    @objc private func prefsChanged() {
        applyPrefs()
    }

    private func applyPrefs() {
        if Lang.current != shownLang {
            shownLang = Lang.current
            NSApp.mainMenu = MainMenu.make()
            settingsWindow?.title = L("Cài đặt TwodayNote")
            // Redraws the icon, whose description has the count in words.
            shownCount = -1
        }
        // Snapshots set light and dark themselves.
        if Prefs.appearance != shownMode, ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil {
            shownMode = Prefs.appearance
            NSApp.appearance = Prefs.appearance.appearance
            popover.appearance = NSApp.appearance
        }
        updateStatusTitle()
        if Prefs.hotKey, hotKey == nil, !Store.isOverridden {
            // ⌃⌥N opens and closes the popover from any app.
            hotKey = HotKey(keyCode: HotKey.keyN, modifiers: HotKey.controlOption) { [weak self] in
                self?.togglePopover(nil)
            }
        } else if !Prefs.hotKey, let current = hotKey {
            current.unregister()
            hotKey = nil
        }
    }
}

extension View {
    /// Rebuilds the view in the new language when Settings changes it.
    func localized() -> some View {
        modifier(Localized())
    }
}

private struct Localized: ViewModifier {
    @AppStorage(Lang.key) private var language = Lang.vi.rawValue

    func body(content: Content) -> some View {
        content
            .id(language)
            .environment(\.locale, Lang.current.locale)
    }
}

/// The app menu is never visible (no Dock icon), but its shortcuts still
/// work while the popover is open: Edit gives text fields ⌘C, ⌘V, ⌘Z.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu(title: "TwodayNote")
        app.addItem(withTitle: L("Cài đặt…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: L("Thoát TwodayNote"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: app)

        let edit = NSMenu(title: L("Sửa"))
        edit.addItem(withTitle: L("Hoàn tác"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("Làm lại"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Cắt"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Sao chép"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        // Images or text: AppDelegate.pasteNote decides.
        edit.addItem(withTitle: L("Dán"), action: #selector(AppDelegate.pasteNote(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Chọn tất cả"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: edit)
        return main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}

/// Settings > Mở cùng macOS. Only works from the installed, signed app.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) throws {
        guard !Store.isOverridden else { return }
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
