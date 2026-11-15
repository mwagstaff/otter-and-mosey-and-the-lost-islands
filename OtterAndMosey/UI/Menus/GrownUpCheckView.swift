import LostIslandsCore
import SwiftUI

/// Shown to a new player after they pick their name, before the opening story: a nudge to let a
/// grown-up check the learning settings. It never blocks play, as "Start adventure" always works.
struct GrownUpCheckView: View {
    @Environment(AppModel.self) private var model
    @State private var shown = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let scale = ScreenMetrics.scale(geometry)
            ZStack {
                if !compact { heroes(height: geometry.size.height) }
                if let profile = model.profile {
                    card(profile, compact: compact, scale: scale)
                        .frame(maxWidth: compact ? 780 : 700 * scale)
                        .padding(.horizontal, compact ? 8 : 24)
                        .padding(.bottom, compact ? 0 : 30)
                        .scaleEffect(shown ? 1 : 0.92)
                        .opacity(shown ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground("bg_title", blur: 6, dim: 0.35)
        }
        .onAppear {
            withAnimation(model.settings.reducedMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) { shown = true }
            if model.profile?.grownUpChecked == true { AudioManager.shared.play(.unlock) }
        }
    }

    private var checked: Bool { model.profile?.grownUpChecked ?? false }

    private func heroes(height: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Image(checked ? "otter_cheer" : "otter_idle").resizable().scaledToFit().frame(height: height * 0.4)
                Spacer()
                Image(checked ? "mosey_cheer" : "mosey_idle").resizable().scaledToFit().frame(height: height * 0.45)
            }
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func card(_ profile: Profile, compact: Bool, scale: CGFloat) -> some View {
        let heading = checked ? "All set, \(profile.nickname)!" : "Nice to meet you, \(profile.nickname)!"
        let lede = checked
            ? "Thanks, grown-up! Time to find the lost crystal fragments."
            : "Before we set sail, ask a grown-up to check the game is just right for you."
        let head = HStack(spacing: compact ? 10 : 16) {
            Glyph(profile.avatar, size: compact ? 34 : 50 * scale)
                .frame(width: compact ? 50 : 72 * scale, height: compact ? 50 : 72 * scale)
                .background(Circle().fill(.white))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: compact ? 3 : 4))
            Text(heading)
                .font(.game(compact ? 26 : 34 * scale, weight: .black))
                .gameTracking()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        let ledeText = Text(lede).font(.game(compact ? 18 : 22 * scale, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    head
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            ledeText
                            Spacer(minLength: 0)
                            actions(compact: true, scale: 1)
                        }
                        summary(profile, compact: true, scale: 1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 16 * scale) {
                    head
                    ledeText
                    summary(profile, compact: false, scale: scale)
                    actions(compact: false, scale: scale)
                    if !checked {
                        Text("Grown-ups can change these any time from the title screen.")
                            .font(.game(15 * scale, weight: .bold))
                            .foregroundStyle(Palette.ink.opacity(0.65))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 32 * scale)
                .padding(.vertical, 26 * scale)
            }
        }
        .foregroundStyle(Palette.ink)
        .panel()
    }

    private func summary(_ profile: Profile, compact: Bool, scale: CGFloat) -> some View {
        let size: CGFloat = compact ? 15 : 19 * scale
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("THE GAME IS SET TO")
                    .font(.game(compact ? 12 : 14 * scale, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                Spacer(minLength: 8)
                if checked {
                    Label("Checked by a grown-up", systemImage: "checkmark")
                        .font(.game(compact ? 12 : 15 * scale, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.teal))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                }
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: compact ? 12 : 18, verticalSpacing: compact ? 3 : 6) {
                ForEach(profile.parent.summary, id: \.label) { line in
                    GridRow {
                        Text(line.label).font(.game(size, weight: .heavy)).foregroundStyle(Palette.ink.opacity(0.65))
                        HStack(spacing: 8) {
                            Text(line.value).font(.game(size, weight: .black))
                            if checked && line.changed {
                                Text("CHANGED")
                                    .font(.game(compact ? 10 : 12 * scale, weight: .heavy))
                                    .foregroundStyle(Color(red: 0.04, green: 0.44, blue: 0.39))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Capsule().fill(Color(red: 0.85, green: 0.95, blue: 0.94)))
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 8 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink.opacity(0.18), lineWidth: 3))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func actions(compact: Bool, scale: CGFloat) -> some View {
        let start = Button(action: tapped { model.startAdventure() }) {
            IconLabel("Start adventure", symbol: "play.fill", size: compact ? 20 : 28 * scale, trailing: true)
        }
        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 28 * scale))
        let grownUpSize: CGFloat = compact ? 16 : (checked ? 18 : 22) * scale
        let grownUps = Button(action: tapped { model.openQuickSetup() }) {
            IconLabel("Grown-ups", symbol: "gearshape.fill", size: grownUpSize)
        }
        .buttonStyle(ChunkyButtonStyle(fill: checked ? Palette.cream : Palette.gold, size: grownUpSize))
        .accessibilityLabel("Grown-ups: check the settings")
        if compact {
            VStack(alignment: .leading, spacing: 10) { start; grownUps }
        } else {
            HStack { grownUps; Spacer(); start }
        }
    }
}
