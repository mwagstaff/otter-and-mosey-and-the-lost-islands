import Foundation

/// Parent-controlled limits on what a session may ask.
public struct ParentSettings: Codable, Equatable, Sendable {
    public var difficulty: DifficultyMode = .adaptive
    public var tables: [Int] = MathsGenerator.defaultTables
    public var spellingTopics: [Skill] = Skill.spellingTopics
    /// Suggested play time in minutes before a gentle break reminder. 0 means no reminder.
    public var sessionMinutes = 0
    /// Optional speed bonuses. Off by default: nothing in the game requires speed.
    public var timedChallenges = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = c.value(.difficulty, default: .adaptive)
        tables = c.value(.tables, default: MathsGenerator.defaultTables)
        spellingTopics = c.value(.spellingTopics, default: Skill.spellingTopics)
        sessionMinutes = c.value(.sessionMinutes, default: 0)
        timedChallenges = c.value(.timedChallenges, default: false)
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to a default when the key is missing or unreadable.
    /// This is what lets newer builds open older save files.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

public struct AnswerOutcome: Equatable, Sendable {
    public let points: Int
    public let combo: Int
    public let multiplier: Int
    public let praise: String
    public let isLevelComplete: Bool
}

public struct LevelResult: Codable, Equatable, Sendable {
    public var stars: Int
    public var accuracy: Double
    public var score: Int
    public var bestCombo: Int
    public var correctFirstTry: Int
    public var total: Int
    public var wordsPerMinute: Double?
    public var typingAccuracy: Double?

    public init(stars: Int, accuracy: Double, score: Int, bestCombo: Int, correctFirstTry: Int, total: Int,
                wordsPerMinute: Double? = nil, typingAccuracy: Double? = nil) {
        self.stars = stars
        self.accuracy = accuracy
        self.score = score
        self.bestCombo = bestCombo
        self.correctFirstTry = correctFirstTry
        self.total = total
        self.wordsPerMinute = wordsPerMinute
        self.typingAccuracy = typingAccuracy
    }
}

public enum Encouragement {
    public static let praise = [
        "Brilliant!", "Super!", "You did it!", "Fantastic!", "Spot on!", "Wonderful!", "Amazing!", "Great thinking!",
    ]
    public static let retry = [
        "Nearly! Have another go.", "Good try. Try again!", "So close!", "Keep going, you can do it!",
        "Not quite. Take your time.", "Mistakes help us learn!",
    ]
    public static let combo = ["Combo!", "On fire!", "Unstoppable!", "Rainbow streak!"]

    public static func pick<R: RandomNumberGenerator>(_ list: [String], using rng: inout R) -> String {
        list.randomElement(using: &rng) ?? ""
    }
}

/// Runs one level's worth of questions. Pure logic: scenes ask it for questions and tell
/// it what happened, so every game mode shares the same scoring and adaptive behaviour.
public struct ChallengeSession: Sendable {
    public let level: LevelDef
    public let settings: ParentSettings
    public let inputProfile: InputProfile
    public private(set) var learner: LearnerModel
    public private(set) var asked = 0
    public private(set) var completed = 0
    public private(set) var correctFirstTry = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    public private(set) var score = 0
    public private(set) var keystrokes = 0
    public private(set) var correctKeystrokes = 0
    public private(set) var wordsPerMinuteSamples: [Double] = []

    private var rng: SeededGenerator
    private var usedKeys: Set<String> = []
    private var usedTexts: Set<String> = []
    private let bank: WordBank

    public init(
        level: LevelDef, learner: LearnerModel, settings: ParentSettings = ParentSettings(),
        inputProfile: InputProfile = .compactTouch, seed: UInt64 = .random(in: 0...UInt64.max),
        bank: WordBank = .shared, questionLimit: Int? = nil
    ) {
        self.questionLimit = questionLimit
        self.level = level
        self.learner = learner
        self.settings = settings
        self.inputProfile = inputProfile
        self.bank = bank
        rng = SeededGenerator(seed: seed)
    }

    /// Optional cap on the number of questions, for shorter sessions.
    private let questionLimit: Int?

    public var total: Int { questionLimit.map { max(1, min($0, level.count)) } ?? level.count }
    public var isFinished: Bool { completed >= total }
    public var progress: Double { total == 0 ? 1 : Double(completed) / Double(total) }
    public var multiplier: Int { min(1 + combo / 3, 4) }

    /// Skills this level may use after applying the parent's topic choices.
    var activeSkills: [Skill] {
        let allowed = level.skills.filter { $0.subject != .spelling || settings.spellingTopics.contains($0) }
        return allowed.isEmpty ? level.skills : allowed
    }

    /// The next question, or nil once the level has asked everything.
    public mutating func next() -> Question? {
        guard asked < total else { return nil }
        asked += 1
        let skills = activeSkills

        // Spaced repetition: bring back something the child found tricky.
        if asked > 1, Double.random(in: 0..<1, using: &rng) < 0.35,
           let key = learner.dueKeys(for: skills).first(where: { !usedKeys.contains($0) }),
           let review = question(forKey: key) {
            usedKeys.insert(key)
            return review
        }

        let skill = skills[(asked - 1 + Int.random(in: 0..<skills.count, using: &rng)) % skills.count]
        let question = fresh(skill: skill)
        usedKeys.insert(question.key)
        return question
    }

    private func format(for skill: Skill) -> AnswerFormat {
        switch level.mode {
        case .wordBlaster, .typingTurbo, .eggRescue: .typed
        case .mathsSplash, .bridgeBuilder: .choice
        case .guardian: skill.subject == .maths ? .choice : .typed
        }
    }

