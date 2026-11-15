import LostIslandsCore
import SwiftUI

// The end-of-game celebration: the crystal comes home, every guardian says thank you, three
// cheers, the player's adventure in numbers, a group photo, and a nudge to keep exploring.
// Nothing spoken uses the player's name (the lines are recorded once); it only appears as text.
// Mirrors web/src/ui/finale.ts.

/// How a member of the cast arrives on the beach.
private enum Entrance { case grow, splash, swoop, float, bounce, sparkle, run, swim }

private struct CastMember: Identifiable {
    let id: String
    let art: String
    var talkArt: String?
    let name: String
    /// Centre, bottom and height, as percentages of the stage.
    let x: Double
    let bottom: Double
    let height: Double
    let entrance: Entrance
    let layer: Double
    var line: DialogueLine?
}

/// Where each guardian stands, and how it arrives, keyed by island.
private let guardianPlaces: [String: (x: Double, bottom: Double, height: Double, entrance: Entrance, layer: Double)] = [
    "woods": (12, 16, 56, .grow, 1),
    "bay": (24, 4, 30, .splash, 4),
    "dragon": (75, 9, 42, .swoop, 3),
    "cloud": (84, 60, 26, .float, 2),
    "candy": (89, 2, 32, .bounce, 5),
    "star": (34, 3, 20, .sparkle, 6),
]

/// Confetti pieces, moved on every frame. A plain class so the frames don't churn SwiftUI state.
private final class ConfettiField {
    struct Bit { var x, y, vx, vy, r, vr, w: Double; var colour: Color; var life: Double }
    var bits: [Bit] = []
    var colours: [Color] = []

    func burst(_ count: Int, at point: CGPoint, scale: Double) {
        for index in 0..<count {
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 4...13) * scale
            bits.append(Bit(x: point.x, y: point.y, vx: cos(angle) * speed, vy: sin(angle) * speed - 6 * scale,
                            r: .random(in: 0...6), vr: .random(in: -0.15...0.15), w: .random(in: 6...12) * scale,
                            colour: colours[index % max(colours.count, 1)], life: 1))
        }
    }

    func step(scale: Double, height: Double) {
        bits.removeAll { $0.y > height + 40 || $0.life <= 0 }
        for index in bits.indices {
            bits[index].vy += 0.25 * scale
            bits[index].vx *= 0.985
            bits[index].x += bits[index].vx
            bits[index].y += bits[index].vy
            bits[index].r += bits[index].vr
            bits[index].life -= 0.004
        }
    }
}

/// Sizes and places on the full-screen stage. Positions spread across the whole width and
/// height; sizes use one unit (`u`) so nothing grows too big on a long, thin phone screen.
private struct Metrics {
    let size: CGSize
    let insets: EdgeInsets
    var w: CGFloat { size.width / 100 }
    var v: CGFloat { size.height / 100 }
    var u: CGFloat { min(w, v * 1.5) }
    /// The 1536×1024 beach picture fills the stage, cropped to its shape.
    var beachScale: CGFloat { max(size.width / 1536, size.height / 1024) }
    /// Where a point on the beach picture (as fractions of it) lands on the stage.
    func onBeach(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: (size.width - 1536 * beachScale) / 2 + x * 1536 * beachScale,
                y: (size.height - 1024 * beachScale) / 2 + y * 1024 * beachScale)
    }
    /// The castle's crystal in the picture, where the flying crystal comes to rest.
    var castleCrystal: CGPoint { onBeach(0.653, 0.106) }
    var skipButton: CGRect {
        CGRect(x: size.width - insets.trailing - 13 * u, y: insets.top + 1.5 * u, width: 12 * u, height: 7 * u)
    }
}

struct FinaleView: View {
    @Environment(AppModel.self) private var model

    // Which run of the timeline is current; bumping it restarts from `startBeat`.
    @State private var run = 0
    @State private var startBeat = 0
    @State private var hurry = false

    @State private var nightGone = false
    @State private var beachOpen = false
    @State private var crystalOn = false
    @State private var crystalHome = false
    @State private var shardPhase = 0
    @State private var flash = 0.0
    @State private var caption: String?
    @State private var entered: Set<String> = []
    @State private var talking: String?
    @State private var bubble: (id: String, text: String)?
    @State private var sash = false
    @State private var hoorays = 0
    @State private var hoorayShown = false
    @State private var jump = false
    @State private var dim = false
    @State private var statsOn = false
    @State private var tilesShown = 0
    @State private var tileValues = [0, 0, 0, 0, 0]
    @State private var medal = 0 // 0 hidden, 1 stamped in, 2 fading out
    @State private var countdown: String?
    @State private var polaroid = false
    @State private var saved = false
    @State private var nextOn = false
    @State private var confetti = ConfettiField()
    @State private var stageSize = CGSize(width: 1, height: 1)
    @State private var bubbleSize = CGSize.zero

