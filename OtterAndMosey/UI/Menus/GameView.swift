import GameController
import LostIslandsCore
import SpriteKit
import SwiftUI

/// Hosts one level: the SpriteKit scene with the HUD, keys, dialogue and results over it.
struct GameView: View {
    let level: LevelDef
    let island: Island

    private enum Stage { case intro, playing, outro, results }

    @Environment(AppModel.self) private var model
    @State private var bridge = GameBridge()
    @State private var scene: GameScene?
    @State private var stage = Stage.intro
    @State private var paused = false
    @State private var summary: RewardSummary?
    @State private var result: LevelResult?
    @State private var hardware = InputDetector.hasHardwareKeyboard

    var body: some View {
        GeometryReader { geometry in
            let compact = ScreenMetrics.isCompact(geometry)
            ZStack {
                if let scene {
                    SpriteView(scene: scene, isPaused: paused, preferredFramesPerSecond: 60)
                        .ignoresSafeArea()
                }
                if stage == .playing || stage == .outro {
                    VStack(spacing: 4) {
                        GameHUD(bridge: bridge) { paused = true }
                        HUDExtras(bridge: bridge)
                        Spacer(minLength: 0)
                        if !hardware, stage == .playing, bridge.dialogue.isEmpty {
                            GameKeyboard(kind: bridge.keyboard, width: geometry.size.width - 16,
                                         onKey: { bridge.key($0) }, onBackspace: { bridge.backspace() })
                        } else if hardware, bridge.keyboard != .none, stage == .playing {
                            Text("⌨️ Type on your keyboard")
                                .font(.game(compact ? 15 : 19, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Palette.ink.opacity(0.8)))
                                .padding(.bottom, 6)
                        }
                    }
                    HardwareKeys(onKey: { bridge.key($0) }, onBackspace: { bridge.backspace() })
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                }
                overlays
            }
            .environment(\.compact, compact)
            .environment(\.uiScale, ScreenMetrics.scale(geometry))
            .onAppear { makeScene(geometry: geometry, compact: compact) }
            .onChange(of: geometry.size) { _, _ in applyInsets(geometry: geometry, compact: compact) }
            .onChange(of: hardware) { _, _ in applyInsets(geometry: geometry, compact: compact) }
        }
        .onChange(of: bridge.result) { _, newValue in
            if let newValue { finish(with: newValue) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in hardware = true }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in hardware = InputDetector.hasHardwareKeyboard }
        .onDisappear { Narrator.shared.stop() }
    }

    @ViewBuilder private var overlays: some View {
        let theme = IslandTheme.island(island.id)
        if stage == .intro {
            DialogueView(lines: level.intro, guardianArt: theme.guardian, guardianName: island.guardian.name) {
                stage = .playing
                scene?.begin()
            }
        } else if !bridge.dialogue.isEmpty {
            DialogueView(lines: bridge.dialogue, guardianArt: bridge.friendship == nil ? theme.guardianHappy : theme.guardian,
                         guardianName: island.guardian.name) { bridge.finishDialogue() }
                .id(bridge.dialogue.first?.text ?? "")
        } else if stage == .outro {
            DialogueView(lines: level.outro, guardianArt: theme.guardianHappy, guardianName: island.guardian.name) { stage = .results }
        } else if stage == .results, let summary, let result {
            LevelCompleteView(level: level, island: island, result: result, summary: summary)
                .transition(.opacity)
        }
        if paused {
            PauseView(title: level.title, resume: { paused = false }, restart: restart, quit: { model.route = .island(island.id) })
        }
    }

    // MARK: - Scene

    private func reservedKeys(compact: Bool) -> CGFloat {
        // Guardians only need keys when they ask spelling questions.
        let typesWords = level.skills.contains { $0.subject == .spelling }
        if level.mode == .guardian, !typesWords { return 0 }
        if hardware { return level.mode == .mathsSplash || level.mode == .bridgeBuilder ? 0 : 40 }
        switch level.mode {
        case .wordBlaster, .guardian:
            return compact ? KeyMetrics.trayHeight(compact: true) + 14 : KeyMetrics.qwertyHeight(compact: false) + 14
        case .typingTurbo: return KeyMetrics.qwertyHeight(compact: compact) + 14
        case .eggRescue: return KeyMetrics.numberHeight(compact: compact) + 14
        case .mathsSplash, .bridgeBuilder: return 0
        }
    }

    private func insets(geometry: GeometryProxy, compact: Bool) -> UIEdgeInsets {
        let safe = geometry.safeAreaInsets
        return UIEdgeInsets(top: safe.top + GameHUD.height(compact: compact, scale: ScreenMetrics.scale(geometry)) + 6, left: safe.leading + 8,
                            bottom: safe.bottom + reservedKeys(compact: compact), right: safe.trailing + 8)
    }

    private func applyInsets(geometry: GeometryProxy, compact: Bool) {
        scene?.insets = insets(geometry: geometry, compact: compact)
    }

