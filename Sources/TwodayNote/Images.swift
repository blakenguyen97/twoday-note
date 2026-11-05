import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Pasted images, one file each, in a folder next to the notes file:
/// ~/Library/Application Support/TwodayNote/Images/. Blocks keep the file
/// names. A file stays until no block, pending paste, or Undo uses it.
enum ImageStore {
    static var folder: URL {
        let notes = Store.url
        let name = Store.isOverridden ? notes.deletingPathExtension().lastPathComponent + "-images" : "Images"
        return notes.deletingLastPathComponent().appending(path: name, directoryHint: .isDirectory)
    }

    static func url(_ name: String) -> URL {
        folder.appending(path: name)
    }

    /// Saves the images on a pasteboard and returns their file names. Nil
    /// when the pasteboard holds text or files that are not images, so ⌘V
    /// pastes as usual.
    static func save(from pasteboard: NSPasteboard) -> [String]? {
        // Images copied in Finder: keep the original file's bytes.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let images = urls.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
            guard images.count == urls.count else { return nil }
            let names = images.compactMap { url in
                (try? Data(contentsOf: url)).flatMap { save($0, ext: url.pathExtension.lowercased()) }
            }
            return names.isEmpty ? nil : names
        }
        let types = pasteboard.types ?? []
        // Rich text from Word, Excel, Pages, or Notes also carries a picture
        // of itself: that is a text paste.
        if types.contains(.rtf) || types.contains(.rtfd) { return nil }
        if let png = pasteboard.data(forType: .png) {
            return save(png, ext: "png").map { [$0] }
        }
        if let jpeg = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)) {
            return save(jpeg, ext: "jpg").map { [$0] }
        }
        // Screenshots and Safari give TIFF: store it as PNG, much smaller.
        if let tiff = pasteboard.data(forType: .tiff),
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            return save(png, ext: "png").map { [$0] }
        }
        return nil
    }

    /// True when ⌘V would paste an image. Reads types only, no file data.
    static func canPaste(from pasteboard: NSPasteboard = .general) -> Bool {
        let types = pasteboard.types ?? []
        if types.contains(.fileURL) {
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            return !urls.isEmpty && urls.allSatisfy { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
        }
        if types.contains(.rtf) || types.contains(.rtfd) { return false }
        return types.contains(.png) || types.contains(.tiff)
            || types.contains(NSPasteboard.PasteboardType(UTType.jpeg.identifier))
    }

    static func save(_ data: Data, ext: String) -> String? {
        guard NSImage(data: data) != nil else { return nil }
        let name = "\(UUID().uuidString).\(ext.isEmpty ? "png" : ext)"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url(name), options: .atomic)
            return name
        } catch {
            print("Could not save image \(name): \(error)")
            return nil
        }
    }

    /// Puts an image on the clipboard.
    static func copy(_ name: String) {
        guard let image = NSImage(contentsOf: url(name)) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    /// Deletes every file in the folder that is not in `keeping`.
    static func prune(keeping: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in files where !keeping.contains(file) && !file.hasPrefix(".") {
            try? FileManager.default.removeItem(at: url(file))
            thumbnails.removeObject(forKey: file as NSString)
        }
    }

    // MARK: Thumbnails

    nonisolated(unsafe) private static let thumbnails = NSCache<NSString, NSImage>()

    /// A small copy for the block rows, made once per file.
    static func thumbnail(_ name: String) -> NSImage? {
        if let cached = thumbnails.object(forKey: name as NSString) { return cached }
        guard let source = CGImageSourceCreateWithURL(url(name) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 240,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        thumbnails.setObject(image, forKey: name as NSString)
        return image
    }
}
