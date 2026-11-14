import Foundation
import Testing
@testable import LostIslandsCore

@Suite struct CatalogTests {
    let catalog = Catalog.shared

    @Test func sixIslandsEachEndWithAGuardian() {
        #expect(catalog.islands.map(\.id) == ["woods", "bay", "dragon", "cloud", "candy", "star"])
        for island in catalog.islands {
            #expect(island.levels.count == 5)
            #expect(island.levels.last?.mode == .guardian)
            #expect(island.levels.dropLast().allSatisfy { $0.mode != .guardian })
            #expect(island.guardian.phases.count == 3)
            #expect(island.levels.allSatisfy { !$0.intro.isEmpty && !$0.outro.isEmpty && $0.count >= 5 })
        }
        #expect(Set(catalog.allLevels.map(\.id)).count == 30)
    }

    @Test func everyGameModeIsUsedAndRewardsExist() {
        #expect(Set(catalog.allLevels.map(\.mode)) == Set(GameMode.allCases))
        for level in catalog.allLevels {
            if let reward = level.reward { #expect(catalog.reward(reward) != nil, "\(reward)") }
        }
        #expect(Catalog.starDecorations.allSatisfy { catalog.reward($0.reward) != nil })
        #expect(!catalog.intro.isEmpty && !catalog.introAfter.isEmpty)
    }

    @Test func dialogueClipKeysMatchTheBuiltScript() {
        let script = Catalog.voicedLines
        #expect(script.count > 100)
        var lines: [(line: DialogueLine, guardian: String?)] = (catalog.intro + catalog.introAfter + catalog.askGrownUp).map { ($0, nil) }
        for island in catalog.islands {
            let kind = island.guardian.kind
            lines += (island.guardian.phases + island.guardian.befriended).map { ($0, kind) }
            for level in island.levels { lines += (level.intro + level.outro).map { ($0, kind) } }
        }
        for (line, guardian) in lines {
            switch line.speaker {
            case .otter, .mosey:
                let entry = script[line.audioKey ?? ""]
                #expect(entry?.text == line.text, "no script entry for: \(line.text)")
                #expect(entry?.speaker == line.speaker.rawValue)
            case .guardian:
                let entry = script[line.audioKey ?? ""]
                #expect(entry?.text == line.text, "no script entry for: \(line.text)")
                #expect(entry?.speaker == guardian, "guardian lines are recorded under their own voice")
            case .narrator:
                let entry = script[line.audioKey ?? ""]
                #expect(entry?.text == line.text, "no script entry for: \(line.text)")
                #expect(entry?.speaker == "narrator")
            }
        }
        for island in catalog.islands {
            for line in island.guardian.befriended where line.speaker == .guardian {
                #expect(script[line.audioKey ?? ""]?.mood == "befriended")
            }
            #expect(script.values.contains { $0.speaker == island.guardian.kind })
        }
        #expect(script.values.filter { $0.scene == "intro" }.count == 12, "nine for Otter and Mosey, three story lines")
    }

    @Test func modesOnlyGetSkillsTheyCanPresent() {
        for level in catalog.allLevels {
            switch level.mode {
            case .mathsSplash, .eggRescue: #expect(level.skills.allSatisfy { $0.subject == .maths }, "\(level.id)")
            case .wordBlaster: #expect(level.skills.allSatisfy { $0.subject == .spelling }, "\(level.id)")
            case .typingTurbo: #expect(level.skills == [.typing], "\(level.id)")
            case .bridgeBuilder, .guardian: #expect(level.skills.allSatisfy { $0.subject != .typing }, "\(level.id)")
            }
        }
    }
}

@Suite struct SessionTests {
    let catalog = Catalog.shared

