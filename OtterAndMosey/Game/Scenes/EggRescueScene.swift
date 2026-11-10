import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode D. Something is locked away (a dragon egg, a treasure chest, a sweet jar).
/// Typing the answer on the number pad cracks it open and a new friend pops out to join
/// the rescued row. Recall, not multiple choice.
final class EggRescueScene: GameScene {
    private var container: SKSpriteNode?
    private var sign: SKSpriteNode?
    private var entryBoxes: [SKSpriteNode] = []
    private var entry = ""
    private var rescued: [SKSpriteNode] = []
    private var busy = false

    override func build() {
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
    }

    private var containerSize: CGFloat { min(play.height * 0.46, 220) }
    private var containerHome: CGPoint { CGPoint(x: play.midX, y: groundY + containerSize * 0.5) }
    private var signPosition: CGPoint { CGPoint(x: play.midX, y: play.maxY - play.height * 0.1) }
    private var friendSize: CGFloat { min(play.height * 0.15, 64) }

    private func perch(_ index: Int) -> CGPoint {
        // Rescued friends line up along the top-left, wrapping under if there are many.
        let perRow = max(Int((play.width * 0.3) / (friendSize * 1.05)), 3)
        return CGPoint(x: play.minX + friendSize * 0.7 + CGFloat(index % perRow) * friendSize * 1.05,
                       y: play.maxY - friendSize * 0.7 - CGFloat(index / perRow) * friendSize * 1.05)
    }

    override func layout() {
        otter.resize(min(play.height * 0.4, 180))
        mosey.resize(min(play.height * 0.56, 260))
        otter.position = CGPoint(x: play.midX - containerSize * 1.15, y: groundY)
        mosey.position = CGPoint(x: play.midX + containerSize * 1.3, y: groundY + mosey.size * 0.24)
        container?.position = containerHome
        sign?.position = signPosition
        for (index, friend) in rescued.enumerated() { friend.position = perch(index) }
        layoutEntry()
    }

    override func caption(for question: Question) -> String {
        question.prompt.count <= 22 ? "Type the answer to open it!" : question.prompt
    }

    override func present(_ question: Question) {
        busy = false
        entry = ""
        sign?.removeFromParent()
        let text = question.prompt.count <= 22 ? question.prompt : "?"
        let fontSize = min(play.height * 0.11, 44)
        let board = makeSign(text: text, size: CGSize(width: min(CGFloat(text.count) * fontSize * 0.68 + 56, play.width * 0.6), height: fontSize * 1.7), fontSize: fontSize)
        board.position = signPosition
        board.zPosition = 16
        addChild(board)
        board.setScale(0)
        board.run(.pop())
        sign = board

        container?.removeFromParent()
        let texture = Art.texture(theme.container)
        let scale = containerSize / max(texture.size().width, texture.size().height)
        let node = SKSpriteNode(texture: texture, size: CGSize(width: texture.size().width * scale, height: texture.size().height * scale))
        node.position = CGPoint(x: containerHome.x, y: size.height + containerSize)
        node.zPosition = 12
        addChild(node)
        container = node
        let drop = SKAction.move(to: containerHome, duration: Effects.reducedMotion ? 0.15 : 0.4)
        drop.timingMode = .easeIn
        node.run(.sequence([drop, .scaleX(to: 1.12, y: 0.88, duration: 0.08), .scaleX(to: 1, y: 1, duration: 0.12)]))
        buildEntry(length: question.typingTarget.count)
    }

    // MARK: - Answer boxes

    private func buildEntry(length: Int) {
        entryBoxes.forEach { $0.removeFromParent() }
        entryBoxes = []
        let side = min(play.height * 0.17, 66)
        for _ in 0..<length {
            let box = makeSign(text: "", size: CGSize(width: side, height: side * 1.1), fontSize: side * 0.7, radius: 10)
            box.zPosition = 18
            addChild(box)
            entryBoxes.append(box)
        }
        layoutEntry()
    }

    private func layoutEntry() {
        guard let first = entryBoxes.first else { return }
        let step = first.size.width * 1.12
        for (index, box) in entryBoxes.enumerated() {
            box.position = CGPoint(x: containerHome.x + (CGFloat(index) - CGFloat(entryBoxes.count - 1) / 2) * step,
                                   y: containerHome.y - containerSize * 0.08)
        }
    }

    private func showEntry() {
        let digits = Array(entry)
        for (index, box) in entryBoxes.enumerated() {
            signLabel(box)?.string = index < digits.count ? String(digits[index]) : ""
        }
    }

    override func handleKey(_ character: Character) {
        guard let question = current, !busy, character.isNumber, entry.count < question.typingTarget.count else { return }
        entry.append(character)
        showEntry()
        AudioManager.shared.play(.key, volume: 0.6)
        Haptics.shared.tap()
        guard entry.count == question.typingTarget.count else { return }
        if question.isCorrect(typed: entry) {
            busy = true
            hatch()
        } else {
            busy = true
            container?.run(.wobble(distance: 10))
            entryBoxes.forEach { $0.run(.wobble(distance: 5)) }
            slip()
            run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in
                self?.entry = ""
                self?.showEntry()
                self?.busy = false
            }]))
        }
    }

    override func handleBackspace() {
        guard !busy, !entry.isEmpty else { return }
        entry.removeLast()
        showEntry()
    }

    private func hatch() {
        guard let node = container else { return }
        let point = node.position
        let outcome = succeed(at: point)
        AudioManager.shared.play(.crack)
        entryBoxes.forEach { $0.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()])) }
        entryBoxes = []
        sign?.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        node.run(.sequence([
            .repeat(.sequence([.rotate(toAngle: 0.14, duration: 0.06), .rotate(toAngle: -0.14, duration: 0.06)]), count: 4),
            .rotate(toAngle: 0, duration: 0.04),
            .run { [weak self] in
                guard let self else { return }
                Effects.rainbowBurst(at: point, in: self, count: 54)
                self.cameraPunch()
                AudioManager.shared.play(.chirp)
            },
            .group([.scale(to: 1.4, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent(),
        ]))
        container = nil

        let friend = SKSpriteNode(texture: Art.texture(theme.friend))
        let texture = friend.texture!.size()
        let big = containerSize * 0.8 / max(texture.width, texture.height)
        friend.size = CGSize(width: texture.width * big, height: texture.height * big)
        friend.position = point
        friend.zPosition = 22
        // Work this out before scaling: a sprite's size follows its scale.
        let small = friendSize / max(friend.size.width, friend.size.height)
        friend.setScale(0)
        addChild(friend)
        let index = rescued.count
        rescued.append(friend)
        friend.run(.sequence([
            .wait(forDuration: 0.55),
            .scale(to: 1.15, duration: 0.18), .scale(to: 1, duration: 0.1),
            .repeat(.sequence([.moveBy(x: 0, y: 16, duration: 0.14), .moveBy(x: 0, y: -16, duration: 0.14)]), count: 2),
            .group([SKAction.move(to: perch(index), duration: 0.45).eased(), .scale(to: small, duration: 0.45)]),
        ]))
        if outcome?.isLevelComplete == true {
            finishLevel(after: 1.8)
        } else {
            run(.sequence([.wait(forDuration: 1.9), .run { [weak self] in self?.askNext() }]))
        }
    }
}
