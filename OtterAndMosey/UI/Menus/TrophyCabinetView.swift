import LostIslandsCore
import SwiftUI

/// The trophy cabinet: the player's records on the left, and a glass cabinet on the right
/// holding every trophy won, with silhouettes for the ones still to win. Tapping any trophy
/// says how to win it and, where there is one, offers a way straight to the level.
struct TrophyCabinetView: View {
    @Environment(AppModel.self) private var model
    @State private var group = TrophyGroup.islands
    @State private var selected: Trophy?

    private static let woodDark = Color(hex: 0x8C5130)
    private static let wood = Color(hex: 0xA8643A)
    private static let glassTop = Color(hex: 0x15505A)
    private static let glassBottom = Color(hex: 0x0D3A42)
    private static let caption = Color(hex: 0xA9DCD5)

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 6 : 14) {
                    header(compact: compact)
                    HStack(alignment: .top, spacing: compact ? 8 : 16) {
                        records(compact: compact)
                            .frame(width: compact ? 178 : 262)
                        cabinet(compact: compact)
                    }
                }
                .padding(compact ? 8 : 24)
                if let selected {
                    detail(selected, compact: compact)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.spring(duration: 0.3), value: selected?.id)
            .screenBackground("bg_title", blur: 8, dim: 0.35)
            .environment(\.compact, compact)
        }
        .onAppear { model.markTrophiesSeen() }
    }

    private var profile: Profile { model.profile ?? Profile(nickname: "") }
    private var all: [Trophy] { Trophies.all(model.catalog) }
    private func won(_ trophy: Trophy) -> Bool { profile.achievements[trophy.id] != nil }

    // MARK: - Header

    private func header(compact: Bool) -> some View {
        let count = Trophies.count(in: profile, catalog: model.catalog)
        return HStack(spacing: compact ? 8 : 14) {
            RoundButton(symbol: "chevron.left", label: "Back") { model.route = model.trophiesReturn }
            VStack(alignment: .leading, spacing: 4) {
                Text("Trophy Cabinet").font(.game(compact ? 18 : 26)).foregroundStyle(Palette.ink)
                ProgressBar(value: Double(count.won) / Double(max(count.total, 1)), height: compact ? 9 : 13)
                Text("\(count.won) of \(count.total) trophies").font(.game(compact ? 11 : 15, weight: .bold)).foregroundStyle(Palette.ink).monospacedDigit()
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 4 : 8)
            .frame(width: compact ? 190 : 300)
            .panel(fill: Palette.gold, radius: 18)
            Spacer(minLength: 0)
            HStack(spacing: compact ? 5 : 8) {
                ForEach(TrophyGroup.allCases, id: \.self) { item in
                    Button(action: tapped { group = item; selected = nil }) { Text(item.title) }
                        .buttonStyle(ChunkyButtonStyle(fill: group == item ? Palette.gold : Palette.cream, size: compact ? 13 : 18))
                        .accessibilityAddTraits(group == item ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Records

    private func records(compact: Bool) -> some View {
        let p = profile
        let rows: [(String, String, String, String?)] = [
            ("⭐️", "Stars", "\(p.totalStars)", "/ \(model.catalog.allLevels.count * 3)"),
            ("pearl", "Pearls", "\(p.stats.pearls)", nil),
            ("badge_answers-50", "Right answers", "\(Trophies.value(of: .answers, in: p))", nil),
            ("badge_sharp-shooter", "Right first time", "\(Trophies.value(of: .firstTry, in: p))", nil),
            ("badge_combo-8", "Best streak", "\(p.bestCombo)", nil),
            ("badge_fast-fingers", "Fastest typing", "\(Trophies.value(of: .typing, in: p))", "wpm"),
            ("badge_adventurer", "Levels played", "\(Trophies.value(of: .levels, in: p))", nil),
            ("badge_explorer", "Days played", "\(p.stats.playDays)", nil),
        ]
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                Text("My records").font(.game(compact ? 16 : 21)).foregroundStyle(Palette.ink)
                ForEach(rows, id: \.1) { art, title, value, unit in
                    HStack(spacing: compact ? 6 : 10) {
                        Glyph(art, size: compact ? 26 : 38)
                        Text(title).font(.game(compact ? 11 : 15, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.75))
                            .lineLimit(2).minimumScaleFactor(0.7)
                        Spacer(minLength: 2)
                        Text(value).font(.game(compact ? 15 : 21)).foregroundStyle(Palette.ink).monospacedDigit()
                        if let unit { Text(unit).font(.game(compact ? 10 : 14, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.55)) }
                    }
                    .padding(.bottom, compact ? 2 : 6)
                    .overlay(alignment: .bottom) {
                        if title != rows.last?.1 {
                            Line().stroke(Palette.ink.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(height: 1)
                        }
                    }
                }
            }
            .padding(compact ? 10 : 16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .panel(radius: 20)
    }

    nonisolated struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }

    // MARK: - Cabinet

    private func cabinet(compact: Bool) -> some View {
        ZStack {
            LinearGradient(colors: [Self.glassTop, Self.glassBottom], startPoint: .top, endPoint: .bottom)
            ScrollView(showsIndicators: true) {
                VStack(spacing: compact ? 8 : 12) {
                    if !profile.pendingTrophies.isEmpty { waiting(compact: compact) }
                    switch group {
                    case .islands: islands(compact: compact)
                    case .milestones: ladders(compact: compact)
                    case .secret, .learning, .collections: grid(all.filter { $0.group == group }, compact: compact)
                    }
                }
                .padding(compact ? 8 : 16)
            }
            LinearGradient(colors: [.clear, .white.opacity(0.06), .clear], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.5, y: 1))
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(compact ? 8 : 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Self.woodDark, Self.wood, Self.wood, Self.woodDark], startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3.5))
        )
    }

    private func waiting(compact: Bool) -> some View {
        let count = profile.pendingTrophies.count
        return HStack(spacing: 10) {
            Image("trophy_parcel").resizable().scaledToFit().frame(height: compact ? 34 : 50)
            Text(count == 1 ? "1 trophy is waiting! Finish any level to unwrap it." : "\(count) trophies are waiting! Finish any level to unwrap them.")
                .font(.game(compact ? 12 : 17, weight: .bold)).foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.gold.opacity(0.6), lineWidth: 2)))
    }

    private func islands(compact: Bool) -> some View {
        let medal: CGFloat = compact ? 34 : 54
        return VStack(spacing: compact ? 6 : 10) {
            ForEach(model.catalog.islands) { island in
                let mine = all.filter { $0.islandID == island.id }
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    HStack(spacing: 8) {
                        Image("island_\(island.id)").resizable().scaledToFit().frame(height: compact ? 20 : 30)
                        Text(island.name).font(.game(compact ? 13 : 17)).foregroundStyle(.white)
                        Text("\(mine.filter(won).count) of \(mine.count)").font(.game(compact ? 11 : 14, weight: .bold)).foregroundStyle(Self.caption)
                    }
                    HStack(alignment: .bottom, spacing: compact ? 4 : 10) {
                        ForEach(island.levels) { level in
                            VStack(spacing: 1) {
                                HStack(spacing: -4) {
                                    ForEach(mine.filter { $0.levelID == level.id }) { trophy in
                                        badgeButton(trophy, size: medal)
                                    }
                                }
                                Text(level.title).font(.game(compact ? 8 : 11.5)).foregroundStyle(Self.caption).lineLimit(1).minimumScaleFactor(0.6)
                                    .frame(maxWidth: medal * 2)
                            }
                        }
                        Spacer(minLength: 0)
                        ForEach(mine.filter { $0.levelID == nil }) { trophy in
                            VStack(spacing: 1) {
                                badgeButton(trophy, size: medal * 1.5)
                                Text(trophy.title).font(.game(compact ? 8 : 11.5)).foregroundStyle(Self.caption).lineLimit(1).minimumScaleFactor(0.5)
                                    .frame(maxWidth: medal * 1.9)
                            }
                        }
                    }
                    .padding(.bottom, compact ? 9 : 14)
                    .background(alignment: .bottom) { Plank(compact: compact) }
                }
            }
        }
    }

    struct Plank: View {
        var compact: Bool
        var body: some View {
            LinearGradient(colors: [Color(hex: 0xE0A868), Color(hex: 0xB9783F)], startPoint: .top, endPoint: .bottom)
                .frame(height: compact ? 8 : 12)
                .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xF2C48A)).frame(height: 2) }
                .shadow(color: .black.opacity(0.35), radius: 5, y: 5)
                .padding(.horizontal, -16)
        }
    }

    private func ladders(compact: Bool) -> some View {
        let rung: CGFloat = compact ? 38 : 52
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: compact ? 8 : 14), GridItem(.flexible())], spacing: compact ? 8 : 10) {
            ForEach(Trophies.ladders) { ladder in
                let rungs = all.filter { $0.ladder == ladder.id }
                let value = Trophies.value(of: ladder.counter, in: profile)
                let next = ladder.rungs.first { value < $0 }
                let previous = ladder.rungs.last { value >= $0 } ?? 0
                VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                    HStack {
                        Text(ladder.title).font(.game(compact ? 13 : 17)).foregroundStyle(.white)
                        Spacer()
                        Text(next.map { "\(value) of \($0) \(ladder.counter.unit)" } ?? "All done!")
                            .font(.game(compact ? 10 : 13, weight: .bold)).foregroundStyle(Self.caption).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    HStack(spacing: compact ? 4 : 8) {
                        ForEach(rungs) { trophy in badgeButton(trophy, size: rung) }
                        ProgressBar(value: next.map { Double(value - previous) / Double($0 - previous) } ?? 1, height: compact ? 7 : 10,
                                    track: .white.opacity(0.12), border: nil)
                    }
                }
                .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 6 : 8)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 2)))
            }
        }
    }

    private func grid(_ trophies: [Trophy], compact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 104 : 150), spacing: compact ? 8 : 12)], spacing: compact ? 8 : 12) {
            ForEach(trophies) { trophy in
                let earned = won(trophy)
                let hidden = trophy.group == .secret && !earned
                Button(action: tapped { selected = trophy }) {
                    VStack(spacing: 3) {
                        if hidden {
                            Text("?").font(.game(compact ? 28 : 40)).foregroundStyle(.white.opacity(0.5))
                                .frame(width: compact ? 50 : 72, height: compact ? 50 : 72)
                                .overlay(Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 4, dash: [7, 5])))
                        } else {
                            badge(trophy, size: compact ? 50 : 72)
                        }
                        Text(hidden ? "???" : trophy.title).font(.game(compact ? 12 : 15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                        Text(hidden ? (trophy.riddle ?? "") : trophy.detail).font(.game(compact ? 10 : 12.5, weight: .bold)).foregroundStyle(Self.caption)
                            .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.7)
                    }
                    .padding(compact ? 6 : 10)
                    .frame(maxWidth: .infinity, minHeight: compact ? 116 : 160, alignment: .top)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(earned ? 0.1 : 0.05)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 2)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Secret trophy. \(trophy.riddle ?? "")" : "\(trophy.title). \(earned ? "Won" : trophy.detail)")
            }
        }
    }

    /// A trophy's picture, or a wrapped parcel if it has been won but is still waiting.
    @ViewBuilder private func badge(_ trophy: Trophy, size: CGFloat) -> some View {
        if profile.pendingTrophies.contains(trophy.id) {
            Image("trophy_parcel").resizable().scaledToFit().padding(size * 0.08).frame(width: size, height: size)
        } else {
            TrophyBadge(trophy: trophy, earned: won(trophy), size: size)
        }
    }

    private func badgeButton(_ trophy: Trophy, size: CGFloat) -> some View {
        Button(action: tapped { selected = trophy }) {
            badge(trophy, size: size)
                .overlay {
                    if selected?.id == trophy.id {
                        Circle().strokeBorder(Palette.gold, style: StrokeStyle(lineWidth: 3, dash: [6, 4])).padding(-3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trophy.title)\(trophy.levelID.flatMap { model.catalog.level($0) }.map { ", \($0.title)" } ?? ""). \(won(trophy) ? "Won" : trophy.detail)")
    }

    // MARK: - Detail

    private func detail(_ trophy: Trophy, compact: Bool) -> some View {
        let earned = won(trophy)
        let hidden = trophy.group == .secret && !earned
        let level = trophy.levelID.flatMap { model.catalog.level($0) }
        let island = trophy.islandID.flatMap { model.catalog.island($0) }
        let progress = earned ? nil : Trophies.progress(trophy, in: profile, catalog: model.catalog)
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { selected = nil }
            VStack(spacing: compact ? 6 : 10) {
                HStack(spacing: 14) {
                    if hidden {
                        Text("?").font(.game(44)).foregroundStyle(Palette.ink.opacity(0.4)).frame(width: compact ? 64 : 90, height: compact ? 64 : 90)
                    } else {
                        TrophyBadge(trophy: trophy, earned: earned, size: compact ? 64 : 90, ghost: Palette.ink.opacity(0.25))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hidden ? "Secret trophy" : trophy.title).font(.game(compact ? 20 : 26)).foregroundStyle(Palette.ink)
                        if let place = level?.title ?? island?.name {
                            Text(level != nil && island != nil ? "\(place) · \(island!.name)" : place)
                                .font(.game(compact ? 13 : 16, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.65))
                        }
                    }
                    Spacer(minLength: 0)
                    RoundButton(symbol: "xmark", size: compact ? 40 : 48, label: "Close") { selected = nil }
                }
                Text(hidden ? (trophy.riddle ?? "") : trophy.detail)
                    .font(.game(compact ? 15 : 19, weight: .bold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let date = profile.achievements[trophy.id] {
                    IconLabel("In your cabinet since \(date.formatted(date: .abbreviated, time: .omitted))", symbol: "checkmark.seal.fill", size: compact ? 13 : 16)
                        .font(.game(compact ? 13 : 16, weight: .bold)).foregroundStyle(Palette.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if profile.pendingTrophies.contains(trophy.id) {
                    IconLabel("Won! It’s waiting for you at the end of your next level.", emoji: "trophy_parcel", size: compact ? 13 : 16)
                        .font(.game(compact ? 13 : 16, weight: .bold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let progress, !hidden {
                    HStack(spacing: 10) {
                        ProgressBar(value: Double(progress.now) / Double(max(progress.needed, 1)), height: compact ? 10 : 14)
                        Text("\(progress.now) of \(progress.needed)").font(.game(compact ? 13 : 16)).foregroundStyle(Palette.ink).monospacedDigit()
                    }
                }
                if !earned, let action = playAction(level: level, island: island) {
                    HStack {
                        Button(action: tapped(action.go)) { IconLabel(action.title, symbol: "play.fill", size: compact ? 16 : 20, trailing: true) }
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 16 : 20))
                        Spacer()
                    }
                }
            }
            .padding(compact ? 14 : 22)
            .frame(maxWidth: compact ? 420 : 520)
            .panel()
            .padding(16)
        }
    }

    private func playAction(level: LevelDef?, island: Island?) -> (title: String, go: () -> Void)? {
        if let level, Progression.isUnlocked(levelID: level.id, in: profile, catalog: model.catalog) {
            return ("Play \(level.title)", { model.route = .play(level.id) })
        }
        if level == nil, let island, Progression.isUnlocked(island: island, in: profile, catalog: model.catalog) {
            return ("Visit \(island.name)", { model.route = .island(island.id) })
        }
        return nil
    }
}

/// A rounded progress bar.
struct ProgressBar: View {
    var value: Double
    var height: CGFloat
    var track: Color = Palette.ink.opacity(0.18)
    var border: Color? = Palette.ink

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(border == nil ? Palette.gold : Palette.teal)
                    .frame(width: max(height, geometry.size.width * min(max(value, 0), 1)))
                    .opacity(value > 0 ? 1 : 0)
            }
            .overlay { if let border { Capsule().strokeBorder(border, lineWidth: 2) } }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded())) percent")
    }
}
