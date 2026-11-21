import LostIslandsCore
import SpriteKit
import SwiftUI

/// Wraps a menu scene in a SpriteView and keeps it informed of the safe area.
struct SceneBackdrop<S: CoverScene>: View {
    let scene: S
    var extraTop: CGFloat = 0
    var extraBottom: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .onAppear { apply(geometry) }
                .onChange(of: geometry.size) { _, _ in apply(geometry) }
                .onChange(of: extraBottom) { _, _ in apply(geometry) }
                .onChange(of: extraTop) { _, _ in apply(geometry) }
        }
    }

    private func apply(_ geometry: GeometryProxy) {
        let safe = geometry.safeAreaInsets
        scene.insets = UIEdgeInsets(top: safe.top + extraTop, left: safe.leading, bottom: safe.bottom + extraBottom, right: safe.trailing)
    }
}

struct TitleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = TitleScene()
    @State private var logoIn = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                SceneBackdrop(scene: scene)
                    .onChange(of: !reduceMotion && !model.settings.reducedMotion, initial: true) { _, animate in
                        scene.setSceneryMotion(animate)
                    }
                VStack(spacing: 0) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: geometry.size.height * (compact ? 0.5 : 0.42))
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                        .scaleEffect(logoIn ? 1 : 0.5)
                        .opacity(logoIn ? 1 : 0)
                        .accessibilityLabel("Otter and Mosey: The Lost Islands")
                    Spacer(minLength: 0)
                    VStack(spacing: compact ? 8 : 14) {
                        if let profile = model.profile, profile.seenIntro {
                            Button(action: tapped { model.continueGame() }) { IconLabel("Continue", symbol: "play.fill", size: compact ? 26 : 36) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 26 : 36, minWidth: compact ? 250 : 320))
                            TrophiesButton(size: compact ? 19 : 26)
                        } else {
                            Button(action: tapped { model.play() }) { IconLabel("Play", symbol: "play.fill", size: compact ? 30 : 40) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 30 : 40, minWidth: compact ? 250 : 320))
                        }
                    }
                    .padding(.bottom, compact ? 12 : 44)
                }
                .padding(.top, compact ? 48 : 64)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: tapped { model.route = .profiles }) {
                            HStack(spacing: 6) {
                                Glyph(model.profile?.avatar ?? "🙂", size: compact ? 26 : 34).padding(.vertical, -6)
                                Text(model.profile?.nickname ?? "Players")
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    }
                    .padding(.horizontal, compact ? 8 : 28)
                    .padding(.top, compact ? 8 : 20)
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: tapped { model.route = .parent }) {
                            IconLabel("Grown-ups", symbol: "gearshape.fill", size: compact ? 14 : 18)
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 14 : 18))
                    }
                    .padding(.horizontal, compact ? 8 : 28)
                    .padding(.bottom, compact ? 10 : 28)
                }
            }
            .environment(\.compact, compact)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.45).delay(0.2)) { logoIn = true }
        }
    }
}

