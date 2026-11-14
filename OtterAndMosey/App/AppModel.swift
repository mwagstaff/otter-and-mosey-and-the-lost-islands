import Foundation
import LostIslandsCore
import Observation

enum Route: Equatable {
    case title, profiles, intro, map, island(String), play(String), collection, trophies, home, parent, ending
}

/// Writes save files off the main thread, one at a time and in order.
nonisolated enum SaveWriter {
    private static let queue = DispatchQueue(label: "lost-islands.save", qos: .utility)

    static func write(_ file: SaveFile, to store: SaveStore) {
        queue.async { try? store.save(file) }
    }

    /// Blocks until every queued write has finished. Used when the app is about to be suspended.
    static func flush() { queue.sync {} }
}

/// App-wide state: the save file, the active profile and where the player is.
@Observable
final class AppModel {
    private(set) var save: SaveFile
    @ObservationIgnored private let store: SaveStore
    var route: Route = .title {
        // Silence the screen being left now. Doing it when that screen disappears is too late:
        // it fades out over the next one, whose first line would be cut off.
        didSet { if route != oldValue { Narrator.shared.stop() } }
    }
    var showSettings = false
    /// Set while a grown-up is play-testing a level from the parent dashboard.
    private(set) var playtest: Playtest?
    /// Stays true while a grown-up moves between the dashboard and play-testing, so the gate
    /// is not asked again. Cleared when they leave the dashboard.
    var parentUnlocked = false
    /// The child last chosen in the parent dashboard.
    var dashboardProfileID: UUID?
    /// Bumped to rebuild the level being played from scratch.
    private(set) var playRun = 0
    /// Seconds played since the app was opened, for the optional break reminder.
    var sessionSeconds = 0.0
    /// An island just unlocked by "Next adventure", which the map shows off on arrival.
    var unlockedIsland: String?
    /// Where the cabinet's back button goes.
    var trophiesReturn: Route = .map
    let catalog = Catalog.shared

    init(store: SaveStore = .applicationSupport()) {
        self.store = store
        save = store.load()
        prepareTrophies()
        applySettings()
        #if DEBUG
        applyDebugArguments()
        #endif
    }

