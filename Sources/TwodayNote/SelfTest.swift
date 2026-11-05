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
            app.popover.behavior = .transient
            model.delete(zoomed.id)
            model.undo = nil
            app.closePopover()

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
