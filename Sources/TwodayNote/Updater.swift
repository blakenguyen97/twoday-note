import AppKit
import Observation
import Security
import TwodayNoteKit

/// Finds a newer TwodayNote on GitHub and installs it over this copy, so
/// nobody downloads and drags a DMG again.
///
/// Once a day (Settings > Cập nhật, on unless turned off) it reads the latest
/// release of `repo`. A newer one shows a dot on the ••• button and a
/// "Cập nhật lên bản …" item in its menu. Clicking it downloads the release's
/// DMG, checks the app inside (same bundle id, the release's version, a valid
/// signature, the same team when this copy has one), swaps it in place of the
/// running app, and opens it again. The notes file is not touched.
///
/// Releases: tag `v<version>` (CFBundleShortVersionString in Info.plist.in)
/// with the DMG from tools/release.sh attached.
@Observable
final class Updater {
    static let shared = Updater()

    nonisolated static let repo = "blakenguyen97/twoday-note"
    static let autoCheckKey = "update.autoCheck"
    static let lastCheckKey = "update.lastCheck"

    enum Phase: Equatable {
        /// Not checked since launch.
        case idle
        case checking
        case upToDate
        case available(Release)
        case installing(Release)
    }

    private(set) var phase: Phase = .idle
    /// What went wrong last, until the next check or install.
    private(set) var problem: String?
    /// When GitHub last answered.
    private(set) var lastCheck = UserDefaults.standard.object(forKey: Updater.lastCheckKey) as? Date

    /// This copy's version: "0.3".
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// "0.3 (202611051644)": the version and its build stamp.
    static var versionText: String {
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !build.isEmpty, build != version else { return version }
        return "\(version) (\(build))"
    }

    static var autoCheck: Bool { UserDefaults.standard.object(forKey: autoCheckKey) as? Bool ?? true }

    /// The release waiting to be installed, or being installed.
    var release: Release? {
        switch phase {
        case .available(let release), .installing(let release): release
        default: nil
        }
    }

    var isAvailable: Bool { if case .available = phase { true } else { false } }
    var isBusy: Bool {
        switch phase {
        case .checking, .installing: true
        default: false
        }
    }

    // MARK: Checking

    /// At launch, every hour, and after sleep: checks once a day has passed.
    /// A failed check (offline) leaves the day open, so the next hour tries again.
    func checkIfDue(now: Date = .now) {
        // Tests and snapshots never reach the network.
        guard Self.autoCheck, !Store.isOverridden, !isBusy, release == nil,
              UpdateSchedule.isDue(lastCheck: lastCheck, now: now) else { return }
        Task { await check() }
    }

    /// Kiểm tra ngay, or the daily check.
    func check() async {
        guard !isBusy else { return }
        let before = phase
        phase = .checking
        problem = nil
        do {
            if let latest = try await Installer.latestRelease() {
                consider(latest)
            } else {
                phase = .upToDate
            }
            lastCheck = .now
            UserDefaults.standard.set(lastCheck, forKey: Self.lastCheckKey)
        } catch {
            phase = before == .checking ? .idle : before
            problem = L("Không kiểm tra được: {}", error.localizedDescription)
        }
    }

    /// What a release means for this copy: an update, or nothing new.
    func consider(_ latest: Release) {
        phase = latest.isUpdate(over: Self.version) ? .available(latest) : .upToDate
    }

    /// For the self-test and snapshots: back to not checked.
    func reset() {
        phase = .idle
        problem = nil
    }

    // MARK: Installing

    /// Cập nhật: downloads, checks, and swaps in the new copy, then opens it.
    /// On failure the update stays offered, with what went wrong.
    func install() {
        guard case .available(let release) = phase, let image = release.diskImage,
              let version = release.version else { return }
        phase = .installing(release)
        problem = nil
        let target = Bundle.main.bundleURL
        Task {
            do {
                try await Installer.install(from: image.url, version: version, over: target)
                Relaunch.now()
            } catch {
                phase = .available(release)
                problem = error.localizedDescription
                showFailure(error.localizedDescription, page: release.page)
            }
        }
    }

    private func showFailure(_ message: String, page: URL) {
        let alert = NSAlert()
        alert.messageText = L("Không cập nhật được")
        alert.informativeText = message
        alert.addButton(withTitle: L("Mở trang tải"))
        alert.addButton(withTitle: L("Đóng"))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(page) }
    }
}