    @Test func everyLevelRunsToCompletion() {
        for level in catalog.allLevels {
            var session = ChallengeSession(level: level, learner: LearnerModel(), seed: 99)
            var seen = 0
            while let question = session.next() {
                seen += 1
                #expect(!question.prompt.isEmpty)
                switch level.mode {
                case .mathsSplash:
                    #expect(question.format == .choice && question.choices.count == 3, "\(level.id)")
                case .bridgeBuilder:
                    #expect(question.format == .choice && question.choices.count >= 2, "\(level.id)")
                case .wordBlaster, .typingTurbo, .eggRescue:
                    #expect(question.format == .typed && !question.typingTarget.isEmpty, "\(level.id)")
                case .guardian:
                    #expect(question.format == (question.skill.subject == .maths ? .choice : .typed))
                }
                if level.mode == .eggRescue {
                    let digitsOnly = question.typingTarget.allSatisfy { $0.isNumber }
                    #expect(digitsOnly)
                }
                let outcome = session.complete(question, firstTry: true, seconds: 3, usedHint: false)
                #expect(outcome.isLevelComplete == (seen == level.count))
            }
            #expect(seen == level.count)
            #expect(session.isFinished && session.result.stars == 3)
            #expect(session.learner.answerCount == level.count)
        }
    }