    #if DEBUG
    /// Development shortcuts: `-debugUnlock` clears every level, `-debugLevel bay-1` opens a level,
    /// `-debugRoute map|collection|home|parent|ending|island:woods` opens a screen (the parent
    /// dashboard without its gate), `-debugPlaytest bay-1` play-tests a level from the dashboard.
    private func applyDebugArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard arguments.contains(where: { $0.hasPrefix("-debug") }) else { return }
        if save.activeProfile == nil {
            var profile = Profile(nickname: "Tester", avatar: "🦦")
            profile.rewards = ["deco-palm"]
            save.profiles.append(profile)
            save.activeProfileID = profile.id
        }
        guard var profile = save.activeProfile else { return }
        profile.seenIntro = true
        if arguments.contains("-debugUnlock") {
            for level in catalog.allLevels {
                let result = LevelResult(stars: 2, accuracy: 0.7, score: 400, bestCombo: 3, correctFirstTry: 4, total: level.count)
                Progression.apply(result, levelID: level.id, learner: profile.learner, to: &profile, catalog: catalog)
            }
        }
        save.activeProfile = profile
        if let level = value(after: "-debugLevel"), catalog.level(level) != nil { route = .play(level) }
        if let level = value(after: "-debugPlaytest") {
            parentUnlocked = true
            startPlaytest(levelID: level, as: save.activeProfileID)
        }
        if let name = value(after: "-debugRoute") {
            switch name {
            case "map": route = .map
            case "collection": route = .collection
            case "trophies": route = .trophies
            case "home": route = .home
            case "parent":
                parentUnlocked = true
                route = .parent
            case "ending": route = .ending
            case "intro": route = .intro
            default: if name.hasPrefix("island:") { route = .island(String(name.dropFirst(7))) }
            }
        }
    }
    #endif

    // MARK: - Trophies

    /// Moves stickers from before the trophy cabinet into it, for every player.
    private func prepareTrophies() {
        let before = save.profiles
        for index in save.profiles.indices { Trophies.prepare(&save.profiles[index], catalog: catalog) }
        if save.profiles != before { persist() }
    }

    /// Trophies won since the player last opened the cabinet.
    var hasNewTrophies: Bool {
        guard let profile else { return false }
        return Trophies.count(in: profile, catalog: catalog).won > profile.trophiesSeen
    }

    func openTrophies() {
        if route != .trophies { trophiesReturn = route }
        route = .trophies
    }

    func markTrophiesSeen() {
        guard let profile else { return }
        let won = Trophies.count(in: profile, catalog: catalog).won
        if profile.trophiesSeen != won { update { $0.trophiesSeen = won } }
    }

    // MARK: - Saving

    func persist() { SaveWriter.write(save, to: store) }

    func persistNow() {
        persist()
        SaveWriter.flush()
    }

    var settings: AppSettings {
        get { save.settings }
        set {
            save.settings = newValue
            applySettings()
            persist()
        }
    }

    private func applySettings() {
        let settings = save.settings
        AudioManager.shared.apply(settings)
        Haptics.shared.enabled = settings.haptics
        Narrator.shared.volume = settings.muted ? 0 : Float(max(settings.effectsVolume, 0.3))
        Narrator.shared.deviceVoice = settings.deviceVoice
        Effects.reducedMotion = settings.reducedMotion
        GameFont.easyRead = settings.easyReadFont
    }

    // MARK: - Profiles

    var profile: Profile? { save.activeProfile }

    func update(_ change: (inout Profile) -> Void) {
        guard var profile = save.activeProfile else { return }
        change(&profile)
        save.activeProfile = profile
        persist()
    }

    func createProfile(nickname: String, avatar: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var profile = Profile(nickname: trimmed.isEmpty ? "Explorer" : String(trimmed.prefix(12)), avatar: avatar)
        profile.rewards = ["deco-palm"]
        save.profiles.append(profile)
        save.activeProfileID = profile.id
        persist()
    }

    func selectProfile(_ id: UUID) {
        save.activeProfileID = id
        persist()
    }

    func deleteProfile(_ id: UUID) {
        save.profiles.removeAll { $0.id == id }
        if save.activeProfileID == id { save.activeProfileID = save.profiles.first?.id }
        persist()
    }

    func resetProgress(_ id: UUID) {
        guard let index = save.profiles.firstIndex(where: { $0.id == id }) else { return }
        let old = save.profiles[index]
        var fresh = Profile(nickname: old.nickname, avatar: old.avatar)
        fresh.id = old.id
        fresh.parent = old.parent
        fresh.rewards = ["deco-palm"]
        save.profiles[index] = fresh
        persist()
    }

    func updateProfile(_ id: UUID, _ change: (inout Profile) -> Void) {
        guard let index = save.profiles.firstIndex(where: { $0.id == id }) else { return }
        change(&save.profiles[index])
        persist()
    }

    // MARK: - Play-testing

    /// A grown-up trying a level. It runs with a copy of the chosen child's settings and skill
    /// levels (or a fresh player's), and nothing it does is saved.
    struct Playtest: Equatable {
        var profile: Profile
    }

    /// The profile a level is played with: the play-test copy, or the active player.
    var playingProfile: Profile? { playtest?.profile ?? profile }

    func startPlaytest(levelID: String, as profileID: UUID?) {
        guard catalog.level(levelID) != nil else { return }
        var tester = save.profiles.first { $0.id == profileID } ?? Profile(nickname: "Tester")
        tester.seenIntro = true
        playtest = Playtest(profile: tester)
        route = .play(levelID)
    }

    func endPlaytest() {
        playtest = nil
        route = .parent
    }

    func leaveParentArea() {
        parentUnlocked = false
        dashboardProfileID = nil
        route = .title
    }

    // MARK: - Navigation

    /// Starts a level again with fresh questions.
    func replay(_ levelID: String) {
        if route == .play(levelID) { playRun += 1 } else { route = .play(levelID) }
    }

    func play() {
        guard let profile else {
            route = .profiles
            return
        }
        route = profile.seenIntro ? .map : .intro
    }

    /// Jumps straight to the island with the next unfinished level.
    func continueGame() {
        guard let profile, profile.seenIntro else { return play() }
        if let next = Progression.nextLevel(for: profile, catalog: catalog), let island = catalog.island(containing: next.id) {
            route = .island(island.id)
        } else {
            route = .map
        }
    }

    func finishIntro() {
        update { $0.seenIntro = true }
        route = .map
    }

    // MARK: - Progress

    /// Saves learning progress part-way through a level, so nothing is lost if the app is closed.
    func updateLearner(_ learner: LearnerModel) {
        guard playtest == nil, var profile = save.activeProfile else { return }
        profile.learner = learner
        save.activeProfile = profile
        persist()
    }

    func complete(levelID: String, result: LevelResult, learner: LearnerModel, friendshipUses: Int) -> RewardSummary {
        if var copy = playtest?.profile {
            // Show what the child would earn, but keep none of it.
            return Progression.apply(result, levelID: levelID, learner: learner, usedFriendshipPower: friendshipUses, to: &copy, catalog: catalog)
        }
        guard var profile = save.activeProfile else { return RewardSummary() }
        let summary = Progression.apply(result, levelID: levelID, learner: learner, usedFriendshipPower: friendshipUses, to: &profile, catalog: catalog)
        save.activeProfile = profile
        persistNow()
        return summary
    }

    /// How much of an island's colour has returned: the share of its levels that are cleared.
    func restoration(of island: Island) -> Double {
        guard let profile else { return 0 }
        if profile.crystals.contains(island.id) { return 1 }
        let cleared = island.levels.filter { profile.stars(for: $0.id) > 0 }.count
        return Double(cleared) / Double(island.levels.count)
    }

    func addPlaytime(_ seconds: Double) {
        guard playtest == nil else { return }
        sessionSeconds += seconds
        guard var profile = save.activeProfile else { return }
        profile.addPlaytime(seconds)
        save.activeProfile = profile
        // Written with the next real save, or when the app goes to the background.
    }

    var breakSuggested: Bool {
        guard let minutes = profile?.parent.sessionMinutes, minutes > 0 else { return false }
        return sessionSeconds >= Double(minutes) * 60
    }
}
