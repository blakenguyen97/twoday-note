import AppKit
import SwiftUI

/// Settings > Giao diện > Liquid Glass. Off, the app uses the design from
/// before macOS 26: the popover, tabs, buttons, and menus are drawn the
/// classic way, and the Undo bar is a plain bar instead of glass.
///
/// macOS picks the design once, when the app starts, from the
/// UIDesignRequiresCompatibility key in Info.plist. Writing the file would
/// break the app's signature, so `applyAtLaunch` sets the key in the copy
/// already in memory, before AppKit reads it. A change needs a relaunch.
enum LiquidGlass {
    static let key = "appearance.liquidGlass"
    static let compatibilityKey = "UIDesignRequiresCompatibility"

    /// The setting as it was at launch: what is on screen now.
    static let isOn = wanted

    /// The setting now, which may wait for a relaunch. On unless turned off.
    /// bool(forKey:) also reads "NO" from a launch argument.
    static var wanted: Bool {
        UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    /// Call first thing in main, before NSApplication exists.
    static func applyAtLaunch() {
        guard !isOn, let info = CFBundleGetInfoDictionary(CFBundleGetMainBundle()) else { return }
        // The bundle's info dictionary is mutable in memory.
        let dictionary = unsafeBitCast(info, to: NSMutableDictionary.self)
        dictionary[compatibilityKey] = true
    }

    /// True when macOS is drawing the classic design.
    static var isClassic: Bool {
        Bundle.main.object(forInfoDictionaryKey: compatibilityKey) as? Bool ?? false
    }

    /// Quits and opens the app again, so the new setting takes effect.
    static func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Waits for this copy to quit, then opens the app again.
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.1; done; open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

extension View {
    /// A floating control's background: Liquid Glass, or a plain bar when
    /// Liquid Glass is off.
    @ViewBuilder
    func floatingBackground<S: Shape>(in shape: S) -> some View {
        if LiquidGlass.isOn {
            glassEffect(.regular, in: shape)
        } else {
            background(.bar, in: shape)
                .overlay { shape.stroke(.separator, lineWidth: 1) }
        }
    }
}
