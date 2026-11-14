import Foundation

/// A parent-selectable ceiling or floor on the adaptive level.
public enum DifficultyMode: String, Codable, CaseIterable, Sendable {
    case adaptive, gentle, steady, stretch

    public var title: String {
        switch self {
        case .adaptive: "Adaptive (recommended)"
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .stretch: "Stretch"
        }
    }

    func clamp(_ level: Int) -> Int {
        switch self {
        case .adaptive: min(max(level, 1), 5)
        case .gentle: min(max(level, 1), 2)
        case .steady: min(max(level, 2), 4)
        case .stretch: min(max(level, 3), 5)
        }
    }
}

/// Running record for one skill.
public struct SkillStats: Codable, Equatable, Sendable {
    public var attempts = 0
    public var correct = 0
    public var streak = 0
    /// Continuous proficiency from 1.0 (just starting) to 5.0 (secure). The whole part is the level.
    public var rating = 1.0
    public var totalSeconds = 0.0
    /// The most recent answers, newest last (true = right first time).
    public var recent: [Bool] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = c.value(.attempts, default: 0)
        correct = c.value(.correct, default: 0)
        streak = c.value(.streak, default: 0)
        rating = c.value(.rating, default: 1.0)
        totalSeconds = c.value(.totalSeconds, default: 0)
        recent = c.value(.recent, default: [])
    }

    public var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }
    public var averageSeconds: Double { attempts == 0 ? 0 : totalSeconds / Double(attempts) }
    public var recentAccuracy: Double {
        recent.isEmpty ? 0 : Double(recent.filter { $0 }.count) / Double(recent.count)
    }
}

/// Leitner-style memory for one troublesome item (a word or a number fact).
public struct ItemMemory: Codable, Equatable, Sendable {
    /// 0 = just missed … 4 = nearly secure.
    public var box = 0
    /// The answer count at which this item should come back.
    public var dueAt = 0
    public var lapses = 1
    public var skill: Skill

    public init(skill: Skill) { self.skill = skill }
}

public struct TypingStats: Codable, Equatable, Sendable {
    public var keystrokes = 0
    public var correctKeystrokes = 0
    public var bestWordsPerMinute = 0.0
    /// Recent words-per-minute samples typed on a real keyboard, newest last.
    public var samples: [Double] = []
    /// The same, typed on the game's on-screen keys. Kept apart because tapping is much
    /// slower than typing, so mixing the two would make either figure misleading.
    public var touchSamples: [Double] = []
    public var bestTouchWordsPerMinute = 0.0

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keystrokes = c.value(.keystrokes, default: 0)
        correctKeystrokes = c.value(.correctKeystrokes, default: 0)
        bestWordsPerMinute = c.value(.bestWordsPerMinute, default: 0)
        samples = c.value(.samples, default: [])
        touchSamples = c.value(.touchSamples, default: [])
        bestTouchWordsPerMinute = c.value(.bestTouchWordsPerMinute, default: 0)
    }

    public var accuracy: Double { keystrokes == 0 ? 0 : Double(correctKeystrokes) / Double(keystrokes) }
    public var averageWordsPerMinute: Double { samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count) }
    public var averageTouchWordsPerMinute: Double { touchSamples.isEmpty ? 0 : touchSamples.reduce(0, +) / Double(touchSamples.count) }

    /// Adds one finished word or sentence. `onScreenKeys` says it was tapped rather than typed.
    public mutating func record(keystrokes: Int, correct: Int, wordsPerMinute: Double?, onScreenKeys: Bool = false) {
        self.keystrokes += keystrokes
        correctKeystrokes += correct
        guard let wordsPerMinute, wordsPerMinute > 0 else { return }
        if onScreenKeys {
            touchSamples.append(wordsPerMinute)
            if touchSamples.count > 20 { touchSamples.removeFirst(touchSamples.count - 20) }
            bestTouchWordsPerMinute = max(bestTouchWordsPerMinute, wordsPerMinute)
        } else {
            samples.append(wordsPerMinute)
            if samples.count > 20 { samples.removeFirst(samples.count - 20) }
            bestWordsPerMinute = max(bestWordsPerMinute, wordsPerMinute)
        }
    }
}

/// Everything the game knows about how one child is getting on. Drives adaptive
/// difficulty and spaced repetition, and feeds the parent dashboard.
public struct LearnerModel: Codable, Equatable, Sendable {
    public private(set) var skills: [String: SkillStats] = [:]
    public private(set) var items: [String: ItemMemory] = [:]
    public private(set) var answerCount = 0
    public var typing = TypingStats()

