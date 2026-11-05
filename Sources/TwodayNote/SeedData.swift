import AppKit
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
        let chart = ImageStore.save(SampleImage.png(), ext: "png").map { [$0] } ?? []
        book.add("Cập nhật số liệu vào slide tuần, nhớ thêm biểu đồ doanh thu tháng 10", defaultKind: .task, day: today, images: chart)
        book.add("# Ý tưởng", defaultKind: .task, day: today)
        let sketches = [SampleImage.png(hue: 0.08), SampleImage.png(hue: 0.75)].compactMap { ImageStore.save($0, ext: "png") }
        book.add("* Widget nhỏ hiện 3 việc quan trọng nhất trong ngày", defaultKind: .task, day: today, images: sketches)
        book.add("- Mật khẩu wifi phòng họp đã đổi, hỏi lễ tân", defaultKind: .task, day: today)
        if let done { book.toggleDone(done.id) }

        let tomorrow = Day.adding(1, to: today)
        book.add("Chuẩn bị demo sprint lúc 10h", defaultKind: .task, day: tomorrow)
        book.add("Đặt vé xe về quê cuối tuần", defaultKind: .task, day: tomorrow)
        book.add("- Mang sạc laptop dự phòng", defaultKind: .task, day: tomorrow)

        // Xem sau: things met by chance, saved over the last days.
        book.add("Bài viết về cách Notes trên Mac sắp xếp ghi chú, đọc khi rảnh", defaultKind: .note, day: Day.adding(-3, to: today), later: true)
        book.add("* Quán cà phê mới ở Hai Bà Trưng, cuối tuần ghé thử", defaultKind: .note, day: Day.adding(-1, to: today), later: true)
        let shot = ImageStore.save(SampleImage.png(hue: 0.35), ext: "png").map { [$0] } ?? []
        book.add("Ảnh chụp bảng giá gói cloud, so sánh sau", defaultKind: .note, day: today, images: shot, later: true)
        // Pasted links: they go under GitHub and YouTube headings. The
        // details are filled in here, so snapshots need no network.
        if let repo = book.add("https://github.com/github/spec-kit", defaultKind: .note, day: Day.adding(-2, to: today), later: true),
           var preview = repo.link {
            preview.summary = "💫 Toolkit to help you get started with SDD or any other process!"
            preview.topics = ["ai", "copilot", "development", "engineering", "prd"]
            preview.stars = 147_472
            preview.language = "Python"
            preview.checked = true
            book.setPreview(preview, for: repo.id)
        }
        if let video = book.add("https://youtu.be/aqz-KE-bpKQ", defaultKind: .note, day: today, later: true),
           var preview = video.link {
            preview.title = "Làm app thanh menu cho Mac bằng SwiftUI, từ đầu"
            preview.author = "Kênh Lập Trình Swift"
            preview.thumbnail = ImageStore.save(SampleImage.png(hue: 0.02, size: NSSize(width: 640, height: 360)), ext: "png")
            preview.checked = true
            book.setPreview(preview, for: video.id)
        }
        // Shown in the order written here: new blocks would go on top.
        for i in book.entries.indices { book.entries[i].order = Double(i) }
        model.replace(book)
        model.refreshDay()
    }
}

/// A bar chart drawn in code: the pasted image in seed data and the self-test.
enum SampleImage {
    static func png(hue: CGFloat = 0.58, size: NSSize = NSSize(width: 640, height: 400)) -> Data {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(white: 0.97, alpha: 1).setFill()
            rect.fill()
            // Drawn at 640 × 400, stretched to `size`.
            let scale = NSAffineTransform()
            scale.scaleX(by: rect.width / 640, yBy: rect.height / 400)
            scale.concat()
            for (i, value) in [0.35, 0.55, 0.45, 0.7, 0.62, 0.85].enumerated() {
                NSColor(hue: hue, saturation: 0.55, brightness: 0.9 - CGFloat(i) * 0.04, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: 60 + CGFloat(i) * 92, y: 40, width: 60, height: 320 * value),
                             xRadius: 8, yRadius: 8).fill()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return Data() }
        return png
    }
}
