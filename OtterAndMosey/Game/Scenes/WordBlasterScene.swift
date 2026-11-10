import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode A. A magical bubble floats up holding a word with letters missing.
/// Typing the right letters pops it.
final class WordBlasterScene: GameScene {
    private var bubble: SKNode?
    private var slots: WordSlotsNode?
    private var typedIndex = 0
    private let driftLayer = SKNode()

    override func build() {
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
        addChild(driftLayer)
        // Small empty bubbles drifting up behind the action.
        let drift = SKEmitterNode()
        drift.particleTexture = Art.bubble(tint: theme.tint.mixed(with: .white, amount: 0.6))
        drift.particleBirthRate = Effects.reducedMotion ? 0.3 : 1.2
        drift.particleLifetime = 9
        drift.particleSpeed = 46
        drift.particleSpeedRange = 20
        drift.emissionAngle = .pi / 2
        drift.emissionAngleRange = 0.35
        drift.particleScale = 0.16
        drift.particleScaleRange = 0.1
        drift.particleAlpha = 0.7
        drift.particleAlphaSpeed = -0.06
        drift.zPosition = 2
        drift.name = "drift"
        driftLayer.addChild(drift)
    }

    override func layout() {
        let height = play.height
        otter.resize(min(height * 0.44, 250))
        mosey.resize(min(height * 0.62, 370))
        otter.position = CGPoint(x: play.minX + play.width * 0.1, y: groundY)
        mosey.position = CGPoint(x: play.maxX - play.width * 0.12, y: groundY + mosey.size * 0.26)
        if let drift = driftLayer.childNode(withName: "drift") as? SKEmitterNode {
            drift.position = CGPoint(x: play.midX, y: play.minY - 20)
            drift.particlePositionRange = CGVector(dx: play.width, dy: 0)
        }
        bubble?.position = bubbleHome
    }

    private var bubbleHome: CGPoint { CGPoint(x: play.midX, y: play.minY + play.height * 0.56) }

    override func present(_ question: Question) {
        typedIndex = 0
        let masked = question.masked ?? String(repeating: "_", count: question.typingTarget.count)
        let count = CGFloat(masked.count)
        let diameter = min(play.height * 0.7, 380)
        let letterWidth = min(diameter * 0.2, play.width * 0.6 / count)
        let width = max(diameter, count * letterWidth + diameter * 0.42)

        let node = SKNode()
        let shell = SKSpriteNode(texture: Art.bubble(tint: theme.tint.mixed(with: .white, amount: 0.55)), size: CGSize(width: width, height: diameter))
        node.addChild(shell)
        let plateSize = CGSize(width: count * letterWidth + 26, height: letterWidth * 1.75)
        let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: "#FFFDF3"), stroke: UIColor(hex: "#0E3B43"), radius: 16, lineWidth: 3), size: plateSize)
        plate.alpha = options.settings.highContrast ? 1 : 0.94
        plate.zPosition = 1
        node.addChild(plate)
        let word = WordSlotsNode(masked: masked, answer: question.answer, letterWidth: letterWidth,
                                 ink: options.settings.highContrast ? .black : UIColor(hex: "#0E3B43"), accent: UIColor(hex: "#E8743B"))
        word.zPosition = 2
        node.addChild(word)
        slots = word

        node.position = CGPoint(x: bubbleHome.x, y: play.minY - diameter)
        node.zPosition = 20
        addChild(node)
        bubble?.removeFromParent()
        bubble = node

        let rise = SKAction.move(to: bubbleHome, duration: Effects.reducedMotion ? 0.2 : 0.7)
        rise.timingMode = .easeOut
        node.run(rise) { [weak node] in
            guard let node, !Effects.reducedMotion else { return }
            // Bubbles wobble gently while they wait.
            let float = SKAction.sequence([.moveBy(x: 0, y: 9, duration: 1.2), .moveBy(x: 0, y: -9, duration: 1.2)]).eased()
            let squish = SKAction.sequence([.scaleX(to: 1.03, y: 0.97, duration: 0.9), .scaleX(to: 0.98, y: 1.02, duration: 0.9)]).eased()
            node.run(.repeatForever(float), withKey: "float")
            shell.run(.repeatForever(squish))
        }
        AudioManager.shared.play(.whoosh, volume: 0.5)
        if question.flashThenHide { word.flashWord(for: 2.6) }
    }

    override func caption(for question: Question) -> String {
        question.flashThenHide ? "Look, then spell it: \(question.prompt)" : question.prompt
    }

    override func handleKey(_ character: Character) {
        guard let question = current, let slots, character.isLetter else { return }
        if question.accepts(character, at: typedIndex) {
            accept(character, question: question, slots: slots)
        } else {
            slots.flashWrong(character)
            bubble?.run(.wobble())
            slip()
        }
    }

    private func accept(_ character: Character, question: Question, slots: WordSlotsNode) {
        slots.fillNext(with: character)
        typedIndex += 1
        AudioManager.shared.play(.key, volume: 0.6)
        Haptics.shared.tap()
        if typedIndex >= question.typingTarget.count { pop() }
    }

    /// A hint fills in the next letter, or shows the whole word again for look-cover-write.
    override func applyHint() {
        guard let question = current, let slots else { return }
        if question.flashThenHide {
            slots.flashWord(for: 2.2)
        } else {
            let target = Array(question.typingTarget)
            if typedIndex < target.count { accept(target[typedIndex], question: question, slots: slots) }
        }
    }

    private func pop() {
        guard let node = bubble else { return }
        let point = node.position
        let outcome = succeed(at: point)
        AudioManager.shared.play(.pop)
        Effects.rainbowBurst(at: point, in: self, count: 48)
        cameraPunch()
        node.removeAllActions()
        node.run(.sequence([.group([.scale(to: 1.35, duration: 0.16), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        bubble = nil
        slots = nil
        if outcome?.isLevelComplete == true {
            finishLevel()
        } else {
            run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in self?.askNext() }]))
        }
    }
}
