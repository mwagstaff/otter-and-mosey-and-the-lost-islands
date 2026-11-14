import Foundation

/// The shelves of the trophy cabinet.
public enum TrophyGroup: String, CaseIterable, Sendable {
    case islands, milestones, learning, collections, secret

    public var title: String {
        switch self {
        case .islands: "Islands"
        case .milestones: "Milestones"
        case .learning: "Learning"
        case .collections: "Collections"
        case .secret: "Secret"
        }
    }
}

/// Lifetime counts that feed the milestone ladders. Each one is a number the cabinet can show
/// as "486 of 500".
public enum TrophyCounter: String, CaseIterable, Sendable {
    case stars, pearls, answers, firstTry, words, maths, streak, typing, levels, friendship, days, crystals

    public var unit: String {
        switch self {
        case .stars: "stars"
        case .pearls: "pearls"
        case .answers: "right answers"
        case .firstTry: "right first time"
        case .words: "words spelt"
        case .maths: "maths answers"
        case .streak: "in a row"
        case .typing: "words a minute"
        case .levels: "levels played"
        case .friendship: "Friendship Power uses"
        case .days: "days played"
        case .crystals: "fragments"
        }
    }
}

/// What has to happen for a trophy to be won.
public enum TrophyRule: Equatable, Sendable {
    case superstar(level: String)
    case flawless(level: String)
    case guardianFriend(island: String)
    case champion(island: String)
    case count(TrophyCounter, Int)
    case skill(Skill)
    case table(Int)
    case firstSteps, pets(Int), allPets, allHats, decorations(Int), allTreasures
    case comeback, neverGiveUp, pearlPerfect, turboAce, hatTrick, oldFriends, backForMore, weekend, noHints, rainbowDay

    /// Won by one particular run rather than by something that stays true. These have to be
    /// remembered as waiting if there is no room to hand them out straight away.
    var isMoment: Bool {
        switch self {
        case .comeback, .neverGiveUp, .pearlPerfect, .turboAce, .oldFriends, .noHints: true
        default: false
        }
    }
}

public struct Trophy: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// How to win it, in words a child can follow.
    public let detail: String
    /// For a secret trophy, the riddle shown until it is won.
    public let riddle: String?
    public let group: TrophyGroup
    /// The painted picture.
    public let art: String
    /// 0 for a one-off trophy; 1…5 for the rung of a milestone ladder (bronze, silver, gold, rainbow, sky).
    public let tier: Int
    public let rule: TrophyRule
    public let islandID: String?
    public let levelID: String?
    /// Groups the rungs of one milestone ladder, such as "answers".
    public let ladder: String?
    /// The short label printed on a rung or a learning badge, such as "250" or "×3".
    public let badge: String?

    init(_ id: String, _ title: String, _ detail: String, group: TrophyGroup, art: String, rule: TrophyRule, tier: Int = 0,
         riddle: String? = nil, islandID: String? = nil, levelID: String? = nil, ladder: String? = nil, badge: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.riddle = riddle
        self.group = group
        self.art = art
        self.tier = tier
        self.rule = rule
        self.islandID = islandID
        self.levelID = levelID
        self.ladder = ladder
        self.badge = badge
    }
}

/// One milestone ladder: a counter and its rungs.
public struct TrophyLadder: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let counter: TrophyCounter
    public let rungs: [Int]
    let art: @Sendable (Int) -> String
}

/// Facts about the level that has just finished, for trophies won by a single run.
struct TrophyRun {
    var levelID: String
    var islandID: String
    var mode: GameMode
    var result: LevelResult
    var previousStars: Int
    var guardianAlreadyFriend: Bool
}

/// The trophy cabinet: every trophy there is, when each is won, and how many are handed out
/// at the end of a level.
public enum Trophies {
    /// The most trophies handed out at the end of one level. Any more wait for the next level.
    public static let perLevel = 2

