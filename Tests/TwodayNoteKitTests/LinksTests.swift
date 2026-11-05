import Foundation
import Testing
@testable import TwodayNoteKit

@Test("GitHub and YouTube links are found", arguments: [
    ("https://github.com/github/spec-kit", LinkSite.github, "github/spec-kit"),
    ("xem cái này https://github.com/apple/swift.git nhé", .github, "apple/swift"),
    ("https://github.com/apple/swift/tree/main/docs", .github, "apple/swift"),
    ("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s", .youtube, "dQw4w9WgXcQ"),
    ("https://youtu.be/dQw4w9WgXcQ?si=abc", .youtube, "dQw4w9WgXcQ"),
    ("https://m.youtube.com/shorts/dQw4w9WgXcQ", .youtube, "dQw4w9WgXcQ"),
])
func findsLinks(_ text: String, site: LinkSite, key: String) {
    let ref = LinkRef.find(in: text)
    #expect(ref?.site == site)
    #expect(ref?.key == key)
}

@Test("Pages that are not a repo or a video have no key", arguments: [
    "https://github.com/apple", "https://github.com/topics/swift", "https://gist.github.com/a/b",
    "https://www.youtube.com/@RickAstleyYT", "https://www.youtube.com/watch?v=short",
])
func linksWithoutKey(_ text: String) {
    let ref = LinkRef.find(in: text)
    #expect(ref != nil)
    #expect(ref?.key == nil)
}

@Test("Other text and other sites have no link", arguments: [
    "Mua sữa", "https://example.com/github.com/a/b", "github.com là gì", "https://notgithub.com/a/b",
])
func noLink(_ text: String) {
    #expect(LinkRef.find(in: text) == nil)
}

@Test("A new link block gets a preview to fill in")
func previewStartsUnchecked() {
    var book = Notebook()
    let repo = book.add("https://github.com/github/spec-kit", defaultKind: .note, day: .now)!
    #expect(repo.link?.title == "spec-kit")
    #expect(repo.link?.repoPath == "github/spec-kit")
    #expect(repo.link?.checked == false)
    let profile = book.add("https://github.com/apple", defaultKind: .note, day: .now)!
    #expect(profile.link?.checked == true)
    #expect(profile.link?.shortURL == "github.com/apple")
    #expect(book.uncheckedLinks.map(\.id) == [repo.id])
    let heading = book.add("# https://github.com/a/b", defaultKind: .note, day: .now)
    #expect(heading?.link == nil)
}

@Test("On Xem sau, links go under their site's heading")
func groupsLinks() {
    var book = Notebook()
    let day = Date.now
    book.add("Một bài viết", defaultKind: .note, day: day, later: true)
    book.add("https://github.com/github/spec-kit", defaultKind: .note, day: day, later: true)
    book.add("https://youtu.be/dQw4w9WgXcQ", defaultKind: .note, day: day, later: true)
    book.add("https://github.com/apple/swift", defaultKind: .note, day: day, later: true)
    book.add("Ghi chú cuối", defaultKind: .note, day: day, later: true)
    book.add("https://www.youtube.com/watch?v=aqz-KE-bpKQ", defaultKind: .note, day: day, later: true)
    // New blocks go on top: notes at the top of the list, links at the top of their section.
    #expect(book.laterEntries.map(\.text) == [
        "Ghi chú cuối", "Một bài viết",
        "GitHub", "https://github.com/apple/swift", "https://github.com/github/spec-kit",
        "YouTube", "https://www.youtube.com/watch?v=aqz-KE-bpKQ", "https://youtu.be/dQw4w9WgXcQ",
    ])
    #expect(book.laterEntries.filter { $0.kind == .heading }.count == 2)
}

@Test("Other blocks and headings go above the site sections")
func plainAboveSites() {
    var book = Notebook()
    book.add("https://github.com/a/b", defaultKind: .note, day: .now, later: true)
    book.add("# Đọc", defaultKind: .note, day: .now, later: true)
    book.add("Bài hay", defaultKind: .note, day: .now, later: true)
    let task = book.add("Việc nhỏ", defaultKind: .task, day: .now)!
    book.moveToLater(task.id)
    #expect(book.laterEntries.map(\.text) == ["Bài hay", "Đọc", "Việc nhỏ", "GitHub", "https://github.com/a/b"])
}

@Test("A heading people wrote themselves is used, whatever its case")
func usesExistingHeading() {
    var book = Notebook()
    book.add("# github", defaultKind: .note, day: .now, later: true)
    book.add("# Khác", defaultKind: .note, day: .now, later: true)
    book.add("https://github.com/a/b", defaultKind: .note, day: .now, later: true)
    #expect(book.laterEntries.map(\.text) == ["Khác", "github", "https://github.com/a/b"])
}

@Test("Links on a day stay in place, and move under a heading when sent to Xem sau")
func dayLinks() {
    var book = Notebook()
    let link = book.add("https://github.com/a/b", defaultKind: .task, day: .now)!
    #expect(book.entries(on: .now).map(\.text) == ["https://github.com/a/b"])
    book.add("Đọc sau", defaultKind: .note, day: .now, later: true)
    book.moveToLater(link.id)
    #expect(book.laterEntries.map(\.text) == ["Đọc sau", "GitHub", "https://github.com/a/b"])
}

@Test("Editing the text updates the link")
func editsLink() {
    var book = Notebook()
    let entry = book.add("Chưa có link", defaultKind: .note, day: .now)!
    let i = book.index(of: entry.id)!
    book.entries[i].text = "https://youtu.be/dQw4w9WgXcQ"
    _ = book.commitText(entry.id)
    #expect(book.entries[i].link?.site == .youtube)
    book.entries[i].text = "Hết link"
    _ = book.commitText(entry.id)
    #expect(book.entries[i].link == nil)
}

@Test("Details from the site are saved, unless the link changed")
func setsPreview() {
    var book = Notebook()
    let entry = book.add("https://youtu.be/dQw4w9WgXcQ", defaultKind: .note, day: .now)!
    var preview = entry.link!
    preview.title = "Video"
    preview.thumbnail = "thumb.jpg"
    preview.checked = true
    let saved = book.setPreview(preview, for: entry.id)
    #expect(saved)
    #expect(book.imageNames == ["thumb.jpg"])
    preview.url = "https://youtu.be/other123456"
    let stale = book.setPreview(preview, for: entry.id)
    #expect(!stale)
}

@Test("Star counts are short", arguments: [(980, "980"), (1_000, "1k"), (1_234, "1.2k"), (147_472, "147k"), (2_000_000, "2M")])
func compactStars(_ count: Int, expected: String) {
    #expect(LinkPreview.compact(count) == expected)
}

@Test("Notes saved before links existed still load")
func loadsOldNotes() throws {
    let json = #"{"version":1,"entries":[{"id":"8C1D6E0A-1111-4C3B-9C55-6F2A1E2B3C4D","text":"https://github.com/a/b","kind":"note","isDone":false,"day":0,"order":0,"createdAt":0}]}"#
    let book = try JSONDecoder().decode(Notebook.self, from: Data(json.utf8))
    #expect(book.entries.first?.link == nil)
}
