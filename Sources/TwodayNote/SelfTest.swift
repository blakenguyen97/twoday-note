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

            model.flush()
            check("the notes file reloads the same", Store.load().entries == model.book.entries)

            app.showPopover()
            try? await Task.sleep(for: .seconds(0.5))
            check("the menu bar icon opens the popover", app.popover.isShown)
            for _ in 1...10 {
                app.closePopover()
                try? await Task.sleep(for: .seconds(0.05))
                app.showPopover()
                try? await Task.sleep(for: .seconds(0.05))
            }
            check("the popover opens and closes 10 times", app.popover.isShown)
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
