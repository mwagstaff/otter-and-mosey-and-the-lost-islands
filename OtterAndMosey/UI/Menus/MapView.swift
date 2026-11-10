import LostIslandsCore
import SpriteKit
import SwiftUI

/// The archipelago. Tap an island to see it, then explore.
struct MapView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = WorldMapScene()
    @State private var selected: String?

    private var states: [IslandState] {
        guard let profile = model.profile else { return [] }
        let currentID = Progression.nextLevel(for: profile, catalog: model.catalog).flatMap { model.catalog.island(containing: $0.id)?.id }
            ?? profile.lastLevelID.flatMap { model.catalog.island(containing: $0)?.id }
        return model.catalog.islands.map { island in
            IslandState(id: island.id, name: island.name, unlocked: Progression.isUnlocked(island: island, in: profile, catalog: model.catalog),
                        hasCrystal: profile.crystals.contains(island.id), restoration: CGFloat(model.restoration(of: island)),
                        isCurrent: island.id == currentID)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                SceneBackdrop(scene: scene, extraTop: compact ? 50 : 80, extraBottom: compact ? 84 : 130)
                VStack(spacing: 0) {
                    HStack(spacing: compact ? 8 : 12) {
                        RoundButton(symbol: "house.fill", label: "Title screen") { model.route = .title }
                        CountChip(emoji: model.profile?.avatar ?? "🙂", text: model.profile?.nickname ?? "")
                        Spacer()
                        CountChip(emoji: "⭐️", text: "\(model.profile?.totalStars ?? 0)")
                        CountChip(emoji: "💎", text: "\(model.profile?.crystals.count ?? 0)/6")
                        Button("🎒 Treasures", action: tapped { model.route = .collection })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 16 : 20))
                        Button("🏝 Home", action: tapped { model.route = .home })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20))
                    }
                    .padding(.horizontal, compact ? 6 : 20)
                    .padding(.top, compact ? 6 : 14)
                    Spacer()
                    if model.breakSuggested {
                        Text("🌙 Great playing today! This is a good moment for a break.")
                            .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 6).panel(fill: Palette.gold, radius: 16)
                            .padding(.bottom, 6)
                    }
                    if let island = selected.flatMap({ model.catalog.island($0) }), let profile = model.profile {
                        card(island, profile: profile, compact: compact)
                            .scaleEffect(ScreenMetrics.scale(geometry), anchor: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, compact ? 6 : 24)
                    } else {
                        Text("Tap an island to explore")
                            .font(.game(compact ? 15 : 22, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16).padding(.vertical, compact ? 5 : 8).panel(radius: 18)
                            .padding(.bottom, compact ? 6 : 24)
                    }
                }
                .animation(.spring(duration: 0.3), value: selected)
            }
            .environment(\.compact, compact)
        }
        .onAppear {
            scene.configure(states)
            scene.onSelect = { selected = $0 }
        }
    }

    private func card(_ island: Island, profile: Profile, compact: Bool) -> some View {
        let unlocked = Progression.isUnlocked(island: island, in: profile, catalog: model.catalog)
        let stars = island.levels.reduce(0) { $0 + profile.stars(for: $1.id) }
        let index = model.catalog.islands.firstIndex { $0.id == island.id } ?? 0
        return HStack(spacing: compact ? 12 : 20) {
            Image("island_\(island.id)").resizable().scaledToFit().frame(height: compact ? 64 : 100).saturation(unlocked ? 0.25 + 0.75 * model.restoration(of: island) : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(island.name).font(.game(compact ? 22 : 30)).foregroundStyle(Palette.ink)
                Text(unlocked ? "\(island.focus)  ·  ⭐️ \(stars)/15\(profile.crystals.contains(island.id) ? "  ·  💎 found" : "")"
                              : "Find the \(model.catalog.islands[max(index - 1, 0)].name) crystal first")
                    .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            Spacer(minLength: 8)
            if unlocked {
                Button("Explore ▶", action: tapped { model.route = .island(island.id) })
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
            } else {
                Text("🔒").font(.system(size: compact ? 34 : 48))
            }
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 8 : 14)
        .panel()
        .frame(maxWidth: 780)
        .padding(.horizontal, 16)
    }
}

