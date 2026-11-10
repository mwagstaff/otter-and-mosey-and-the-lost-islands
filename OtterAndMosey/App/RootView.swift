import Combine
import LostIslandsCore
import SwiftUI

/// Switches between the game's screens and owns the cross-cutting overlays.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model
        ZStack {
            Palette.ink.ignoresSafeArea()
            screen
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
                .id(routeKey)
            if model.showSettings {
                SettingsOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(model.settings.reducedMotion ? nil : .easeInOut(duration: 0.35), value: routeKey)
        .animation(.easeInOut(duration: 0.2), value: model.showSettings)
        // Rebuild text when the typeface option changes.
        .id(model.settings.easyReadFont)
        .onReceive(clock) { _ in
            guard scenePhase == .active, model.profile != nil, model.route != .title, model.route != .parent else { return }
            model.addPlaytime(10)
        }
        .onChange(of: model.route) { _, route in music(for: route) }
        .onAppear { music(for: model.route) }
    }

    private var routeKey: String { String(describing: model.route) }

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
        case .home: HomeIslandView()
        case .parent: ParentAreaView()
        case .ending: EndingView()
        }
    }

    private func music(for route: Route) {
        switch route {
        case .island(let id): AudioManager.shared.playMusic(IslandTheme.island(id).music)
        case .play(let id): AudioManager.shared.playMusic(IslandTheme.island(model.catalog.island(containing: id)?.id ?? "woods").music)
        case .parent: break
        default: AudioManager.shared.playMusic("music_title")
        }
    }
}