    /// How many answers pass before an item in each box returns.
    static let intervals = [3, 8, 20, 45, 100]
    static let recentWindow = 12

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skills = c.value(.skills, default: [:])
        items = c.value(.items, default: [:])
        answerCount = c.value(.answerCount, default: 0)
        typing = c.value(.typing, default: TypingStats())
    }

    public func stats(for skill: Skill) -> SkillStats { skills[skill.rawValue] ?? SkillStats() }

    /// The level (1–5) to pitch the next question at.
    public func level(for skill: Skill, mode: DifficultyMode = .adaptive) -> Int {
        mode.clamp(Int(stats(for: skill).rating.rounded(.down)))
    }

    /// Records a first attempt at a question.
    public mutating func record(key: String, skill: Skill, correct: Bool, seconds: Double, usedHint: Bool) {
        answerCount += 1
        var stats = self.stats(for: skill)
        stats.attempts += 1
        stats.totalSeconds += min(max(seconds, 0), 120)
        let cleanCorrect = correct && !usedHint
        stats.recent.append(cleanCorrect)
        if stats.recent.count > Self.recentWindow { stats.recent.removeFirst(stats.recent.count - Self.recentWindow) }

        if correct {
            stats.correct += 1
            stats.streak += 1
            let quick = seconds < 6
            var gain = usedHint ? 0.04 : (quick ? 0.18 : 0.12)
            if stats.streak >= 5, !usedHint { gain += 0.05 }
            stats.rating = min(5.0, stats.rating + gain)
        } else {
            stats.streak = 0
            // Mistakes ease the level down gently; two in a row eases a little more.
            let recentMisses = stats.recent.suffix(3).filter { !$0 }.count
            stats.rating = max(1.0, stats.rating - (recentMisses >= 2 ? 0.3 : 0.2))
        }
        skills[skill.rawValue] = stats
        updateMemory(key: key, skill: skill, correct: cleanCorrect)
    }

    private mutating func updateMemory(key: String, skill: Skill, correct: Bool) {
        // Only specific facts and words are worth revisiting; generic "topic at level" keys are not.
        guard key.hasPrefix("word:") || key.hasPrefix("mul:") || key.hasPrefix("div:") else { return }
        if correct {
            guard var memory = items[key] else { return }
            memory.box += 1
            if memory.box >= Self.intervals.count {
                items[key] = nil
            } else {
                memory.dueAt = answerCount + Self.intervals[memory.box]
                items[key] = memory
            }
        } else {
            var memory = items[key] ?? ItemMemory(skill: skill)
            if items[key] != nil { memory.lapses += 1 }
            memory.box = 0
            memory.dueAt = answerCount + Self.intervals[0]
            items[key] = memory
        }
    }

    /// Troublesome items that are ready to be practised again, most overdue first.
    public func dueKeys(for skills: [Skill]) -> [String] {
        items.filter { skills.contains($0.value.skill) && $0.value.dueAt <= answerCount }
            .sorted { ($0.value.dueAt, $0.key) < ($1.value.dueAt, $1.key) }
            .map(\.key)
    }

    /// Words and facts the child has slipped on more than once, for the parent dashboard.
    public var troublesomeItems: [(key: String, lapses: Int)] {
        items.filter { $0.value.lapses >= 2 }
            .sorted { $0.value.lapses != $1.value.lapses ? $0.value.lapses > $1.value.lapses : $0.key < $1.key }
            .map { ($0.key, $0.value.lapses) }
    }

    public func accuracy(for subject: Subject) -> Double? {
        let relevant = Skill.allCases.filter { $0.subject == subject }.map { stats(for: $0) }
        let attempts = relevant.reduce(0) { $0 + $1.attempts }
        guard attempts > 0 else { return nil }
        return Double(relevant.reduce(0) { $0 + $1.correct }) / Double(attempts)
    }

    public var practisedSkills: [Skill] { Skill.allCases.filter { stats(for: $0).attempts > 0 } }

    /// Skills with enough evidence to say they need more practice.
    public var skillsNeedingPractice: [Skill] {
        Skill.allCases.filter {
            let stats = self.stats(for: $0)
            return stats.attempts >= 5 && stats.recentAccuracy < 0.6
        }
    }
}
