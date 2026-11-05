import AppKit
import SwiftUI

/// A segmented control as wide as its space, the segments sharing it
/// equally: the system NSSegmentedControl with `.fillEqually`. SwiftUI's
/// segmented Picker on the Mac keeps its natural width instead.
struct FillSegments: NSViewRepresentable {
    let title: String
    let labels: [String]
    @Binding var selection: Int
    /// Read where the view is made, so a new accent in Settings redraws it.
    var accent = Palette.accent

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        if control.segmentCount != labels.count { control.segmentCount = labels.count }
        for (index, label) in labels.enumerated() where control.label(forSegment: index) != label {
            control.setLabel(label, forSegment: index)
        }
        if control.selectedSegment != selection { control.selectedSegment = selection }
        // The chosen segment in the accent color, like SwiftUI's segmented Picker.
        control.selectedSegmentBezelColor = NSColor(accent)
        control.setAccessibilityLabel(title)
    }

    /// The width it is offered, the system height.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let natural = nsView.intrinsicContentSize
        return CGSize(width: proposal.width.map { max($0, natural.width) } ?? natural.width, height: natural.height)
    }

    final class Coordinator: NSObject {
        var selection: Binding<Int>

        init(selection: Binding<Int>) {
            self.selection = selection
        }

        @objc func changed(_ sender: NSSegmentedControl) {
            selection.wrappedValue = sender.selectedSegment
        }
    }
}