    @Test func sameSeedGivesSameQuestions() {
        let level = catalog.level("bay-1")!
        var a = ChallengeSession(level: level, learner: LearnerModel(), seed: 5)
        var b = ChallengeSession(level: level, learner: LearnerModel(), seed: 5)
        for _ in 0..<level.count { #expect(a.next()?.prompt == b.next()?.prompt) }
    }

    @Test func questionsDoNotRepeatWithinALevel() {
        for id in ["woods-1", "woods-4", "bay-1", "dragon-1"] {
            var session = ChallengeSession(level: catalog.level(id)!, learner: LearnerModel(), seed: 31)
            var prompts: [String] = []
            while let question = session.next() { prompts.append(question.answer + question.prompt) }
            #expect(Set(prompts).count == prompts.count, "\(id)")
        }
    }

    @Test func mistakesLowerStarsButNeverBelowOne() {
        let level = catalog.level("woods-1")!
        var session = ChallengeSession(level: level, learner: LearnerModel(), seed: 1)
        while let question = session.next() {
            session.recordSlip()
            _ = session.complete(question, firstTry: false, seconds: 20, usedHint: true)
        }
        #expect(session.result.stars == 1)
        #expect(session.result.score > 0)
        #expect(session.bestCombo == 0)
    }

    @Test func grownUpHelpIsSuggestedAfterRepeatedSlipsOnOneQuestion() {
        var session = ChallengeSession(level: catalog.level("woods-1")!, learner: LearnerModel(), seed: 1)
        _ = session.next()
        var answers: [Bool] = []
        for _ in 0..<5 { answers.append(session.recordSlip()) }
        #expect(answers == [false, false, false, true, false], "suggested on the fourth slip, and only once")
    }

    @Test func grownUpHelpComesSoonerAfterSeveralTrickyQuestions() {
        var session = ChallengeSession(level: catalog.level("woods-1")!, learner: LearnerModel(), seed: 1)
        for _ in 0..<ChallengeSession.trickyStreakBeforeHelp {
            let question = session.next()!
            session.recordSlip()
            _ = session.complete(question, firstTry: false, seconds: 10, usedHint: false)
        }
        _ = session.next()
        let first = session.recordSlip()
        let second = session.recordSlip()
        #expect(!first)
        #expect(second)
    }

    @Test func grownUpHelpIsOfferedAgainOnLaterQuestions() {
        var session = ChallengeSession(level: catalog.level("woods-1")!, learner: LearnerModel(), seed: 1)
        var suggestions: [Bool] = []
        for _ in 0..<4 {
            let question = session.next()!
            var suggested = false
            for _ in 0..<ChallengeSession.slipsBeforeHelp where session.recordSlip() { suggested = true }
            suggestions.append(suggested)
            _ = session.complete(question, firstTry: false, seconds: 10, usedHint: true)
        }
        #expect(suggestions == [true, true, true, true])
    }

    @Test func grownUpHelpLinesComeFromOtterAndMosey() {
        #expect(catalog.askGrownUp.count >= 2)
        #expect(catalog.askGrownUp.allSatisfy { $0.speaker == .otter || $0.speaker == .mosey })
        #expect(catalog.askGrownUp.allSatisfy { $0.text.contains("grown-up") })
    }

    @Test func combosMultiplyPoints() {
        var session = ChallengeSession(level: catalog.level("bay-4")!, learner: LearnerModel(), seed: 1)
        var points: [Int] = []
        while let question = session.next() {
            points.append(session.complete(question, firstTry: true, seconds: 8, usedHint: false).points)
        }
        #expect(points.first == 100)
        #expect(points.last! > points.first!)
        #expect(session.bestCombo == 8)
    }

    @Test func dueReviewItemsAreBroughtBack() {
        var learner = LearnerModel()
        learner.record(key: "mul:8x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false)
        for _ in 0..<5 { learner.record(key: "addition:L1", skill: .addition, correct: true, seconds: 2, usedHint: false) }
        var found = 0
        for seed in 0..<40 {
            var session = ChallengeSession(level: catalog.level("dragon-1")!, learner: learner, seed: UInt64(seed))
            while let question = session.next() {
                if question.key == "mul:8x7" { found += 1 }
            }
        }
        #expect(found >= 25, "the missed fact should usually return (\(found)/40)")
    }

    @Test func parentTopicChoicesAreRespected() {
        var settings = ParentSettings()
        settings.spellingTopics = [.prefixes]
        settings.tables = [4]
        var words = ChallengeSession(level: catalog.level("woods-4")!, learner: LearnerModel(), settings: settings, seed: 2)
        while let question = words.next() { #expect(question.skill == .prefixes) }
        var tables = ChallengeSession(level: catalog.level("dragon-1")!, learner: LearnerModel(), settings: settings, seed: 2)
        while let question = tables.next() { #expect(question.key.hasPrefix("mul:4x"), "\(question.key)") }
    }

    @Test func typingLevelsAreJudgedOnAccuracyNotSpeed() {
        var session = ChallengeSession(level: catalog.level("woods-3")!, learner: LearnerModel(), seed: 4)
        while let question = session.next() {
            session.recordTyping(keystrokes: 10, correct: 10, wordsPerMinute: 2)
            _ = session.complete(question, firstTry: true, seconds: 300, usedHint: false)
        }
        #expect(session.result.stars == 3, "slow but accurate typing earns full stars")
        #expect(session.result.wordsPerMinute == 2)
    }
}

@Suite struct ProgressionTests {
    let catalog = Catalog.shared

    func perfect(_ level: LevelDef) -> LevelResult {
        LevelResult(stars: 3, accuracy: 1, score: 900, bestCombo: level.count, correctFirstTry: level.count, total: level.count)
    }

    @Test func starThresholds() {
        #expect(Progression.stars(forAccuracy: 1) == 3)
        #expect(Progression.stars(forAccuracy: 0.7) == 2)
        #expect(Progression.stars(forAccuracy: 0) == 1)
    }

    @Test func levelsAndIslandsUnlockInOrder() {
        var profile = Profile(nickname: "Test")
        #expect(Progression.isUnlocked(levelID: "woods-1", in: profile))
        #expect(!Progression.isUnlocked(levelID: "woods-2", in: profile))
        #expect(!Progression.isUnlocked(levelID: "bay-1", in: profile))
        #expect(Progression.nextLevel(for: profile)?.id == "woods-1")
        for level in catalog.island("woods")!.levels {
            #expect(Progression.isUnlocked(levelID: level.id, in: profile))
            Progression.apply(perfect(level), levelID: level.id, learner: profile.learner, to: &profile)
        }
        #expect(profile.crystals == ["woods"])
        #expect(Progression.isUnlocked(levelID: "bay-1", in: profile))
        #expect(!Progression.isUnlocked(levelID: "dragon-1", in: profile))
        #expect(Progression.nextLevel(for: profile)?.id == "bay-1")
    }

    @Test func rewardsAreGrantedOnce() {
        var profile = Profile(nickname: "Test")
        let level = catalog.level("woods-1")!
        let first = Progression.apply(perfect(level), levelID: level.id, learner: profile.learner, to: &profile)
        #expect(first.isFirstClear && first.reward?.id == "pet-firefly")
        #expect(first.trophies.map(\.id) == ["first-steps", "superstar-woods-1"])
        #expect(profile.pendingTrophies == ["flawless-woods-1", "combo-5"], "the rest wait, this level's own first")
        #expect(first.trophiesWaiting == 2)
        #expect(first.decorations.map(\.id) == ["deco-palm"])
        let second = Progression.apply(perfect(level), levelID: level.id, learner: profile.learner, to: &profile)
        #expect(!second.isFirstClear && second.reward == nil && second.decorations.isEmpty)
        #expect(second.trophies.map(\.id) == ["flawless-woods-1", "combo-5"], "waiting trophies come out next time")
        #expect(profile.rewards.filter { $0 == "pet-firefly" }.count == 1)
        #expect(profile.levels[level.id]?.plays == 2)
    }

    @Test func aWorseReplayNeverLosesStars() {
        var profile = Profile(nickname: "Test")
        let level = catalog.level("woods-1")!
        Progression.apply(perfect(level), levelID: level.id, learner: profile.learner, to: &profile)
        var poor = perfect(level)
        poor.stars = 1
        poor.score = 10
        Progression.apply(poor, levelID: level.id, learner: profile.learner, to: &profile)
        #expect(profile.stars(for: level.id) == 3 && profile.levels[level.id]?.bestScore == 900)
    }

    @Test func finishingEveryIslandCompletesTheGame() {
        var profile = Profile(nickname: "Test")
        var last = RewardSummary()
        for level in catalog.allLevels {
            #expect(Progression.isUnlocked(levelID: level.id, in: profile), "\(level.id)")
            last = Progression.apply(perfect(level), levelID: level.id, learner: profile.learner, usedFriendshipPower: level.mode == .guardian ? 3 : 0, to: &profile)
        }
        #expect(last.gameComplete && profile.crystals.count == 6 && profile.totalStars == 90)
        #expect(profile.achievements["friend-star"] != nil, "the guardian's own trophy is never held back")
        #expect(profile.achievements.count + profile.pendingTrophies.count >= 60)
        #expect(Progression.nextLevel(for: profile) == nil)
    }
}

@Suite struct SaveTests {
    func temporaryStore() -> SaveStore {
        SaveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("lost-islands-\(UUID().uuidString)"))
    }

    func sampleFile() -> SaveFile {
        var file = SaveFile()
        var profile = Profile(nickname: "Pip", avatar: "🐬")
        profile.learner.record(key: "mul:8x7", skill: .multiplication, correct: false, seconds: 4, usedHint: false)
        profile.levels["woods-1"] = LevelRecord()
        profile.levels["woods-1"]?.stars = 2
        profile.achievements["first-steps"] = Date(timeIntervalSince1970: 1_700_000_000)
        profile.decorations = [PlacedDecoration(reward: "deco-palm", x: 0.4, y: 0.6)]
        file.profiles = [profile, Profile(nickname: "Sam")]
        file.activeProfileID = profile.id
        file.settings.easyReadFont = true
        return file
    }

    @Test func roundTripsEverything() throws {
        let store = temporaryStore()
        let file = sampleFile()
        try store.save(file)
        let loaded = store.load()
        #expect(loaded == file)
        #expect(store.load().activeProfile?.nickname == "Pip")
    }

    @Test func missingFileGivesAFreshSave() {
        let file = temporaryStore().load()
        #expect(file.profiles.isEmpty && file.version == SaveFile.currentVersion)
    }

    @Test func corruptFileFallsBackToBackup() throws {
        let store = temporaryStore()
        var file = sampleFile()
        try store.save(file)
        file.settings.muted = true
        try store.save(file) // first save becomes the backup
        try Data("{ not json".utf8).write(to: store.fileURL)
        let recovered = store.load()
        #expect(recovered.profiles.count == 2, "progress survives a corrupt main file")
        #expect(recovered.settings.muted == false, "recovered from the previous good save")
    }

    @Test func aCorruptFileIsNeverCopiedOverTheBackup() throws {
        let store = temporaryStore()
        try store.save(sampleFile())
        try store.save(sampleFile())
        try Data("garbage".utf8).write(to: store.fileURL)
        try store.save(SaveFile())
        let backup = try SaveMigrator.load(Data(contentsOf: store.backupURL))
        #expect(backup.profiles.count == 2)
    }

    @Test func olderSavesWithMissingFieldsStillOpen() throws {
        let legacy = """
        {"version":1,"profiles":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","nickname":"Old","levels":{"woods-1":{"stars":3}}}]}
        """
        let file = try SaveMigrator.load(Data(legacy.utf8))
        #expect(file.version == SaveFile.currentVersion)
        #expect(file.activeProfile?.nickname == "Old", "v1 files gain an active profile")
        #expect(file.activeProfile?.stars(for: "woods-1") == 3)
        #expect(file.activeProfile?.parent == ParentSettings() && file.settings == AppSettings())
    }

    @Test func newerSavesAreRejectedRatherThanMangled() {
        let future = #"{"version":99,"profiles":[]}"#
        do {
            _ = try SaveMigrator.load(Data(future.utf8))
            Issue.record("a version 99 save should not load")
        } catch {
            #expect(error as? SaveError == .fromTheFuture(version: 99))
        }
    }

    @Test func playtimeIsTrackedPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let day = { (offset: Int) in calendar.date(from: DateComponents(year: 2026, month: 3, day: 10 + offset, hour: 23, minute: 30))! }
        var profile = Profile(nickname: "Pip")
        profile.addPlaytime(600, at: day(0), calendar: calendar)
        profile.addPlaytime(300, at: day(-3), calendar: calendar)
        profile.addPlaytime(120, at: day(-7), calendar: calendar)
        profile.addPlaytime(60, at: day(0), calendar: calendar)
        #expect(profile.playSeconds == 1080)
        #expect(Profile.dayKey(day(0), calendar: calendar) == "2026-03-10")
        #expect(profile.playSeconds(overLast: 1, endingAt: day(0), calendar: calendar) == 660)
        #expect(profile.playSeconds(overLast: 7, endingAt: day(0), calendar: calendar) == 960, "a week ago is outside the last 7 days")
        #expect(profile.playSeconds(overLast: 1, endingAt: day(1), calendar: calendar) == 0)
    }

    @Test func oldDailyPlaytimeIsPruned() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var profile = Profile(nickname: "Pip")
        for offset in 0..<60 { profile.addPlaytime(10, at: calendar.date(byAdding: .day, value: offset, to: start)!, calendar: calendar) }
        #expect(profile.dailyPlaySeconds.count <= Profile.playHistoryDays)
        #expect(profile.playSeconds == 600, "the running total keeps everything")
    }

    @Test func activeProfileSetterUpdatesInPlace() {
        var file = sampleFile()
        var profile = file.activeProfile!
        profile.seenIntro = true
        file.activeProfile = profile
        #expect(file.profiles[0].seenIntro && file.profiles.count == 2)
    }
}

@Suite struct TrophyTests {
    let catalog = Catalog.shared
    let monday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!

