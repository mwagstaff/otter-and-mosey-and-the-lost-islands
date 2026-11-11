import Foundation
import LostIslandsCore
import SpriteKit
import Testing
@testable import OtterAndMosey

/// Checks that need the app bundle: bundled art and audio, and the app-level save flow.
/// Run one at a time: several tests use the shared narrator, and would cut each other off.
@MainActor
@Suite(.serialized) struct AppTests {
    @Test func everyArtAssetTheGameNamesIsBundled() {
        var names = ["logo", "bg_title", "bg_map", "bg_ending", "duo_ride", "crystal_whole", "crystal_shard", "pearl", "ring", "cliff"]
        for kind in ["otter", "mosey"] {
            for pose in ["idle", "blink", "cheer", "think", "oops"] { names.append("\(kind)_\(pose)") }
        }
        names += ["otter_run", "mosey_swim", "otter_talk", "mosey_talk"]
        for island in Catalog.shared.islands {
            let theme = IslandTheme.island(island.id)
            names += [theme.background, theme.foreground, theme.guardian, theme.guardianHappy, theme.islandArt, theme.container, theme.friend]
        }
        for name in names { #expect(Art.hasAsset(name), "missing art: \(name)") }
    }

    @Test func everySoundEffectAndMusicTrackIsBundled() {
        for effect in SFX.allCases {
            #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") != nil, "missing sound: \(effect.rawValue)")
        }
        for track in ["music_title", "music_woods", "music_bay", "music_dragon"] {
            #expect(Bundle.main.url(forResource: track, withExtension: "m4a") != nil, "missing music: \(track)")
        }
    }

    @Test func everyNarrationLineHasARecording() {
        let missing = WordBank.narration.keys.filter { Narrator.clipURL($0) == nil }.sorted()
        #expect(missing.isEmpty, "\(missing.count) narrator clips missing, e.g. \(missing.prefix(5))")
        #expect(Narrator.shared.canSay(key: "word_because", fallback: ""))
        Narrator.shared.deviceVoice = false
        #expect(!Narrator.shared.canSay(key: nil, fallback: "anything"), "no recording and no device voice means silence")
    }

    @Test func everyCharacterLineHasARecording() {
        let missing = Catalog.voicedLines.filter { Narrator.clipURL($0.key) == nil }.map(\.value.text).sorted()
        #expect(Catalog.voicedLines.count == 178, "133 for Otter and Mosey, 41 for the guardians, 4 story lines")
        #expect(missing.isEmpty, "\(missing.count) character lines missing a recording, e.g. \(missing.prefix(3))")
    }

    @Test func speakingALineDrivesTheSpeechStage() async throws {
        let stage = SpeechStage.shared
        let voicedLine = Catalog.shared.intro.first { $0.speaker == .otter }!
        #expect(Narrator.clipURL(voicedLine.audioKey ?? "") != nil, "the opening Otter line has a recording")

        // A recorded line: the speaker is set and the mouth moves with the clip.
        Narrator.shared.volume = 0.9
        Narrator.shared.speakLine(voicedLine, voiced: true)
        #expect(stage.speaker == .otter)
        var peak = 0.0
        var opened = false
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(50))
            peak = max(peak, stage.level)
            opened = opened || stage.mouthOpen
        }
        #expect(peak > 0.3 && opened, "level peaked at \(peak)")

        // A line with no recording: the made-up rhythm still marks the speaker, then ends.
        let silent = DialogueLine(speaker: .guardian, text: "Harrumph!")
        Narrator.shared.speakLine(silent, voiced: true)
        #expect(stage.speaker == .guardian)
        opened = false
        for _ in 0..<12 {
            try await Task.sleep(for: .milliseconds(50))
            opened = opened || stage.mouthOpen
        }
        #expect(opened)
        try await Task.sleep(for: .milliseconds(700))
        #expect(stage.speaker == nil && !stage.mouthOpen, "the cue clears when the line is over")

        // Story lines have no speaker to mark.
        Narrator.shared.speakLine(DialogueLine(speaker: .narrator, text: "Once upon a time"), voiced: true)
        #expect(stage.speaker == nil)
        Narrator.shared.stop()
    }

    @Test func progressSurvivesARelaunch() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("app-test-\(UUID().uuidString)")
        let store = SaveStore(directory: directory)
        let first = AppModel(store: store)
        first.createProfile(nickname: "  Pip the Very Long Name ", avatar: "🐬", favourite: "mosey")
        #expect(first.profile?.nickname.count == 12, "nicknames are trimmed and capped")
        first.finishIntro()
        let level = Catalog.shared.level("woods-1")!
        let result = LevelResult(stars: 3, accuracy: 1, score: 600, bestCombo: 6, correctFirstTry: 6, total: 6)
        let summary = first.complete(levelID: level.id, result: result, learner: LearnerModel(), friendshipUses: 0)
        #expect(summary.reward?.id == "pet-firefly")
        first.persistNow()

        let second = AppModel(store: store)
        #expect(second.profile?.stars(for: "woods-1") == 3)
        #expect(second.profile?.seenIntro == true)
        #expect(second.restoration(of: Catalog.shared.island("woods")!) == 0.2)
        second.continueGame()
        #expect(second.route == .island("woods"))
    }

    @Test func trayKeyboardAlwaysContainsTheAnswerLetters() {
        for word in ["u", "au", "because", "international"] {
            let letters = GameScene.trayLetters(for: word)
            #expect(Set(word).isSubset(of: Set(letters)), "\(word)")
            #expect(letters.count <= 10 && Set(letters).count == letters.count)
        }
    }

    @Test func everyModeBuildsASceneAndAsksAQuestion() {
        for id in ["woods-1", "bay-1", "woods-2", "dragon-1", "woods-3", "woods-5"] {
            let level = Catalog.shared.level(id)!
            let island = Catalog.shared.island(containing: id)!
            let bridge = GameBridge()
            let options = SceneOptions(settings: AppSettings(), favourite: .otter, accessory: nil, island: island,
                                       inputProfile: .compactTouch, startRestoration: 0, endRestoration: 0.4)
            let session = ChallengeSession(level: level, learner: LearnerModel(), seed: 3)
            let scene: GameScene
            switch level.mode {
            case .wordBlaster: scene = WordBlasterScene(session: session, bridge: bridge, options: options)
            case .mathsSplash: scene = MathsSplashScene(session: session, bridge: bridge, options: options)
            case .bridgeBuilder: scene = BridgeBuilderScene(session: session, bridge: bridge, options: options)
            case .eggRescue: scene = EggRescueScene(session: session, bridge: bridge, options: options)
            case .typingTurbo: scene = TypingTurboScene(session: session, bridge: bridge, options: options)
            case .guardian: scene = GuardianScene(session: session, bridge: bridge, options: options)
            }
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
            scene.size = view.frame.size
            view.presentScene(scene)
            scene.begin()
            #expect(scene.isBuilt, "\(id)")
            #expect(bridge.total == level.count)
            if level.mode == .guardian {
                #expect(!bridge.dialogue.isEmpty, "guardians open with a line of dialogue")
            } else {
                #expect(scene.current != nil && !bridge.caption.isEmpty, "\(id) should have asked a question")
            }
        }
    }
}
