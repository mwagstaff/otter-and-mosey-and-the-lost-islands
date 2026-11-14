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
                            IconLabel("Type on your keyboard", symbol: "keyboard.fill", size: compact ? 15 : 19)
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
                overlays(geometry: geometry, compact: compact)
            }
            .environment(\.compact, compact)
            .environment(\.uiScale, ScreenMetrics.scale(geometry))
            .onAppear {
                makeScene(geometry: geometry, compact: compact)
                #if DEBUG
                // `-debugResults` jumps straight to the results screen with a perfect run.
                if ProcessInfo.processInfo.arguments.contains("-debugResults"), let scene {
                    var perfect = LevelResult(stars: 3, accuracy: 1, score: 900, bestCombo: level.count, correctFirstTry: level.count, total: level.count)
                    perfect.pearls = 10
                    result = perfect
                    summary = model.complete(levelID: level.id, result: perfect, learner: scene.session.learner, friendshipUses: 0)
                    stage = .results
                }
                #endif
            }
            .onChange(of: geometry.size) { _, _ in applyInsets(geometry: geometry, compact: compact) }
            .onChange(of: hardware) { _, _ in applyInsets(geometry: geometry, compact: compact) }
            .onChange(of: stage) { _, _ in applyInsets(geometry: geometry, compact: compact) }
            .onChange(of: bridge.dialogue.isEmpty) { _, _ in applyInsets(geometry: geometry, compact: compact) }
        }
        .onChange(of: bridge.result) { _, newValue in
            if let newValue { finish(with: newValue) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in hardware = true }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in hardware = InputDetector.hasHardwareKeyboard }
    }

    @ViewBuilder private func overlays(geometry: GeometryProxy, compact: Bool) -> some View {
        if stage == .intro {
            DialogueView(lines: level.intro, guardianName: island.guardian.name) {
                stage = .playing
                // Make room for the keys before the first question is laid out.
                applyInsets(geometry: geometry, compact: compact, playing: true)
                scene?.begin()
            }
        } else if !bridge.dialogue.isEmpty {
            DialogueView(lines: bridge.dialogue, guardianName: island.guardian.name, belowHUD: true) {
                // Back to the playing layout before the scene lays out its next question.
                applyInsets(geometry: geometry, compact: compact, playing: stage == .playing)
                bridge.finishDialogue()
            }
                .id(bridge.dialogue.first?.text ?? "")
        } else if stage == .outro {
            DialogueView(lines: level.outro, guardianName: island.guardian.name, belowHUD: true) { stage = .results }
        } else if stage == .results, let summary, let result {
            LevelCompleteView(level: level, island: island, result: result, summary: summary)
                .transition(.opacity)
        }
        if paused {
            PauseView(title: level.title, resume: { paused = false }, restart: restart, quit: leave)
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

    private func insets(geometry: GeometryProxy, compact: Bool, playing: Bool) -> UIEdgeInsets {
        let safe = geometry.safeAreaInsets
        // The keys are only on screen while playing. Whenever someone is talking, the ground sits
        // just above the speech panel instead, so the panel never covers the characters and the
        // scenery is not left floating over an empty gap.
        let bottom = playing ? reservedKeys(compact: compact) : DialogueView.reservedHeight(compact: compact)
        return UIEdgeInsets(top: safe.top + GameHUD.height(compact: compact, scale: ScreenMetrics.scale(geometry)) + 6, left: safe.leading + 8,
                            bottom: safe.bottom + bottom, right: safe.trailing + 8)
    }

    private func applyInsets(geometry: GeometryProxy, compact: Bool, playing: Bool? = nil) {
        scene?.insets = insets(geometry: geometry, compact: compact, playing: playing ?? (stage == .playing && bridge.dialogue.isEmpty))
    }

    private func makeScene(geometry: GeometryProxy, compact: Bool) {
        guard scene == nil, let profile = model.playingProfile else { return }
        let base = model.restoration(of: island)
        let isGuardian = level.mode == .guardian
        let options = SceneOptions(
            settings: model.settings,
            accessory: profile.equippedAccessory.flatMap { model.catalog.reward($0) }.map { Art.iconName($0.art) ?? $0.emoji },
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
        made.insets = insets(geometry: geometry, compact: compact, playing: false)
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
        model.replay(level.id)
    }

    private func leave() {
        if model.playtest != nil { model.endPlaytest() } else { model.route = .island(island.id) }
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
                if model.playtest != nil { PlaytestNote() }
                Button(action: tapped(resume)) { IconLabel("Keep playing", symbol: "play.fill", size: compact ? 22 : 28) }.buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: 260))
                HStack(spacing: 12) {
                    Button(action: tapped(restart)) { IconLabel("Start again", symbol: "arrow.counterclockwise", size: compact ? 17 : 22) }.buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button(action: tapped { model.showSettings = true }) { IconLabel("Sound", symbol: "gearshape.fill", size: compact ? 17 : 22) }.buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button(action: tapped(quit)) {
                        if model.playtest != nil {
                            IconLabel("Dashboard", symbol: "chart.bar.fill", size: compact ? 17 : 22)
                        } else {
                            IconLabel("Leave", emoji: "🏝", size: compact ? 17 : 22)
                        }
                    }.buttonStyle(ChunkyButtonStyle(fill: Palette.coral, ink: .white, size: compact ? 17 : 22))
                }
            }
            .padding(compact ? 20 : 36)
            .panel()
            .scaleEffect(scale)
        }
    }
}

