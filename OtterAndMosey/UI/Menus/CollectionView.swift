import LostIslandsCore
import SwiftUI

/// Everything the player has collected: crystals, pets, hats and stickers.
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = 0
    private let tabs = [("💎", "Crystals"), ("🐾", "Pets"), ("🎩", "Hats"), ("🏅", "Stickers")]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 6 : 14) {
                    HStack(spacing: 8) {
                        RoundButton(symbol: "chevron.left", label: "Back to map") { model.route = .map }
                        Spacer()
                        ForEach(tabs.indices, id: \.self) { index in
                            Button(action: tapped { tab = index }) { IconLabel(tabs[index].1, emoji: tabs[index].0, size: compact ? 15 : 20) }
                                .buttonStyle(ChunkyButtonStyle(fill: tab == index ? Palette.gold : Palette.cream, size: compact ? 15 : 20))
                        }
                        Spacer()
                    }
                    ScrollView {
                        content(compact: compact).padding(compact ? 10 : 20)
                    }
                    .panel(fill: Palette.cream.opacity(0.96))
                }
                .padding(compact ? 8 : 24)
            }
            .screenBackground("bg_title", blur: 8, dim: 0.4)
            .environment(\.compact, compact)
        }
    }

    @ViewBuilder private func content(compact: Bool) -> some View {
        let profile = model.profile
        let columns = [GridItem(.adaptive(minimum: compact ? 130 : 170), spacing: 12)]
        switch tab {
        case 0:
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.catalog.islands) { island in
                    let found = profile?.crystals.contains(island.id) ?? false
                    tile(compact: compact, title: island.name, subtitle: found ? "Fragment found!" : "Still lost…", earned: found) {
                        Image("crystal_shard").resizable().scaledToFit().colorMultiply(Palette.hex(island.colour)).saturation(found ? 1 : 0).opacity(found ? 1 : 0.35)
                    }
                }
            }
        case 1: rewardGrid(.pet, columns: columns, compact: compact)
        case 2: rewardGrid(.accessory, columns: columns, compact: compact)
        default:
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Progression.achievements) { achievement in
                    let earned = profile?.achievements[achievement.id] != nil
                    tile(compact: compact, title: achievement.title, subtitle: achievement.detail, earned: earned) {
                        Glyph(achievement.emoji, size: compact ? 50 : 70, art: achievement.art).saturation(earned ? 1 : 0).opacity(earned ? 1 : 0.3)
                    }
                }
            }
        }
    }

    private func rewardGrid(_ kind: RewardKind, columns: [GridItem], compact: Bool) -> some View {
        let profile = model.profile
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.catalog.rewards.filter { $0.kind == kind }) { reward in
                let owned = profile?.has(reward.id) ?? false
                let worn = profile?.equippedAccessory == reward.id
                Button(action: tapped {
                    guard owned, kind == .accessory else { return }
                    model.update { $0.equippedAccessory = worn ? nil : reward.id }
                }) {
                    tile(compact: compact, title: owned ? reward.name : "???",
                         subtitle: !owned ? "Keep exploring to find it" : (kind == .accessory ? (worn ? "Wearing it! Tap to take off" : "Tap to wear") : "Your friend"),
                         earned: owned, highlight: worn) {
                        Glyph(reward.emoji, size: compact ? 50 : 70, art: reward.art).saturation(owned ? 1 : 0).opacity(owned ? 1 : 0.25)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile<Icon: View>(compact: Bool, title: String, subtitle: String, earned: Bool, highlight: Bool = false, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 4) {
            icon().frame(height: compact ? 50 : 70)
            Text(title).font(.game(compact ? 14 : 18)).foregroundStyle(Palette.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            Text(subtitle).font(.game(compact ? 11 : 13, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: compact ? 118 : 160)
        .background(RoundedRectangle(cornerRadius: 16).fill(highlight ? Palette.gold.opacity(0.6) : (earned ? .white : .white.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink.opacity(earned ? 1 : 0.3), lineWidth: 3)))
    }
}

/// The home island, which the player decorates with things earned on the adventure.
struct HomeIslandView: View {
    @Environment(AppModel.self) private var model
    @State private var dragging: UUID?

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let itemSize: CGFloat = compact ? 54 : 84 * ScreenMetrics.scale(geometry)
            ZStack {
                // Pets the player has rescued wander along the beach.
                ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                    Glyph(pet.emoji, size: itemSize * 0.85, art: pet.art)
                        .position(x: geometry.size.width * (0.12 + 0.76 * Double(index) / Double(max(pets.count - 1, 1))), y: geometry.size.height * (index.isMultiple(of: 2) ? 0.8 : 0.72))
                }
                ForEach(model.profile?.decorations ?? []) { placed in
                    if let reward = model.catalog.reward(placed.reward) {
                        Glyph(reward.emoji, size: itemSize * 1.25, art: reward.art)
                            .scaleEffect(dragging == placed.id ? 1.2 : 1)
                            .position(x: placed.x * geometry.size.width, y: placed.y * geometry.size.height)
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    dragging = placed.id
                                    move(placed.id, to: value.location, in: geometry.size, persist: false)
                                }
                                .onEnded { value in
                                    dragging = nil
                                    move(placed.id, to: value.location, in: geometry.size, persist: true)
                                })
                            .onTapGesture(count: 2) { model.update { $0.decorations.removeAll { $0.id == placed.id } } }
                    }
                }
                VStack {
                    HStack {
                        RoundButton(symbol: "chevron.left", label: "Back to map") { model.route = .map }
                        Spacer()
                        Text("Rainbow Island").font(.game(compact ? 22 : 32)).foregroundStyle(Palette.ink).padding(.horizontal, 18).padding(.vertical, 6).panel(radius: 18)
                        Spacer()
                        Color.clear.frame(width: 54, height: 54)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Text("Tap to add. Drag to move. Double-tap to put away.")
                            .font(.game(compact ? 12 : 16, weight: .bold)).foregroundStyle(Palette.ink)
                        ForEach(decorations) { reward in
                            Button(action: tapped { add(reward) }) {
                                Glyph(reward.emoji, size: compact ? 38 : 52, art: reward.art)
                                    .frame(width: compact ? 52 : 68, height: compact ? 52 : 68)
                                    .background(Circle().fill(.white).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(reward.name)")
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .panel(fill: Palette.cream.opacity(0.95))
                }
                .padding(compact ? 8 : 24)
            }
            .screenBackground("bg_title", saturation: 0.35 + 0.65 * Double(model.profile?.crystals.count ?? 0) / 6)
        }
    }

    private var pets: [Reward] {
        model.catalog.rewards.filter { $0.kind == .pet && (model.profile?.has($0.id) ?? false) }
    }

    private var decorations: [Reward] {
        model.catalog.rewards.filter { $0.kind == .decoration && (model.profile?.has($0.id) ?? false) }
    }

    private func add(_ reward: Reward) {
        model.update { profile in
            guard profile.decorations.count < 24 else { return }
            profile.decorations.append(PlacedDecoration(reward: reward.id, x: .random(in: 0.25...0.75), y: .random(in: 0.4...0.65)))
        }
        AudioManager.shared.play(.pop, volume: 0.6)
    }

    private func move(_ id: UUID, to point: CGPoint, in size: CGSize, persist: Bool) {
        let x = min(max(point.x / size.width, 0.04), 0.96), y = min(max(point.y / size.height, 0.18), 0.82)
        model.update { profile in
            guard let index = profile.decorations.firstIndex(where: { $0.id == id }) else { return }
            profile.decorations[index].x = x
            profile.decorations[index].y = y
        }
    }
}

/// Sound and accessibility options that children can safely change themselves.
struct SettingsOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { model.showSettings = false }
                VStack(spacing: compact ? 6 : 14) {
                    HStack {
                        Text("Settings").font(.game(compact ? 26 : 36)).foregroundStyle(Palette.ink)
                        Spacer()
                        RoundButton(symbol: "xmark", size: 50, label: "Close") { model.showSettings = false }
                    }
                    ScrollView {
                        SettingsControls(compact: compact)
                    }
                }
                .padding(compact ? 14 : 28)
                .frame(maxWidth: 720, maxHeight: geometry.size.height * 0.94)
                .panel()
                .padding(10)
            }
        }
    }
}