    public static let ladders: [TrophyLadder] = [
        TrophyLadder(id: "stars", title: "Star Collector", counter: .stars, rungs: [10, 30, 60, 90]) { _ in "badge_stars-30" },
        TrophyLadder(id: "pearls", title: "Pearl Diver", counter: .pearls, rungs: [25, 100, 250, 500]) { _ in "badge_pearls" },
        TrophyLadder(id: "answers", title: "Busy Brain", counter: .answers, rungs: [50, 100, 250, 500, 1000]) { $0 < 250 ? "badge_answers-50" : "badge_answers-250" },
        TrophyLadder(id: "first-try", title: "Sharp Shooter", counter: .firstTry, rungs: [25, 100, 250, 500]) { _ in "badge_sharp-shooter" },
        TrophyLadder(id: "words", title: "Wordsmith", counter: .words, rungs: [40, 150, 400]) { _ in "badge_wordsmith" },
        TrophyLadder(id: "maths", title: "Number Ninja", counter: .maths, rungs: [40, 150, 400]) { _ in "badge_number-ninja" },
        TrophyLadder(id: "combo", title: "Streak Star", counter: .streak, rungs: [5, 8, 9]) { "badge_combo-\($0)" },
        TrophyLadder(id: "typing", title: "Fast Fingers", counter: .typing, rungs: [8, 12, 15, 20]) { _ in "badge_fast-fingers" },
        TrophyLadder(id: "levels", title: "Adventurer", counter: .levels, rungs: [10, 30, 60, 100]) { _ in "badge_adventurer" },
        TrophyLadder(id: "friends", title: "Best Friends", counter: .friendship, rungs: [1, 10, 30]) { _ in "badge_friendship" },
        TrophyLadder(id: "days", title: "Explorer", counter: .days, rungs: [2, 5, 10, 20]) { _ in "badge_explorer" },
        TrophyLadder(id: "crystals", title: "Crystal Keeper", counter: .crystals, rungs: [3, 6]) { "badge_crystal-\($0)" },
    ]

    /// The timetables with a learning trophy each.
    public static let tables = [2, 3, 4, 5, 8, 10]
    /// Right-first-time answers needed for a learning trophy.
    public static let mastery = 20

    /// Every trophy, in cabinet order.
    public static func all(_ catalog: Catalog = .shared) -> [Trophy] {
        if let cached = sharedList, catalog.allLevels.map(\.id) == Catalog.shared.allLevels.map(\.id),
           catalog.rewards.count == Catalog.shared.rewards.count { return cached }
        return build(catalog)
    }

    private static let sharedList: [Trophy]? = build(.shared)

    public static func trophy(_ id: String, catalog: Catalog = .shared) -> Trophy? {
        all(catalog).first { $0.id == id }
    }

