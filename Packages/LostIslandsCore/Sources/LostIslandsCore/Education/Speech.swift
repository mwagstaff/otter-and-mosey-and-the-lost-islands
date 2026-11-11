import Foundation

/// Turns a stream of loudness readings into "mouth open" or "mouth closed" without flicker.
/// Two thresholds stop it chattering around one level, and a minimum hold keeps each state
/// on screen long enough to read as a mouth movement.
public struct MouthGate: Sendable {
    public var openAbove: Double
    public var closeBelow: Double
    public var minimumHold: Double
    public private(set) var isOpen = false
    private var lastChange = -Double.infinity

    public init(openAbove: Double = 0.35, closeBelow: Double = 0.2, minimumHold: Double = 0.07) {
        self.openAbove = openAbove
        self.closeBelow = closeBelow
        self.minimumHold = minimumHold
    }

    /// Feeds one loudness reading (0–1) taken at `time` seconds and returns the mouth state.
    @discardableResult
    public mutating func update(level: Double, at time: Double) -> Bool {
        guard time - lastChange >= minimumHold else { return isOpen }
        let wanted = isOpen ? level > closeBelow : level > openAbove
        if wanted != isOpen {
            isOpen = wanted
            lastChange = time
        }
        return isOpen
    }
}

/// A made-up talking rhythm for lines that have no recording (or when sound is off),
/// so the speaker is still shown moving their mouth.
public enum Chatter {
    /// How long a silent line "talks" for, from its length.
    public static func duration(forTextLength count: Int) -> Double {
        min(max(Double(count) * 0.06, 1.0), 4.0)
    }

    /// Loudness (0–1) at `time` seconds into a line lasting `duration` seconds:
    /// about four and a half syllables a second, with a slower swell so it is not mechanical.
    public static func level(at time: Double, duration: Double) -> Double {
        guard time >= 0, time < duration else { return 0 }
        let syllable = abs(sin(.pi * 4.5 * time))
        let swell = 0.7 + 0.3 * sin(2.3 * time + 0.6)
        let fadeOut = min(1, (duration - time) / 0.15)
        return syllable * swell * fadeOut
    }
}
