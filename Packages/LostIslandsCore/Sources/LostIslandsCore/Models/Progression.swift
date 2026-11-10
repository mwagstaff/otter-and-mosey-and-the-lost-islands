import Foundation

public struct Achievement: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let emoji: String
}

/// What a child earned from finishing a level, for the celebration screen.
public struct RewardSummary: Equatable, Sendable {
    public var stars = 0
    public var isFirstClear = false
    public var isNewBest = false
    public var reward: Reward?
    public var crystalIsland: Island?
    public var achievements: [Achievement] = []
    public var decorations: [Reward] = []
    public var gameComplete = false

    public init(stars: Int = 0) { self.stars = stars }
}

/// Unlock rules, star ratings and achievements.
public enum Progression {
    /// Finishing always earns at least one star: effort is never shown as failure.
    public static func stars(forAccuracy accuracy: Double) -> Int {
        if accuracy >= 0.85 { return 3 }
        if accuracy >= 0.55 { return 2 }
        return 1
    }

    public static func isUnlocked(island: Island, in profile: Profile, catalog: Catalog = .shared) -> Bool {
        guard let index = catalog.islands.firstIndex(where: { $0.id == island.id }) else { return false }
        return index == 0 || profile.crystals.contains(catalog.islands[index - 1].id)
    }

    public static func isUnlocked(levelID: String, in profile: Profile, catalog: Catalog = .shared) -> Bool {
        guard let island = catalog.island(containing: levelID), isUnlocked(island: island, in: profile, catalog: catalog),
              let index = island.levels.firstIndex(where: { $0.id == levelID })
        else { return false }
        return index == 0 || profile.stars(for: island.levels[index - 1].id) > 0
    }

    /// The next level the child has not yet cleared, for the Continue button.
    public static func nextLevel(for profile: Profile, catalog: Catalog = .shared) -> LevelDef? {
        catalog.allLevels.first { profile.stars(for: $0.id) == 0 && isUnlocked(levelID: $0.id, in: profile, catalog: catalog) }
    }

    public static let achievements: [Achievement] = [
        Achievement(id: "first-steps", title: "First Steps", detail: "Finish your first level", emoji: "👣"),
        Achievement(id: "three-stars", title: "Shining Bright", detail: "Earn three stars on a level", emoji: "🌟"),
        Achievement(id: "perfect", title: "Flawless", detail: "Finish a level with every answer right first time", emoji: "💯"),
        Achievement(id: "combo-5", title: "Combo Champion", detail: "Get 5 right in a row", emoji: "🔥"),
        Achievement(id: "combo-8", title: "Rainbow Streak", detail: "Get 8 right in a row", emoji: "🌈"),
        Achievement(id: "crystal-1", title: "Crystal Finder", detail: "Recover a crystal fragment", emoji: "💎"),
        Achievement(id: "crystal-3", title: "Halfway Hero", detail: "Recover three crystal fragments", emoji: "🏅"),
        Achievement(id: "crystal-6", title: "World Restorer", detail: "Restore the Great Rainbow Crystal", emoji: "👑"),
        Achievement(id: "friendship", title: "Best Friends", detail: "Use Friendship Power", emoji: "💞"),
        Achievement(id: "pets-5", title: "Animal Friend", detail: "Collect five pets", emoji: "🐾"),
        Achievement(id: "answers-50", title: "Busy Brain", detail: "Answer 50 questions", emoji: "🧠"),
        Achievement(id: "answers-250", title: "Unstoppable", detail: "Answer 250 questions", emoji: "🚀"),
        Achievement(id: "wordsmith", title: "Wordsmith", detail: "Spell 40 words", emoji: "📚"),
        Achievement(id: "number-ninja", title: "Number Ninja", detail: "Answer 40 maths questions", emoji: "🔢"),
        Achievement(id: "fast-fingers", title: "Fast Fingers", detail: "Type at 15 words per minute", emoji: "⌨️"),
        Achievement(id: "stars-30", title: "Star Collector", detail: "Collect 30 stars", emoji: "✨"),
    ]

    /// Applies a finished level to the profile and reports what was newly earned.
    @discardableResult
    public static func apply(
        _ result: LevelResult, levelID: String, learner: LearnerModel, usedFriendshipPower: Int = 0,
        to profile: inout Profile, catalog: Catalog = .shared, now: Date = Date()
    ) -> RewardSummary {
        var summary = RewardSummary(stars: result.stars)
        guard let level = catalog.level(levelID), let island = catalog.island(containing: levelID) else { return summary }

        var record = profile.levels[levelID] ?? LevelRecord()
        summary.isFirstClear = record.stars == 0
        summary.isNewBest = result.stars > record.stars || result.score > record.bestScore
        record.stars = max(record.stars, result.stars)
        record.bestScore = max(record.bestScore, result.score)
        record.plays += 1
        profile.levels[levelID] = record
        profile.learner = learner
        profile.lastLevelID = levelID
        profile.bestCombo = max(profile.bestCombo, result.bestCombo)
        profile.friendshipPowers += usedFriendshipPower

        if summary.isFirstClear, let id = level.reward, let reward = catalog.reward(id), !profile.has(id) {
            profile.rewards.append(id)
            summary.reward = reward
        }
        if level.mode == .guardian, !profile.crystals.contains(island.id) {
            profile.crystals.append(island.id)
            summary.crystalIsland = island
            summary.gameComplete = profile.crystals.count == catalog.islands.count
        }
        for (needed, id) in Catalog.starDecorations {
            if profile.totalStars >= needed, !profile.has(id), let reward = catalog.reward(id) {
                profile.rewards.append(id)
                summary.decorations.append(reward)
            }
        }
        summary.achievements = newAchievements(for: profile, result: result)
        for achievement in summary.achievements { profile.achievements[achievement.id] = now }
        return summary
    }

    static func newAchievements(for profile: Profile, result: LevelResult, catalog: Catalog = .shared) -> [Achievement] {
        let learner = profile.learner
        let spelled = Skill.allCases.filter { $0.subject == .spelling }.reduce(0) { $0 + learner.stats(for: $1).correct }
        let sums = Skill.allCases.filter { $0.subject == .maths }.reduce(0) { $0 + learner.stats(for: $1).correct }
        let pets = profile.rewards.filter { catalog.reward($0)?.kind == .pet }.count
        let earned: [String: Bool] = [
            "first-steps": !profile.levels.isEmpty,
            "three-stars": result.stars >= 3,
            "perfect": result.total > 0 && result.correctFirstTry == result.total,
            "combo-5": profile.bestCombo >= 5,
            "combo-8": profile.bestCombo >= 8,
            "crystal-1": profile.crystals.count >= 1,
            "crystal-3": profile.crystals.count >= 3,
            "crystal-6": profile.crystals.count >= 6,
            "friendship": profile.friendshipPowers > 0,
            "pets-5": pets >= 5,
            "answers-50": learner.answerCount >= 50,
            "answers-250": learner.answerCount >= 250,
            "wordsmith": spelled >= 40,
            "number-ninja": sums >= 40,
            "fast-fingers": learner.typing.bestWordsPerMinute >= 15,
            "stars-30": profile.totalStars >= 30,
        ]
        return achievements.filter { earned[$0.id] == true && profile.achievements[$0.id] == nil }
    }
}
