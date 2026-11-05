import Foundation
import Testing
@testable import TwodayNoteKit

@Suite("Updates")
struct UpdatesTests {
    @Test("Versions compare number by number")
    func versions() throws {
        let v03 = try #require(AppVersion("0.3"))
        #expect(try #require(AppVersion("v0.4")) > v03)
        #expect(try #require(AppVersion("0.10")) > #require(AppVersion("0.9")))
        #expect(try #require(AppVersion("0.3.0")) == v03)
        #expect(try #require(AppVersion("0.3.1")) > v03)
        #expect(try #require(AppVersion("1.0-beta")) == #require(AppVersion("1")))
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("") == nil)
        #expect(AppVersion("0..3") == nil)
        #expect(v03.description == "0.3")
    }

    @Test("Reads a GitHub release and picks its disk image")
    func decodes() throws {
        let json = """
        {"tag_name": "v0.4", "name": "TwodayNote 0.4", "html_url": "https://github.com/blakenguyen97/twoday-note/releases/tag/v0.4",
         "body": "Updates", "draft": false, "prerelease": false,
         "assets": [
           {"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt", "size": 10},
           {"name": "TwodayNote-0.4.dmg", "browser_download_url": "https://github.com/x/TwodayNote-0.4.dmg", "size": 2400000}
         ]}
        """
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))
        #expect(release.version?.description == "0.4")
        #expect(release.diskImage?.name == "TwodayNote-0.4.dmg")
        #expect(release.isUpdate(over: "0.3"))
        #expect(!release.isUpdate(over: "0.4"))
        #expect(!release.isUpdate(over: "0.5"))
    }

    @Test("No update without a disk image, or from a draft or pre-release")
    func notOffered() {
        let page = URL(string: "https://github.com")!
        let dmg = Release.Asset(name: "TwodayNote-9.dmg", url: page, size: 1)
        #expect(!Release(tag: "v9", page: page, assets: []).isUpdate(over: "0.3"))
        #expect(!Release(tag: "v9", page: page, draft: true, assets: [dmg]).isUpdate(over: "0.3"))
        #expect(!Release(tag: "v9", page: page, prerelease: true, assets: [dmg]).isUpdate(over: "0.3"))
        #expect(!Release(tag: "nightly", page: page, assets: [dmg]).isUpdate(over: "0.3"))
        #expect(Release(tag: "v9", page: page, assets: [dmg]).isUpdate(over: "0.3"))
    }

    @Test("Checks once a day")
    func schedule() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(UpdateSchedule.isDue(lastCheck: nil, now: now))
        #expect(!UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }
}