    private func makeScene(geometry: GeometryProxy, compact: Bool) {
        guard scene == nil, let profile = model.profile else { return }
        let base = model.restoration(of: island)
        let isGuardian = level.mode == .guardian
        let options = SceneOptions(
            settings: model.settings,
            favourite: profile.favourite == "mosey" ? .mosey : .otter,
            accessory: profile.equippedAccessory.flatMap { model.catalog.reward($0)?.emoji },
            island: island,
            inputProfile: InputDetector.profile(compact: compact),
            startRestoration: CGFloat(base * 0.75),
            endRestoration: isGuardian ? 1 : CGFloat(min(1, base * 0.75 + 0.5))
        )
        var limit: Int?
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-debugShort") { limit = 3 }
        #endif
        let session = ChallengeSession(level: level, learner: profile.learner, settings: profile.parent,
                                       inputProfile: options.inputProfile, questionLimit: limit)
        bridge.onLearnerChanged = { [model] learner in model.updateLearner(learner) }
        let made: GameScene
        switch level.mode {
        case .wordBlaster: made = WordBlasterScene(session: session, bridge: bridge, options: options)
        case .mathsSplash: made = MathsSplashScene(session: session, bridge: bridge, options: options)
        case .bridgeBuilder: made = BridgeBuilderScene(session: session, bridge: bridge, options: options)
        case .eggRescue: made = EggRescueScene(session: session, bridge: bridge, options: options)
        case .typingTurbo: made = TypingTurboScene(session: session, bridge: bridge, options: options)
        case .guardian: made = GuardianScene(session: session, bridge: bridge, options: options)
        }
        made.insets = insets(geometry: geometry, compact: compact)
        scene = made
    }

    private func finish(with levelResult: LevelResult) {
        guard summary == nil, let scene else { return }
        result = levelResult
        summary = model.complete(levelID: level.id, result: levelResult, learner: scene.session.learner, friendshipUses: bridge.friendshipUses)
        stage = .outro
    }

    private func restart() {
        // Rebuild this screen from scratch with fresh questions.
        model.route = .island(island.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { model.route = .play(level.id) }
    }
}

struct PauseView: View {
    var title: String
    var resume: () -> Void
    var restart: () -> Void
    var quit: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: compact ? 10 : 18) {
                Text("Paused").font(.game(compact ? 30 : 44)).foregroundStyle(Palette.ink)
                Text(title).font(.game(compact ? 16 : 22, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                Button("▶  Keep playing", action: tapped(resume)).buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: 260))
                HStack(spacing: 12) {
                    Button("↺ Start again", action: tapped(restart)).buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button("⚙︎ Sound", action: tapped { model.showSettings = true }).buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button("🏝 Leave", action: tapped(quit)).buttonStyle(ChunkyButtonStyle(fill: Palette.coral, ink: .white, size: compact ? 17 : 22))
                }
            }
            .padding(compact ? 20 : 36)
            .panel()
            .scaleEffect(scale)
        }
    }
}

/// The celebration after a level: stars, what was earned, and where to go next.
struct LevelCompleteView: View {
    let level: LevelDef
    let island: Island
    let result: LevelResult
    let summary: RewardSummary
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale
    @State private var shownStars = 0

    private var next: LevelDef? {
        guard let profile = model.profile, let next = model.catalog.nextLevel(after: level.id),
              Progression.isUnlocked(levelID: next.id, in: profile, catalog: model.catalog) else { return nil }
        return next
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: compact ? 6 : 14) {
                Text(headline).font(.game(compact ? 28 : 44)).foregroundStyle(Palette.ink).gameTracking()
                StarRow(stars: shownStars, size: compact ? 44 : 70)
                    .animation(.spring(duration: 0.4, bounce: 0.6), value: shownStars)
                HStack(spacing: compact ? 14 : 24) {
                    stat("Score", "\(result.score)")
                    stat(level.mode == .typingTurbo ? "Accuracy" : "First try", "\(Int((result.accuracy * 100).rounded()))%")
                    if result.bestCombo >= 2 { stat("Best streak", "\(result.bestCombo)") }
                    if let speed = result.wordsPerMinute { stat("Speed", "\(Int(speed.rounded())) wpm") }
                }
                rewards
                HStack(spacing: 12) {
                    Button("🏝 Island", action: tapped { model.route = .island(island.id) })
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button("↺ Again", action: tapped { replay() })
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    if summary.gameComplete {
                        Button("🌈 The ending!", action: tapped { model.route = .ending })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                    } else if let next {
                        Button("Next ▶", action: tapped { model.route = .play(next.id) })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26, minWidth: 150))
                    } else if summary.crystalIsland != nil {
                        Button("🗺 Map", action: tapped { model.route = .map })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26, minWidth: 150))
                    }
                }
                .padding(.top, 4)
            }
            .padding(compact ? 16 : 34)
            .frame(maxWidth: compact ? 640 : 820)
            .panel()
            .scaleEffect(scale)
            .padding(20)
        }
        .task {
            for star in 1...max(result.stars, 1) {
                try? await Task.sleep(for: .seconds(0.4))
                shownStars = star
                AudioManager.shared.play(.star)
                Haptics.shared.tap()
            }
            if summary.crystalIsland != nil || summary.reward != nil { AudioManager.shared.play(.unlock) }
        }
    }

    private var headline: String {
        if summary.crystalIsland != nil { return "Crystal fragment found!" }
        return result.stars == 3 ? "Superstar!" : result.stars == 2 ? "Great work!" : "You did it!"
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.game(compact ? 22 : 32)).foregroundStyle(Palette.ink)
            Text(title).font(.game(compact ? 12 : 16, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.6))
        }
    }

    @ViewBuilder private var rewards: some View {
        let items: [(String, String)] =
            (summary.crystalIsland.map { [("💎", "\($0.name) crystal")] } ?? [])
            + (summary.reward.map { [($0.emoji, $0.name)] } ?? [])
            + summary.decorations.map { ($0.emoji, $0.name) }
            + summary.achievements.map { ($0.emoji, $0.title) }
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Text(item.0).font(.system(size: compact ? 24 : 34))
                            Text(item.1).font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.gold.opacity(0.5)).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: compact ? 46 : 60)
        }
    }

    private func replay() {
        model.route = .island(island.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { model.route = .play(level.id) }
    }
}
