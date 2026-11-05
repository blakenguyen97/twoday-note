import Foundation

/// A version like "0.3" or "1.2.10", compared number by number:
/// 0.10 is newer than 0.9, and 0.3 is the same as 0.3.0.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let parts: [Int]

    /// Reads "0.3", "v0.3", or "0.4-beta" (the part after "-" is ignored).
    /// Nil when there is no number to read.
    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        if let dash = text.firstIndex(of: "-") { text = String(text[..<dash]) }
        let numbers = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        var parts = numbers.compactMap { $0 }
        while parts.count > 1, parts.last == 0 { parts.removeLast() }
        self.parts = parts
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

/// A GitHub release, as api.github.com/repos/<owner>/<repo>/releases/latest returns it.
public struct Release: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public var name: String
        public var url: URL
        public var size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case url = "browser_download_url"
        }

        public init(name: String, url: URL, size: Int) {
            self.name = name
            self.url = url
            self.size = size
        }
    }

    public var tag: String
    public var name: String?
    public var page: URL
    public var notes: String?
    public var draft: Bool
    public var prerelease: Bool
    public var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, draft, prerelease, assets
        case tag = "tag_name"
        case page = "html_url"
        case notes = "body"
    }

    public init(tag: String, name: String? = nil, page: URL, notes: String? = nil,
                draft: Bool = false, prerelease: Bool = false, assets: [Asset]) {
        self.tag = tag
        self.name = name
        self.page = page
        self.notes = notes
        self.draft = draft
        self.prerelease = prerelease
        self.assets = assets
    }

    /// "v0.4" read as 0.4.
    public var version: AppVersion? { AppVersion(tag) }

    /// The disk image to install from: TwodayNote-0.4.dmg, or else any .dmg.
    public var diskImage: Asset? {
        let dmgs = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }
        return dmgs.first { $0.name.hasPrefix("TwodayNote") } ?? dmgs.first
    }

    /// True when this release is newer than `current` and has a disk image
    /// to install. Drafts and pre-releases are never offered.
    public func isUpdate(over current: String) -> Bool {
        guard !draft, !prerelease, diskImage != nil,
              let version, let running = AppVersion(current) else { return false }
        return version > running
    }
}

public enum UpdateSchedule {
    /// One check a day.
    public static let interval: TimeInterval = 24 * 60 * 60

    /// True when the last check is a day old, never happened, or is in the
    /// future (the clock was set back).
    public static func isDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        let age = now.timeIntervalSince(lastCheck)
        return age >= interval || age < 0
    }
}
