import SwiftUI
import TwodayNoteKit

/// The Settings window (⌘, or ••• > Cài đặt…). A menu bar app has few
/// settings, so they fit one grouped Form that sizes to its content.
struct SettingsView: View {
    var body: some View {
        Form {
            GeneralSettings()
            ShortcutList()
            AppearanceSettings()
        }
        .formStyle(.grouped)
        // Three short sections fit on a laptop screen without scrolling.
        .fitsContent(max: 900)
        .frame(width: 480)
        .noInitialFocus()
    }
}

struct GeneralSettings: View {
    @AppStorage(Prefs.carryOverKey) private var carryOver = true
    @AppStorage(Prefs.showCountKey) private var showCount = true
    @AppStorage(Prefs.hotKeyKey) private var hotKey = true
    @AppStorage(Lang.key) private var language = Lang.vi.rawValue
    // State as a stored property: the @State macro needs Xcode (see CLAUDE.md).
    private let launchState = State(initialValue: LaunchAtLogin.isEnabled)
    private let errorState = State<String?>(initialValue: nil)

    private var launchAtLogin: Bool {
        get { launchState.wrappedValue }
        nonmutating set { launchState.wrappedValue = newValue }
    }

    private var loginError: String? {
        get { errorState.wrappedValue }
        nonmutating set { errorState.wrappedValue = newValue }
    }

    var body: some View {
        Section(L("Chung")) {
            // Each language's name in itself, so people find theirs.
            Picker(L("Ngôn ngữ"), selection: $language) {
                ForEach(Lang.allCases) { Text($0.name).tag($0.rawValue) }
            }
            Toggle(isOn: launchState.projectedValue) {
                Text(L("Mở cùng macOS"))
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
            .onChange(of: launchAtLogin) { _, on in
                do {
                    try LaunchAtLogin.set(on)
                    loginError = nil
                } catch {
                    loginError = L("Không bật được: {}", error.localizedDescription)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            }
            Toggle(isOn: $hotKey) {
                Text(L("Phím tắt toàn cục ⌃⌥N"))
                Text(L("Mở và đóng TwodayNote từ bất kỳ app nào."))
            }
            Toggle(L("Hiện số việc còn lại trên thanh menu"), isOn: $showCount)
            Toggle(isOn: $carryOver) {
                Text(L("Chuyển việc chưa xong sang hôm nay"))
                Text(L("Task chưa tick của những ngày trước tự lên đầu danh sách hôm nay."))
            }
        }
    }
}

/// Teaches the shortcuts and typing prefixes (mac-design: keyboard first).
private struct ShortcutList: View {
    var body: some View {
        Section(L("Phím tắt và gõ nhanh")) {
            row(L("Mở / đóng TwodayNote"), "⌃⌥N")
            row(L("Hôm nay · Ngày mai · Xem sau"), "⌘1 ⌘2 ⌘3")
            row(L("Thêm khối"), "Return")
            row(L("Đóng"), "Esc")
            LabeledContent(L("Gõ ở đầu dòng")) {
                Text(L("# tiêu đề  - ghi chú  * ý tưởng  [] task"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