/// Choose, add or remove a player. Only a nickname and a picture are ever asked for.
struct ProfilesView: View {
    private enum CreationStep { case character, name }
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var creationStep = CreationStep.character
    @State private var nickname = ""
    @State private var avatar = "🦦"
    @State private var deleting: Profile?
    /// Shown when "Let's go!" is tapped with no name typed yet.
    @State private var askingForName = false
    /// Goes up by one per wobble; the field wiggles as it animates to the new value.
    @State private var nameWobbles: CGFloat = 0
    private static let nameHint = "What shall we call you? Type your name in the box!"
    private let avatars = ["🦦", "🐬", "🦄", "🦖", "👾", "👻", "👸", "🐢", "🦀", "🐲", "🦉", "🦋", "🐰", "⭐️", "🌈", "🚀", "🎨"]
    private var creating: Bool { adding || model.save.profiles.isEmpty }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 8 : 18) {
                    HStack {
                        RoundButton(symbol: "chevron.left", label: creating && creationStep == .name ? "Back to character" : "Back", action: goBack)
                        Spacer()
                        Text(creating ? "New explorer" : "Who's playing?").font(.game(compact ? 28 : 42)).foregroundStyle(.white).shadow(radius: 4)
                            .lineLimit(1).minimumScaleFactor(0.7).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Color.clear.frame(width: 54, height: 54)
                    }
                    if creating {
                        if creationStep == .character {
                            characterForm(compact: compact)
                        } else {
                            let formWidth = min(760, geometry.size.width - (compact ? 20 : 56))
                            ScrollView {
                                nameForm(compact: compact, width: formWidth)
                                    .padding(.bottom, 6) // Keep the panel's shadow inside the scroll area.
                                    .frame(maxWidth: .infinity)
                            }
                            .defaultScrollAnchor(.center, for: .alignment)
                        }
                    } else { list(compact: compact) }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 10 : 28)
            }
            .screenBackground("bg_title", blur: 6, dim: 0.35)
            .environment(\.compact, compact)
        }
        .confirmationDialog("Remove \(deleting?.nickname ?? "") and all their progress?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Remove player", role: .destructive) {
                if let deleting { model.deleteProfile(deleting.id) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        }
    }

    private func list(compact: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(model.save.profiles) { profile in
                    Button(action: tapped {
                        model.selectProfile(profile.id)
                        model.play()
                    }) {
                        VStack(spacing: 6) {
                            Glyph(profile.avatar, size: compact ? 62 : 92)
                            Text(profile.nickname).font(.game(compact ? 20 : 26)).foregroundStyle(Palette.ink)
                            HStack(spacing: 10) {
                                HStack(spacing: 3) { Glyph("⭐️", size: compact ? 18 : 24); Text("\(profile.totalStars)") }
                                HStack(spacing: 3) { Glyph("💎", size: compact ? 18 : 24); Text("\(profile.crystals.count)/6") }
                            }
                            .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                        }
                        .frame(width: compact ? 150 : 210, height: compact ? 150 : 220)
                        .panel(fill: profile.id == model.profile?.id ? Palette.gold.opacity(0.9) : Palette.cream)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Remove player", role: .destructive) { deleting = profile } }
                }
                Button(action: tapped {
                    nickname = ""
                    avatar = avatars[0]
                    askingForName = false
                    creationStep = .character
                    adding = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: compact ? 44 : 64)).foregroundStyle(Palette.teal)
                        Text("New player").font(.game(compact ? 18 : 24)).foregroundStyle(Palette.ink)
                    }
                    .frame(width: compact ? 150 : 210, height: compact ? 150 : 220)
                    .panel()
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    private func characterForm(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 18) {
            Text("1 of 2 · Choose your character")
                .font(.game(compact ? 20 : 26)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 60 : 80), spacing: 12)], spacing: 12) {
                    ForEach(Array(avatars.enumerated()), id: \.element) { index, choice in
                        Button(action: tapped { avatar = choice }) {
                            Glyph(choice, size: compact ? 44 : 58)
                                .frame(width: compact ? 60 : 80, height: compact ? 60 : 80)
                                .background(Circle().fill(choice == avatar ? Palette.gold : .white).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Picture \(index + 1)")
                        .accessibilityAddTraits(choice == avatar ? .isSelected : [])
                    }
                }
                .padding(4)
            }
            HStack(spacing: 12) {
                Button("Cancel", action: tapped(goBack))
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 22))
                Button(action: tapped { creationStep = .name }) {
                    IconLabel("Next", symbol: "arrow.right", size: compact ? 22 : 28, trailing: true)
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: compact ? 150 : 200))
            }
        }
        .padding(compact ? 14 : 28)
        .panel()
        .frame(maxWidth: 760)
    }

    private func nameKeyboard(width: CGFloat) -> some View {
        GameKeyboard(kind: .qwerty(space: true), width: width, onKey: typeName, onBackspace: deleteName, embedded: true,
                     uppercase: KeyboardCapitalization.name(after: nickname))
            .background(HardwareKeys(onKey: typeName, onBackspace: deleteName).frame(width: 0, height: 0))
            .accessibilityLabel("Nickname keyboard")
    }

    private func nameForm(compact: Bool, width: CGFloat) -> some View {
        VStack(spacing: compact ? 6 : 16) {
            Text("2 of 2 · What shall we call you?")
                .font(.game(compact ? 16 : 24)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            HStack(spacing: compact ? 8 : 12) {
                Glyph(avatar, size: compact ? 40 : 72)
                Text(nickname.isEmpty ? "Nickname" : nickname)
                    .font(.game(compact ? 24 : 32))
                    .foregroundStyle(nickname.isEmpty ? Palette.ink.opacity(0.5) : Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityLabel("Nickname")
                    .accessibilityValue(nickname.isEmpty ? "Not entered" : nickname)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 6 : 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(askingForName ? Palette.coral : Palette.ink, lineWidth: askingForName ? 4 : 3)))
                    .frame(maxWidth: 340)
                    .modifier(Wobble(wobbles: nameWobbles))
                    .onChange(of: nickname) { _, value in
                        if value.count > 12 { nickname = String(value.prefix(12)) }
                        if askingForName, !value.trimmingCharacters(in: .whitespaces).isEmpty { askingForName = false }
                    }
                RoundButton(symbol: "delete.left", size: compact ? 44 : 54, label: "Delete letter", action: deleteName)
            }
            if askingForName {
                HStack(spacing: 8) {
                    Image("otter_idle").resizable().scaledToFit().frame(height: compact ? 24 : 40).accessibilityHidden(true)
                    Text(Self.nameHint).font(.game(compact ? 14 : 20)).foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, compact ? 8 : 14)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.gold.opacity(0.35)))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            nameKeyboard(width: width - (compact ? 20 : 56))
            HStack(spacing: 12) {
                Button("Back", action: tapped(goBack)).buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 22))
                Button(action: tapped(letsGo)) { IconLabel("Let's go!", symbol: "play.fill", size: compact ? 22 : 28, trailing: true) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: compact ? 150 : 200))
            }
        }
        .padding(compact ? 10 : 28)
        .frame(width: width)
        .panel()
    }

    private func goBack() {
        askingForName = false
        if creating && creationStep == .name {
            creationStep = .character
        } else if adding && !model.save.profiles.isEmpty {
            adding = false
        } else {
            model.route = .title
        }
    }

    private func typeName(_ character: Character) {
        guard nickname.count < 12, character.isLetter || character == " " || character == "-" || character == "’" else { return }
        let startsWord = KeyboardCapitalization.name(after: nickname)
        nickname += startsWord ? String(character).uppercased() : String(character)
    }

    private func deleteName() {
        if !nickname.isEmpty { nickname.removeLast() }
    }

    /// Creates the player, or, with no name typed yet, gives the box a friendly wiggle and asks for one.
    private func letsGo() {
        guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Haptics.shared.nudge()
            withAnimation(model.settings.reducedMotion ? nil : .spring(duration: 0.3)) { askingForName = true }
            if !model.settings.reducedMotion {
                withAnimation(.easeInOut(duration: 0.6)) { nameWobbles += 1 }
            }
            AccessibilityNotification.Announcement(Self.nameHint).post()
            return
        }
        askingForName = false
        model.createProfile(nickname: nickname, avatar: avatar)
        adding = false
        nickname = ""
        model.play()
    }
}