    private static func build(_ catalog: Catalog) -> [Trophy] {
        var list: [Trophy] = []
        for island in catalog.islands {
            for level in island.levels {
                list.append(Trophy("superstar-\(level.id)", "Superstar", "Earn three stars in \(level.title).", group: .islands,
                                   art: "badge_three-stars", rule: .superstar(level: level.id), islandID: island.id, levelID: level.id))
                list.append(Trophy("flawless-\(level.id)", "Flawless", "Get every answer right first time in \(level.title).", group: .islands,
                                   art: "badge_perfect", rule: .flawless(level: level.id), islandID: island.id, levelID: level.id))
            }
            list.append(Trophy("friend-\(island.id)", "\(island.guardian.name)’s Friend", "Befriend \(island.guardian.name) and find the \(island.name) crystal fragment.",
                               group: .islands, art: "badge_crystal-1", rule: .guardianFriend(island: island.id), islandID: island.id))
            list.append(Trophy("champion-\(island.id)", "\(island.name) Champion", "Earn three stars on every level of \(island.name).",
                               group: .islands, art: "trophy_champion", rule: .champion(island: island.id), islandID: island.id))
        }
        for ladder in ladders {
            for (index, rung) in ladder.rungs.enumerated() {
                let detail = switch ladder.counter {
                case .streak: rung == 9 ? "Get all 9 right in a row in a guardian battle." : "Get \(rung) right in a row."
                case .typing: "Type at \(rung) words a minute."
                case .friendship: rung == 1 ? "Use Friendship Power." : "Use Friendship Power \(rung) times."
                case .days: "Play on \(rung) different days."
                case .crystals: rung == 6 ? "Restore the Great Rainbow Crystal." : "Recover \(rung) crystal fragments."
                case .levels: "Finish \(rung) levels."
                default: "Collect \(rung) \(ladder.counter.unit)."
                }
                list.append(Trophy("\(ladder.id)-\(rung)", ladder.title, detail, group: .milestones, art: ladder.art(rung),
                                   rule: .count(ladder.counter, rung), tier: index + 1, ladder: ladder.id, badge: "\(rung)"))
            }
        }
        for table in tables {
            list.append(Trophy("table-\(table)", "×\(table) table", "Get \(mastery) answers in the \(table) times table right first time.",
                               group: .learning, art: "badge_tables", rule: .table(table), badge: "×\(table)"))
        }
        let topics: [(Skill, String, String)] = [
            (.prefixes, "Prefix Pro", "badge_prefixes"), (.suffixes, "Suffix Star", "badge_suffixes"),
            (.homophones, "Homophone Hero", "badge_homophones"), (.exceptionWords, "Tricky Word Tamer", "badge_tricky-words"),
            (.fractions, "Fraction Finder", "badge_fractions"), (.division, "Fair Sharer", "badge_division"),
            (.placeValue, "Place Value Pal", "badge_place-value"), (.wordProblems, "Puzzle Solver", "badge_word-problems"),
        ]
        for (skill, title, art) in topics {
            list.append(Trophy("skill-\(skill.rawValue)", title, "Get \(mastery) \(skill.title.lowercased()) questions right first time.",
                               group: .learning, art: art, rule: .skill(skill)))
        }
        let pets = catalog.rewards.filter { $0.kind == .pet }.count
        list += [
            Trophy("first-steps", "First Steps", "Finish your first level.", group: .collections, art: "badge_first-steps", rule: .firstSteps),
            Trophy("pets-5", "Animal Friend", "Collect five pets.", group: .collections, art: "badge_pets-5", rule: .pets(5)),
            Trophy("pets-all", "Animal Park", "Collect all \(pets) pets.", group: .collections, art: "badge_pets-all", rule: .allPets),
            Trophy("hats-all", "Dress-up", "Try on every hat.", group: .collections, art: "badge_hats-all", rule: .allHats),
            Trophy("decorator", "Home Designer", "Put 8 decorations on your Home island.", group: .collections, art: "badge_decorator", rule: .decorations(8)),
            Trophy("treasure-all", "Treasure Hunter", "Collect every treasure in the game.", group: .collections, art: "badge_treasure-all", rule: .allTreasures),
        ]
        let secrets: [(String, String, String, String, TrophyRule)] = [
            ("comeback", "Comeback Kid", "Get a question right after two wrong tries.", "Try, try and try again…", .comeback),
            ("never-give-up", "Never Give Up", "Turn a one-star level into three stars.", "One becomes three…", .neverGiveUp),
            ("pearl-perfect", "Pearl Perfect", "Scoop every pearl in a Maths Splash level.", "Every pearl, every time…", .pearlPerfect),
            ("turbo-ace", "Turbo Ace", "Type with no slips at all in Typing Turbo.", "Faster than a comet, with no slips…", .turboAce),
            ("hat-trick", "Hat Trick", "Finish three levels in a row wearing a hat.", "Wear it, wear it, wear it!", .hatTrick),
            ("old-friends", "Old Friends", "Visit a guardian you’ve already befriended.", "Pop in on a friend…", .oldFriends),
            ("back-for-more", "Back for More", "Play the same level three times.", "Once more, with feeling…", .backForMore),
            ("weekend", "Weekend Explorer", "Play on a Saturday and on a Sunday.", "Saturday… and Sunday?", .weekend),
            ("no-hints", "No Help Needed", "Beat a guardian without a single hint.", "No help needed…", .noHints),
            ("rainbow-day", "Rainbow Day", "Win trophies on three different islands in one day.", "Three islands, one day…", .rainbowDay),
        ]
        for (id, title, detail, riddle, rule) in secrets {
            list.append(Trophy(id, title, detail, group: .secret, art: "badge_\(id)", rule: rule, riddle: riddle))
        }
        return list
    }

    // MARK: - Counting

