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
        .fitsContent(max: 840)
        .frame(width: 480)
        .noInitialFocus()
    }
}

struct GeneralSettings: View {
    @AppStorage(Prefs.carryOverKey) private var carryOver = true
    @AppStorage(Prefs.showCountKey) private var showCount = true
    @AppStorage(Prefs.hotKeyKey) private var hotKey = true
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
        Section("Chung") {
            Toggle(isOn: launchState.projectedValue) {
                Text("Mở cùng macOS")
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
            .onChange(of: launchAtLogin) { _, on in
                do {
                    try LaunchAtLogin.set(on)
                    loginError = nil
                } catch {
                    loginError = "Không bật được: \(error.localizedDescription)"
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            }
            Toggle(isOn: $hotKey) {
                Text("Phím tắt toàn cục ⌃⌥N")
                Text("Mở và đóng TwodayNote từ bất kỳ app nào.")
            }
            Toggle("Hiện số việc còn lại trên thanh menu", isOn: $showCount)
            Toggle(isOn: $carryOver) {
                Text("Chuyển việc chưa xong sang hôm nay")
                Text("Task chưa tick của những ngày trước tự lên đầu danh sách hôm nay.")
            }
        }
    }
}

/// Teaches the shortcuts and typing prefixes (mac-design: keyboard first).
private struct ShortcutList: View {
    var body: some View {
        Section("Phím tắt và gõ nhanh") {
            row("Mở / đóng TwodayNote", "⌃⌥N")
            row("Hôm nay · Ngày mai · Ngày kia", "⌘1 ⌘2 ⌘3")
            row("Thêm khối", "Return")
            row("Đóng", "Esc")
            LabeledContent("Gõ ở đầu dòng") {
                Text("# tiêu đề  - ghi chú  * ý tưởng  [] task")
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