/// The celebration after a level: stars, what was earned, and where to go next.
/// New trophies wait in a tray until each is tapped and flies into the little cabinet in the
/// corner; only then do the buttons appear.
struct LevelCompleteView: View {
    let level: LevelDef
    let island: Island
    let result: LevelResult
    let summary: RewardSummary
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @Environment(\.uiScale) private var scale
    @State private var shownStars = 0
    @State private var collected: Set<String> = []
    @State private var flights: [Flight] = []
    @State private var tokenFrames: [String: CGRect] = [:]
    @State private var cabinetFrame = CGRect.zero
    @State private var cabinetBumps = 0
    @State private var nudge = 0

    private struct Flight: Identifiable {
        let id: String
        let trophy: Trophy
        let from: CGPoint
        let to: CGPoint
        var progress = 0.0
    }

    private var next: LevelDef? {
        // Play-testing ignores locks.
        if model.playtest != nil { return model.catalog.nextLevel(after: level.id) }
        guard let profile = model.profile, let next = model.catalog.nextLevel(after: level.id),
              Progression.isUnlocked(levelID: next.id, in: profile, catalog: model.catalog) else { return nil }
        return next
    }

    /// The island the crystal just found opens up.
    private var nextIsland: Island? {
        guard let index = model.catalog.islands.firstIndex(where: { $0.id == island.id }), index + 1 < model.catalog.islands.count else { return nil }
        return model.catalog.islands[index + 1]
    }

