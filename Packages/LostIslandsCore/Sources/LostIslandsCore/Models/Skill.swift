import Foundation

/// The broad subject a skill belongs to. Used for dashboards and accuracy totals.
public enum Subject: String, Codable, CaseIterable, Sendable {
    case spelling, typing, maths

    public var title: String {
        switch self {
        case .spelling: "Spelling"
        case .typing: "Typing"
        case .maths: "Maths"
        }
    }
}

/// A single trackable skill. Raw values are stable: they are used as save-data keys.
public enum Skill: String, Codable, CaseIterable, Sendable {
    case exceptionWords, prefixes, suffixes, homophones, starterWords
    case typing
    case addition, subtraction, multiplication, division
    case fractions, placeValue, sequences, wordProblems

    public var subject: Subject {
        switch self {
        case .exceptionWords, .prefixes, .suffixes, .homophones, .starterWords: .spelling
        case .typing: .typing
        default: .maths
        }
    }

    public var title: String {
        switch self {
        case .exceptionWords: "Tricky words"
        case .prefixes: "Prefixes"
        case .suffixes: "Suffixes"
        case .homophones: "Homophones"
        case .starterWords: "Warm-up words"
        case .typing: "Typing"
        case .addition: "Addition"
        case .subtraction: "Subtraction"
        case .multiplication: "Times tables"
        case .division: "Division"
        case .fractions: "Fractions"
        case .placeValue: "Place value"
        case .sequences: "Number sequences"
        case .wordProblems: "Word problems"
        }
    }

    public static var spellingTopics: [Skill] { [.starterWords, .exceptionWords, .prefixes, .suffixes, .homophones] }
    public static var mathsTopics: [Skill] { allCases.filter { $0.subject == .maths } }
}

/// How the child is entering text. Typing content adapts to this.
public enum InputProfile: String, Codable, Sendable {
    /// iPhone-sized touch keyboard: short words, letter trays.
    case compactTouch
    /// iPad-sized touch keyboard: longer words and short sentences.
    case fullTouch
    /// Hardware keyboard attached: full sentences, speed is measured.
    case hardware
}

/// Deterministic generator so question generation can be tested and replayed.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
