import LostIslandsCore
import SwiftUI

enum Palette {
    static let ink = Color(red: 0.055, green: 0.231, blue: 0.263)
    static let cream = Color(red: 1.0, green: 0.965, blue: 0.878)
    static let gold = Color(red: 1.0, green: 0.784, blue: 0.239)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.369)
    static let teal = Color(red: 0.09, green: 0.722, blue: 0.651)
    static let sky = Color(red: 0.239, green: 0.722, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.494, blue: 0.714)
    static let leaf = Color(red: 0.118, green: 0.62, blue: 0.322)

    static func hex(_ hex: String) -> Color { Color(UIColor(hex: hex)) }
}

extension Font {
    /// The game typeface: rounded by default, or wide-spaced Verdana when easy-read text is on.
    static func game(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        if GameFont.easyRead {
            return .custom(weight == .regular || weight == .medium ? "Verdana" : "Verdana-Bold", size: size * 0.92)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// Wider letter spacing when easy-read text is on.
    func gameTracking() -> some View { tracking(GameFont.easyRead ? 1.4 : 0.2) }

    /// Paints a bundled picture edge to edge behind a screen without affecting its layout.
    func screenBackground(_ name: String, saturation: Double = 1, blur: CGFloat = 0, dim: Double = 0) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Image(name).resizable().scaledToFill()
                    .saturation(saturation)
                    .blur(radius: blur)
                    .overlay(Palette.ink.opacity(dim))
                    .ignoresSafeArea()
            }
    }

    /// A chunky cream card with a dark outline.
    func panel(fill: Color = Palette.cream, radius: CGFloat = 22, stroke: Color = Palette.ink) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 3.5))
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 5)
        )
    }
}

/// A big, squashy button with a solid drop edge. Sized for small fingers.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Palette.gold
    var ink: Color = Palette.ink
    var size: CGFloat = 24
    var minWidth: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.game(size))
            .gameTracking()
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, size * 0.95)
            .padding(.vertical, size * 0.5)
            .frame(minWidth: max(minWidth, 60), minHeight: 52)
            .background(
                ZStack {
                    Capsule().fill(Palette.ink).offset(y: configuration.isPressed ? 2 : 6)
                    Capsule().fill(fill)
                    Capsule().fill(.white.opacity(0.25)).padding(4).mask(Rectangle().padding(.bottom, size * 1.1))
                    Capsule().strokeBorder(Palette.ink, lineWidth: 3.5)
                }
            )
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A round icon button (pause, hint, back…), never smaller than 52 points.
struct RoundButton: View {
    var symbol: String
    var fill: Color = Palette.cream
    var size: CGFloat = 54
    var label: String
    var action: () -> Void

    var body: some View {
        Button {
            AudioManager.shared.play(.tap)
            Haptics.shared.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle().fill(Palette.ink).offset(y: 4)
                        Circle().fill(fill)
                        Circle().strokeBorder(Palette.ink, lineWidth: 3.5)
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct StarRow: View {
    var stars: Int
    var size: CGFloat = 22
    var total = 3

    var body: some View {
        HStack(spacing: size * 0.08) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(index < stars ? Palette.gold : Palette.ink.opacity(0.18))
                    .overlay(Image(systemName: "star").font(.system(size: size, weight: .black)).foregroundStyle(Palette.ink.opacity(index < stars ? 0.9 : 0.25)))
            }
        }
        .accessibilityLabel("\(stars) of \(total) stars")
    }
}

/// A small picture: the game's own painted art for an emoji or asset name where it exists,
/// otherwise the system emoji. `art` names a specific painting (a reward or a sticker).
struct Glyph: View {
    var emoji: String
    var size: CGFloat
    var art: String?

    init(_ emoji: String, size: CGFloat, art: String? = nil) {
        self.emoji = emoji
        self.size = size
        self.art = art
    }

    var body: some View {
        if let name = art.flatMap({ Art.iconName($0) }) ?? Art.iconName(emoji) {
            Image(name).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Text(emoji).font(.system(size: size * 0.82)).frame(width: size, height: size)
        }
    }
}

/// Words with a picture beside them, for buttons and captions. The picture is either painted
/// art (`emoji`) or a simple symbol in the text colour (`symbol`).
struct IconLabel: View {
    var text: String
    var emoji: String?
    var symbol: String?
    /// The text size the label sits in; the picture is sized to match.
    var size: CGFloat
    var trailing = false

    init(_ text: String, emoji: String? = nil, symbol: String? = nil, size: CGFloat, trailing: Bool = false) {
        self.text = text
        self.emoji = emoji
        self.symbol = symbol
        self.size = size
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: size * 0.32) {
            if !trailing { picture }
            Text(text)
            if trailing { picture }
        }
    }

    @ViewBuilder private var picture: some View {
        if let emoji {
            Glyph(emoji, size: size * 1.35).padding(.vertical, -size * 0.2)
        } else if let symbol {
            Image(systemName: symbol).font(.system(size: size * 0.78, weight: .heavy))
        }
    }
}

extension Reward {
    /// The painting of this reward.
    var art: String { "reward_\(id)" }
}



/// A small pill showing a count next to a picture, for stars and crystals in top bars.
struct CountChip: View {
    var emoji: String
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            Glyph(emoji, size: 28)
            Text(text).font(.game(20)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .panel(radius: 26)
    }
}

/// True on phone-height screens. Layouts use this instead of device checks.
struct CompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var compact: Bool {
        get { self[CompactKey.self] }
        set { self[CompactKey.self] = newValue }
    }
}

/// How much to enlarge play-screen chrome on big tablets (1 on phones and small iPads).
struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

enum ScreenMetrics {
    static func isCompact(_ geometry: GeometryProxy) -> Bool {
        geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom < 520
    }

    /// 1.0 up to an 11-inch iPad, rising to 1.3 on the 13-inch.
    static func scale(_ geometry: GeometryProxy) -> CGFloat {
        isCompact(geometry) ? 1 : min(max(geometry.size.height / 800, 1), 1.3)
    }
}

/// Plays the tap sound for any standard button action.
func tapped(_ action: @escaping () -> Void) -> () -> Void {
    {
        AudioManager.shared.play(.tap)
        Haptics.shared.tap()
        action()
    }
}