    private var allCollected: Bool { summary.trophies.allSatisfy { collected.contains($0.id) } }
    private var cabinetCount: Int { summary.trophyCount - summary.trophies.count + collected.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            panel
                .scaleEffect(scale)
                .padding(compact ? 10 : 20)
            if !summary.trophies.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniCabinet(won: cabinetCount, total: summary.trophyTotal, height: compact ? 74 : 120, bumps: cabinetBumps)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("results")) } action: { cabinetFrame = $0 }
                    }
                }
                .padding(compact ? 8 : 24)
                .transition(.opacity)
            }
            ForEach(flights) { flight in
                TrophyBadge(trophy: flight.trophy, size: compact ? 60 : 108)
                    .modifier(ArcFlight(progress: flight.progress, from: flight.from, to: flight.to))
                    .opacity(model.settings.reducedMotion ? 1 - flight.progress : 1)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(.named("results"))
        .task {
            for star in 1...max(result.stars, 1) {
                try? await Task.sleep(for: .seconds(0.4))
                shownStars = star
                AudioManager.shared.play(.star)
                Haptics.shared.tap()
            }
            if summary.crystalIsland != nil || summary.reward != nil { AudioManager.shared.play(.unlock) }
        }
        .task {
            // A gentle wiggle if the trophies sit untapped for a while.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                if allCollected { return }
                nudge += 1
            }
        }
    }

    private var panel: some View {
        VStack(spacing: compact ? 6 : 12) {
            if let found = summary.crystalIsland {
                HStack(alignment: .center, spacing: compact ? 14 : 26) {
                    CrystalShowcase(island: found, height: compact ? 136 : 330)
                    VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                        Text(headline).font(.game(compact ? 22 : 42)).foregroundStyle(Palette.ink).gameTracking()
                        StarRow(stars: shownStars, size: compact ? 26 : 56)
                            .animation(.spring(duration: 0.4, bounce: 0.6), value: shownStars)
                        FragmentRow(found: model.playingProfile?.crystals ?? [found.id], catalog: model.catalog, height: compact ? 22 : 50)
                        stats
                    }
                }
            } else {
                Text(headline).font(.game(compact ? 28 : 44)).foregroundStyle(Palette.ink).gameTracking()
                StarRow(stars: shownStars, size: compact ? 32 : 70)
                    .animation(.spring(duration: 0.4, bounce: 0.6), value: shownStars)
                stats
            }
            if model.playtest != nil { PlaytestNote() }
            rewards
            if !summary.trophies.isEmpty { tray }
            actions
                .padding(.top, compact ? 0 : 4)
        }
        .padding(.horizontal, compact ? 14 : 30)
        .padding(.vertical, compact ? 8 : 30)
        .frame(maxWidth: summary.crystalIsland != nil ? (compact ? 720 : 960) : (compact ? 640 : 820))
        .panel()
    }

    private var stats: some View {
        HStack(spacing: compact ? 14 : 24) {
            stat("Score", "\(result.score)")
            stat(level.mode == .typingTurbo ? "Accuracy" : "First try", "\(Int((result.accuracy * 100).rounded()))%")
            if result.bestCombo >= 2 { stat("Best streak", "\(result.bestCombo)") }
            if let speed = result.wordsPerMinute { stat("Speed", "\(Int(speed.rounded())) wpm") }
        }
    }

    private var headline: String {
        if summary.crystalIsland != nil { return "Crystal fragment found!" }
        return result.stars == 3 ? "Superstar!" : result.stars == 2 ? "Great work!" : "You did it!"
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.game(compact ? 18 : 32)).foregroundStyle(Palette.ink)
            Text(title).font(.game(compact ? 12 : 16, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.6))
        }
    }

    @ViewBuilder private var rewards: some View {
        let items: [(String, String?, String)] =
            (summary.reward.map { [($0.emoji, $0.art, $0.name)] } ?? [])
            + summary.decorations.map { ($0.emoji, $0.art, $0.name) }
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Glyph(item.0, size: compact ? 30 : 42, art: item.1)
                            Text(item.2).font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.gold.opacity(0.5)).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: compact ? 46 : 60)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Trophies

    private var trayTitle: Text {
        let left = summary.trophies.count - collected.count
        if left == 0 {
            return Text("All in your cabinet! ").foregroundColor(Palette.gold) + Text("\(summary.trophyCount) of \(summary.trophyTotal) trophies")
        }
        let lead = left == summary.trophies.count
            ? (left == 1 ? "A new trophy! " : "\(left) new trophies! ")
            : "\(left) more to go! "
        return Text(lead).foregroundColor(Palette.gold) + Text(left == 1 ? "Tap it to put it in your cabinet" : "Tap them to put them in your cabinet")
    }

    private var tray: some View {
        VStack(spacing: compact ? 2 : 6) {
            trayTitle
                .font(.game(compact ? 14 : 19))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: compact ? 24 : 46) {
                ForEach(summary.trophies) { trophy in token(trophy) }
            }
            if summary.trophiesWaiting > 0, allCollected {
                Text(summary.trophiesWaiting == 1 ? "1 more trophy is waiting for your next level" : "\(summary.trophiesWaiting) more trophies are waiting for your next levels")
                    .font(.game(compact ? 11 : 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xA9DCD5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 4 : 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.ink))
    }

    private func token(_ trophy: Trophy) -> some View {
        let done = collected.contains(trophy.id) || flights.contains { $0.id == trophy.id }
        let size: CGFloat = compact ? (done ? 30 : 48) : (done ? 60 : 108)
        return Button(action: { collect(trophy) }) {
            VStack(spacing: 1) {
                ZStack {
                    if !done {
                        Circle()
                            .fill(RadialGradient(colors: [Palette.gold.opacity(0.75), Palette.gold.opacity(0)], center: .center, startRadius: 4, endRadius: size * 0.75))
                            .frame(width: size * 1.5, height: size * 1.5)
                    }
                    TrophyBadge(trophy: trophy, size: size)
                        .opacity(flights.contains { $0.id == trophy.id } ? 0 : 1)
                        .phaseAnimator([0, 1], trigger: nudge) { content, phase in
                            content.rotationEffect(.degrees(done ? 0 : phase * 10))
                        } animation: { _ in .spring(duration: 0.18, bounce: 0.7) }
                }
                .frame(height: done ? (compact ? 32 : 66) : (compact ? 52 : 116))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("results")) } action: { tokenFrames[trophy.id] = $0 }
                .overlay(alignment: .topTrailing) {
                    if !done {
                        Text("Tap!")
                            .font(.game(compact ? 11 : 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(Palette.coral).overlay(Capsule().strokeBorder(.white, lineWidth: 2.5)))
                            .offset(x: 6)
                    }
                }
                Text(trophy.title).font(.game(compact ? 13 : 18)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                Text(trophy.badge.map { trophy.tier > 0 ? "\($0) \(trophy.ladderUnit)" : $0 } ?? subtitle(trophy))
                    .font(.game(compact ? 10 : 14, weight: .bold)).foregroundStyle(Color(hex: 0xA9DCD5)).lineLimit(1).minimumScaleFactor(0.6)
                if done {
                    Text("In your cabinet")
                        .font(.game(compact ? 10 : 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Palette.teal).overlay(Capsule().strokeBorder(.white, lineWidth: 2.5)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: compact ? 130 : 190)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.35), value: done)
        .accessibilityLabel(done ? "\(trophy.title), in your cabinet" : "Collect the \(trophy.title) trophy")
    }

    private func subtitle(_ trophy: Trophy) -> String {
        if let levelID = trophy.levelID, let level = model.catalog.level(levelID) { return level.title }
        if let islandID = trophy.islandID, let island = model.catalog.island(islandID) { return island.name }
        return trophy.detail
    }

    private func collect(_ trophy: Trophy) {
        guard !collected.contains(trophy.id), !flights.contains(where: { $0.id == trophy.id }),
              let from = tokenFrames[trophy.id] else { return }
        AudioManager.shared.play(.whoosh)
        Haptics.shared.tap()
        let to = CGPoint(x: cabinetFrame.midX, y: cabinetFrame.minY + cabinetFrame.height * 0.35)
        flights.append(Flight(id: trophy.id, trophy: trophy, from: CGPoint(x: from.midX, y: from.midY), to: to))
        let duration = model.settings.reducedMotion ? 0.3 : 0.8
        Task { @MainActor in
            // Let the flyer appear at its start before it moves.
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(.easeInOut(duration: duration)) {
                if let index = flights.firstIndex(where: { $0.id == trophy.id }) { flights[index].progress = 1 }
            }
            try? await Task.sleep(for: .seconds(duration))
            flights.removeAll { $0.id == trophy.id }
            withAnimation(.spring(duration: 0.4)) { _ = collected.insert(trophy.id) }
            cabinetBumps += 1
            AudioManager.shared.play(.unlock, volume: 0.8)
            Haptics.shared.success()
        }
    }

    // MARK: - Buttons

    @ViewBuilder private var actions: some View {
        if allCollected {
            HStack(spacing: 12) {
                if model.playtest != nil {
                    Button(action: tapped { model.endPlaytest() }) { IconLabel("Dashboard", symbol: "chart.bar.fill", size: compact ? 17 : 22) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                } else {
                    Button(action: tapped { model.route = .island(island.id) }) { IconLabel("Take a break", emoji: "🏝", size: compact ? 17 : 22) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                }
                Button(action: tapped { replay() }) { IconLabel("Again", symbol: "arrow.counterclockwise", size: compact ? 17 : 22) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                if summary.gameComplete, model.playtest == nil {
                    Button(action: tapped { model.route = .ending }) { IconLabel("The ending!", emoji: "🌈", size: compact ? 20 : 26) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                } else if let next {
                    Button(action: tapped { model.route = .play(next.id) }) { IconLabel("Next", symbol: "play.fill", size: compact ? 20 : 26, trailing: true) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26, minWidth: 150))
                } else if summary.crystalIsland != nil, model.playtest == nil {
                    Button(action: tapped {
                        model.unlockedIsland = nextIsland?.id
                        model.route = .map
                    }) { IconLabel("Next adventure", symbol: "play.fill", size: compact ? 20 : 26, trailing: true) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26, minWidth: 150))
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Text("Tap your trophies to carry on")
                .font(.game(compact ? 14 : 18, weight: .bold))
                .foregroundStyle(Palette.ink.opacity(0.65))
                .frame(minHeight: compact ? 34 : 56)
        }
    }

    private func replay() { model.replay(level.id) }
}

extension Trophy {
    /// The unit after a rung's number on the results screen, such as "250 right answers".
    var ladderUnit: String {
        guard case let .count(counter, _) = rule else { return "" }
        return counter.unit
    }
}

/// The island's crystal fragment, glowing in the island's colour.
struct CrystalShowcase: View {
    let island: Island
    var height: CGFloat
    @Environment(AppModel.self) private var model
    @State private var spin = false
    @State private var bob = false

    var body: some View {
        let colour = Palette.hex(island.colour)
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RadialGradient(colors: [colour.mix(with: .white, by: 0.55), colour, Palette.ink], center: .center, startRadius: 4, endRadius: height * 0.7))
            // Drawn as an overlay so the oversized rays never change the card's size.
            Color.clear.overlay {
                Rays()
                    .fill(.white.opacity(0.18))
                    .frame(width: height * 1.6, height: height * 1.6)
                    .rotationEffect(.degrees(spin ? 360 : 0))
            }
            Image("crystal_shard")
                .resizable()
                .scaledToFit()
                .colorMultiply(colour.mix(with: .white, by: 0.35))
                .frame(height: height * 0.78)
                .shadow(color: .white.opacity(0.85), radius: 18)
                .offset(y: bob ? -6 : 4)
            VStack {
                Spacer()
                Text("\(island.name) fragment")
                    .font(.game(height * 0.055))
                    .foregroundStyle(.white)
                    .shadow(color: Palette.ink, radius: 0, y: 2)
                    .padding(.bottom, height * 0.03)
            }
        }
        .frame(width: height * 0.72, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The \(island.name) crystal fragment")
        .onAppear {
            guard !model.settings.reducedMotion else { return }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) { bob = true }
        }
    }

    /// Thin wedges of light radiating from the centre.
    nonisolated struct Rays: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(rect.width, rect.height)
            for index in 0..<15 {
                let start = Angle.degrees(Double(index) * 24)
                path.move(to: centre)
                path.addArc(center: centre, radius: radius, startAngle: start, endAngle: start + .degrees(9), clockwise: false)
                path.closeSubpath()
            }
            return path
        }
    }
}

/// Six fragment slots, filled in each island's colour once its fragment is back.
struct FragmentRow: View {
    let found: [String]
    let catalog: Catalog
    var height: CGFloat

    var body: some View {
        HStack(spacing: height * 0.25) {
            ForEach(catalog.islands) { island in
                let back = found.contains(island.id)
                Image("crystal_shard")
                    .resizable()
                    .renderingMode(back ? .original : .template)
                    .scaledToFit()
                    .foregroundStyle(Palette.ink.opacity(0.15))
                    .colorMultiply(back ? Palette.hex(island.colour).mix(with: .white, by: 0.35) : .white)
                    .frame(height: height)
            }
            Text("\(found.count) of \(catalog.islands.count) fragments back")
                .font(.game(height * 0.42, weight: .bold))
                .foregroundStyle(Palette.ink)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(found.count) of \(catalog.islands.count) crystal fragments found")
    }
}

/// Reminds a grown-up play-testing a level that none of it is kept.
struct PlaytestNote: View {
    @Environment(\.compact) private var compact

    var body: some View {
        IconLabel("Play-test: nothing is saved", symbol: "eye.fill", size: compact ? 13 : 16)
            .font(.game(compact ? 13 : 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.ink.opacity(0.8)))
    }
}
