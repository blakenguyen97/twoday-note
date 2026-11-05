import SwiftUI

/// Animation and timing tokens. Views never hard-code a duration.
enum Motion {
    /// A change on screen: a block appears, a tab switches, a check ticks.
    static let change: Animation = .snappy
    /// Paging through the guide.
    static let page: Animation = .smooth
    /// A key going down and up in a guide demo.
    static let press: Animation = .snappy(duration: 0.18)
    /// The text cursor's blink.
    static let blink: Animation = .easeInOut(duration: 0.5)

    /// How long a guide demo holds each step.
    static let beat: Duration = .seconds(1.1)
    /// A longer hold, before a demo starts over.
    static let hold: Duration = .seconds(2.2)
    /// One typed letter in a guide demo.
    static let keystroke: Duration = .milliseconds(60)
    /// How long a key stays down.
    static let keyDown: Duration = .milliseconds(220)
}