/// The shared sound and accessibility controls, used by Settings and the parent area.
struct SettingsControls: View {
    var compact: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = Binding(get: { model.settings }, set: { model.settings = $0 })
        VStack(spacing: compact ? 6 : 12) {
            slider("Music", "music.note", value: settings.musicVolume)
            slider("Sounds", "bell.fill", value: settings.effectsVolume)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 250 : 300), spacing: 10)], spacing: compact ? 6 : 10) {
                toggle("Mute everything", "speaker.slash.fill", settings.muted)
                toggle("Read questions aloud", "text.bubble.fill", settings.spokenInstructions)
                toggle("Character voices", "person.wave.2.fill", settings.characterVoices)
                toggle("Device voice for other sums", "waveform", settings.deviceVoice)
                toggle("Vibration", "iphone.radiowaves.left.and.right", settings.haptics)
                toggle("Calmer motion", "tortoise.fill", settings.reducedMotion)
                toggle("High contrast", "circle.lefthalf.filled", settings.highContrast)
                toggle("Easy-read text", "textformat.size", settings.easyReadFont)
            }
        }
    }

    private func slider(_ title: String, _ symbol: String, value: Binding<Double>) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.game(compact ? 17 : 22)).foregroundStyle(Palette.ink).frame(width: compact ? 130 : 170, alignment: .leading)
            Slider(value: value, in: 0...1) { editing in
                if !editing { AudioManager.shared.play(.correct) }
            }
            .tint(Palette.teal)
            .frame(minHeight: 44)
        }
    }

    private func toggle(_ title: String, _ symbol: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Label(title, systemImage: symbol).font(.game(compact ? 16 : 20, weight: .bold)).foregroundStyle(Palette.ink)
        }
        .tint(Palette.teal)
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.7)))
    }
}
