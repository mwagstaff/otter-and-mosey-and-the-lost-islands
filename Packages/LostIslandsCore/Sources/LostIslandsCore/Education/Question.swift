import Foundation

/// How a question expects to be answered.
public enum AnswerFormat: String, Codable, Sendable {
    /// Pick one of `choices` (tap, drag, swim through).
    case choice
    /// Type `typingTarget` one character at a time.
    case typed
}

/// One educational challenge, independent of how any game mode presents it.
public struct Question: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Stable key for spaced repetition, e.g. `mul:7x8` or `word:because`.
    public let key: String
    public let skill: Skill
    public let format: AnswerFormat
    /// What to show: `7 × 8 = ?`, or a sentence with a gap.
    public let prompt: String
    /// The canonical full answer (`56`, `because`).
    public let answer: String
    /// For `.choice`: shuffled options including the right one.
    public let choices: [String]
    /// The right entry in `choices` (may differ from `answer`, e.g. missing letters `au`).
    public let correctChoice: String
    /// For spelling: the word with `_` where letters are missing. Nil when nothing is shown.
    public let masked: String?
    /// For `.typed`: exactly the characters the child must type, in order.
    public let typingTarget: String
    /// A gentle nudge shown on request or after repeated slips.
    public let hint: String
    /// What the narrator should say aloud.
    public let spoken: String
    public let level: Int
    /// True when the full word should be shown briefly and then hidden (look, cover, write).
    public let flashThenHide: Bool

    public init(
        id: UUID = UUID(), key: String, skill: Skill, format: AnswerFormat, prompt: String,
        answer: String, choices: [String] = [], correctChoice: String? = nil, masked: String? = nil,
        typingTarget: String? = nil, hint: String, spoken: String? = nil, level: Int,
        flashThenHide: Bool = false
    ) {
        self.id = id
        self.key = key
        self.skill = skill
        self.format = format
        self.prompt = prompt
        self.answer = answer
        self.choices = choices
        self.correctChoice = correctChoice ?? answer
        self.masked = masked
        self.typingTarget = typingTarget ?? answer
        self.hint = hint
        self.spoken = spoken ?? prompt
        self.level = level
        self.flashThenHide = flashThenHide
    }

    public func isCorrect(choice: String) -> Bool { choice == correctChoice }

    /// Lenient comparison for typed input: case and surrounding spaces never count against a child.
    public func isCorrect(typed: String) -> Bool {
        Question.normalise(typed) == Question.normalise(typingTarget)
    }

    public static func normalise(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Whether `character` is the right key for position `index` of the typing target.
    public func accepts(_ character: Character, at index: Int) -> Bool {
        let target = Array(typingTarget)
        guard target.indices.contains(index) else { return false }
        return Question.normalise(String(character)) == Question.normalise(String(target[index]))
    }
}