    func result(_ level: LevelDef, firstTry: Int? = nil) -> LevelResult {
        let right = firstTry ?? level.count
        return LevelResult(stars: Progression.stars(forAccuracy: Double(right) / Double(level.count)), accuracy: Double(right) / Double(level.count),
                           score: 100, bestCombo: right, correctFirstTry: right, total: level.count)
    }

    @Test func thereAre145TrophiesWithUniqueIDsAndArt() {
        let all = Trophies.all(catalog)
        #expect(all.count == 145)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(all.filter { $0.group == .islands }.count == 72)
        #expect(all.filter { $0.group == .milestones }.count == 43)
        #expect(all.filter { $0.group == .learning }.count == 14)
        #expect(all.filter { $0.group == .collections }.count == 6)
        #expect(all.filter { $0.group == .secret }.count == 10)
        #expect(all.allSatisfy { !$0.art.isEmpty && !$0.detail.isEmpty })
    }

    @Test func noMoreThanTwoAreHandedOutAndTheRestWait() {
        var profile = Profile(nickname: "Pip")
        let level = catalog.level("woods-1")!
        var awarded = 0
        for _ in 0..<12 {
            let summary = Progression.apply(result(level), levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
            #expect(summary.trophies.count <= Trophies.perLevel)
            awarded += summary.trophies.count
        }
        #expect(awarded == profile.achievements.count)
        #expect(profile.achievements["back-for-more"] != nil && profile.achievements["levels-10"] != nil)
    }

    @Test func thisLevelsMedalsComeBeforeWaitingOnes() {
        var profile = Profile(nickname: "Pip")
        profile.pendingTrophies = ["first-steps"]
        profile.levels["woods-1"] = LevelRecord()
        profile.trophiesReady = true
        let level = catalog.level("woods-2")!
        let summary = Progression.apply(result(level), levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
        #expect(summary.trophies.map(\.id) == ["superstar-woods-2", "flawless-woods-2"])
        #expect(profile.pendingTrophies.first == "first-steps")
    }

    @Test func oneOffMomentsAreKeptIfThereIsNoRoom() {
        var profile = Profile(nickname: "Pip")
        let level = catalog.level("woods-1")!
        var poor = result(level, firstTry: 1)
        Progression.apply(poor, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
        #expect(profile.stars(for: level.id) == 1)
        poor = result(level)
        poor.comeback = true
        let summary = Progression.apply(poor, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
        let won = Set(summary.trophies.map(\.id) + profile.pendingTrophies)
        #expect(won.isSuperset(of: ["never-give-up", "comeback", "superstar-woods-1", "flawless-woods-1"]))
    }

    @Test func oldStickersMoveIntoTheCabinet() {
        var profile = Profile(nickname: "Pip")
        profile.achievements = ["wordsmith": monday, "first-steps": monday, "three-stars": monday]
        profile.levels["woods-1"] = LevelRecord()
        profile.levels["woods-1"]?.stars = 3
        Trophies.prepare(&profile, catalog: catalog, now: monday)
        #expect(profile.achievements["words-40"] != nil && profile.achievements["first-steps"] != nil)
        #expect(profile.achievements["three-stars"] == nil && profile.achievements["wordsmith"] == nil)
        #expect(profile.achievements["superstar-woods-1"] != nil, "already-won trophies go straight in")
        #expect(profile.pendingTrophies.isEmpty && profile.trophiesReady)
    }

    @Test func lifetimeCountsAddUp() {
        let calendar = Calendar(identifier: .gregorian)
        var profile = Profile(nickname: "Pip")
        let level = catalog.level("bay-1")!
        var run = result(level)
        run.pearls = 12
        run.tableFirstTry = ["3": 2]
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9))!
        let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
        Progression.apply(run, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: saturday, calendar: calendar)
        Progression.apply(run, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: saturday, calendar: calendar)
        Progression.apply(run, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: sunday, calendar: calendar)
        #expect(profile.stats.pearls == 36 && profile.stats.tableFirstTry["3"] == 6)
        #expect(profile.stats.playDays == 2 && Set(profile.stats.weekendDays) == [1, 7])
        #expect(Trophies.progress(Trophies.trophy("pearls-100")!, in: profile)! == (36, 100))
    }

    @Test func pearlPerfectNeedsEveryPearl() {
        var profile = Profile(nickname: "Pip")
        profile.trophiesReady = true
        let level = catalog.level("bay-1")!
        var run = result(level, firstTry: 3)
        run.pearls = 24
        run.pearlsOffered = 25
        Progression.apply(run, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
        #expect(!profile.pendingTrophies.contains("pearl-perfect") && profile.achievements["pearl-perfect"] == nil)
        run.pearls = 25
        let summary = Progression.apply(run, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog, now: monday)
        #expect(summary.trophies.map(\.id).contains("pearl-perfect") || profile.pendingTrophies.contains("pearl-perfect"))
    }

    @Test func sessionsCountHintsComebacksAndTables() {
        var session = ChallengeSession(level: catalog.level("dragon-1")!, learner: LearnerModel(), seed: 7)
        let question = session.next()!
        session.recordSlip()
        session.recordSlip()
        _ = session.complete(question, firstTry: false, seconds: 3, usedHint: true)
        let second = session.next()!
        _ = session.complete(second, firstTry: true, seconds: 2, usedHint: false)
        let result = session.result
        #expect(result.hintsUsed == 1 && result.comeback)
        #expect(ChallengeSession.table(of: "mul:8x7") == 8 && ChallengeSession.table(of: "div:3x4") == 3 && ChallengeSession.table(of: "word:said") == nil)
    }

    @Test func hatsTriedAreRemembered() {
        var profile = Profile(nickname: "Pip")
        profile.wear("hat-leaf")
        profile.wear(nil)
        profile.wear("hat-crown")
        #expect(profile.stats.hatsWorn == ["hat-leaf", "hat-crown"] && profile.equippedAccessory == "hat-crown")
    }
}