    public static func value(of counter: TrophyCounter, in profile: Profile) -> Int {
        let learner = profile.learner
        switch counter {
        case .stars: return profile.totalStars
        case .pearls: return profile.stats.pearls
        case .answers: return learner.answerCount
        case .firstTry: return Skill.allCases.reduce(0) { $0 + learner.stats(for: $1).correct }
        case .words: return Skill.allCases.filter { $0.subject == .spelling }.reduce(0) { $0 + learner.stats(for: $1).attempts }
        case .maths: return Skill.allCases.filter { $0.subject == .maths }.reduce(0) { $0 + learner.stats(for: $1).attempts }
        case .streak: return profile.bestCombo
        case .typing: return Int(max(learner.typing.bestWordsPerMinute, learner.typing.bestTouchWordsPerMinute))
        case .levels: return profile.levels.values.reduce(0) { $0 + $1.plays }
        case .friendship: return profile.friendshipPowers
        case .days: return profile.stats.playDays
        case .crystals: return profile.crystals.count
        }
    }

    /// Progress towards a trophy as (now, needed), for the cabinet's progress bars.
    public static func progress(_ trophy: Trophy, in profile: Profile, catalog: Catalog = .shared) -> (now: Int, needed: Int)? {
        switch trophy.rule {
        case let .count(counter, needed): (min(value(of: counter, in: profile), needed), needed)
        case let .skill(skill): (min(profile.learner.stats(for: skill).correct, mastery), mastery)
        case let .table(table): (min(profile.stats.tableFirstTry[String(table)] ?? 0, mastery), mastery)
        case let .pets(needed): (min(petCount(profile, catalog), needed), needed)
        case .allPets: (petCount(profile, catalog), catalog.rewards.filter { $0.kind == .pet }.count)
        case .allHats: (hatsTried(profile, catalog), catalog.rewards.filter { $0.kind == .accessory }.count)
        case let .decorations(needed): (min(profile.decorations.count, needed), needed)
        case .allTreasures: (catalog.rewards.filter { profile.has($0.id) }.count, catalog.rewards.count)
        case let .champion(island):
            catalog.island(island).map { island in (island.levels.filter { profile.stars(for: $0.id) == 3 }.count, island.levels.count) }
        default: nil
        }
    }

    private static func petCount(_ profile: Profile, _ catalog: Catalog) -> Int {
        profile.rewards.filter { catalog.reward($0)?.kind == .pet }.count
    }

    private static func hatsTried(_ profile: Profile, _ catalog: Catalog) -> Int {
        catalog.rewards.filter { $0.kind == .accessory && profile.stats.hatsWorn.contains($0.id) }.count
    }

    // MARK: - Winning

    /// Whether the conditions for a trophy hold now. `run` is the level that has just finished,
    /// if any; trophies for a single moment can only be won with one.
    static func isMet(_ trophy: Trophy, profile: Profile, run: TrophyRun?, catalog: Catalog) -> Bool {
        switch trophy.rule {
        case let .superstar(level): return profile.stars(for: level) >= 3
        case let .flawless(level): return profile.levels[level]?.flawless == true
        case let .guardianFriend(island): return profile.crystals.contains(island)
        case let .champion(island):
            guard let island = catalog.island(island) else { return false }
            return island.levels.allSatisfy { profile.stars(for: $0.id) >= 3 }
        case let .count(counter, needed): return value(of: counter, in: profile) >= needed
        case let .skill(skill): return profile.learner.stats(for: skill).correct >= mastery
        case let .table(table): return (profile.stats.tableFirstTry[String(table)] ?? 0) >= mastery
        case .firstSteps: return !profile.levels.isEmpty
        case let .pets(needed): return petCount(profile, catalog) >= needed
        case .allPets: return petCount(profile, catalog) >= catalog.rewards.filter { $0.kind == .pet }.count
        case .allHats: return hatsTried(profile, catalog) >= catalog.rewards.filter { $0.kind == .accessory }.count
        case let .decorations(needed): return profile.decorations.count >= needed
        case .allTreasures: return catalog.rewards.allSatisfy { profile.has($0.id) }
        case .hatTrick: return profile.stats.hatStreak >= 3
        case .backForMore: return profile.levels.values.contains { $0.plays >= 3 }
        case .weekend: return Set(profile.stats.weekendDays).isSuperset(of: [1, 7])
        case .rainbowDay: return profile.stats.trophyDayIslands.count >= 3
        case .comeback: return run?.result.comeback == true
        case .neverGiveUp: return run.map { $0.previousStars == 1 && $0.result.stars == 3 } ?? false
        case .pearlPerfect:
            guard let run, run.mode == .mathsSplash else { return false }
            return run.result.pearlsOffered > 0 && run.result.pearls >= run.result.pearlsOffered
        case .turboAce:
            guard let run, run.mode == .typingTurbo, let accuracy = run.result.typingAccuracy else { return false }
            return accuracy >= 1
        case .oldFriends: return run.map { $0.mode == .guardian && $0.guardianAlreadyFriend } ?? false
        case .noHints: return run.map { $0.mode == .guardian && $0.result.hintsUsed == 0 && $0.result.total > 0 } ?? false
        }
    }

