import Foundation
import TwodayNoteKit

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an
/// empty store. Only things a person can make in the app.
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        guard model.book.entries.isEmpty else { return }
        let today = Day.start(of: .now)
        var book = Notebook()
        // Yesterday's unfinished task carries over to today.
        book.add("Gọi chị Lan chốt lịch họp thứ Sáu", defaultKind: .task, day: Day.adding(-1, to: today))
        let done = book.add("Trả lời email khách về báo giá", defaultKind: .task, day: today)
        book.add("Review PR đăng nhập bằng Google", defaultKind: .task, day: today)
        book.add("Cập nhật số liệu vào slide tuần, nhớ thêm biểu đồ doanh thu tháng 10", defaultKind: .task, day: today)
        book.add("# Ý tưởng", defaultKind: .task, day: today)
        book.add("* Widget nhỏ hiện 3 việc quan trọng nhất trong ngày", defaultKind: .task, day: today)
        book.add("- Mật khẩu wifi phòng họp đã đổi, hỏi lễ tân", defaultKind: .task, day: today)
        if let done { book.toggleDone(done.id) }

        let tomorrow = Day.adding(1, to: today)
        book.add("Chuẩn bị demo sprint lúc 10h", defaultKind: .task, day: tomorrow)
        book.add("Đặt vé xe về quê cuối tuần", defaultKind: .task, day: tomorrow)
        book.add("- Mang sạc laptop dự phòng", defaultKind: .task, day: tomorrow)
        model.replace(book)
        model.refreshDay()
    }
}