    private var calm: Bool { model.settings.reducedMotion }
    /// From the grown-ups' area it plays for the child chosen there; otherwise for the active player.
    private var profile: Profile? {
        guard model.endingFromGrownUps else { return model.profile }
        return model.save.profiles.first { $0.id == model.endingProfileID } ?? model.profile
    }
    private var name: String { profile?.nickname ?? "Explorer" }
    private var finale: Catalog.Finale? { model.catalog.finale }

    private var cast: [CastMember] {
        var members = [
            CastMember(id: "otter", art: "otter_cheer", talkArt: "otter_talk", name: "Otter", x: 45, bottom: 3, height: 36, entrance: .run, layer: 7),
            CastMember(id: "mosey", art: "mosey_cheer", talkArt: "mosey_talk", name: "Mosey", x: 60, bottom: 1, height: 34, entrance: .swim, layer: 7),
        ]
        for island in model.catalog.islands {
            guard let place = guardianPlaces[island.id] else { continue }
            members.append(CastMember(id: island.id, art: "guardian_\(island.guardian.kind)_happy", name: island.guardian.name,
                                      x: place.x, bottom: place.bottom, height: place.height, entrance: place.entrance, layer: place.layer,
                                      line: finale?.guardians[island.id]))
        }
        return members
    }

    var body: some View {
        // The stage fills the whole screen, edge to edge; only the buttons keep out of the notch.
        GeometryReader { geometry in
            let size = geometry.size
            stage(Metrics(size: size, insets: geometry.safeAreaInsets))
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { hurry = true }
                .onAppear { stageSize = size }
                .onChange(of: size) { _, new in stageSize = new }
        }
        .ignoresSafeArea()
        .background(Color(red: 0.02, green: 0.04, blue: 0.12))
        .statusBarHidden()
        .task(id: run) { await play(from: startBeat) }
        .onAppear {
            confetti.colours = model.catalog.islands.map { Palette.hex($0.colour) } + [Palette.gold, .white]
            AudioManager.shared.playMusic("music_title")
        }
        .onDisappear { Narrator.shared.stop() }
    }

    // MARK: - The stage

    @ViewBuilder private func stage(_ m: Metrics) -> some View {
        let size = m.size
        let u = m.u, v = m.v, w = m.w
        ZStack(alignment: .topLeading) {
            // Night sky, then the beach opening from the crystal in colour.
            RadialGradient(colors: [Color(red: 0.14, green: 0.13, blue: 0.35), Color(red: 0.04, green: 0.06, blue: 0.18), .black],
                           center: .init(x: 0.5, y: 0.4), startRadius: 0, endRadius: size.width * 0.7)
                .opacity(nightGone ? 0 : 1)
            Image("bg_title").resizable().scaledToFill().frame(width: size.width, height: size.height)
                .saturation(beachOpen ? 1 : 0).brightness(beachOpen ? 0 : -0.4)
                .mask {
                    Circle().frame(width: beachOpen ? size.width * 3 : 1, height: beachOpen ? size.width * 3 : 1)
                        .position(m.castleCrystal)
                }
            rays(m)
            shards(m)
            Image("crystal_whole").resizable().scaledToFit()
                .frame(width: crystalHome ? 0.055 * 1536 * m.beachScale : 14 * u)
                .shadow(color: .white.opacity(0.8), radius: 3 * u)
                .scaleEffect(crystalOn ? 1 : 0.3)
                .opacity(crystalOn && !crystalHome ? 1 : 0)
                .position(crystalHome ? m.castleCrystal : CGPoint(x: 50 * w, y: 36 * v))

            // The cast and speech bubbles layer among themselves, beneath the panels.
            ZStack(alignment: .topLeading) {
                ForEach(cast) { member in figure(member, m) }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            // An overlay, so the bubble's alignment guides never move the cast.
            .overlay(alignment: .topLeading) {
                if let bubble, let member = cast.first(where: { $0.id == bubble.id }) {
                    speech(bubble.text, from: member, m).id(bubble.text)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }

            confettiLayer(size)
            Color(red: 0.03, green: 0.1, blue: 0.12).opacity(dim ? 0.45 : 0).allowsHitTesting(false)
            overlays(m)
            Color.white.opacity(flash).allowsHitTesting(false)
            if !nextOn {
                Button(action: tapped { skipToEnd() }) { Text("Skip") }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: max(14, 1.8 * u)))
                    .position(x: m.skipButton.midX, y: m.skipButton.midY)
                Text("Tap to speed up").font(.game(max(11, 1.5 * u), weight: .bold)).foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 0, y: 1)
                    .fixedSize()
                    .position(x: m.insets.leading + 9 * u, y: size.height - m.insets.bottom - 3 * v)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func rays(_ m: Metrics) -> some View {
        let u = m.u, v = m.v
        let colours: [Color] = [.red, .yellow, .green, .blue, .purple]
        return AngularGradient(gradient: Gradient(stops: (0..<40).flatMap { index -> [Gradient.Stop] in
            let start = Double(index) / 40
            return [.init(color: colours[index % 5].opacity(0.35), location: start),
                    .init(color: colours[index % 5].opacity(0.35), location: start + 0.01),
                    .init(color: .clear, location: start + 0.011), .init(color: .clear, location: start + 0.024)]
        }), center: .center)
        .frame(width: 160 * u, height: 160 * u)
        .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 0, endRadius: 48 * u))
        .rotationEffect(.degrees(crystalOn && !calm ? 360 : 0))
        .animation(calm ? nil : .linear(duration: 18).repeatForever(autoreverses: false), value: crystalOn)
        .opacity(crystalOn ? (crystalHome ? 0.55 : 1) : 0)
        .position(crystalHome ? m.onBeach(0.65, 0.14) : CGPoint(x: 50 * m.w, y: 36 * v))
        .allowsHitTesting(false)
    }

