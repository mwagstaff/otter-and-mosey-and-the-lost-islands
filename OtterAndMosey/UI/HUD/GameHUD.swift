import LostIslandsCore
import SwiftUI

/// The strip across the top of every level: pause, progress, the question, hint and listen.
struct GameHUD: View {
    var bridge: GameBridge
    var onPause: () -> Void
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale
    @Environment(AppModel.self) private var model

    static func height(compact: Bool, scale: CGFloat = 1) -> CGFloat { compact ? 64 : 92 * scale }

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            RoundButton(symbol: "pause.fill", size: compact ? 52 : 62 * scale, label: "Pause", action: onPause)
            progress
            Text(bridge.caption)
                .font(.game(captionSize, weight: .bold))
                .gameTracking()
                .foregroundStyle(model.settings.highContrast ? .black : Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: compact ? 52 : 68 * scale)
                .panel(fill: model.settings.highContrast ? .white : Palette.cream, radius: 18)
            if bridge.combo >= 2 {
                Text("×\(bridge.multiplier) 🔥\(bridge.combo)")
                    .font(.game(compact ? 16 : 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.coral).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3)))
                    .transition(.scale.combined(with: .opacity))
            }
            RoundButton(symbol: "speaker.wave.2.fill", size: compact ? 52 : 62 * scale, label: "Hear it again") { bridge.repeatSpeech() }
            RoundButton(symbol: "lightbulb.fill", fill: Palette.gold, size: compact ? 52 : 62 * scale, label: "Hint") { bridge.hint() }
        }
        .padding(.horizontal, compact ? 6 : 16)
        .frame(height: Self.height(compact: compact, scale: scale))
        .animation(.spring(duration: 0.25), value: bridge.combo)
    }

    private var captionSize: CGFloat {
        let base: CGFloat = compact ? 24 : 34 * scale
        return bridge.caption.count > 40 ? base * 0.8 : base
    }

    private var progress: some View {
        VStack(spacing: 3) {
            Text("\(bridge.completed)/\(bridge.total)")
                .font(.game(compact ? 15 : 19))
                .foregroundStyle(Palette.ink)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ink.opacity(0.18))
                Capsule().fill(LinearGradient(colors: Art.rainbow.map { Color($0) }, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, (compact ? 60 : 84) * CGFloat(bridge.completed) / CGFloat(max(bridge.total, 1))))
            }
            .frame(width: compact ? 60 : 84, height: 10)
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .panel(radius: 16)
        .animation(.spring(duration: 0.4), value: bridge.completed)
        .accessibilityLabel("\(bridge.completed) of \(bridge.total) done")
    }
}

/// The hint bubble, praise toasts and the Friendship Power meter that sit just under the HUD.
struct HUDExtras: View {
    var bridge: GameBridge
    @State private var toastVisible = false
    @Environment(\.compact) private var compact

    var body: some View {
        VStack(spacing: 6) {
            if let hint = bridge.hintText {
                HStack(spacing: 8) {
                    Text("💡")
                    Text(hint).font(.game(compact ? 16 : 22, weight: .bold)).gameTracking().foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .panel(fill: Palette.gold.opacity(0.95), radius: 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack {
                if let charge = bridge.friendship {
                    FriendshipMeter(charge: charge)
                }
                Spacer()
                if toastVisible {
                    Text(bridge.toast)
                        .font(.game(compact ? 20 : 28))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Palette.teal).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, compact ? 10 : 20)
        .animation(.spring(duration: 0.3), value: bridge.hintText)
        .animation(.spring(duration: 0.25, bounce: 0.4), value: toastVisible)
        .onChange(of: bridge.toastID) { _, id in
            toastVisible = true
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                if bridge.toastID == id { toastVisible = false }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FriendshipMeter: View {
    var charge: Double
    @Environment(\.compact) private var compact

    var body: some View {
        HStack(spacing: 8) {
            Text("💞").font(.system(size: compact ? 22 : 30))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.85))
                Capsule().fill(LinearGradient(colors: [Palette.pink, Palette.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(14, (compact ? 150 : 230) * charge))
            }
            .frame(width: compact ? 150 : 230, height: compact ? 18 : 24)
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
            .animation(.spring(duration: 0.5), value: charge)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .panel(radius: 20)
        .accessibilityLabel("Friendship Power \(Int(charge * 100)) percent")
    }
}
