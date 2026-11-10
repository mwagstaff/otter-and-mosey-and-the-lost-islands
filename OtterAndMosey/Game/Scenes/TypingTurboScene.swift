import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode E. Otter rides Mosey down a scrolling course. Every correct key is a burst of
/// speed; streaks light up a rainbow trail. Accuracy earns the stars: nothing here needs speed.
final class TypingTurboScene: GameScene {
    private let rider = SKSpriteNode(texture: Art.texture("duo_ride"))
    private let trail = Effects.trail()
    private var board: SKSpriteNode?
    private let textLabel = SKLabelNode()
    private var target: [Character] = []
    private var typedIndex = 0
    private var meter = TypingMeter()
    private var streak = 0
    private var wrongFlash = false
    private var pace: CGFloat = 70
    private var lastTime: TimeInterval = 0
    private var bob: CGFloat = 0
    private var finishing = false
    private var flag: SKSpriteNode?

    override var scrollsBackdrop: Bool { true }

    override func build() {
        rider.zPosition = 20
        addChild(rider)
        trail.zPosition = 19
        trail.targetNode = self
        addChild(trail)
        textLabel.verticalAlignmentMode = .center
        textLabel.horizontalAlignmentMode = .center
        textLabel.numberOfLines = 0
        textLabel.zPosition = 1
    }

    private var riderHome: CGPoint { CGPoint(x: play.minX + play.width * 0.26, y: play.minY + play.height * 0.3) }
    private var boardSize: CGSize { CGSize(width: min(play.width * 0.86, 820), height: min(max(play.height * 0.4, 70), 150)) }

    override func layout() {
        let texture = rider.texture?.size() ?? CGSize(width: 2, height: 1)
        let width = min(play.height * 0.75, 330)
        rider.size = CGSize(width: width, height: width * texture.height / texture.width)
        rider.position = riderHome
        board?.position = CGPoint(x: play.midX, y: play.maxY - boardSize.height * 0.58)
    }

    override func caption(for question: Question) -> String {
        options.inputProfile == .hardware ? "Type the words on your keyboard to zoom!" : "Type the words to zoom!"
    }

    override func shouldSpeak(_ question: Question) -> Bool { false }

    override func present(_ question: Question) {
        target = Array(question.typingTarget)
        typedIndex = 0
        meter = TypingMeter()
        board?.removeFromParent()
        let panel = SKSpriteNode(texture: Art.panel(size: boardSize, fill: options.settings.highContrast ? .white : UIColor(hex: "#FFF6E0")), size: boardSize)
        panel.position = CGPoint(x: play.midX, y: play.maxY - boardSize.height * 0.58)
        panel.zPosition = 25
        textLabel.removeFromParent()
        textLabel.preferredMaxLayoutWidth = boardSize.width - 36
        panel.addChild(textLabel)
        addChild(panel)
        panel.setScale(0.8)
        panel.run(.pop())
        board = panel
        render()
    }

