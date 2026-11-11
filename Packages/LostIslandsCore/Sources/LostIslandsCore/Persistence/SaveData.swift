import Foundation

public struct LevelRecord: Codable, Equatable, Sendable {
    public var stars = 0
    public var bestScore = 0
    public var plays = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = c.value(.stars, default: 0)
        bestScore = c.value(.bestScore, default: 0)
        plays = c.value(.plays, default: 0)
    }
}

public struct PlacedDecoration: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var reward: String
    /// Position on the home island as fractions of its width and height.
    public var x: Double
    public var y: Double

    public init(reward: String, x: Double, y: Double) {
        self.reward = reward
        self.x = x
        self.y = y
    }
}

/// One child's local profile. Holds a nickname and progress only: no personal details.
public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var nickname: String
    public var avatar: String
    /// "otter" or "mosey": who leads on screen.
    public var favourite: String
    public var levels: [String: LevelRecord] = [:]
    /// Island ids whose crystal fragment has been recovered.
    public var crystals: [String] = []
    public var rewards: [String] = []
    public var equippedAccessory: String?
    /// Achievement id to the date it was earned.
    public var achievements: [String: Date] = [:]
    public var learner = LearnerModel()
    public var parent = ParentSettings()
    public var playSeconds = 0.0
    public var seenIntro = false
    public var decorations: [PlacedDecoration] = []
    public var lastLevelID: String?
    public var bestCombo = 0
    public var friendshipPowers = 0

    public init(nickname: String, avatar: String = "🦦", favourite: String = "otter") {
        self.nickname = nickname
        self.avatar = avatar
        self.favourite = favourite
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        nickname = c.value(.nickname, default: "Explorer")
        avatar = c.value(.avatar, default: "🦦")
        favourite = c.value(.favourite, default: "otter")
        levels = c.value(.levels, default: [:])
        crystals = c.value(.crystals, default: [])
        rewards = c.value(.rewards, default: [])
        equippedAccessory = c.value(.equippedAccessory, default: nil)
        achievements = c.value(.achievements, default: [:])
        learner = c.value(.learner, default: LearnerModel())
        parent = c.value(.parent, default: ParentSettings())
        playSeconds = c.value(.playSeconds, default: 0)
        seenIntro = c.value(.seenIntro, default: false)
        decorations = c.value(.decorations, default: [])
        lastLevelID = c.value(.lastLevelID, default: nil)
        bestCombo = c.value(.bestCombo, default: 0)
        friendshipPowers = c.value(.friendshipPowers, default: 0)
    }

    public var totalStars: Int { levels.values.reduce(0) { $0 + $1.stars } }
    public func stars(for levelID: String) -> Int { levels[levelID]?.stars ?? 0 }
    public func has(_ reward: String) -> Bool { rewards.contains(reward) }
}

/// Device-wide preferences shared by every profile.
public struct AppSettings: Codable, Equatable, Sendable {
    public var musicVolume = 0.5
    public var effectsVolume = 0.8
    public var muted = false
    public var haptics = true
    public var reducedMotion = false
    public var highContrast = false
    public var easyReadFont = false
    public var spokenInstructions = true
    /// Let the device's built-in voice read questions that have no narrator recording.
    public var deviceVoice = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        musicVolume = c.value(.musicVolume, default: 0.5)
        effectsVolume = c.value(.effectsVolume, default: 0.8)
        muted = c.value(.muted, default: false)
        haptics = c.value(.haptics, default: true)
        reducedMotion = c.value(.reducedMotion, default: false)
        highContrast = c.value(.highContrast, default: false)
        easyReadFont = c.value(.easyReadFont, default: false)
        spokenInstructions = c.value(.spokenInstructions, default: true)
        deviceVoice = c.value(.deviceVoice, default: false)
    }
}

/// The whole save file. `version` is bumped whenever the shape changes in a way that
/// tolerant decoding cannot absorb; `SaveMigrator` upgrades older files.
public struct SaveFile: Codable, Equatable, Sendable {
    public static let currentVersion = 2

    public var version = SaveFile.currentVersion
    public var profiles: [Profile] = []
    public var activeProfileID: UUID?
    public var settings = AppSettings()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.value(.version, default: 1)
        profiles = c.value(.profiles, default: [])
        activeProfileID = c.value(.activeProfileID, default: nil)
        settings = c.value(.settings, default: AppSettings())
    }

    public var activeProfile: Profile? {
        get { profiles.first { $0.id == activeProfileID } }
        set {
            guard let newValue, let index = profiles.firstIndex(where: { $0.id == newValue.id }) else { return }
            profiles[index] = newValue
        }
    }
}

public enum SaveError: Error, Equatable {
    /// The file was written by a newer version of the game than this one understands.
    case fromTheFuture(version: Int)
}

public enum SaveMigrator {
    /// Decodes any supported save version and upgrades it to the current shape.
    public static func load(_ data: Data) throws -> SaveFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var file = try decoder.decode(SaveFile.self, from: data)
        guard file.version <= SaveFile.currentVersion else { throw SaveError.fromTheFuture(version: file.version) }
        if file.version < 2 {
            // v1 allowed a save with profiles but no active one; v2 always has an active profile.
            if file.activeProfile == nil { file.activeProfileID = file.profiles.first?.id }
        }
        file.version = SaveFile.currentVersion
        return file
    }

    public static func encode(_ file: SaveFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(file)
    }
}

/// Reads and writes the save file. Writes are atomic and the previous good file is kept
/// as a backup, so a crash or a full disk mid-write cannot destroy progress.
public struct SaveStore: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("save.json") }
    public var backupURL: URL { directory.appendingPathComponent("save.backup.json") }

    public init(directory: URL) { self.directory = directory }

    public static func applicationSupport() -> SaveStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return SaveStore(directory: base.appendingPathComponent("LostIslands", isDirectory: true))
    }

    /// Loads the save, falling back to the backup, then to a fresh file. Never throws:
    /// a child should always be able to play.
    public func load() -> SaveFile {
        for url in [fileURL, backupURL] {
            if let data = try? Data(contentsOf: url), let file = try? SaveMigrator.load(data) {
                return file
            }
        }
        return SaveFile()
    }

    public func save(_ file: SaveFile) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try SaveMigrator.encode(file)
        if let existing = try? Data(contentsOf: fileURL), (try? SaveMigrator.load(existing)) != nil {
            try? existing.write(to: backupURL, options: .atomic)
        }
        try data.write(to: fileURL, options: .atomic)
    }
}
