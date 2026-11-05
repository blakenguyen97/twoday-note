import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/TwodayNote-test.json APP_SNAPSHOT=/tmp/shots ~/Applications/TwodayNote.app/Contents/MacOS/TwodayNote
/// opens the popover from the menu bar and writes day0-light.png, day0-dark.png
/// … for each day, later-light.png (Xem sau), image-light.png (the image viewer), guide0-light.png …
/// (each page of the guide), plus settings-light.png
/// and settings-dark.png, then quits.
/// Each PNG gets a <name>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=day0,settings limits the pages.
enum Snapshot {
    static func runIfRequested(app: AppDelegate) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        // No open/close animation, or a capture can catch the popover mid-fade.
        app.popover.animates = false
        Task {
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                // The popover follows the menu bar, not the app: set it directly.
                app.popover.appearance = NSApp.appearance
                for offset in 0..<AppModel.dayCount where only?.contains("day\(offset)") ?? true {
                    if !app.popover.isShown { app.showPopover() }
                    app.model.dayOffset = offset
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.popoverWindow, to: "\(dir)/day\(offset)-\(mode).png")
                }
                if only == nil || only?.contains("later") == true {
                    if !app.popover.isShown { app.showPopover() }
                    app.model.dayOffset = AppModel.laterTab
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.popoverWindow, to: "\(dir)/later-\(mode).png")
                }
                if only == nil || only?.contains("focus") == true {
                    // Today with a Focus session 4 minutes in.
                    if !app.popover.isShown { app.showPopover() }
                    app.model.dayOffset = 0
                    app.model.focus.start(minutes: 25, now: .now.addingTimeInterval(-4 * 60 - 12))
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.popoverWindow, to: "\(dir)/focus-\(mode).png")
                    app.model.focus.stop()
                }
                if only == nil || only?.contains("image") == true,
                   let entry = app.model.book.entries(on: app.model.today).first(where: { $0.images.count > 1 }) {
                    // Today with an idea's image open large.
                    if !app.popover.isShown { app.showPopover() }
                    app.model.dayOffset = 0
                    app.model.viewer = ImageViewer(entryID: entry.id, name: entry.images[0])
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.popoverWindow, to: "\(dir)/image-\(mode).png")
                    // The same image zoomed in.
                    ZoomScrollView.find(in: app.popoverWindow?.contentView)?.zoom(by: 3)
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.popoverWindow, to: "\(dir)/image-zoom-\(mode).png")
                    app.model.viewer = nil
                    // Let the viewer go, so the next one opens fitted.
                    try? await Task.sleep(for: .seconds(1))
                }
                if only == nil || only?.contains("guide") == true {
                    // Each page of the guide, its demo still at its poster step.
                    if !app.popover.isShown { app.showPopover() }
                    app.model.dayOffset = 0
                    app.model.openGuide()
                    for page in GuidePage.allCases {
                        app.model.guidePage = page.rawValue
                        try? await Task.sleep(for: .seconds(0.8))
                        capture(app.popoverWindow, to: "\(dir)/guide\(page.rawValue)-\(mode).png")
                    }
                    app.model.showsGuide = false
                    try? await Task.sleep(for: .seconds(0.4))
                }
                if only == nil || only?.contains("settings") == true {
                    app.showSettings(nil)
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(app.settings, to: "\(dir)/settings-\(mode).png")
                    app.settings?.close()
                }
            }
            print("SNAPSHOT done \(dir)")
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so materials and glass
    /// look as on screen. Needs Screen Recording permission for the app that
    /// started this one; without it, draws the view hierarchy instead.
    private static func capture(_ window: NSWindow?, to path: String) {
        guard let window else {
            print("SNAPSHOT no window for \(path)")
            return
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"),
                                window: window.contentView?.bounds.size ?? .zero)
        try? FileManager.default.removeItem(atPath: path)
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, glass is blank)")
        }
    }
}
