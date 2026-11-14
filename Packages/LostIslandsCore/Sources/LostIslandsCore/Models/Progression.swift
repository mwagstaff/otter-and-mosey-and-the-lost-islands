import Foundation

/// What a child earned from finishing a level, for the celebration screen.
public struct RewardSummary: Equatable, Sendable {
    public var stars = 0
    public var isFirstClear = false
    public var isNewBest = false
    public var reward: Reward?
    public var crystalIsland: Island?
    /// Trophies handed out at the end of this level, at most `Trophies.perLevel`.
    public var trophies: [Trophy] = []
    /// Trophies won but held back for a later level.
    public var trophiesWaiting = 0
    /// The cabinet after this level: trophies won, out of how many.
    public var trophyCount = 0
    public var trophyTotal = 0
    public var decorations: [Reward] = []
    public var gameComplete = false

    public init(stars: Int = 0) { self.stars = stars }
}

/// Unlock rules, star ratings and what a finished level earns.
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

    /// Applies a finished level to the profile and reports what was newly earned.
    @discardableResult
    public static func apply(
        _ result: LevelResult, levelID: String, learner: LearnerModel, usedFriendshipPower: Int = 0,
        to profile: inout Profile, catalog: Catalog = .shared, now: Date = Date(), calendar: Calendar = .current
    ) -> RewardSummary {
        var summary = RewardSummary(stars: result.stars)
        guard let level = catalog.level(levelID), let island = catalog.island(containing: levelID) else { return summary }
        Trophies.prepare(&profile, catalog: catalog, now: now)

        var record = profile.levels[levelID] ?? LevelRecord()
        let run = TrophyRun(levelID: levelID, islandID: island.id, mode: level.mode, result: result, previousStars: record.stars,
                            guardianAlreadyFriend: level.mode == .guardian && profile.crystals.contains(island.id))
        summary.isFirstClear = record.stars == 0
        if result.total > 0, result.correctFirstTry >= result.total { record.flawless = true }
        summary.isNewBest = result.stars > record.stars || result.score > record.bestScore
        record.stars = max(record.stars, result.stars)
        record.bestScore = max(record.bestScore, result.score)
        record.plays += 1
        profile.levels[levelID] = record
        profile.learner = learner
        profile.lastLevelID = levelID
        profile.bestCombo = max(profile.bestCombo, result.bestCombo)
        profile.friendshipPowers += usedFriendshipPower
        tally(result, on: now, into: &profile, calendar: calendar)

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
        summary.trophies = Trophies.award(&profile, run: run, catalog: catalog, now: now)
        summary.trophiesWaiting = profile.pendingTrophies.count
        (summary.trophyCount, summary.trophyTotal) = Trophies.count(in: profile, catalog: catalog)
        return summary
    }

    /// Adds a finished level to the lifetime counts the trophy cabinet uses.
    static func tally(_ result: LevelResult, on now: Date, into profile: inout Profile, calendar: Calendar) {
        profile.stats.pearls += result.pearls
        for (table, count) in result.tableFirstTry { profile.stats.tableFirstTry[table, default: 0] += count }
        let today = Profile.dayKey(now, calendar: calendar)
        if profile.stats.lastPlayDay != today {
            profile.stats.playDays += 1
            profile.stats.lastPlayDay = today
        }
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7, !profile.stats.weekendDays.contains(weekday) { profile.stats.weekendDays.append(weekday) }
        profile.stats.hatStreak = profile.equippedAccessory == nil ? 0 : profile.stats.hatStreak + 1
    }
}
