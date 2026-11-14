import Combine
import LostIslandsCore
import SwiftUI

/// Switches between the game's screens and owns the cross-cutting overlays.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    @State private var showDedication = true

    var body: some View {
        @Bindable var model = model
        ZStack {
            Palette.ink.ignoresSafeArea()
            screen
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
                .id(routeKey)
            if showDedication {
                DedicationView { showDedication = false }
                    .transition(.opacity)
                    .zIndex(20)
            }
            if model.showSettings {
                SettingsOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(model.settings.reducedMotion ? nil : .easeInOut(duration: 0.35), value: routeKey)
        .animation(.easeInOut(duration: 0.2), value: model.showSettings)
        .animation(.easeInOut(duration: 0.7), value: showDedication)
        // Rebuild text when the typeface option changes.
        .id(model.settings.easyReadFont)
        .onReceive(clock) { _ in
            guard scenePhase == .active, model.profile != nil, model.route != .title, model.route != .parent else { return }
            model.addPlaytime(10)
        }
        .onChange(of: model.route) { _, route in music(for: route) }
        .onAppear { music(for: model.route) }
    }

    private var routeKey: String {
        if case .play = model.route { return "\(model.route)#\(model.playRun)" }
        return String(describing: model.route)
    }

    @ViewBuilder private var screen: some View {
        switch model.route {
        case .title: TitleView()
        case .profiles: ProfilesView()
        case .intro: IntroView()
        case .map: MapView()
        case .island(let id):
            if let island = model.catalog.island(id) { IslandView(island: island) } else { MapView() }
        case .play(let id):
            if let level = model.catalog.level(id), let island = model.catalog.island(containing: id) {
                GameView(level: level, island: island)
            } else {
                MapView()
            }
        case .collection: CollectionView()
        case .trophies: TrophyCabinetView()
        case .home: HomeIslandView()
        case .parent: ParentAreaView()
        case .ending: EndingView()
        }
    }

    private func music(for route: Route) {
        switch route {
        case .island(let id): AudioManager.shared.playMusic(IslandTheme.island(id).music)
        case .play(let id): AudioManager.shared.playMusic(IslandTheme.island(model.catalog.island(containing: id)?.id ?? "woods").music)
        default: AudioManager.shared.playMusic("music_title")
        }
    }
}

/// The first thing on screen when the game opens: who it was made for, and by whom.
/// It stays for ten seconds, or until tapped, then fades into the title screen.
struct DedicationView: View {
    var onDone: () -> Void
    @State private var shown = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let scale = ScreenMetrics.scale(geometry)
            ZStack {
                VStack(spacing: compact ? 4 : 14) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: compact ? 6 : 16) {
                        Image("otter_cheer").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.44 : 0.36))
                        Image("mosey_cheer").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.4 : 0.32))
                    }
                    .scaleEffect(shown ? 1 : 0.8, anchor: .bottom)
                    .accessibilityHidden(true)
                    Text("For Skyla and Nova")
                        .font(.game(compact ? 40 : 64 * scale))
                        .gameTracking()
                        .foregroundStyle(.white)
                        .shadow(color: Palette.ink.opacity(0.9), radius: 0, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Developed by SkyNoLimit.dev")
                        .font(.game(compact ? 15 : 22 * scale, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    Spacer(minLength: compact ? 56 : 110)
                }
                .padding(.horizontal, 24)
                VStack {
                    Spacer()
                    Button(action: tapped(onDone)) { IconLabel("Tap to continue", symbol: "play.fill", size: compact ? 18 : 24 * scale, trailing: true) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 24 * scale))
                        .padding(.bottom, compact ? 14 : 40)
                }
            }
            .screenBackground("bg_title", blur: 10, dim: 0.45)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDone)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { shown = true }
            // Long enough to read at leisure; the button moves on sooner.
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled { onDone() }
        }
    }
}