    /// Typed letters turn green, the next one sits on a highlight, the rest wait in ink.
    private func render() {
        let count = CGFloat(max(target.count, 1))
        let lines: CGFloat = count > 30 ? 2 : 1
        let fontSize = min(boardSize.height * (lines == 2 ? 0.32 : 0.6), (boardSize.width - 40) * lines / (count * 0.66))
        let font = GameFont.ui(fontSize, weight: .heavy)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSMutableAttributedString()
        let ink = options.settings.highContrast ? UIColor.black : UIColor(hex: "#0E3B43")
        for (index, character) in target.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: GameFont.kerning + 1, .paragraphStyle: paragraph]
            let shown = character == " " && index == typedIndex ? "␣" : String(character)
            if index < typedIndex {
                attributes[.foregroundColor] = UIColor(hex: "#1E9E52")
            } else if index == typedIndex {
                attributes[.foregroundColor] = wrongFlash ? UIColor(hex: "#E8743B") : ink
                attributes[.backgroundColor] = UIColor(hex: "#FFE066")
            } else {
                attributes[.foregroundColor] = ink.withAlphaComponent(0.55)
            }
            text.append(NSAttributedString(string: shown, attributes: attributes))
        }
        textLabel.attributedText = text
    }

    override func handleKey(_ character: Character) {
        guard current != nil, typedIndex < target.count, let question = current else { return }
        let correct = question.accepts(character, at: typedIndex) || (target[typedIndex] == " " && character == " ")
        meter.record(correct: correct)
        if correct {
            typedIndex += 1
            streak += 1
            wrongFlash = false
            pace = min(pace + 60, 560)
            AudioManager.shared.play(.key, volume: 0.55)
            if streak % 10 == 0 {
                Effects.floatText("\(streak) in a row!", at: CGPoint(x: rider.position.x, y: rider.position.y + rider.size.height * 0.7), colour: UIColor(hex: "#FFE066"), in: self)
                AudioManager.shared.play(.combo, volume: 0.7)
            }
            render()
            if typedIndex >= target.count { completeText() }
        } else {
            // A slip costs nothing but the streak. No toast, no fuss: just try the key again.
            streak = 0
            wrongFlash = true
            AudioManager.shared.play(.wrong, volume: 0.35)
            Haptics.shared.nudge()
            rider.run(.wobble(distance: 5))
            render()
        }
    }

    private func completeText() {
        if meter.accuracy < 0.9 { markImperfect() }
        // Speed is only meaningful with a real keyboard; touch typing records accuracy alone.
        let speedSample = options.inputProfile == .hardware ? meter.wordsPerMinute : nil
        session.recordTyping(keystrokes: meter.keystrokes, correct: meter.correct, wordsPerMinute: speedSample)
        let outcome = succeed(at: CGPoint(x: rider.position.x + rider.size.width * 0.3, y: rider.position.y + rider.size.height * 0.4))
        pace = min(pace + 160, 640)
        board?.run(.sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        board = nil
        if outcome?.isLevelComplete == true {
            crossFinishLine()
        } else {
            run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.askNext() }]))
        }
    }

    private func crossFinishLine() {
        finishing = true
        let post = SKSpriteNode(texture: Art.emoji("🏁", size: 160), size: CGSize(width: play.height * 0.4, height: play.height * 0.4))
        post.position = CGPoint(x: size.width + post.size.width, y: riderHome.y + post.size.height * 0.3)
        post.zPosition = 18
        addChild(post)
        flag = post
        AudioManager.shared.play(.victory)
        finishLevel(after: 1.0)
    }

    override func update(_ currentTime: TimeInterval) {
        guard isBuilt else { return }
        let delta = CGFloat(min(lastTime == 0 ? 0 : currentTime - lastTime, 1.0 / 20))
        lastTime = currentTime
        // Speed eases back to a steady cruise, so the ride never stops and never punishes a pause.
        let cruise: CGFloat = finishing ? 240 : 70
        pace += (cruise - pace) * min(delta * 0.9, 1)
        backdrop.scroll(by: pace * delta)
        bob += delta * (2 + pace / 120)
        let lift = Effects.reducedMotion ? 0 : sin(bob) * 6
        let lean = min((pace - 70) / 500, 1)
        rider.position = CGPoint(x: riderHome.x + lean * play.width * 0.1, y: riderHome.y + lift)
        rider.zRotation = lean * 0.08
        trail.position = CGPoint(x: rider.position.x - rider.size.width * 0.42, y: rider.position.y - rider.size.height * 0.1)
        trail.particleBirthRate = pace > 150 ? (Effects.reducedMotion ? 20 : min(pace / 3, 180)) : 0
        if let flag {
            flag.position.x -= pace * 1.4 * delta
            if flag.position.x < -flag.size.width { flag.removeFromParent(); self.flag = nil }
        }
    }
}