/// One island's levels, laid out as a path. The scenery regains colour as levels are cleared.
struct IslandView: View {
    let island: Island
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let theme = IslandTheme.island(island.id)
            ZStack {
                VStack(spacing: compact ? 4 : 16) {
                    HStack {
                        RoundButton(symbol: "map.fill", label: "World map") { model.route = .map }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(island.name).font(.game(compact ? 26 : 40)).foregroundStyle(Palette.ink)
                            Text(island.tagline).font(.game(compact ? 13 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                        }
                        .padding(.horizontal, 22).padding(.vertical, 6).panel(radius: 20)
                        Spacer()
                        CountChip(emoji: "⭐️", text: "\(island.levels.reduce(0) { $0 + (model.profile?.stars(for: $1.id) ?? 0) })/15")
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .center, spacing: compact ? 6 : 16 * ScreenMetrics.scale(geometry)) {
                        ForEach(Array(island.levels.enumerated()), id: \.element.id) { index, level in
                            levelButton(level, index: index, theme: theme, compact: compact, scale: ScreenMetrics.scale(geometry))
                                .offset(y: index.isMultiple(of: 2) ? (compact ? 10 : 26) : (compact ? -10 : -26))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 8 : 24)
            }
            .screenBackground(theme.background, saturation: 0.08 + 0.92 * model.restoration(of: island))
            .environment(\.compact, compact)
        }
    }

    private func levelButton(_ level: LevelDef, index: Int, theme: IslandTheme, compact: Bool, scale: CGFloat) -> some View {
        let profile = model.profile
        let unlocked = profile.map { Progression.isUnlocked(levelID: level.id, in: $0, catalog: model.catalog) } ?? false
        let stars = profile?.stars(for: level.id) ?? 0
        let isNext = unlocked && stars == 0
        let size: CGFloat = compact ? 74 : 118 * scale
        return Button(action: tapped { if unlocked { model.route = .play(level.id) } }) {
            VStack(spacing: compact ? 2 : 6) {
                ZStack {
                    Circle().fill(Palette.ink).offset(y: 5)
                    Circle().fill(unlocked ? Color(theme.tint.mixed(with: .white, amount: 0.55)) : Color.gray.opacity(0.85))
                    Circle().strokeBorder(isNext ? Palette.gold : Palette.ink, lineWidth: isNext ? 6 : 4)
                    if !unlocked {
                        Text("🔒").font(.system(size: size * 0.4))
                    } else if level.mode == .guardian {
                        Image(stars > 0 ? theme.guardianHappy : theme.guardian).resizable().scaledToFit().padding(size * 0.1)
                    } else {
                        Text(icon(level.mode)).font(.system(size: size * 0.46))
                    }
                }
                .frame(width: size, height: size)
                .scaleEffect(isNext ? 1.08 : 1)
                StarRow(stars: stars, size: compact ? 14 : 20 * scale).opacity(unlocked ? 1 : 0.3)
                VStack(spacing: 0) {
                    Text(level.title).font(.game(compact ? 13 : 18 * scale)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Text(level.blurb).font(.game(compact ? 10 : 13 * scale, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(width: compact ? 130 : 196 * scale)
                .panel(fill: Palette.cream.opacity(unlocked ? 1 : 0.7), radius: 12)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel("\(level.title). \(unlocked ? "\(stars) stars" : "Locked")")
    }

    private func icon(_ mode: GameMode) -> String {
        switch mode {
        case .wordBlaster: "🫧"
        case .mathsSplash: "🌊"
        case .bridgeBuilder: "🌈"
        case .eggRescue: island.id == "dragon" ? "🥚" : (island.id == "candy" ? "🍬" : "🗝️")
        case .typingTurbo: "⚡️"
        case .guardian: "👑"
        }
    }
}
