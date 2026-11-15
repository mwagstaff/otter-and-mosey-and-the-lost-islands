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
            if model.showSettings && model.parentUnlocked {
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
            guard scenePhase == .active, model.profile != nil, model.route != .title, model.route != .parent, model.route != .quickSetup else { return }
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
        case .grownUpCheck: GrownUpCheckView()
        case .quickSetup: QuickSetupView()
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
        case .ending: FinaleView()
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
                    let rosette = min(150, max(116, geometry.size.height * 0.19))
                    HStack(spacing: compact ? 12 : 36) {
                        PlaytesterRosette(name: "Skyla", ribbon: Palette.teal, size: rosette)
                            .scaleEffect(shown ? 1 : 0.01)
                            .rotationEffect(.degrees(shown ? 0 : -30))
                            .animation(.spring(duration: 0.7, bounce: 0.45).delay(0.25), value: shown)
                        HStack(alignment: .bottom, spacing: compact ? 6 : 16) {
                            Image("otter_cheer").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.44 : 0.36))
                            Image("mosey_cheer").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.4 : 0.32))
                        }
                        .scaleEffect(shown ? 1 : 0.8, anchor: .bottom)
                        PlaytesterRosette(name: "Nova", ribbon: Palette.coral, size: rosette)
                            .scaleEffect(shown ? 1 : 0.01)
                            .rotationEffect(.degrees(shown ? 0 : -30))
                            .animation(.spring(duration: 0.7, bounce: 0.45).delay(0.4), value: shown)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Chief playtesters: Skyla and Nova")
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

/// A prize rosette with a playtester's name in the middle, for the dedication screen.
private struct PlaytesterRosette: View {
    let name: String
    let ribbon: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: -size * 0.1) {
            ZStack {
                Circle().fill(stripes)
                Circle().strokeBorder(Palette.ink, lineWidth: 4)
                Circle()
                    .fill(Palette.cream)
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                    .frame(width: size * 0.74, height: size * 0.74)
                VStack(spacing: 0) {
                    Text("CHIEF\nPLAYTESTER")
                        .font(.game(size * 0.074))
                        .tracking(size * 0.004)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-2)
                    Text(name)
                        .font(.game(size * 0.17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(Palette.ink)
                .frame(width: size * 0.62)
            }
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.ink).offset(y: 5))
            .zIndex(1)
            HStack(spacing: 6) {
                RibbonTail().rotationEffect(.degrees(10))
                RibbonTail().rotationEffect(.degrees(-10))
            }
            .foregroundStyle(ribbon)
            .frame(height: size * 0.27)
        }
    }

    /// Gold and paler gold wedges, like the pleats of a rosette.
    private var stripes: AngularGradient {
        let light = Color(red: 1, green: 0.83, blue: 0.36)
        let stops = (0..<36).flatMap { index -> [Gradient.Stop] in
            let colour = index.isMultiple(of: 2) ? light : Palette.gold
            return [.init(color: colour, location: Double(index) / 36), .init(color: colour, location: Double(index + 1) / 36)]
        }
        return AngularGradient(stops: stops, center: .center)
    }

    private struct RibbonTail: View {
        var body: some View {
            TailShape()
                .fill(.foreground)
                .overlay(TailShape().stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                .aspectRatio(0.6, contentMode: .fit)
        }
    }

    /// A ribbon end with a notch cut out of the bottom.
    nonisolated private struct TailShape: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.78))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}
