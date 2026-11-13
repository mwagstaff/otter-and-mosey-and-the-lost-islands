import LostIslandsCore
import SwiftUI

/// Speech bubbles for story moments. Tap anywhere to move on; Skip jumps to the end.
struct DialogueView: View {
    var lines: [DialogueLine]
    var guardianName: String = "Guardian"
    /// Set when the level's HUD is on screen, so Skip sits under it instead of over its buttons.
    var belowHUD = false
    var onLineShown: (Int) -> Void = { _ in }
    var onFinish: () -> Void

    @State private var index = 0
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale
    @Environment(AppModel.self) private var model

    private var line: DialogueLine { lines[min(index, lines.count - 1)] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture(perform: advance)
            // No portrait here: the speaker is already on screen, talking, and named on the badge.
            Group {
                VStack(alignment: .leading, spacing: 6) {
                    Text(speakerName)
                        .font(.game(compact ? 15 : 19 * scale))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(speakerColour))
                    Text(line.text)
                        .font(.game(compact ? 21 : 30 * scale, weight: .bold))
                        .gameTracking()
                        .foregroundStyle(model.settings.highContrast ? .black : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Spacer()
                        IconLabel("Tap to continue", symbol: "play.fill", size: compact ? 13 : 16 * scale, trailing: true)
                            .font(.game(compact ? 13 : 16 * scale, weight: .bold))
                            .foregroundStyle(Palette.ink.opacity(0.55))
                    }
                }
                .padding(compact ? 14 : 22)
                .panel(fill: model.settings.highContrast ? .white : Palette.cream)
                .onTapGesture(perform: advance)
            }
            .padding(.horizontal, compact ? 16 : 40)
            .padding(.bottom, compact ? 10 : 30)
            .frame(maxWidth: 1000 * scale)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: tapped(finish)) { IconLabel("Skip", symbol: "forward.end.fill", size: compact ? 16 : 20 * scale, trailing: true) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20 * scale))
                .padding(compact ? 12 : 24)
                .padding(.top, belowHUD ? GameHUD.height(compact: compact, scale: scale) : 0)
        }
        .onAppear(perform: show)
    }

    /// Room to leave at the bottom of a scene so its ground shows above the speech panel.
    static func reservedHeight(compact: Bool) -> CGFloat { compact ? 124 : 190 }

    private var speakerName: String {
        switch line.speaker {
        case .otter: "Otter"
        case .mosey: "Mosey"
        case .guardian: guardianName
        case .narrator: "Story"
        }
    }

    private var speakerColour: Color {
        switch line.speaker {
        case .otter: Palette.hex("#8A4B2A")
        case .mosey: Palette.hex("#1F6FD0")
        case .guardian: Palette.hex("#8E5BD9")
        case .narrator: Palette.ink
        }
    }

    private func show() {
        onLineShown(index)
        AudioManager.shared.play(.nav, volume: 0.6)
        // The mouth and speech badge move for every speaker, recorded or not.
        Narrator.shared.speakLine(line, voiced: model.settings.characterVoices)
    }

    private func advance() {
        if index + 1 < lines.count {
            index += 1
            show()
        } else {
            finish()
        }
    }

    private func finish() {
        Narrator.shared.stop()
        onFinish()
    }
}
