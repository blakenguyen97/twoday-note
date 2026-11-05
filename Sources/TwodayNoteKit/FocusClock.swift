import Foundation

/// A Pomodoro-style countdown: start, pause, resume, stop. It stores the
/// end time, not a count of ticks, so a late or missed tick never drifts.
public struct FocusClock: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case running(end: Date)
        case paused(remaining: TimeInterval)
        /// The time ran out; shown until the next start or a dismiss.
        case finished
    }

    public static let choices = [15, 25, 45, 60]

    public private(set) var phase: Phase = .idle
    public private(set) var duration: TimeInterval = 25 * 60

    public init() {}

    public var isRunning: Bool { if case .running = phase { true } else { false } }
    public var isPaused: Bool { if case .paused = phase { true } else { false } }
    public var isFinished: Bool { phase == .finished }

    public mutating func start(minutes: Int, now: Date = .now) {
        duration = TimeInterval(max(1, minutes) * 60)
        phase = .running(end: now.addingTimeInterval(duration))
    }

    public mutating func pause(now: Date = .now) {
        guard case .running(let end) = phase else { return }
        phase = .paused(remaining: max(0, end.timeIntervalSince(now)))
    }

    public mutating func resume(now: Date = .now) {
        guard case .paused(let remaining) = phase else { return }
        phase = .running(end: now.addingTimeInterval(remaining))
    }

    public mutating func stop() {
        phase = .idle
    }

    /// Seconds left while running or paused, nil otherwise.
    public func remaining(now: Date = .now) -> TimeInterval? {
        switch phase {
        case .running(let end): max(0, end.timeIntervalSince(now))
        case .paused(let remaining): remaining
        case .idle, .finished: nil
        }
    }

    /// 0 at the start, 1 at the end.
    public func progress(now: Date = .now) -> Double {
        guard let remaining = remaining(now: now), duration > 0 else { return isFinished ? 1 : 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    /// Moves to finished when the time is up. True only on that tick.
    public mutating func tick(now: Date = .now) -> Bool {
        guard case .running(let end) = phase, now >= end else { return false }
        phase = .finished
        return true
    }

    /// "25:00", "4:05", "0:01". Rounds up, so the last second shows 0:01, not 0:00.
    public static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