/// A gentle side-to-side wiggle, played once each time `wobbles` goes up by one.
private struct Wobble: GeometryEffect {
    var wobbles: CGFloat
    var animatableData: CGFloat {
        get { wobbles }
        set { wobbles = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = wobbles - wobbles.rounded(.down)
        // Three swings that fade out, with a slight tilt so it feels playful rather than stern.
        let swing = sin(progress * .pi * 6) * (1 - progress)
        let transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .rotated(by: swing * 0.04)
            .translatedBy(x: -size.width / 2 + swing * 12, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

/// The opening story and the practice round that follows it.
struct IntroView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = IntroScene()
    @State private var step = 0 // 0 = story, 1 = practice, 2 = after-story
    @State private var question = 0
    @State private var peeking = false
    /// Wrong answers already tapped on the current tap-the-answer question.
    @State private var ruledOut: Set<String> = []

    private var practice: PracticeQuestion { IntroScene.practice[question] }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                SceneBackdrop(scene: scene, extraBottom: step == 1 ? KeyMetrics.trayHeight(compact: compact) + 14 : DialogueView.reservedHeight(compact: compact))
                if step == 0 {
                    DialogueView(lines: model.catalog.intro, onLineShown: { index in
                        // The story beats drive the scene: line 5 shakes the crystal, line 6 breaks it.
                        if index == 4 { scene.rumble() }
                        if index == 5 { scene.shatter() }
                    }, onFinish: startTutorial)
                } else if step == 1 {
                    VStack {
                        banner(compact: compact)
                        Spacer()
                        answerKeys(width: geometry.size.width - 16, compact: compact)
                    }
                    HardwareKeys(onKey: { scene.handleKey($0) }, onBackspace: {}).frame(width: 1, height: 1).opacity(0.01)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: tapped { model.finishIntro() }) { IconLabel("Skip", symbol: "forward.end.fill", size: compact ? 16 : 20, trailing: true) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20))
                        }
                        Spacer()
                    }
                    .padding(compact ? 12 : 24)
                    .padding(.top, compact ? 44 : 60)
                } else {
                    DialogueView(lines: model.catalog.introAfter) { model.finishIntro() }
                }
            }
            .environment(\.uiScale, ScreenMetrics.scale(geometry))
            .environment(\.compact, compact)
        }
        .onAppear {
            scene.onQuestion = { index in
                question = index
                peeking = false
                ruledOut = []
                say(IntroScene.practice[index])
            }
            scene.onPeek = { peeking = true }
            scene.onTutorialDone = {
                Narrator.shared.stop()
                step = 2
            }
        }
    }

    private func banner(compact: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Practice \(question + 1) of \(IntroScene.practice.count)")
                .font(.game(compact ? 13 : 17, weight: .heavy)).foregroundStyle(Palette.ink.opacity(0.7))
            Text(peeking ? "Here's a peek! Remember it, then try again." : practice.instruction)
                .font(.game(compact ? 20 : 30, weight: .bold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18).padding(.vertical, 10).panel(radius: 18)
        .padding(.top, 8)
        .padding(.horizontal, compact ? 110 : 150) // Clear of the Skip button.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private func answerKeys(width: CGFloat, compact: Bool) -> some View {
        switch practice.answer {
        case let .letters(_, _, tray):
            GameKeyboard(kind: .tray(tray), width: width, onKey: { scene.handleKey($0) }, onBackspace: {})
        case let .choice(_, _, choices):
            HStack(spacing: compact ? 12 : 20) {
                ForEach(choices, id: \.self) { choice in
                    Button(action: tapped {
                        if !scene.choose(choice) { ruledOut.insert(choice) }
                    }) {
                        Text(choice).frame(minWidth: compact ? 64 : 96)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 26 : 36))
                    // A wrong answer fades away, as the tunnels fizz shut in the maths levels.
                    .opacity(ruledOut.contains(choice) ? 0.35 : 1)
                    .disabled(ruledOut.contains(choice))
                }
            }
            .frame(height: KeyMetrics.trayHeight(compact: compact) - 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(Palette.ink.opacity(0.82).ignoresSafeArea(edges: [.bottom, .horizontal]))
        }
    }

    /// The question is also said aloud, like every question in the game.
    private func say(_ item: PracticeQuestion) {
        if model.settings.spokenInstructions { Narrator.shared.say(key: item.speechKey, fallback: item.speech) }
    }

    private func startTutorial() {
        // Skipping the story still breaks the crystal, so the practice makes sense.
        scene.shatter()
        step = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard step == 1 else { return }
            scene.startTutorial()
        }
    }
}