    @ViewBuilder private func shards(_ m: Metrics) -> some View {
        let u = m.u, v = m.v, w = m.w
        let starts: [(Double, Double)] = [(-10, 10), (110, 5), (-10, 70), (110, 75), (30, 115), (70, -15)]
        ForEach(Array(model.catalog.islands.enumerated()), id: \.offset) { index, island in
            let angle = Double(index) / Double(max(model.catalog.islands.count, 1)) * 2 * .pi
            let start = starts[index % starts.count]
            let point: (Double, Double) = switch shardPhase {
            case 1: (start.0, start.1)
            case 2: (50 + cos(angle) * 14, 36 + sin(angle) * 18)
            case 3: (50, 36)
            default: (start.0, start.1)
            }
            Image("crystal_shard").resizable().scaledToFit()
                .frame(width: 6 * u)
                .shadow(color: Palette.hex(island.colour), radius: 1.2 * u)
                .shadow(color: Palette.hex(island.colour), radius: 2.4 * u)
                .rotationEffect(.degrees(shardPhase == 2 ? 0 : shardPhase == 3 ? 360 : -160))
                .scaleEffect(shardPhase == 3 ? 0.4 : 1)
                .opacity(shardPhase == 2 ? 1 : 0)
                .position(x: point.0 * w, y: point.1 * v)
                .animation(calm ? .easeOut(duration: 0.3) : .easeInOut(duration: shardPhase == 2 ? 1.7 : 1).delay(Double(index) * 0.12), value: shardPhase)
        }
    }

    // MARK: - The cast