    /// Renames stickers from before the cabinet and puts in every trophy the player had
    /// already won, so a returning player starts with a cabinet that reflects what they've done.
    /// Safe to call repeatedly.
    public static func prepare(_ profile: inout Profile, catalog: Catalog = .shared, now: Date = Date()) {
        guard !profile.trophiesReady else { return }
        let renamed = ["wordsmith": "words-40", "number-ninja": "maths-40", "fast-fingers": "typing-15",
                       "friendship": "friends-1", "crystal-3": "crystals-3", "crystal-6": "crystals-6"]
        let known = Set(all(catalog).map(\.id))
        var trophies: [String: Date] = [:]
        for (id, date) in profile.achievements {
            let newID = renamed[id] ?? id
            if known.contains(newID) { trophies[newID] = date }
        }
        for trophy in all(catalog) where trophies[trophy.id] == nil && !trophy.rule.isMoment {
            if isMet(trophy, profile: profile, run: nil, catalog: catalog) { trophies[trophy.id] = now }
        }
        profile.achievements = trophies
        profile.trophiesReady = true
    }

    /// Hands out trophies at the end of a level: the ones for what was just done first, then
    /// any that were waiting, then the rest. At most `perLevel`; the others wait.
    static func award(_ profile: inout Profile, run: TrophyRun, limit: Int = perLevel, catalog: Catalog, now: Date) -> [Trophy] {
        let list = all(catalog)
        let byID = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        let waiting = profile.pendingTrophies.filter { byID[$0] != nil && profile.achievements[$0] == nil }
        let newlyMet = list.filter {
            profile.achievements[$0.id] == nil && !waiting.contains($0.id) && isMet($0, profile: profile, run: run, catalog: catalog)
        }

        func rank(_ trophy: Trophy) -> Int {
            switch trophy.rule {
            case let .guardianFriend(island) where island == run.islandID: 0
            case .firstSteps: 0
            case let .superstar(level) where level == run.levelID: 1
            case let .flawless(level) where level == run.levelID: 1
            default: trophy.rule.isMoment ? 2 : 4
            }
        }
        // Waiting trophies come after this run's own, in the order they were won.
        let fresh = newlyMet.enumerated().sorted { a, b in
            let (ra, rb) = (rank(a.element), rank(b.element))
            if ra != rb { return ra < rb }
            if a.element.tier != b.element.tier { return a.element.tier < b.element.tier }
            return a.offset < b.offset
        }.map(\.element)
        let ordered = fresh.filter { rank($0) < 4 } + waiting.compactMap { byID[$0] } + fresh.filter { rank($0) >= 4 }

        let given = Array(ordered.prefix(limit))
        for trophy in given { profile.achievements[trophy.id] = now }
        profile.pendingTrophies = ordered.dropFirst(limit).map(\.id)

        if !given.isEmpty {
            let today = Profile.dayKey(now)
            if profile.stats.trophyDay != today {
                profile.stats.trophyDay = today
                profile.stats.trophyDayIslands = []
            }
            if !profile.stats.trophyDayIslands.contains(run.islandID) { profile.stats.trophyDayIslands.append(run.islandID) }
        }
        return given
    }

    /// How many trophies the player has, out of how many.
    public static func count(in profile: Profile, catalog: Catalog = .shared) -> (won: Int, total: Int) {
        let list = all(catalog)
        return (list.filter { profile.achievements[$0.id] != nil }.count, list.count)
    }
}
