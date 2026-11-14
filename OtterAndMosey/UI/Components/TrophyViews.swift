import LostIslandsCore
import SwiftUI

extension Trophy {
    /// The ring colour for a milestone rung: bronze, silver, gold, rainbow pink, sky blue.
    var ringColour: Color? {
        guard tier > 0 else { return nil }
        return Self.rings[min(tier, Self.rings.count) - 1]
    }

    static let rings = [Color(hex: 0xC98A4B), Color(hex: 0xC9D3DB), Palette.gold, Palette.pink, Color(hex: 0x8FA8FF)]
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// One trophy's painting. A trophy still to be won shows as a soft silhouette of its shape.
struct TrophyBadge: View {
    let trophy: Trophy
    var earned = true
    var size: CGFloat
    /// The colour of the silhouette for a trophy still to be won.
    var ghost: Color = .white.opacity(0.2)

    var body: some View {
        ZStack {
            if let ring = trophy.ringColour {
                Circle().strokeBorder(earned ? ring : ghost, style: StrokeStyle(lineWidth: size * 0.07, dash: earned ? [] : [size * 0.08, size * 0.06]))
            }
            Image(trophy.art)
                .resizable()
                .renderingMode(earned ? .original : .template)
                .scaledToFit()
                .foregroundStyle(ghost)
                .padding(trophy.ringColour == nil ? 0 : size * 0.08)
            if let label = trophy.badge {
                Text(label)
                    .font(.game(size * 0.2))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.06)
                    .background(Capsule().fill(Palette.ink).overlay(Capsule().strokeBorder(trophy.ringColour ?? Palette.gold, lineWidth: max(1.5, size * 0.03))))
                    .opacity(earned ? 1 : 0.7)
                    .offset(x: size * 0.3, y: size * 0.36)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The little cabinet in the corner of the results screen that trophies fly into.
struct MiniCabinet: View {
    var won: Int
    var total: Int
    var height: CGFloat
    var bumps: Int

    var body: some View {
        VStack(spacing: 2) {
            Image("trophy_cabinet")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: bumps) { content, scale in
                    content.scaleEffect(x: scale.width, y: scale.height, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.width) {
                        CubicKeyframe(1.12, duration: 0.12)
                        CubicKeyframe(0.95, duration: 0.12)
                        CubicKeyframe(1, duration: 0.16)
                    }
                    KeyframeTrack(\.height) {
                        CubicKeyframe(0.9, duration: 0.12)
                        CubicKeyframe(1.06, duration: 0.12)
                        CubicKeyframe(1, duration: 0.16)
                    }
                }
            Text("\(won) / \(total)")
                .font(.game(height * 0.15))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .background(Capsule().fill(Palette.ink))
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trophy cabinet: \(won) of \(total) trophies")
    }
}

/// Moves a view along a gentle arc from one point to another as `progress` runs from 0 to 1.
struct ArcFlight: ViewModifier, Animatable {
    var progress: Double
    let from: CGPoint
    let to: CGPoint

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 180)
        let x = (1 - t) * (1 - t) * from.x + 2 * (1 - t) * t * control.x + t * t * to.x
        let y = (1 - t) * (1 - t) * from.y + 2 * (1 - t) * t * control.y + t * t * to.y
        content
            .scaleEffect(1.1 - 0.8 * t)
            .rotationEffect(.degrees(-18 * sin(t * .pi)))
            .position(x: x, y: y)
    }
}

/// The Trophies button used on the title screen and the map.
struct TrophiesButton: View {
    var size: CGFloat
    /// Leaves out the word where the bar is short of room; the picture and count remain.
    var showsTitle = true
    @Environment(AppModel.self) private var model

    var body: some View {
        let count = model.profile.map { Trophies.count(in: $0, catalog: model.catalog).won } ?? 0
        Button(action: tapped { model.openTrophies() }) {
            HStack(spacing: size * 0.32) {
                Glyph("🏆", size: size * 1.35, art: "trophy_champion").padding(.vertical, -size * 0.2)
                if showsTitle { Text("Trophies") }
                Text("\(count)")
                    .font(.game(size * 0.72))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.35)
                    .background(Capsule().fill(Palette.ink))
            }
        }
        .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: size))
        .overlay(alignment: .topTrailing) {
            if model.hasNewTrophies {
                Text("New!")
                    .font(.game(size * 0.6))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Palette.coral).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)))
                    .rotationEffect(.degrees(8))
                    .offset(x: 8, y: -12)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Trophies, \(count) won\(model.hasNewTrophies ? ", new ones to see" : "")")
    }
}