/// Quits and opens this app again from the same place.
enum Relaunch {
    static func now() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Waits for this copy to quit, then opens the app again.
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.1; done; open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

enum UpdateError: LocalizedError {
    case server(Int)
    case translocated
    case notWritable(String)
    case noApp
    case wrongApp
    case wrongVersion(String)
    case badSignature
    case otherTeam
    case tool(String, String)

    var errorDescription: String? {
        switch self {
        case .server(let code):
            L("GitHub trả lời mã {}.", code)
        case .translocated:
            L("TwodayNote đang chạy từ chỗ tạm của macOS. Kéo app vào thư mục Applications rồi mở lại.")
        case .notWritable(let folder):
            L("Không có quyền ghi vào {}. Tải bản mới từ GitHub và cài bằng tay.", folder)
        case .noApp:
            L("Trong file tải về không có TwodayNote.")
        case .wrongApp:
            L("App trong file tải về không phải TwodayNote.")
        case .wrongVersion(let found):
            L("File tải về là bản {}, không khớp với bản trên GitHub.", found)
        case .badSignature:
            L("Chữ ký của app tải về không hợp lệ.")
        case .otherTeam:
            L("App tải về được ký bởi người khác.")
        case .tool(let name, let output):
            L("{} báo lỗi: {}", name, output)
        }
    }
}

/// The network and disk work, off the main thread.
nonisolated enum Installer {
    /// The latest release, or nil when the repo has none.
    @concurrent static func latestRelease() async throws -> Release? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Updater.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TwodayNote", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil }
        guard code == 200 else { throw UpdateError.server(code) }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    /// Downloads the DMG at `url`, checks the app in it, and puts it where
    /// `target` (the running app) is.
    @concurrent static func install(from url: URL, version: AppVersion, over target: URL) async throws {
        let files = FileManager.default
        guard !target.path.contains("/AppTranslocation/") else { throw UpdateError.translocated }
        let folder = target.deletingLastPathComponent()
        guard files.isWritableFile(atPath: folder.path), files.isWritableFile(atPath: target.path) else {
            throw UpdateError.notWritable(folder.path)
        }

        // A scratch folder on the same disk as the app, so the swap is one rename.
        let work = try files.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: target, create: true)
        defer { try? files.removeItem(at: work) }

        var request = URLRequest(url: url)
        request.setValue("TwodayNote", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (download, response) = try await URLSession.shared.download(for: request)
        // A file URL (the self-test's disk image) has no status code.
        let code = (response as? HTTPURLResponse)?.statusCode ?? (url.isFileURL ? 200 : 0)
        guard code == 200 else { throw UpdateError.server(code) }
        let image = work.appending(path: "update.dmg")
        try files.moveItem(at: download, to: image)

        let mount = work.appending(path: "mount", directoryHint: .isDirectory)
        try files.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", image.path, "-nobrowse", "-readonly", "-noautoopen",
                                     "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }

        // The app in the image: same name as this one, or else the only .app.
        var source = mount.appending(path: target.lastPathComponent)
        if !files.fileExists(atPath: source.path) {
            guard let app = try files.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) else { throw UpdateError.noApp }
            source = app
        }
        guard let bundle = Bundle(url: source), bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.wrongApp
        }
        let found = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        guard AppVersion(found) == version else { throw UpdateError.wrongVersion(found) }
        let team = try signingTeam(of: source)
        // A copy signed by a developer takes updates from that developer only.
        if let current = try? signingTeam(of: target), current != team { throw UpdateError.otherTeam }

        let staged = work.appending(path: "new", directoryHint: .isDirectory).appending(path: target.lastPathComponent)
        try run("/usr/bin/ditto", [source.path, staged.path])
        // Not downloaded by a browser, but make sure macOS will not ask again.
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        _ = try files.replaceItemAt(target, withItemAt: staged)
    }

    /// Checks the app's signature and returns its team, nil when signed ad hoc.
    static func signingTeam(of app: URL) throws -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateError.badSignature
        }
        let strict = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(code, strict, nil) == errSecSuccess else { throw UpdateError.badSignature }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
        else { throw UpdateError.badSignature }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Runs a command-line tool and fails with its output when it fails.
    @discardableResult
    static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.tool(URL(fileURLWithPath: tool).lastPathComponent,
                                   output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}
