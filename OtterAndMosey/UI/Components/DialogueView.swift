import LostIslandsCore
import SwiftUI

/// Speech bubbles for story moments. Tap anywhere to move on; Skip jumps to the end.
struct DialogueView: View {
    var lines: [DialogueLine]
    var guardianArt: String?
    var guardianName: String = "Guardian"
    var onLineShown: (Int) -> Void = { _ in }
    var onFinish: () -> Void

    @State private var index = 0
    @State private var appear = false
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale
    @Environment(AppModel.self) private var model

    private var line: DialogueLine { lines[min(index, lines.count - 1)] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture(perform: advance)
            HStack(alignment: .bottom, spacing: compact ? 10 : 18) {
                portrait
                    .frame(width: compact ? 96 : 150 * scale, height: compact ? 96 : 150 * scale)
                    .scaleEffect(appear ? 1 : 0.6)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: appear)
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
                        Text("Tap to continue ▶")
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
            Button("Skip ⏭", action: tapped(finish))
                .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20 * scale))
                .padding(compact ? 12 : 24)
        }
        .onAppear {
            appear = true
            show()
        }
    }

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

    @ViewBuilder private var portrait: some View {
        switch line.speaker {
        case .otter: Image("otter_idle").resizable().scaledToFit()
        case .mosey: Image("mosey_idle").resizable().scaledToFit()
        case .guardian: Image(guardianArt ?? "guardian_tree").resizable().scaledToFit()
        case .narrator: Text("📖").font(.system(size: compact ? 60 : 96))
        }
    }

    private func show() {
        onLineShown(index)
        AudioManager.shared.play(.nav, volume: 0.6)
        if model.settings.spokenInstructions { Narrator.shared.speak(line.text) }
    }

    private func advance() {
        if index + 1 < lines.count {
            appear = false
            index += 1
            appear = true
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
