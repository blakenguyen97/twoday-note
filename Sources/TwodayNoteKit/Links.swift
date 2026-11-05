import Foundation

/// Sites whose links get a card and, on Xem sau, a heading of their own.
public enum LinkSite: String, Codable, CaseIterable, Sendable {
    case github, youtube

    /// The heading their links go under on Xem sau.
    public var heading: String {
        switch self {
        case .github: "GitHub"
        case .youtube: "YouTube"
        }
    }
}

/// A GitHub or YouTube link found in a block's text.
public struct LinkRef: Hashable, Sendable {
    public var site: LinkSite
    /// The link as it appears in the text.
    public var url: String
    /// "owner/repo" on GitHub, the video id on YouTube. Nil for other pages
    /// (a profile, a channel), which get a card without details.
    public var key: String?

    public init(site: LinkSite, url: String, key: String?) {
        self.site = site
        self.url = url
        self.key = key
    }

    /// The first GitHub or YouTube link in `text`.
    public static func find(in text: String) -> LinkRef? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let found = Range(match.range, in: text) else { continue }
            if let ref = parse(String(text[found])) { return ref }
        }
        return nil
    }

    /// A GitHub or YouTube link, or nil for any other text.
    public static func parse(_ string: String) -> LinkRef? {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              var host = url.host()?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "github.com" || host.hasSuffix(".github.com") {
            return LinkRef(site: .github, url: string, key: host == "github.com" ? repo(parts) : nil)
        }
        if host == "youtu.be" {
            return LinkRef(site: .youtube, url: string, key: parts.first.flatMap(videoID))
        }
        if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            return LinkRef(site: .youtube, url: string, key: video(parts, url: url))
        }
        return nil
    }

    /// GitHub pages that are not an owner.
    private static let reserved: Set<String> = [
        "about", "apps", "codespaces", "collections", "enterprise", "events", "explore", "features",
        "issues", "login", "marketplace", "new", "notifications", "orgs", "pricing", "pulls",
        "search", "settings", "sponsors", "topics", "trending",
    ]

    private static func repo(_ parts: [String]) -> String? {
        guard parts.count >= 2, !reserved.contains(parts[0].lowercased()) else { return nil }
        var name = parts[1]
        if name.hasSuffix(".git") { name.removeLast(4) }
        return name.isEmpty ? nil : "\(parts[0])/\(name)"
    }

    private static func video(_ parts: [String], url: URL) -> String? {
        if parts.first == "watch" {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            return query?.first { $0.name == "v" }?.value.flatMap(videoID)
        }
        guard parts.count >= 2, ["shorts", "embed", "live", "v"].contains(parts[0]) else { return nil }
        return videoID(parts[1])
    }

    /// Video ids are 11 letters, digits, - or _.
    private static func videoID(_ id: String) -> String? {
        let ok = id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        return ok ? id : nil
    }
}

/// What a block with a link shows about it. Made from the link at once,
/// filled in with details from the site later, and saved with the block, so
/// it shows offline.
public struct LinkPreview: Codable, Hashable, Sendable {
    public var site: LinkSite
    public var url: String
    /// "owner/repo" or the video id, as in `LinkRef.key`.
    public var key: String?
    /// The repo's name or the video's title.
    public var title: String?
    /// The video's channel.
    public var author: String?
    /// The repo's description.
    public var summary: String?
    public var topics: [String]?
    public var stars: Int?
    public var language: String?
    /// The video's thumbnail: a file in the image folder.
    public var thumbnail: String?
    /// True once the site answered, or when there is nothing to ask it.
    public var checked: Bool

    public init(_ ref: LinkRef) {
        site = ref.site
        url = ref.url
        key = ref.key
        title = ref.site == .github ? ref.key?.split(separator: "/").last.map(String.init) : nil
        checked = ref.key == nil
    }

    /// "github/spec-kit": the owner and repo.
    public var repoPath: String? { site == .github ? key : nil }

    /// The page without "https://" and "www.", for links with no details.
    public var shortURL: String {
        var text = url
        for prefix in ["https://", "http://", "www."] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        return text.hasSuffix("/") ? String(text.dropLast()) : text
    }

    /// "147k", "1.2k", "980": a star count.
    public static func compact(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case ..<10_000:
            String(format: "%.1fk", Double(count) / 1_000).replacingOccurrences(of: ".0k", with: "k")
        case ..<1_000_000: "\(count / 1_000)k"
        default:
            String(format: "%.1fM", Double(count) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        }
    }
}

extension Entry {
    /// Every file in the image folder this block uses: pasted images and a
    /// link's thumbnail.
    public var files: [String] {
        images + [link?.thumbnail].compactMap { $0 }
    }
}
