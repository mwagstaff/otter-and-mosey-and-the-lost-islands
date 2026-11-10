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
                            Button("▶  Continue", action: tapped { model.continueGame() })
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 26 : 36, minWidth: compact ? 250 : 320))
                            Button("🗺  World map", action: tapped { model.play() })
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 19 : 26, minWidth: compact ? 210 : 270))
                        } else {
                            Button("▶  Play", action: tapped { model.play() })
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
                                Text(model.profile?.avatar ?? "🙂")
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
    @State private var favourite = "otter"
    @State private var deleting: Profile?
    @FocusState private var nameFocused: Bool
    private let avatars = ["🦦", "🐬", "🐢", "🦀", "🐲", "🦉", "🦋", "🐰", "⭐️", "🌈", "🚀", "🎨"]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 8 : 18) {
                    HStack {
                        RoundButton(symbol: "chevron.left", label: "Back") { model.route = .title }
                        Spacer()
                        Text(adding ? "New explorer" : "Who is playing?").font(.game(compact ? 28 : 42)).foregroundStyle(.white).shadow(radius: 4)
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
                            Text(profile.avatar).font(.system(size: compact ? 50 : 76))
                            Text(profile.nickname).font(.game(compact ? 20 : 26)).foregroundStyle(Palette.ink)
                            HStack(spacing: 10) {
                                Text("⭐️ \(profile.totalStars)")
                                Text("💎 \(profile.crystals.count)/6")
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
                Text(avatar).font(.system(size: compact ? 40 : 56))
                TextField("Nickname", text: $nickname)
                    .font(.game(compact ? 24 : 32))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 6 : 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 3)))
                    .frame(maxWidth: 340)
                    .onChange(of: nickname) { _, value in if value.count > 12 { nickname = String(value.prefix(12)) } }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(avatars, id: \.self) { choice in
                        Button(action: tapped { avatar = choice }) {
                            Text(choice).font(.system(size: compact ? 30 : 40))
                                .frame(width: compact ? 52 : 64, height: compact ? 52 : 64)
                                .background(Circle().fill(choice == avatar ? Palette.gold : .white).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            HStack(spacing: 14) {
                Text("My favourite:").font(.game(compact ? 17 : 22)).foregroundStyle(Palette.ink)
                ForEach(["otter", "mosey"], id: \.self) { who in
                    Button(action: tapped { favourite = who }) {
                        HStack(spacing: 6) {
                            Image("\(who)_idle").resizable().scaledToFit().frame(height: compact ? 44 : 64)
                            Text(who.capitalized).font(.game(compact ? 17 : 22)).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(favourite == who ? Palette.gold : .white).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                if !model.save.profiles.isEmpty {
                    Button("Cancel", action: tapped { adding = false }).buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 22))
                }
                Button("Let's go! ▶", action: tapped {
                    nameFocused = false
                    model.createProfile(nickname: nickname, avatar: avatar, favourite: favourite)
                    adding = false
                    nickname = ""
                    model.play()
                })
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 28, minWidth: 200))
            }
        }
        .padding(compact ? 14 : 28)
        .panel()
        .frame(maxWidth: 760)
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
                SceneBackdrop(scene: scene, extraBottom: step == 1 ? KeyMetrics.trayHeight(compact: compact) + 14 : (compact ? 96 : 150))
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
                            Button("Skip ⏭", action: tapped { model.finishIntro() })
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
            scene.onTutorialDone = { step = 2 }
        }
    }

    private func startTutorial() {
        // Skipping the story still breaks the crystal, so the tutorial makes sense.
        scene.shatter()
        step = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { scene.startTutorial() }
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
                    Button("🗺  Keep exploring", action: tapped { model.route = .map })
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
