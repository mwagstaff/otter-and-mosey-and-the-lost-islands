import Foundation
import LostIslandsCore
import Observation

enum Route: Equatable {
    case title, profiles, intro, map, island(String), play(String), collection, home, parent, ending
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
    var route: Route = .title
    var showSettings = false
    /// Seconds played since the app was opened, for the optional break reminder.
    var sessionSeconds = 0.0
    let catalog = Catalog.shared

    init(store: SaveStore = .applicationSupport()) {
        self.store = store
        save = store.load()
        applySettings()
        #if DEBUG
        applyDebugArguments()
        #endif
    }

    #if DEBUG
    /// Development shortcuts: `-debugUnlock` clears every level, `-debugLevel bay-1` opens a level,
    /// `-debugRoute map|collection|home|parent|ending|island:woods` opens a screen.
    private func applyDebugArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard arguments.contains(where: { $0.hasPrefix("-debug") }) else { return }
        if save.activeProfile == nil {
            var profile = Profile(nickname: "Tester", avatar: "🦦", favourite: arguments.contains("-debugMosey") ? "mosey" : "otter")
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
        if let name = value(after: "-debugRoute") {
            switch name {
            case "map": route = .map
            case "collection": route = .collection
            case "home": route = .home
            case "parent": route = .parent
            case "ending": route = .ending
            case "intro": route = .intro
            default: if name.hasPrefix("island:") { route = .island(String(name.dropFirst(7))) }
            }
        }
    }
    #endif

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

    func createProfile(nickname: String, avatar: String, favourite: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var profile = Profile(nickname: trimmed.isEmpty ? "Explorer" : String(trimmed.prefix(12)), avatar: avatar, favourite: favourite)
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
        var fresh = Profile(nickname: old.nickname, avatar: old.avatar, favourite: old.favourite)
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

    // MARK: - Navigation

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
        guard var profile = save.activeProfile else { return }
        profile.learner = learner
        save.activeProfile = profile
        persist()
    }

    func complete(levelID: String, result: LevelResult, learner: LearnerModel, friendshipUses: Int) -> RewardSummary {
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
        sessionSeconds += seconds
        guard var profile = save.activeProfile else { return }
        profile.playSeconds += seconds
        save.activeProfile = profile
        // Written with the next real save, or when the app goes to the background.
    }

    var breakSuggested: Bool {
        guard let minutes = profile?.parent.sessionMinutes, minutes > 0 else { return false }
        return sessionSeconds >= Double(minutes) * 60
    }
}
