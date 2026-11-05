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
