import AppKit
import TwodayNoteKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/TwodayNote-self.json ~/Applications/TwodayNote.app/Contents/MacOS/TwodayNote --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        // The checks read the Vietnamese text, whatever Settings says.
        Lang.override = .vi
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            let app = AppDelegate.shared
            model.replace(Notebook())
            model.dayOffset = 0

            check("Return adds a task to today", model.add("Mua sữa") && model.visible.count == 1)
            check("“# ” makes a heading", model.add("# Buổi chiều") && model.visible.last?.kind == .heading)
            check("an empty line adds nothing", !model.add("   ") && model.visible.count == 2)

            let task = model.visible[0]
            model.toggleDone(task.id)
            check("the checkbox marks a task done", model.todayCounts == (0, 1))

            model.dayOffset = 1
            check("tomorrow starts empty", model.visible.isEmpty)
            _ = model.add("Đặt vé xe")
            let ticket = model.visible[0]
            model.move(ticket.id, toOffset: 0)
            model.dayOffset = 0
            check("Dời sang moves a block to another day", model.visible.contains { $0.id == ticket.id })

            model.delete(ticket.id)
            check("Xoá removes the block", !model.visible.contains { $0.id == ticket.id })
            model.undoRemoval()
            check("Hoàn tác brings it back", model.visible.contains { $0.id == ticket.id })

            model.clearDone()
            check("Xoá việc đã xong removes only done tasks", model.todayCounts == (1, 0))

            // Carry-over from yesterday.
            var book = model.book
            book.add("Việc hôm qua", defaultKind: .task, day: Day.adding(-1, to: .now))
            model.replace(book)
            model.refreshDay()
            check("unfinished tasks from yesterday carry over", model.visible.first?.text == "Việc hôm qua")

            // Xem sau.
            model.dayOffset = AppModel.laterTab
            check("Xem sau starts empty, with notes as the new kind", model.visible.isEmpty && model.newKind == .note)
            check("Return adds a note to Xem sau", model.add("Link bài viết hay") && model.visible.first?.kind == .note)
            let saved = model.visible[0]
            model.dayOffset = 0
            check("Xem sau keeps the day's kind apart", model.newKind == .task)
            check("a Xem sau block is on no day", !model.visible.contains { $0.id == saved.id })
            _ = model.add("Việc để sau")
            let later = model.visible.last!
            model.moveToLater(later.id)
            check("Dời sang > Xem sau takes a block off today", !model.visible.contains { $0.id == later.id })
            model.dayOffset = AppModel.laterTab
            check("…and puts it at the end of Xem sau", model.visible.map(\.id) == [saved.id, later.id])
            var later2 = model.book
            later2.rollOver(today: Day.adding(2, to: model.today))
            check("a task on Xem sau never carries over", later2.laterEntries.count == 2)
            model.move(later.id, toOffset: 0)
            model.dayOffset = 0
            check("Dời sang > Hôm nay brings it back", model.visible.contains { $0.id == later.id })
            model.delete(later.id)
            model.dayOffset = AppModel.laterTab
            model.delete(saved.id)
            model.undo = nil

            // Links on Xem sau go under GitHub and YouTube headings.
            _ = model.add("Đọc khi rảnh")
            check("a pasted GitHub link gets a GitHub heading",
                  model.add("https://github.com/github/spec-kit") && model.visible.map(\.text).suffix(2) == ["GitHub", "https://github.com/github/spec-kit"])
            check("…and a card with the repo name", model.visible.last?.link.map { $0.title == "spec-kit" && $0.repoPath == "github/spec-kit" } == true)
            check("a pasted YouTube link gets a YouTube heading",
                  model.add("https://youtu.be/dQw4w9WgXcQ") && model.visible.map(\.text).suffix(2) == ["YouTube", "https://youtu.be/dQw4w9WgXcQ"])
            _ = model.add("https://github.com/apple/swift")
            _ = model.add("Ghi chú thường")
            check("a second GitHub link joins its section, a plain note stays above",
                  model.visible.map(\.text) == ["Đọc khi rảnh", "Ghi chú thường", "GitHub", "https://github.com/github/spec-kit",
                                                "https://github.com/apple/swift", "YouTube", "https://youtu.be/dQw4w9WgXcQ"],
                  model.visible.map(\.text).joined(separator: " | "))
            let video = model.visible.last!
            var preview = video.link!
            preview.thumbnail = ImageStore.save(SampleImage.png(), ext: "png")
            preview.checked = true
            var filled = model.book
            filled.setPreview(preview, for: video.id)
            model.replace(filled)
            let thumb = ImageStore.url(preview.thumbnail ?? "")
            model.delete(video.id)
            check("a deleted video keeps its thumbnail while Hoàn tác shows", FileManager.default.fileExists(atPath: thumb.path))
            model.undoRemoval()
            check("Hoàn tác brings the video back with its thumbnail",
                  model.book.entries.first { $0.id == video.id }?.link?.thumbnail == preview.thumbnail)
            model.replace(Notebook())
            check("the thumbnail file goes with its block", !FileManager.default.fileExists(atPath: thumb.path))
            model.dayOffset = 0

            // Pasted images.
            let board = NSPasteboard(name: .init("TwodayNote-selftest"))
            board.clearContents()
            board.setData(SampleImage.png(), forType: .png)
            check("⌘V with an image waits in the add field", model.pasteImages(from: board) && model.pendingImages.count == 1)
            check("Return adds a block made of only an image", model.add("") && model.visible.last?.images.count == 1)
            let shot = model.visible.last!
            let file = ImageStore.url(shot.images[0])
            check("the image is saved as a file", FileManager.default.fileExists(atPath: file.path))
            model.editingID = shot.id
            check("⌘V while editing adds to that block", model.pasteImages(from: board) && model.book.entries.first { $0.id == shot.id }?.images.count == 2)
            model.editingID = nil
            let second = model.book.entries.first { $0.id == shot.id }!.images[1]
            model.removeImage(second, from: shot.id)
            model.undoRemoval()
            check("Xoá ảnh has Hoàn tác", model.book.entries.first { $0.id == shot.id }?.images.count == 2)
            board.clearContents()
            board.setString("chữ thường", forType: .string)
            check("⌘V with text pastes as text", !model.pasteImages(from: board))
            model.toggleDone(shot.id)
            check("finishing a task drops its images", model.book.entries.first { $0.id == shot.id }?.images.isEmpty == true)
            check("the files stay while Hoàn tác shows", FileManager.default.fileExists(atPath: file.path))
            model.undoRemoval()
            check("Hoàn tác gives the images back", model.book.entries.first { $0.id == shot.id }.map { !$0.isDone && $0.images.count == 2 } == true)
            model.toggleDone(shot.id)
            model.undo = nil
            check("the image files are deleted when Hoàn tác ends", !FileManager.default.fileExists(atPath: file.path))
            model.delete(shot.id)
            model.undo = nil

            model.flush()
            check("the notes file reloads the same", Store.load().entries == model.book.entries)

            app.showPopover()
            try? await Task.sleep(for: .seconds(0.5))
            check("the menu bar icon opens the popover", app.popover.isShown)
            let paste = NSApp.mainMenu?.item(withTitle: "Sửa")?.submenu?.item(withTitle: "Dán")
            check("⌘V in the popover reaches the image paste",
                  paste?.action.map { NSApp.target(forAction: $0, to: nil, from: paste) as AnyObject? === app } == true)
            for _ in 1...10 {
                app.closePopover()
                try? await Task.sleep(for: .seconds(0.05))
                app.showPopover()
                try? await Task.sleep(for: .seconds(0.05))
            }
            check("the popover opens and closes 10 times", app.popover.isShown)

            // The image viewer zooms and pans. The close from the loop above
            // lands late, and a transient popover closes when another app
            // takes focus: settle, then keep it open for these checks.
            try? await Task.sleep(for: .seconds(0.5))
            app.popover.behavior = .applicationDefined
            if !app.popover.isShown { app.showPopover() }
            board.clearContents()
            board.setData(SampleImage.png(), forType: .png)
            _ = model.pasteImages(from: board)
            _ = model.add("Ảnh để phóng to")
            let zoomed = model.visible.last!
            model.viewer = ImageViewer(entryID: zoomed.id, name: zoomed.images[0])
            try? await Task.sleep(for: .seconds(0.5))
            let zoomView = ZoomScrollView.find(in: app.popoverWindow?.contentView)
            check("a thumbnail opens the image fitted", zoomView?.isFitted == true && zoomView?.canPan == false)
            zoomView?.zoom(by: 3)
            try? await Task.sleep(for: .seconds(0.5))
            check("zooming in lets the image be dragged", zoomView?.isFitted == false && zoomView?.canPan == true)
            let before = zoomView?.contentView.bounds.origin
            zoomView?.pan(by: CGSize(width: 40, height: 0))
            check("dragging moves the image", zoomView?.contentView.bounds.origin != before)
            if let zoomView, let window = zoomView.window {
                let start = zoomView.magnification
                let center = window.convertPoint(toScreen: zoomView.convert(NSPoint(x: zoomView.bounds.midX, y: zoomView.bounds.midY), to: nil))
                @MainActor func controlScroll(_ lines: Int32) {
                    guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0) else { return }
                    cg.flags = .maskControl
                    cg.location = CGPoint(x: center.x, y: (NSScreen.screens.first?.frame.height ?? 0) - center.y)
                    if let event = NSEvent(cgEvent: cg) { zoomView.scrollWheel(with: event) }
                }
                controlScroll(3)
                let zoomedIn = zoomView.magnification
                controlScroll(-3)
                check("⌃ + scroll zooms in and out", zoomedIn > start && zoomView.magnification < zoomedIn,
                      "\(start) → \(zoomedIn) → \(zoomView.magnification)")
            } else {
                check("⌃ + scroll zooms in and out", false, "the viewer is not on screen")
            }
            zoomView?.fit()
            try? await Task.sleep(for: .seconds(0.5))
            check("⌘0 fits it back", zoomView?.isFitted == true && zoomView?.canPan == false)
            zoomView?.zoom(by: 3)
            model.viewer = nil
            try? await Task.sleep(for: .seconds(1))
            model.viewer = ImageViewer(entryID: zoomed.id, name: zoomed.images[0])
            try? await Task.sleep(for: .seconds(0.5))
            let reopened = ZoomScrollView.find(in: app.popoverWindow?.contentView)
            check("the image opens fitted again after closing zoomed", reopened !== zoomView && reopened?.isFitted == true,
                  "same view: \(reopened === zoomView), magnification \(reopened?.magnification ?? 0)")
            model.viewer = nil
            try? await Task.sleep(for: .seconds(0.5))

            // Paging through wide screenshots with ‹ ›, fitted and zoomed in.
            board.clearContents()
            board.setData(SampleImage.png(hue: 0.08, size: NSSize(width: 2880, height: 1200)), forType: .png)
            _ = model.pasteImages(from: board, into: zoomed.id)
            board.clearContents()
            board.setData(SampleImage.png(hue: 0.75, size: NSSize(width: 1200, height: 2400)), forType: .png)
            _ = model.pasteImages(from: board, into: zoomed.id)
            let pages = model.book.entries.first { $0.id == zoomed.id }!.images
            model.viewer = ImageViewer(entryID: zoomed.id, name: pages[2])
            try? await Task.sleep(for: .seconds(0.5))
            @MainActor func arrow(_ key: Int) {
                let character = String(Character(UnicodeScalar(key)!))
                if let window = app.popoverWindow,
                   let down = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.numericPad, .function],
                                               timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                               context: nil, characters: character, charactersIgnoringModifiers: character,
                                               isARepeat: false, keyCode: key == NSLeftArrowFunctionKey ? 123 : 124) {
                    window.makeKey()
                    // False at the first or last image, where the button is disabled.
                    _ = window.performKeyEquivalent(with: down)
                }
            }
            for round in 0..<3 {
                arrow(NSLeftArrowFunctionKey)
                try? await Task.sleep(for: .seconds(0.4))
                if round == 1 { ZoomScrollView.find(in: app.popoverWindow?.contentView)?.zoom(by: 4) }
                try? await Task.sleep(for: .seconds(0.4))
                arrow(NSLeftArrowFunctionKey)
                try? await Task.sleep(for: .seconds(0.4))
                arrow(NSRightArrowFunctionKey)
                try? await Task.sleep(for: .seconds(0.4))
            }
            check("← → page through wide images", model.viewer?.name == pages[1]
                  && ZoomScrollView.find(in: app.popoverWindow?.contentView)?.isFitted == true,
                  "showing \(model.viewer.map { pages.firstIndex(of: $0.name) ?? -1 } ?? -1)")
            model.viewer = nil

            // The guide: ••• > Hướng dẫn sử dụng, paged with ← →, closed with Đóng.
            model.guidePage = 5
            app.showGuide(nil)
            try? await Task.sleep(for: .seconds(0.6))
            check("Hướng dẫn sử dụng opens the guide at its first page", model.showsGuide && model.guidePage == 0)
            // The pages lay out before the arrow keys reach them.
            try? await Task.sleep(for: .seconds(1))
            arrow(NSRightArrowFunctionKey)
            try? await Task.sleep(for: .seconds(0.6))
            arrow(NSRightArrowFunctionKey)
            try? await Task.sleep(for: .seconds(0.6))
            arrow(NSLeftArrowFunctionKey)
            try? await Task.sleep(for: .seconds(0.6))
            check("→ and ← page through the guide", model.guidePage == 1, "page \(model.guidePage ?? -1)")
            model.closeGuide()
            check("closing the guide shows the notes again", !model.showsGuide)
            check("tests leave the guide's first-launch setting alone", UserDefaults.standard.object(forKey: Prefs.guideSeenKey) == nil
                  || Prefs.guideSeen)

            app.popover.behavior = .transient
            model.delete(zoomed.id)
            model.undo = nil
            app.closePopover()

            // Settings > Giao diện > Chế độ, and Ngôn ngữ.
            let defaults = UserDefaults.standard
            let savedMode = defaults.string(forKey: Prefs.appearanceKey)
            defaults.set(AppearanceMode.dark.rawValue, forKey: Prefs.appearanceKey)
            try? await Task.sleep(for: .seconds(0.2))
            check("Chế độ Tối makes the app dark", NSApp.appearance?.name == .darkAqua && app.popover.appearance?.name == .darkAqua)
            defaults.set(AppearanceMode.light.rawValue, forKey: Prefs.appearanceKey)
            try? await Task.sleep(for: .seconds(0.2))
            check("Chế độ Sáng makes it light", NSApp.appearance?.name == .aqua)
            defaults.set(savedMode, forKey: Prefs.appearanceKey)
            try? await Task.sleep(for: .seconds(0.2))
            check("Theo hệ thống follows the Mac again", savedMode != nil || NSApp.appearance == nil)
            check("macOS draws the design the Liquid Glass setting had at launch", LiquidGlass.isClassic == !LiquidGlass.isOn)
            Lang.override = .en
            check("English names the tabs in English", model.label(offset: AppModel.laterTab) == "Later"
                  && Progress.summary(remaining: 2, done: 1) == "2 to do · 1 done")
            Lang.override = .vi
            check("Tiếng Việt names them in Vietnamese", model.label(offset: AppModel.laterTab) == "Xem sau")

            // Updates: the rules, without the network.
            let updater = Updater.shared
            check("Settings shows the app's version", !Updater.versionText.isEmpty
                  && Updater.versionText.hasPrefix(Updater.version) && AppVersion(Updater.version) != nil, Updater.versionText)
            updater.checkIfDue()
            check("the daily check stays off the network in tests", updater.phase == .idle)
            updater.consider(Snapshot.sampleRelease)
            check("a newer release on GitHub is offered", updater.isAvailable
                  && (updater.release?.version).map { $0 > AppVersion(Updater.version)! } == true)
            let page = URL(string: "https://github.com/\(Updater.repo)")!
            updater.consider(Release(tag: "v\(Updater.version)", page: page,
                                     assets: [.init(name: "TwodayNote.dmg", url: page, size: 1)]))
            check("the same version is up to date", updater.phase == .upToDate)
            updater.reset()
            await checkInstall()

            // Focus.
            model.focus.start(minutes: 25)
            check("Bắt đầu shows the countdown in the menu bar", app.statusTitle.contains("25:00"), app.statusTitle)
            model.focus.pause()
            check("Tạm dừng keeps the time", model.focus.isPaused && app.statusTitle.contains("25:00"), app.statusTitle)
            model.focus.resume()
            check("Tiếp tục runs again", model.focus.isRunning)
            model.focus.start(minutes: 1, now: .now.addingTimeInterval(-61))
            app.focusTick()
            check("the end shows Hết giờ", model.focus.isFinished && app.statusTitle.contains("Hết giờ"), app.statusTitle)
            model.focus.stop()
            check("Dừng clears the menu bar", app.statusTitle.isEmpty, app.statusTitle)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// The whole install on copies in /tmp: a disk image with TwodayNote 9.9
    /// replaces a copy of this app; one that claims another version does not.
    private static func checkInstall() async {
        let root = URL(fileURLWithPath: "/tmp/TwodayNote-update-test", isDirectory: true)
        let files = FileManager.default
        try? files.removeItem(at: root)
        defer { try? files.removeItem(at: root) }
        let name = Bundle.main.bundleURL.lastPathComponent
        let installed = root.appending(path: "Applications").appending(path: name)
        let stage = root.appending(path: "stage", directoryHint: .isDirectory)
        let image = root.appending(path: "TwodayNote-9.9.dmg")
        do {
            try files.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Installer.run("/usr/bin/ditto", [Bundle.main.bundleURL.path, installed.path])
            let next = stage.appending(path: name)
            try Installer.run("/usr/bin/ditto", [Bundle.main.bundleURL.path, next.path])
            let plist = next.appending(path: "Contents/Info.plist").path
            try Installer.run("/usr/bin/plutil", ["-replace", "CFBundleShortVersionString", "-string", "9.9", plist])
            try Installer.run("/usr/bin/codesign", ["--force", "--sign", "-", next.path])
            try Installer.run("/usr/bin/hdiutil", ["create", "-quiet", "-volname", "TwodayNote", "-srcfolder", stage.path,
                                                   "-fs", "HFS+", "-format", "UDZO", image.path])
        } catch {
            check("an update installs in place", false, "setup: \(error.localizedDescription)")
            return
        }
        func version() -> String? {
            NSDictionary(contentsOf: installed.appending(path: "Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
        }
        let before = version()
        var refused = false
        do {
            try await Installer.install(from: image, version: AppVersion("9.8")!, over: installed)
        } catch UpdateError.wrongVersion {
            refused = true
        } catch {}
        check("a disk image with another version is refused", refused && version() == before)
        do {
            try await Installer.install(from: image, version: AppVersion("9.9")!, over: installed)
            // codesign, not Security: it already read this path's old signature in this process.
            let signed = (try? Installer.run("/usr/bin/codesign", ["--verify", "--strict", "--deep", installed.path])) != nil
            check("an update installs in place, still signed", version() == "9.9" && signed, version() ?? "none")
        } catch {
            check("an update installs in place", false, error.localizedDescription)
        }
        let mounts = (try? files.contentsOfDirectory(atPath: "/Volumes")) ?? []
        let leftover = (try? Installer.run("/usr/bin/hdiutil", ["info"]))?.contains(root.path) ?? false
        check("the disk image is ejected after installing", !leftover, mounts.joined(separator: ", "))
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
