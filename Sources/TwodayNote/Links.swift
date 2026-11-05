import AppKit
import TwodayNoteKit

/// Asks GitHub and YouTube about a link: a repo's description, topics, and
/// stars (GitHub's public API), a video's title, channel, and thumbnail
/// (YouTube's oEmbed). Neither needs a key.
enum LinkFetcher {
    /// The preview with the site's details, `checked` once the site gave a
    /// final answer. Nil when it should be asked again later (offline,
    /// rate limit).
    static func fetch(_ preview: LinkPreview) async -> LinkPreview? {
        guard let key = preview.key else {
            var done = preview
            done.checked = true
            return done
        }
        switch preview.site {
        case .github: return await repo(key, preview)
        case .youtube: return await video(key, preview)
        }
    }

    private static func repo(_ path: String, _ preview: LinkPreview) async -> LinkPreview? {
        guard let url = URL(string: "https://api.github.com/repos/\(path)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TwodayNote", forHTTPHeaderField: "User-Agent")
        guard let (data, status) = await load(request) else { return nil }
        var result = preview
        switch status {
        case 200:
            guard let repo = try? JSONDecoder().decode(Repo.self, from: data) else { return nil }
            result.title = repo.name
            result.key = repo.full_name
            result.summary = repo.description.flatMap(EntryText.clean)
            result.topics = repo.topics?.isEmpty == false ? repo.topics : nil
            result.stars = repo.stargazers_count
            result.language = repo.language
        case 404, 451:
            // Private, deleted, or not a repo: keep the card as it is.
            break
        default:
            return nil
        }
        result.checked = true
        return result
    }

    private struct Repo: Decodable {
        var name: String
        var full_name: String
        var description: String?
        var topics: [String]?
        var stargazers_count: Int?
        var language: String?
    }

    private static func video(_ id: String, _ preview: LinkPreview) async -> LinkPreview? {
        var result = preview
        var oembed = URLComponents(string: "https://www.youtube.com/oembed")
        oembed?.queryItems = [URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(id)"),
                              URLQueryItem(name: "format", value: "json")]
        guard let url = oembed?.url, let (data, status) = await load(URLRequest(url: url, timeoutInterval: 15)) else { return nil }
        if status == 200, let info = try? JSONDecoder().decode(OEmbed.self, from: data) {
            result.title = info.title
            result.author = info.author_name
        } else if ![401, 403, 404].contains(status) {
            return nil
        }
        // hqdefault exists for every video. It is 4:3 with bars, which the
        // card crops away.
        if result.thumbnail == nil, let image = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"),
           let (bytes, code) = await load(URLRequest(url: image, timeoutInterval: 15)), code == 200 {
            result.thumbnail = ImageStore.save(bytes, ext: "jpg")
        }
        result.checked = true
        return result
    }

    private struct OEmbed: Decodable {
        var title: String?
        var author_name: String?
    }

    private static func load(_ request: URLRequest) async -> (Data, Int)? {
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode)
    }
}