    private mutating func fresh(skill: Skill) -> Question {
        let pitch = learner.level(for: skill, mode: settings.difficulty)
        switch skill.subject {
        case .maths:
            for _ in 0..<8 {
                let candidate = MathsGenerator.make(skill: skill, level: pitch, tables: settings.tables, format: format(for: skill), using: &rng)
                if !usedTexts.contains(candidate.prompt) {
                    usedTexts.insert(candidate.prompt)
                    return candidate
                }
            }
            return MathsGenerator.make(skill: skill, level: pitch, tables: settings.tables, format: format(for: skill), using: &rng)
        case .typing:
            let question = SpellingGenerator.typing(level: pitch, profile: inputProfile, bank: bank, avoiding: usedTexts, using: &rng)
            usedTexts.insert(question.answer)
            return question
        case .spelling:
            let pool = bank.pool(topics: [skill], level: pitch)
            let unused = pool.filter { !usedTexts.contains($0.word) }
            let entry = (unused.isEmpty ? pool : unused).randomElement(using: &rng)!
            usedTexts.insert(entry.word)
            return SpellingGenerator.make(entry: entry, style: format(for: skill) == .typed ? .typed : .choice,
                                          level: pitch, bank: bank, using: &rng)
        }
    }

    private mutating func question(forKey key: String) -> Question? {
        if key.hasPrefix("word:"), let entry = bank.entry(for: String(key.dropFirst(5))) {
            guard !usedTexts.contains(entry.word) else { return nil }
            usedTexts.insert(entry.word)
            let pitch = max(1, learner.level(for: entry.topic, mode: settings.difficulty) - 1)
            return SpellingGenerator.make(entry: entry, style: format(for: entry.topic) == .typed ? .typed : .choice,
                                          level: pitch, bank: bank, using: &rng)
        }
        let skill: Skill = key.hasPrefix("div:") ? .division : .multiplication
        return MathsGenerator.make(factKey: key, level: learner.level(for: skill, mode: settings.difficulty),
                                   format: format(for: skill), using: &rng)
    }

    /// A wrong attempt. The question stays open; only the combo is lost.
    public mutating func recordSlip() {
        combo = 0
    }

    /// The question has been answered correctly (possibly after slips or a hint).
    public mutating func complete(_ question: Question, firstTry: Bool, seconds: Double, usedHint: Bool) -> AnswerOutcome {
        completed += 1
        learner.record(key: question.key, skill: question.skill, correct: firstTry, seconds: seconds, usedHint: usedHint)
        let points: Int
        if firstTry {
            correctFirstTry += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            points = 100 * multiplier + (settings.timedChallenges && seconds < 5 ? 50 : 0)
        } else {
            combo = 0
            points = 40
        }
        score += points
        let praise = combo >= 3 && combo % 3 == 0
            ? Encouragement.pick(Encouragement.combo, using: &rng)
            : Encouragement.pick(Encouragement.praise, using: &rng)
        return AnswerOutcome(points: points, combo: combo, multiplier: multiplier, praise: praise, isLevelComplete: isFinished)
    }

    public mutating func retryMessage() -> String { Encouragement.pick(Encouragement.retry, using: &rng) }

    /// Typing measurements for one finished word or sentence.
    public mutating func recordTyping(keystrokes: Int, correct: Int, wordsPerMinute: Double?) {
        self.keystrokes += keystrokes
        correctKeystrokes += correct
        if let wordsPerMinute { wordsPerMinuteSamples.append(wordsPerMinute) }
        learner.typing.record(keystrokes: keystrokes, correct: correct, wordsPerMinute: wordsPerMinute)
    }

    public var result: LevelResult {
        let accuracy = total == 0 ? 1 : Double(correctFirstTry) / Double(total)
        let typingAccuracy = keystrokes == 0 ? nil : Double(correctKeystrokes) / Double(keystrokes)
        // Typing levels are judged on key accuracy, never on speed.
        let judged = level.mode == .typingTurbo ? (typingAccuracy ?? accuracy) : accuracy
        return LevelResult(
            stars: Progression.stars(forAccuracy: judged), accuracy: judged, score: score, bestCombo: bestCombo,
            correctFirstTry: correctFirstTry, total: total,
            wordsPerMinute: wordsPerMinuteSamples.isEmpty ? nil : wordsPerMinuteSamples.reduce(0, +) / Double(wordsPerMinuteSamples.count),
            typingAccuracy: typingAccuracy
        )
    }
}

/// Measures typing accuracy and speed for one piece of text.
public struct TypingMeter: Sendable {
    public private(set) var keystrokes = 0
    public private(set) var correct = 0
    private var firstKey: Date?
    private var lastKey: Date?

    public init() {}

    public mutating func record(correct isCorrect: Bool, at time: Date = Date()) {
        keystrokes += 1
        if isCorrect { correct += 1 }
        if firstKey == nil { firstKey = time }
        lastKey = time
    }

    public var accuracy: Double { keystrokes == 0 ? 1 : Double(correct) / Double(keystrokes) }

    /// Standard words per minute (five characters per word). Nil until there is enough to measure.
    public var wordsPerMinute: Double? {
        guard let firstKey, let lastKey, correct >= 5 else { return nil }
        let minutes = lastKey.timeIntervalSince(firstKey) / 60
        guard minutes > 0.01 else { return nil }
        return (Double(correct) / 5) / minutes
    }
}
