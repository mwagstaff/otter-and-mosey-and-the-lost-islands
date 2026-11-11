import GameController
import LostIslandsCore
import Observation
import UIKit

/// Which on-screen keys the current question needs.
enum KeyboardKind: Equatable {
    case none
    /// A single row of big letter tiles (compact phones, short answers).
    case tray([Character])
    case qwerty(space: Bool)
    case numbers
}

/// The link between a SpriteKit scene and the SwiftUI controls drawn over it.
/// The scene publishes HUD state here; SwiftUI forwards key presses back.
@Observable
final class GameBridge {
    var completed = 0
    var total = 0
    var combo = 0
    var multiplier = 1
    var score = 0
    /// The question or instruction shown at the top of the screen.
    var caption = ""
    var hintText: String?
    var toast = ""
    var toastID = 0
    var keyboard: KeyboardKind = .none
    /// Friendship Power charge from 0 to 1, or nil when the meter is hidden.
    var friendship: Double?
    var friendshipUses = 0
    /// Lines the scene wants spoken before play continues.
    var dialogue: [DialogueLine] = []
    var dialogueSpeakerName = ""
    @ObservationIgnored var onDialogueDone: (() -> Void)?
    /// Set when the level is over and the celebration should appear.
    var result: LevelResult?
    var speakable = ""
    /// The narrator clip for the current question, if it has one.
    var speakableKey: String?
    /// False when the listen button would be silent for this question.
    var canSpeak = false

    @ObservationIgnored weak var scene: GameScene?
    @ObservationIgnored var onLearnerChanged: ((LearnerModel) -> Void)?

    func showToast(_ text: String) {
        toast = text
        toastID += 1
    }

    func say(_ lines: [DialogueLine], speaker: String = "", then done: @escaping () -> Void) {
        guard !lines.isEmpty else { return done() }
        dialogueSpeakerName = speaker
        onDialogueDone = done
        dialogue = lines
    }

    func finishDialogue() {
        dialogue = []
        let done = onDialogueDone
        onDialogueDone = nil
        done?()
    }

    func key(_ character: Character) { scene?.handleKey(character) }
    func backspace() { scene?.handleBackspace() }
    func hint() { scene?.requestHint() }
    func repeatSpeech() { Narrator.shared.say(key: speakableKey, fallback: speakable) }
}

enum InputDetector {
    static var hasHardwareKeyboard: Bool { GCKeyboard.coalesced != nil }

    static func profile(compact: Bool) -> InputProfile {
        if hasHardwareKeyboard { return .hardware }
        return compact ? .compactTouch : .fullTouch
    }
}
