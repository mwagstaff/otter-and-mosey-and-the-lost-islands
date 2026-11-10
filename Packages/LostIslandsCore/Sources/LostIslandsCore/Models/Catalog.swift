import Foundation

public enum GameMode: String, Codable, CaseIterable, Sendable {
    case wordBlaster, mathsSplash, bridgeBuilder, eggRescue, typingTurbo, guardian

    public var title: String {
        switch self {
        case .wordBlaster: "Word Blaster"
        case .mathsSplash: "Maths Splash"
        case .bridgeBuilder: "Rainbow Bridge"
        case .eggRescue: "Number Rescue"
        case .typingTurbo: "Typing Turbo"
        case .guardian: "Guardian"
        }
    }
}

public enum Speaker: String, Codable, Sendable {
    case otter, mosey, guardian, narrator
}

/// One line of dialogue. Stored in JSON as `"o:Hello!"` (o, m, g or n).
public struct DialogueLine: Codable, Equatable, Sendable {
    public let speaker: Speaker
    public let text: String

    public init(speaker: Speaker, text: String) {
        self.speaker = speaker
        self.text = text
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Dialogue needs a speaker prefix: \(raw)"))
        }
        switch parts[0] {
        case "o": speaker = .otter
        case "m": speaker = .mosey
        case "g": speaker = .guardian
        default: speaker = .narrator
        }
        text = parts[1]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let prefix = switch speaker {
        case .otter: "o"
        case .mosey: "m"
        case .guardian: "g"
        case .narrator: "n"
        }
        try container.encode("\(prefix):\(text)")
    }
}

public struct LevelDef: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let mode: GameMode
    public let skills: [Skill]
    /// How many questions the level asks.
    public let count: Int
    public let intro: [DialogueLine]
    public let outro: [DialogueLine]
    /// Reward id granted the first time the level is cleared.
    public let reward: String?
    public let blurb: String
}

public struct GuardianDef: Codable, Equatable, Sendable {
    public let name: String
    public let kind: String
    /// What the guardian says at the start of each phase.
    public let phases: [DialogueLine]
    public let befriended: [DialogueLine]
}

public struct Island: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    public let focus: String
    /// Hex colour of this island's crystal fragment, e.g. `#3FBF6B`.
    public let colour: String
    public let guardian: GuardianDef
    public let levels: [LevelDef]
}

public enum RewardKind: String, Codable, Sendable {
    case pet, accessory, decoration
}

public struct Reward: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: RewardKind
    public let name: String
    public let emoji: String
}

/// All bundled level definitions and story text.
public struct Catalog: Codable, Sendable {
    public let islands: [Island]
    public let rewards: [Reward]
    public let intro: [DialogueLine]
    public let introAfter: [DialogueLine]

    public static let shared: Catalog = {
        do {
            guard let url = Bundle.module.url(forResource: "islands", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("Bundled catalogue failed to load: \(error)")
            return Catalog(islands: [], rewards: [], intro: [], introAfter: [])
        }
    }()

    public var allLevels: [LevelDef] { islands.flatMap(\.levels) }

    public func level(_ id: String) -> LevelDef? { allLevels.first { $0.id == id } }

    public func island(_ id: String) -> Island? { islands.first { $0.id == id } }

    public func island(containing levelID: String) -> Island? {
        islands.first { $0.levels.contains { $0.id == levelID } }
    }

    public func reward(_ id: String) -> Reward? { rewards.first { $0.id == id } }

    /// The level that follows `levelID` on the same island, if any.
    public func nextLevel(after levelID: String) -> LevelDef? {
        guard let island = island(containing: levelID),
              let index = island.levels.firstIndex(where: { $0.id == levelID }),
              index + 1 < island.levels.count
        else { return nil }
        return island.levels[index + 1]
    }

    /// Decorations everyone starts with or earns from star totals: (stars needed, reward id).
    public static let starDecorations: [(stars: Int, reward: String)] = [
        (0, "deco-palm"), (6, "deco-flowers"), (20, "deco-castle"), (45, "deco-tent"),
    ]
}
