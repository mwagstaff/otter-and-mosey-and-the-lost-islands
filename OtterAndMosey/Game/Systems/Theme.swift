import LostIslandsCore
import SpriteKit
import UIKit

/// The look of one island: which art to use and how its ambient effects behave.
struct IslandTheme {
    enum Ambient { case fireflies, bubbles, embers, sparkles, sprinkles, stars }

    let id: String
    let tint: UIColor
    let ambient: Ambient
    /// Little things that pop up as the island recovers.
    let blooms: [String]
    /// Art for the "type the answer to open it" mode: what is locked, and who comes out.
    let container: String
    let friend: String
    let music: String
    /// True when the heroes swim or float through this island's travel levels.
    let underwater: Bool

    var background: String { "bg_\(id)" }
    var foreground: String { "fg_\(id)" }
    var guardian: String { "guardian_\(guardianKind)" }
    var guardianHappy: String { "guardian_\(guardianKind)_happy" }
    var islandArt: String { "island_\(id)" }

    private var guardianKind: String {
        switch id {
        case "woods": "tree"
        case "bay": "octopus"
        case "dragon": "dragon"
        case "cloud": "wizard"
        case "candy": "marshmallow"
        default: "shadow"
        }
    }

    static func island(_ id: String) -> IslandTheme {
        switch id {
        case "woods":
            IslandTheme(id: id, tint: UIColor(hex: "#3FBF6B"), ambient: .fireflies, blooms: ["🌸", "🌼", "🌷", "🍄", "🦋"],
                        container: "chest", friend: "friend_fish", music: "music_woods", underwater: false)
        case "bay":
            IslandTheme(id: id, tint: UIColor(hex: "#29B6E8"), ambient: .bubbles, blooms: ["🐠", "🐚", "🪸", "⭐️", "🐟"],
                        container: "chest", friend: "friend_fish", music: "music_bay", underwater: true)
        case "dragon":
            IslandTheme(id: id, tint: UIColor(hex: "#F2683C"), ambient: .embers, blooms: ["🔥", "💎", "🌋", "✨", "🌺"],
                        container: "egg", friend: "babydragon", music: "music_dragon", underwater: false)
        case "cloud":
            IslandTheme(id: id, tint: UIColor(hex: "#8FA8FF"), ambient: .sparkles, blooms: ["🌈", "☁️", "🕊️", "🌼", "🎈"],
                        container: "chest", friend: "friend_fish", music: "music_cloud", underwater: false)
        case "candy":
            IslandTheme(id: id, tint: UIColor(hex: "#FF7EB6"), ambient: .sprinkles, blooms: ["🍭", "🍬", "🧁", "🍓", "🍩"],
                        container: "jar", friend: "friend_gummy", music: "music_candy", underwater: false)
        default:
            IslandTheme(id: "star", tint: UIColor(hex: "#9B6BFF"), ambient: .stars, blooms: ["⭐️", "🌟", "🪐", "💫", "☄️"],
                        container: "chest", friend: "friend_fish", music: "music_star", underwater: false)
        }
    }
}

/// Shared type styling for SpriteKit and SwiftUI, including the easy-read option.
enum GameFont {
    static var easyRead = false

    static func ui(_ size: CGFloat, weight: UIFont.Weight = .heavy) -> UIFont {
        if easyRead {
            // Verdana's open letter shapes and wide spacing are a common recommendation for dyslexic readers.
            return UIFont(name: weight >= .bold ? "Verdana-Bold" : "Verdana", size: size * 0.92) ?? .systemFont(ofSize: size, weight: weight)
        }
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static var kerning: CGFloat { easyRead ? 1.6 : 0.3 }
}

/// A SpriteKit label that uses the game typeface and re-renders when its text changes.
final class GameLabel: SKLabelNode {
    private var pointSize: CGFloat = 24
    private var ink: UIColor = .white
    private var weight: UIFont.Weight = .heavy
    private var tracking: CGFloat?
    /// When set, the label shrinks so its text never spills past this width.
    var fitWidth: CGFloat? { didSet { render() } }

    var string: String = "" { didSet { if string != oldValue { render() } } }
    var colour: UIColor { get { ink } set { ink = newValue; render() } }

    convenience init(_ text: String, size: CGFloat, colour: UIColor = .white, weight: UIFont.Weight = .heavy, tracking: CGFloat? = nil, maxWidth: CGFloat? = nil) {
        self.init()
        pointSize = size
        ink = colour
        self.weight = weight
        self.tracking = tracking
        verticalAlignmentMode = .center
        horizontalAlignmentMode = .center
        if let maxWidth {
            numberOfLines = 0
            preferredMaxLayoutWidth = maxWidth
        }
        string = text
        render()
    }

    private func render() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributedText = NSAttributedString(string: string, attributes: [
            .font: GameFont.ui(pointSize, weight: weight),
            .foregroundColor: ink,
            .kern: tracking ?? GameFont.kerning,
            .paragraphStyle: paragraph,
        ])
        if let fitWidth {
            setScale(1)
            let width = frame.width
            setScale(width > fitWidth && width > 0 ? fitWidth / width : 1)
        }
    }
}
