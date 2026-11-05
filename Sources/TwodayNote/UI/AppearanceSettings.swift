import SwiftUI
import TwodayNoteKit

/// Settings > Appearance: light, dark, or the Mac's mode, and the accent color.
struct AppearanceSettings: View {
    @Bindable private var store = ThemeStore.shared
    @AppStorage(Prefs.appearanceKey) private var mode = AppearanceMode.system.rawValue
    @AppStorage(LiquidGlass.key) private var liquidGlass = true

    var body: some View {
        Section(L("Giao diện")) {
            Picker(L("Chế độ"), selection: $mode) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $liquidGlass) {
                Text("Liquid Glass")
                Text(L("Tắt để dùng giao diện cổ điển, như trước macOS 26."))
            }
            if liquidGlass != LiquidGlass.isOn {
                // macOS picks the design when the app starts.
                LabeledContent {
                    Button(L("Mở lại")) { LiquidGlass.relaunch() }
                } label: {
                    Text(L("Mở lại TwodayNote để áp dụng"))
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent(L("Màu nhấn")) {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(store.theme.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// One color dot, like the accent row in System Settings.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6) // grid: ok
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