    private func figure(_ member: CastMember, _ m: Metrics) -> some View {
        let v = m.v, w = m.w
        let isIn = entered.contains(member.id)
        let art = talking == member.id ? (member.talkArt ?? member.art) : member.art
        return Image(art).resizable().scaledToFit()
            .frame(height: member.height * v)
            .shadow(color: .black.opacity(0.25), radius: 0.6 * v, y: 0.6 * v)
            .scaleEffect(x: !isIn && member.entrance == .grow ? 0.6 : 1, y: !isIn && member.entrance == .grow ? 0.01 : 1, anchor: .bottom)
            .scaleEffect(!isIn && member.entrance == .sparkle ? 0.01 : !isIn && member.entrance == .swoop ? 0.6 : 1, anchor: .bottom)
            .rotationEffect(.degrees(!isIn && member.entrance == .swoop ? -25 : !isIn && member.entrance == .sparkle ? -40 : 0))
            .offset(entranceOffset(member, isIn: isIn, u: w, v: v))
            .offset(y: jump ? -member.height * v * 0.18 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.5).delay(Double(member.layer) * 0.04), value: jump)
            .opacity(isIn ? 1 : 0)
            .brightness(nextOn ? -0.15 : 0)
            .position(x: member.x * w, y: (100 - member.bottom) * v - member.height * v / 2)
            .zIndex(member.layer)
            .allowsHitTesting(false)
    }

    private func entranceOffset(_ member: CastMember, isIn: Bool, u: CGFloat, v: CGFloat) -> CGSize {
        guard !isIn else { return .zero }
        switch member.entrance {
        case .splash: return CGSize(width: 0, height: member.height * v * 0.7)
        case .swoop: return CGSize(width: 60 * u, height: -50 * v)
        case .float: return CGSize(width: 0, height: -50 * v)
        case .bounce: return CGSize(width: 30 * u, height: 0)
        case .run: return CGSize(width: -60 * u, height: 0)
        case .swim: return CGSize(width: 50 * u, height: member.height * v * 0.2)
        case .grow, .sparkle: return .zero
        }
    }

    /// The space a character's picture takes up on the stage.
    private func pictureRect(_ member: CastMember, _ m: Metrics) -> CGRect {
        let height = member.height * m.v
        let art = UIImage(named: member.art)?.size ?? CGSize(width: 1, height: 1)
        let width = height * art.width / max(art.height, 1)
        return CGRect(x: member.x * m.w - width / 2, y: (100 - member.bottom - member.height) * m.v, width: width, height: height)
    }

    /// A speech bubble placed so it never covers the speaker (or the Skip button), its tail
    /// pointing at them and drawn behind the words.
    private func speech(_ text: String, from member: CastMember, _ m: Metrics) -> some View {
        let u = m.u
        let measured = bubbleSize == .zero ? CGSize(width: 34 * u, height: 10 * u) : bubbleSize
        var avoid = [m.skipButton]
        if sash { avoid.append(CGRect(x: 30 * m.w, y: 4 * m.v, width: 40 * m.w, height: 8 * u)) }
        let spot = BubblePlacement.place(stage: m.size, speaker: pictureRect(member, m), bubble: measured,
                                         margin: m.size.width * 0.012, gap: m.size.height * 0.025, avoid: avoid)
        let tail = 2.8 * u
        let alignment: Alignment = switch spot.tail {
        case .down: .bottomLeading
        case .up, .left: .topLeading
        case .right: .topTrailing
        }
        let tailOffset: CGSize = switch spot.tail {
        case .down: CGSize(width: spot.tailAt - tail / 2, height: tail / 2)
        case .up: CGSize(width: spot.tailAt - tail / 2, height: -tail / 2)
        case .left: CGSize(width: -tail / 2, height: spot.tailAt - tail / 2)
        case .right: CGSize(width: tail / 2, height: spot.tailAt - tail / 2)
        }
        return VStack(alignment: .leading, spacing: 0.3 * u) {
            Text(member.name.uppercased()).font(.game(max(10, 1.5 * u))).foregroundStyle(Palette.ink.opacity(0.65)).tracking(0.5)
            Text(text).font(.game(max(13, 2.2 * u))).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 1.6 * u).padding(.vertical, 1.2 * u)
        .frame(maxWidth: 34 * u, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { bubbleSize = $0 }
        .background(RoundedRectangle(cornerRadius: 2.2 * u).fill(Palette.cream))
        .background(alignment: alignment) {
            Rectangle().fill(Palette.cream)
                .frame(width: tail, height: tail)
                .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 0.35 * u))
                .rotationEffect(.degrees(45))
                .offset(tailOffset)
        }
        .background(RoundedRectangle(cornerRadius: 2.2 * u).fill(Palette.ink).offset(y: 0.5 * u))
        .overlay(RoundedRectangle(cornerRadius: 2.2 * u).strokeBorder(Palette.ink, lineWidth: 0.35 * u))
        .position(x: spot.origin.x + measured.width / 2, y: spot.origin.y + measured.height / 2)
        .animation(nil, value: measured)
        .allowsHitTesting(false)
    }

    private func confettiLayer(_ size: CGSize) -> some View {
        TimelineView(.animation) { _ in
            Canvas { context, canvas in
                confetti.step(scale: max(canvas.width / 1000, 0.5), height: canvas.height)
                for bit in confetti.bits {
                    var piece = context
                    piece.translateBy(x: bit.x, y: bit.y)
                    piece.rotate(by: .radians(bit.r))
                    piece.opacity = min(1, bit.life * 2)
                    piece.fill(Path(CGRect(x: -bit.w / 2, y: -bit.w / 4, width: bit.w, height: bit.w / 2)), with: .color(bit.colour))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Captions, panels and the photo

    @ViewBuilder private func overlays(_ m: Metrics) -> some View {
        let u = m.u, v = m.v, w = m.w
        let outline = Palette.ink
        if let caption {
            Text(caption).font(.game(4 * u)).foregroundStyle(.white).multilineTextAlignment(.center)
                .shadow(color: outline, radius: 0, y: 0.4 * u).shadow(color: .black.opacity(0.6), radius: 2 * u)
                .frame(width: 90 * u)
                .position(x: 50 * w, y: 12 * v)
                .transition(.opacity.combined(with: .offset(y: -1 * v)))
                .id(caption)
                .allowsHitTesting(false)
        }
        if sash {
            Text("★ \(name) ★").font(.game(4 * u)).foregroundStyle(.white)
                .padding(.horizontal, 4 * u).padding(.vertical, 0.8 * u)
                .panel(fill: Palette.coral, radius: 1.4 * u)
                .position(x: 50 * w, y: 11 * v)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        Text("Hooray!").font(.game(11 * u)).foregroundStyle(Palette.gold)
            .shadow(color: outline, radius: 0, y: 0.8 * u)
            .scaleEffect(hoorayShown ? 1 : 0.3).rotationEffect(.degrees(hoorayShown ? 0 : -8))
            .opacity(hoorayShown ? 1 : 0)
            .position(x: 50 * w, y: 30 * v)
            .allowsHitTesting(false)
        if statsOn { statsPanel(u: u).position(x: 50 * w, y: 50 * v).transition(.scale(scale: 0.9).combined(with: .opacity)) }
        if medal > 0 {
            VStack(spacing: 0) {
                Image("trophy_champion").resizable().scaledToFit().frame(width: 22 * u)
                    .shadow(color: Palette.gold.opacity(0.9), radius: 3 * u)
                Text("Rainbow Crystal Champion").font(.game(3 * u)).foregroundStyle(.white)
                    .padding(.horizontal, 3 * u).padding(.vertical, 0.8 * u)
                    .panel(fill: Palette.coral, radius: 1.2 * u)
                    .offset(y: -1 * u)
                Text("Awarded to \(name)").font(.game(2.6 * u)).foregroundStyle(.white).shadow(color: outline, radius: 0, y: 0.3 * u)
            }
            .opacity(medal == 1 ? 1 : 0)
            .position(x: 50 * w, y: 50 * v)
            .transition(.scale(scale: 3).combined(with: .opacity))
            .allowsHitTesting(false)
        }
        if let countdown {
            Text(countdown).font(.game(16 * u)).foregroundStyle(.white).shadow(color: outline, radius: 0, y: 0.8 * u)
                .position(x: 50 * w, y: 40 * v).id(countdown)
                .transition(.scale(scale: 2).combined(with: .opacity))
        }
        VStack(spacing: 0) {
            Image("bg_ending").resizable().aspectRatio(1.5, contentMode: .fill).frame(width: 53 * u, height: 53 * u / 1.5).clipped()
            Text(GroupPhoto.caption(for: name)).font(.custom("Bradley Hand", size: 2.6 * u).weight(.bold)).foregroundStyle(Palette.ink)
                .padding(.vertical, 1.4 * u)
        }
        .padding([.top, .horizontal], 1.4 * u)
        .background(.white)
        .shadow(color: .black.opacity(0.45), radius: 3 * u, y: 2 * u)
        .rotationEffect(.degrees(polaroid ? -3 : 14))
        .offset(y: polaroid ? 0 : -80 * v)
        .opacity(polaroid ? 1 : 0)
        .position(x: 50 * w, y: 47 * v)
        .allowsHitTesting(false)
        if saved {
            IconLabel("Photo saved to Treasures", emoji: "🎒", size: 2 * u).font(.game(2 * u)).foregroundStyle(.white)
                .padding(.horizontal, 2 * u).padding(.vertical, 0.9 * u)
                .panel(fill: Palette.teal, radius: 5 * u)
                .position(x: 78 * w, y: 90 * v)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        if nextOn {
            nextPanel(u: u)
                .frame(width: 72 * u)
                .position(x: 50 * w, y: 72 * v)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var tally: [(emoji: String, value: Int, label: String)] {
        guard let profile else { return [] }
        return [
            ("✨", profile.learner.answerCount, "questions answered"),
            ("⭐️", profile.totalStars, "stars won"),
            ("🏅", Trophies.count(in: profile, catalog: model.catalog).won, "trophies"),
            ("🎒", model.catalog.rewards.filter { profile.has($0.id) }.count, "treasures"),
            ("🔥", profile.bestCombo, "best streak"),
        ]
    }

    private func statsPanel(u: CGFloat) -> some View {
        VStack(spacing: 1.6 * u) {
            Text("\(name)'s adventure").font(.game(3.6 * u)).foregroundStyle(Palette.ink)
            HStack(spacing: 1.2 * u) {
                ForEach(Array(tally.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 0.4 * u) {
                        Glyph(item.emoji, size: 5 * u)
                        Text(tileValues[index].formatted()).font(.game(3.4 * u)).monospacedDigit().foregroundStyle(Palette.ink)
                        Text(item.label).font(.game(1.5 * u, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 1.2 * u).padding(.horizontal, 0.6 * u)
                    .frame(maxWidth: .infinity, minHeight: 13 * u)
                    .background(RoundedRectangle(cornerRadius: 1.6 * u).fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 1.6 * u).strokeBorder(Palette.ink, lineWidth: 0.3 * u)))
                    .opacity(index < tilesShown ? 1 : 0)
                    .offset(y: index < tilesShown ? 0 : 2 * u)
                }
            }
        }
        .padding(.horizontal, 3 * u).padding(.vertical, 2.4 * u)
        .frame(width: 66 * u)
        .panel(radius: 2.4 * u)
    }

    private func nextPanel(u: CGFloat) -> some View {
        let left = profileLeft
        let everything = left.trophies == 0 && left.stars == 0 && left.pets == 0
        return VStack(spacing: 0.8 * u) {
            Text(everything ? "You found everything!" : "The adventure goes on!").font(.game(3.4 * u)).foregroundStyle(Palette.ink)
            Text(everything
                 ? "Every trophy, every star and every pet. You're a true Lost Islands legend! Play any level again, just for fun."
                 : "Every island is open. Play any level again to find what's still hiding.")
                .font(.game(1.9 * u, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.8)).multilineTextAlignment(.center)
            if !everything {
                HStack(spacing: 1.4 * u) {
                    if left.trophies > 0 { pill("🏅", left.trophies == 1 ? "1 trophy to find" : "\(left.trophies) trophies to find", u: u) }
                    if left.stars > 0 { pill("⭐️", left.stars == 1 ? "1 more star to win" : "\(left.stars) more stars to win", u: u) }
                    if left.pets > 0 { pill("🐾", left.pets == 1 ? "1 pet waiting" : "\(left.pets) pets waiting", u: u) }
                }
                .padding(.vertical, 0.6 * u)
            }
            HStack(spacing: 1.6 * u) {
                let size = max(16, 2.4 * u)
                if model.endingFromGrownUps {
                    Button(action: tapped { model.leaveEndingForGrownUps() }) { Text("Back to grown-ups") }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: size))
                    Button(action: tapped {
                        startBeat = 0
                        run += 1
                    }) { IconLabel("Watch again", emoji: "🌈", size: size) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: size))
                } else {
                    Button(action: tapped { model.route = .map }) { IconLabel("Back to the map", emoji: "🗺", size: size) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: size))
                    Button(action: tapped { model.openTrophies() }) { IconLabel("See my trophies", emoji: "🏅", size: size) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: size))
                }
            }
            .padding(.top, 0.6 * u)
        }
        .padding(.horizontal, 3 * u).padding(.vertical, 2.4 * u)
        .panel(radius: 2.4 * u)
    }

    private func pill(_ emoji: String, _ text: String, u: CGFloat) -> some View {
        IconLabel(text, emoji: emoji, size: 1.9 * u).font(.game(1.9 * u)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 1.6 * u).padding(.vertical, 0.6 * u)
            .background(Capsule().fill(.white).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 0.3 * u)))
    }

    /// What is still out there to find, for the last card.
    private var profileLeft: (trophies: Int, stars: Int, pets: Int) {
        guard let profile else { return (0, 0, 0) }
        let count = Trophies.count(in: profile, catalog: model.catalog)
        return (count.total - count.won,
                model.catalog.allLevels.count * 3 - profile.totalStars,
                model.catalog.rewards.filter { $0.kind == .pet && !profile.has($0.id) }.count)
    }

    // MARK: - Timing

    /// Waits, or stops early when the screen is tapped. Throws when the run is replaced or the screen goes.
    private func wait(_ seconds: Double) async throws {
        let end = Date().addingTimeInterval(calm ? min(seconds, 0.6) : seconds)
        hurry = false
        while Date() < end, !hurry {
            try await Task.sleep(for: .milliseconds(40))
        }
        hurry = false
    }

    private func animate(_ animation: Animation? = .easeInOut(duration: 0.5), _ change: () -> Void) {
        withAnimation(calm ? .easeOut(duration: 0.25) : animation, change)
    }

    /// Says a line in a speech bubble over its speaker, waiting for the recording (or a tap).
    private func say(_ id: String, _ line: DialogueLine?, least: Double? = nil) async throws {
        guard let line else { return }
        animate(.spring(duration: 0.35, bounce: 0.4)) { bubble = (id, line.text) }
        talking = id
        Narrator.shared.speakLine(line, voiced: model.settings.characterVoices)
        defer { Narrator.shared.stop(); talking = nil }
        try await wait(least ?? 0.9 + Double(line.text.count) * 0.04)
        hurry = false
        var tappedOut = false
        while Narrator.shared.isSpeaking, !tappedOut {
            try await Task.sleep(for: .milliseconds(80))
            if hurry { tappedOut = true }
        }
        try await wait(0.25)
    }

    /// A story line: read by the narrator, shown as a caption.
    private func tell(_ line: DialogueLine?, least: Double = 2.4) async throws {
        guard let line else { return }
        show(line)
        try await wait(least)
        while Narrator.shared.isSpeaking, !hurry { try await Task.sleep(for: .milliseconds(80)) }
    }

    private func show(_ line: DialogueLine?) {
        guard let line else { return }
        animate(.easeOut(duration: 0.6)) { caption = line.text }
        Narrator.shared.speakLine(line, voiced: model.settings.characterVoices)
    }

    private func burst(_ count: Int, x: Double, y: Double) {
        let scale = max(stageSize.width / 1000, 0.5)
        confetti.burst(calm ? count / 3 : count, at: CGPoint(x: x * stageSize.width, y: y * stageSize.height), scale: scale)
    }

    private func skipToEnd() {
        startBeat = 6
        run += 1
    }

    /// Puts everything as it would be at the start of `beat`, for Skip.
    private func reset(to beat: Int) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            bubble = nil; caption = nil; sash = false; dim = false; statsOn = false; medal = 0
            countdown = nil; polaroid = false; saved = false; nextOn = false; hoorayShown = false; shardPhase = 0; flash = 0
            nightGone = beat > 1; beachOpen = beat > 1; crystalOn = beat > 0; crystalHome = beat > 1
            var people: Set<String> = []
            if beat > 2 { people.formUnion(model.catalog.islands.map(\.id)) }
            if beat > 3 { people.formUnion(["otter", "mosey"]) }
            entered = people
        }
        confetti.bits = []
        Narrator.shared.stop()
    }

    // MARK: - The beats

    private func play(from beat: Int) async {
        reset(to: beat)
        do {
            if beat == 0 { try await wait(0.3) }
            for index in beat..<7 {
                switch index {
                case 0: try await crystalComesHome()
                case 1: try await colourReturns()
                case 2: try await friendsArrive()
                case 3: try await threeCheers()
                case 4: try await adventureInNumbers()
                case 5: try await groupPhoto()
                default: try await adventureGoesOn()
                }
            }
        } catch {
            // Replaced by Skip, or the screen was left.
        }
    }

    private func crystalComesHome() async throws {
        show(finale?.opening.first)
        try await wait(1.2)
        shardPhase = 1
        try await Task.sleep(for: .milliseconds(30))
        shardPhase = 2
        AudioManager.shared.play(.whoosh)
        try await wait(2)
        shardPhase = 3
        try await wait(1.4)
        withAnimation(.easeOut(duration: 0.1)) { flash = 0.9 }
        withAnimation(.easeOut(duration: 1).delay(0.1)) { flash = 0 }
        animate(.spring(duration: 0.9, bounce: 0.5)) { crystalOn = true }
        AudioManager.shared.play(.crystal)
        burst(90, x: 0.5, y: 0.3)
        if let line = finale?.opening.dropFirst().first { try await tell(line, least: 2.6) }
    }

    private func colourReturns() async throws {
        animate { caption = nil }
        animate(.easeInOut(duration: 2)) { nightGone = true; beachOpen = true }
        animate(.easeInOut(duration: 1.6)) { crystalHome = true }
        AudioManager.shared.play(.unlock)
        try await wait(1.6)
        if let line = finale?.opening.dropFirst(2).first { try await tell(line, least: 2.6) }
        animate { caption = nil }
    }

    private func friendsArrive() async throws {
        for member in cast where guardianPlaces[member.id] != nil {
            animate(.spring(duration: 0.9, bounce: 0.35)) { _ = entered.insert(member.id) }
            AudioManager.shared.play(.pop, volume: 0.8)
            if member.entrance == .splash || member.entrance == .sparkle { burst(30, x: member.x / 100, y: 0.8) }
            try await wait(0.7)
            try await say(member.id, member.line)
            animate(.easeOut(duration: 0.2)) { bubble = nil }
            try await wait(0.25)
        }
    }

    private func threeCheers() async throws {
        animate(.spring(duration: 0.9, bounce: 0.3)) { _ = entered.insert("otter") }
        try await wait(0.5)
        animate(.spring(duration: 1.1, bounce: 0.3)) { _ = entered.insert("mosey") }
        try await wait(1)
        let thanks = finale?.thanks ?? []
        if thanks.count > 0 { try await say("otter", thanks[0]) }
        if thanks.count > 1 { try await say("mosey", thanks[1]) }
        animate(.spring(duration: 0.5, bounce: 0.5)) { sash = true }
        if thanks.count > 2 { try await say("otter", thanks[2], least: 1.8) }
        animate(.easeOut(duration: 0.2)) { bubble = nil }
        for index in 0..<3 {
            withAnimation(.spring(duration: 0.4, bounce: 0.6)) { hoorayShown = true }
            jump = true
            // The whole cast shouts, recorded together as one sound.
            AudioManager.shared.play(.cheer)
            if index == 2 { AudioManager.shared.play(.victory, volume: 0.5) }
            burst(120, x: 0.2 + Double(index) * 0.3, y: 0.4)
            try await wait(0.45)
            jump = false
            try await wait(0.45)
            withAnimation(.easeOut(duration: 0.25)) { hoorayShown = false }
            try await wait(0.25)
        }
        try await wait(0.6)
        animate { sash = false }
    }

    private func adventureInNumbers() async throws {
        let items = tally
        tileValues = Array(repeating: 0, count: 5)
        tilesShown = 0
        animate { dim = true; statsOn = true }
        try await wait(0.6)
        for (index, item) in items.enumerated() {
            animate(.spring(duration: 0.4, bounce: 0.5)) { tilesShown = index + 1 }
            AudioManager.shared.play(.pop, volume: 0.6)
            Task { @MainActor in
                for step in 1...15 {
                    let progress = Double(step) / 15
                    tileValues[index] = Int((Double(item.value) * (1 - pow(1 - progress, 3))).rounded())
                    try? await Task.sleep(for: .milliseconds(60))
                }
                tileValues[index] = item.value
            }
            try await wait(0.45)
        }
        try await wait(2)
        animate { statsOn = false }
        animate(.spring(duration: 0.8, bounce: 0.45)) { medal = 1 }
        AudioManager.shared.play(.levelComplete)
        burst(160, x: 0.5, y: 0.45)
        try await wait(3.4)
        animate { medal = 2 }
        try await wait(0.5)
        animate { medal = 0; dim = false }
    }

    private func groupPhoto() async throws {
        try await say("mosey", finale?.photo.first, least: 2.2)
        animate(.easeOut(duration: 0.2)) { bubble = nil }
        // Otter counts down; the big numbers match the recording.
        let spoken = finale?.countdown ?? []
        for (index, number) in ["3", "2", "1"].enumerated() {
            animate(.spring(duration: 0.4)) { countdown = number }
            if index < spoken.count { Narrator.shared.speakLine(spoken[index], voiced: model.settings.characterVoices) }
            else { AudioManager.shared.play(.tap) }
            try await wait(0.9)
        }
        Narrator.shared.stop()
        animate(.easeOut(duration: 0.2)) { countdown = nil }
        withAnimation(.easeOut(duration: 0.1)) { flash = 0.9 }
        withAnimation(.easeOut(duration: 1).delay(0.1)) { flash = 0 }
        AudioManager.shared.play(.portal)
        animate(.spring(duration: 1, bounce: 0.3)) { dim = true; polaroid = true }
        try await wait(1.2)
        animate(.spring(duration: 0.5, bounce: 0.4)) { saved = true }
        try await wait(3.2)
        animate { polaroid = false; saved = false; dim = false }
        try await wait(0.6)
    }

    private func adventureGoesOn() async throws {
        let after = finale?.after ?? []
        if after.count > 0 { try await say("otter", after[0]) }
        if after.count > 1 { try await say("mosey", after[1]) }
        animate(.easeOut(duration: 0.2)) { bubble = nil }
        animate(.spring(duration: 0.6, bounce: 0.35)) { nextOn = true }
    }
}
