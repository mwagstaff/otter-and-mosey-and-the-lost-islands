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
    @State private var scene = TitleScene()
    @State private var logoIn = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                SceneBackdrop(scene: scene)
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
                            HStack(spacing: compact ? 10 : 14) {
                                Button(action: tapped { model.play() }) { IconLabel("World map", emoji: "🗺", size: compact ? 19 : 26) }
                                    .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 19 : 26))
                                TrophiesButton(size: compact ? 19 : 26)
                            }
                        } else {
                            Button(action: tapped { model.play() }) { IconLabel("Play", symbol: "play.fill", size: compact ? 30 : 40) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 30 : 40, minWidth: compact ? 250 : 320))
                        }
                    }
                    .padding(.bottom, compact ? 12 : 44)
                }
                .padding(.top, compact ? 0 : 20)
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        Button(action: tapped { model.route = .profiles }) {
                            HStack(spacing: 6) {
                                Glyph(model.profile?.avatar ?? "🙂", size: compact ? 26 : 34).padding(.vertical, -6)
                                Text(model.profile?.nickname ?? "Players")
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                        Spacer()
                        Button("Grown-ups", action: tapped { model.route = .parent })
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 14 : 18))
                        RoundButton(symbol: "gearshape.fill", size: compact ? 54 : 64, label: "Settings") { model.showSettings = true }
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
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var nickname = ""
    @State private var avatar = "🦦"
    @State private var deleting: Profile?
    /// Shown when "Let's go!" is tapped with no name typed yet.
    @State private var askingForName = false
    /// Goes up by one per wobble; the field wiggles as it animates to the new value.
    @State private var nameWobbles: CGFloat = 0
    @FocusState private var nameFocused: Bool
    private static let nameHint = "What shall we call you? Type your name in the box!"
    private let avatars = ["🦦", "🐬", "🦄", "🦖", "👾", "👻", "👸", "🐢", "🦀", "🐲", "🦉", "🦋", "🐰", "⭐️", "🌈", "🚀", "🎨"]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 8 : 18) {
                    HStack {
                        RoundButton(symbol: "chevron.left", label: "Back") { model.route = .title }
                        Spacer()
                        Text(adding ? "New explorer" : "Who's playing?").font(.game(compact ? 28 : 42)).foregroundStyle(.white).shadow(radius: 4)
                        Spacer()
                        Color.clear.frame(width: 54, height: 54)
                    }
                    if adding || model.save.profiles.isEmpty { form(compact: compact) } else { list(compact: compact) }
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
                Button(action: tapped { adding = true }) {
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

    private func form(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            HStack(spacing: 12) {
                Glyph(avatar, size: compact ? 52 : 72)
                TextField("Nickname", text: $nickname)
                    .font(.game(compact ? 24 : 32))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 6 : 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(askingForName ? Palette.coral : Palette.ink, lineWidth: askingForName ? 4 : 3)))
                    .frame(maxWidth: 340)
                    .modifier(Wobble(wobbles: nameWobbles))
                    .onSubmit(letsGo)
                    .onChange(of: nickname) { _, value in
                        if value.count > 12 { nickname = String(value.prefix(12)) }
                        if askingForName, !value.trimmingCharacters(in: .whitespaces).isEmpty { askingForName = false }
                    }
            }
            if askingForName {
                HStack(spacing: 8) {
                    Image("otter_idle").resizable().scaledToFit().frame(height: compact ? 30 : 40).accessibilityHidden(true)
                    Text(Self.nameHint).font(.game(compact ? 16 : 20)).foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.gold.opacity(0.35)))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(avatars, id: \.self) { choice in
                        Button(action: tapped { avatar = choice }) {
                            Glyph(choice, size: compact ? 40 : 50)
                                .frame(width: compact ? 56 : 68, height: compact ? 56 : 68)
                                .background(Circle().fill(choice == avatar ? Palette.gold : .white).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            HStack(spacing: 12) {
                if !model.save.profiles.isEmpty {
                    Button("Cancel", action: tapped { adding = false; askingForName = false }).buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 22))
                }
                Button(action: tapped(letsGo)) { IconLabel("Let's go!", symbol: "play.fill", size: compact ? 22 : 28, trailing: true) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: 200))
            }
        }
        .padding(compact ? 14 : 28)
        .panel()
        .frame(maxWidth: 760)
    }

    /// Creates the player, or, with no name typed yet, gives the box a friendly wiggle and asks for one.
    private func letsGo() {
        guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Haptics.shared.nudge()
            withAnimation(model.settings.reducedMotion ? nil : .spring(duration: 0.3)) { askingForName = true }
            if !model.settings.reducedMotion {
                withAnimation(.easeInOut(duration: 0.6)) { nameWobbles += 1 }
            }
            nameFocused = true
            AccessibilityNotification.Announcement(Self.nameHint).post()
            return
        }
        nameFocused = false
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

/// The opening story and the one-question tutorial.
struct IntroView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = IntroScene()
    @State private var step = 0 // 0 = story, 1 = tutorial, 2 = after-story

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
                        Text("Tap the missing letter to bring the flower back!")
                            .font(.game(compact ? 20 : 30, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 18).padding(.vertical, 10).panel(radius: 18)
                            .padding(.top, 8)
                        Spacer()
                        GameKeyboard(kind: .tray(IntroScene.tutorialLetters), width: geometry.size.width - 16,
                                     onKey: { scene.handleKey($0) }, onBackspace: {})
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
            scene.onTutorialDone = {
                Narrator.shared.stop()
                step = 2
            }
        }
    }

    private func startTutorial() {
        // Skipping the story still breaks the crystal, so the tutorial makes sense.
        scene.shatter()
        step = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard step == 1 else { return }
            scene.startTutorial()
            // The word is also said aloud, like every spelling question in the game.
            if model.settings.spokenInstructions { Narrator.shared.say(key: "word_sun", fallback: "Sun. The sun is hot and bright.") }
        }
    }
}

/// The reward for restoring all six fragments.
struct EndingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack(alignment: .bottom) {
                VStack(spacing: 8) {
                    Text("The Rainbow Crystal is whole again!").font(.game(compact ? 24 : 38)).foregroundStyle(Palette.ink)
                    Text("Thank you, \(model.profile?.nickname ?? "explorer"). Every island is full of colour because of you.")
                        .font(.game(compact ? 16 : 22, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.8)).multilineTextAlignment(.center)
                    Button(action: tapped { model.route = .map }) { IconLabel("Keep exploring", emoji: "🗺", size: compact ? 20 : 26) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                }
                .padding(compact ? 14 : 24)
                .panel(fill: Palette.cream.opacity(0.94))
                .padding(.bottom, compact ? 10 : 30)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .screenBackground("bg_ending")
        }
        .onAppear { AudioManager.shared.play(.victory) }
    }
}
