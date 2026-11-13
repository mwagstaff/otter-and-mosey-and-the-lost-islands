import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode F. The island's guardian is muddled, grumpy or lonely rather than dangerous.
/// Right answers charge the Friendship Power meter; when it is full, Otter and Mosey
/// perform a joint special move. Three rounds win the guardian over and reveal the crystal fragment.
final class GuardianScene: GameScene {
    private let guardian = SKSpriteNode()
    private var sign: SKSpriteNode?
    private var slots: WordSlotsNode?
    private var orbs: [SKSpriteNode] = []
    private var typedIndex = 0
    private var phase = 0
    private var charge = 0.0
    private var powerButton: SKSpriteNode?
    private var crystal: SKSpriteNode?
    private var acceptingAnswers = false
    private let guardianBadge = SpeechBadge(role: .guardian, width: 80)

    private var perPhase: Double { max(1, Double(session.total) / 3) }

    override func build() {
        addChild(otter)
        addChild(mosey)
        guardian.texture = Art.texture(theme.guardian)
        guardian.anchorPoint = CGPoint(x: 0.5, y: 0)
        guardian.zPosition = 9
        addChild(guardian)
        addChild(guardianBadge)
        bridge.friendship = 0
        if !Effects.reducedMotion {
            guardian.run(.repeatForever(SKAction.sequence([.scaleY(to: 1.03, duration: 1.4), .scaleY(to: 1, duration: 1.4)]).eased()))
        }
    }

    private var guardianHeight: CGFloat { min(play.height * 0.74, 520) }
    private var signPosition: CGPoint { CGPoint(x: play.minX + play.width * 0.5, y: play.maxY - play.height * 0.16) }
    private var orbSize: CGFloat { min(play.height * 0.3, 170) }

    override func layout() {
        let texture = guardian.texture?.size() ?? CGSize(width: 1, height: 1)
        guardian.size = CGSize(width: guardianHeight * texture.width / texture.height, height: guardianHeight)
        guardian.position = CGPoint(x: play.maxX - max(guardian.size.width * 0.52, play.width * 0.14), y: groundY)
        guardianBadge.resize(min(max(play.height * 0.22, 56), 120))
        guardianBadge.position = CGPoint(x: guardian.position.x - guardian.size.width * 0.42, y: guardian.position.y + guardian.size.height * 0.78)
        otter.resize(min(play.height * 0.36, 250))
        mosey.resize(min(play.height * 0.46, 330))
        otter.position = CGPoint(x: play.minX + play.width * 0.1, y: groundY)
        mosey.position = CGPoint(x: play.minX + play.width * 0.2, y: groundY + play.height * 0.27)
        sign?.position = signPosition
        layoutOrbs()
    }

    override func start() {
        AudioManager.shared.play(.guardian)
        bridge.say([options.island.guardian.phases[0]], speaker: options.island.guardian.name) { [weak self] in self?.askNext() }
    }

    // MARK: - Questions

    override func caption(for question: Question) -> String {
        if question.skill.subject == .spelling { return question.prompt }
        return question.prompt.count <= 22 ? "Tap the right answer to charge Friendship Power!" : question.prompt
    }

    override func present(_ question: Question) {
        typedIndex = 0
        acceptingAnswers = false
        clearQuestion()

        // The guardian lobs a harmless muddle that becomes the question.
        let muddle = SKSpriteNode(texture: Art.emoji("🌀"), size: CGSize(width: 44, height: 44))
        muddle.position = CGPoint(x: guardian.position.x - guardian.size.width * 0.3, y: guardian.position.y + guardian.size.height * 0.6)
        muddle.zPosition = 30
        addChild(muddle)
        guardian.run(.sequence([.rotate(toAngle: 0.06, duration: 0.1), .rotate(toAngle: 0, duration: 0.15)]))
        AudioManager.shared.play(.whoosh, volume: 0.5)
        muddle.run(.sequence([
            .group([SKAction.move(to: signPosition, duration: Effects.reducedMotion ? 0.15 : 0.45).eased(), .rotate(byAngle: 6, duration: 0.45)]),
            .removeFromParent(),
            .run { [weak self] in self?.reveal(question) },
        ]))
    }

    private func reveal(_ question: Question) {
        acceptingAnswers = true
        let fontSize = min(play.height * 0.1, 56)
        if question.format == .typed {
            let masked = question.masked ?? String(repeating: "_", count: question.typingTarget.count)
            let letterWidth = min(fontSize * 0.95, play.width * 0.5 / CGFloat(masked.count))
            let boardSize = CGSize(width: CGFloat(masked.count) * letterWidth + 40, height: letterWidth * 1.9)
            let board = makeSign(text: "", size: boardSize, fontSize: fontSize)
            let word = WordSlotsNode(masked: masked, answer: question.answer, letterWidth: letterWidth,
                                     ink: options.settings.highContrast ? .black : UIColor(hex: "#0E3B43"), accent: UIColor(hex: "#E8743B"))
            word.zPosition = 2
            board.addChild(word)
            slots = word
            show(board)
            if question.flashThenHide { word.flashWord(for: 2.6) }
        } else {
            let text = question.prompt.count <= 22 ? question.prompt : "?"
            let board = makeSign(text: text, size: CGSize(width: min(CGFloat(text.count) * fontSize * 0.7 + 56, play.width * 0.5), height: fontSize * 1.8), fontSize: fontSize)
            show(board)
            for choice in question.choices {
                let orb = SKSpriteNode(texture: Art.circle(diameter: 160, fill: theme.tint.mixed(with: .white, amount: 0.25)), size: CGSize(width: orbSize, height: orbSize))
                orb.name = choice
                orb.zPosition = 22
                let label = GameLabel(choice, size: orbSize * (choice.count > 3 ? 0.28 : 0.4), colour: .white)
                label.zPosition = 1
                orb.addChild(label)
                orb.setScale(0)
                addChild(orb)
                orbs.append(orb)
                orb.run(.sequence([.wait(forDuration: 0.07 * Double(orbs.count)), .pop()]))
            }
            layoutOrbs()
        }
    }

    private func show(_ board: SKSpriteNode) {
        board.position = signPosition
        board.zPosition = 21
        board.setScale(0)
        board.run(.pop())
        addChild(board)
        sign = board
    }

    private func layoutOrbs() {
        let count = CGFloat(orbs.count)
        for (index, orb) in orbs.enumerated() {
            orb.position = CGPoint(x: signPosition.x + (CGFloat(index) - (count - 1) / 2) * orbSize * 1.25,
                                   y: signPosition.y - play.height * 0.36)
        }
    }

    private func clearQuestion() {
        sign?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        sign = nil
        slots = nil
        orbs.forEach { $0.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()])) }
        orbs = []
    }

    // MARK: - Input

    override func handleKey(_ character: Character) {
        guard acceptingAnswers, let question = current, question.format == .typed, let slots, character.isLetter else { return }
        if question.accepts(character, at: typedIndex) {
            typeNext(character, question: question, slots: slots)
        } else {
            slots.flashWrong(character)
            guardianGiggle()
            slip()
        }
    }

    private func typeNext(_ character: Character, question: Question, slots: WordSlotsNode) {
        slots.fillNext(with: character)
        typedIndex += 1
        AudioManager.shared.play(.key, volume: 0.6)
        if typedIndex >= question.typingTarget.count { answered(at: signPosition) }
    }

    override func applyHint() {
        guard let question = current, question.format == .typed, let slots else { return }
        if question.flashThenHide {
            slots.flashWord(for: 2.2)
        } else {
            let target = Array(question.typingTarget)
            if typedIndex < target.count { typeNext(target[typedIndex], question: question, slots: slots) }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if let crystal, crystal.position.distance(to: point) < max(crystal.size.height, 90) {
            collectCrystal()
            return
        }
        if let powerButton, powerButton.frame.insetBy(dx: -24, dy: -24).contains(point) {
            unleashFriendshipPower()
            return
        }
        guard acceptingAnswers, let question = current, question.format == .choice else { return }
        guard let orb = orbs.filter({ $0.alpha == 1 }).min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
              orb.position.distance(to: point) < orbSize * 0.8, let choice = orb.name else { return }
        if question.isCorrect(choice: choice) {
            orb.run(.pop(to: 1.15))
            answered(at: orb.position)
        } else {
            orb.run(.sequence([.wobble(), .fadeAlpha(to: 0.35, duration: 0.2)]))
            guardianGiggle()
            slip()
        }
    }

    private func guardianGiggle() {
        guard !Effects.reducedMotion else { return }
        guardian.run(.sequence([.rotate(toAngle: 0.05, duration: 0.08), .rotate(toAngle: -0.05, duration: 0.08), .rotate(toAngle: 0, duration: 0.08)]))
    }

    private func answered(at point: CGPoint) {
        acceptingAnswers = false
        let outcome = succeed(at: point)
        charge = min(1, charge + 1 / perPhase)
        bridge.friendship = charge
        // A spark of friendship flies to the heroes each time.
        let spark = SKSpriteNode(texture: Art.emoji("💖"), size: CGSize(width: 36, height: 36))
        spark.position = point
        spark.zPosition = 40
        addChild(spark)
        spark.run(.sequence([SKAction.move(to: CGPoint(x: otter.position.x, y: otter.position.y + otter.size * 0.7), duration: 0.45).eased(), .removeFromParent()]))
        let full = charge >= 0.999 || outcome?.isLevelComplete == true
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in
            guard let self else { return }
            self.clearQuestion()
            if full { self.offerFriendshipPower() } else { self.askNext() }
        }]))
    }

    // MARK: - Friendship Power

    private func offerFriendshipPower() {
        bridge.keyboard = .none
        bridge.friendship = 1
        bridge.caption = "Friendship Power is ready. Tap it!"
        AudioManager.shared.play(.portal)
        let buttonSize = CGSize(width: min(play.width * 0.46, 380), height: min(play.height * 0.24, 96))
        let button = makeSign(text: "Friendship Power!", size: buttonSize, fill: UIColor(hex: "#FF7EB6"), ink: .white, fontSize: buttonSize.height * 0.36)
        signLabel(button)?.colour = .white
        for side: CGFloat in [-1, 1] {
            let hearts = SKSpriteNode(texture: Art.emoji("💞"), size: CGSize(width: buttonSize.height * 0.62, height: buttonSize.height * 0.62))
            hearts.position = CGPoint(x: side * buttonSize.width * 0.5, y: buttonSize.height * 0.34)
            hearts.zRotation = -side * 0.25
            hearts.zPosition = 2
            button.addChild(hearts)
        }
        button.position = CGPoint(x: play.midX, y: play.midY)
        button.zPosition = 50
        button.setScale(0)
        addChild(button)
        button.run(.pop())
        if !Effects.reducedMotion {
            button.run(.repeatForever(SKAction.sequence([.scale(to: 1.07, duration: 0.45), .scale(to: 1, duration: 0.45)]).eased()), withKey: "pulse")
        }
        powerButton = button
    }

    private func unleashFriendshipPower() {
        guard let button = powerButton else { return }
        powerButton = nil
        button.removeAllActions()
        button.run(.sequence([.group([.scale(to: 1.5, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        bridge.friendshipUses += 1
        bridge.caption = "Friendship Power!"
        AudioManager.shared.play(.friendship)
        Haptics.shared.crescendo()
        otter.celebrate()
        mosey.celebrate()

        // Otter and Mosey spin a rainbow between them and send it across to the guardian.
        let from = CGPoint(x: (otter.position.x + mosey.position.x) / 2, y: mosey.position.y)
        let to = CGPoint(x: guardian.position.x, y: guardian.position.y + guardian.size.height * 0.55)
        let beam = Effects.trail()
        beam.particleBirthRate = Effects.reducedMotion ? 40 : 320
        beam.particleLifetime = 0.9
        beam.particleScale = 0.8
        beam.emissionAngleRange = .pi * 2
        beam.particleSpeed = 60
        beam.targetNode = self
        beam.position = from
        beam.zPosition = 45
        addChild(beam)
        let heart = SKSpriteNode(texture: Art.emoji("🌈", size: 128), size: CGSize(width: 80, height: 80))
        heart.zPosition = 46
        beam.addChild(heart)
        let rise = SKAction.move(to: CGPoint(x: from.x + 40, y: play.maxY - 60), duration: 0.35).eased()
        let strike = SKAction.move(to: to, duration: 0.4)
        strike.timingMode = .easeIn
        beam.run(.sequence([
            .group([rise, .rotate(byAngle: .pi * 2, duration: 0.35)]),
            strike,
            .run { [weak self] in self?.guardianReacts(at: to) },
            .run { beam.particleBirthRate = 0 },
            .run { heart.removeFromParent() },
            .wait(forDuration: 1),
            .removeFromParent(),
        ]))
    }

    private func guardianReacts(at point: CGPoint) {
        Effects.rainbowBurst(at: point, in: self, count: 90)
        cameraPunch(scale: 0.93, hold: 0.15)
        AudioManager.shared.play(.guardian)
        let emoji = ["💫", "😂", "💖"][min(phase, 2)]
        Effects.floatPicture(emoji, at: CGPoint(x: point.x, y: point.y + guardian.size.height * 0.35), size: min(play.height * 0.26, 110), in: self)
        if !Effects.reducedMotion {
            guardian.run(.sequence([
                .scaleX(to: 1.15, y: 0.85, duration: 0.1), .scaleX(to: 0.92, y: 1.1, duration: 0.12), .scaleX(to: 1, y: 1, duration: 0.12),
                .repeat(.sequence([.rotate(toAngle: 0.09, duration: 0.09), .rotate(toAngle: -0.09, duration: 0.09)]), count: 3),
                .rotate(toAngle: 0, duration: 0.08),
            ]))
        }
        backdrop.setRestoration(options.startRestoration + (options.endRestoration - options.startRestoration) * CGFloat(phase + 1) / 3 * 0.9)
        bloom(count: 4)
        phase += 1
        charge = 0
        let guardianInfo = options.island.guardian
        run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in
            guard let self else { return }
            self.bridge.friendship = 0
            if self.phase < 3, !self.session.isFinished {
                self.bridge.say([guardianInfo.phases[min(self.phase, guardianInfo.phases.count - 1)]], speaker: guardianInfo.name) { [weak self] in self?.askNext() }
            } else {
                self.befriend()
            }
        }]))
    }

    // MARK: - Ending

    private func befriend() {
        bridge.friendship = nil
        guardian.texture = Art.texture(theme.guardianHappy)
        layout()
        guardian.run(.pop())
        Effects.rainbowBurst(at: CGPoint(x: guardian.position.x, y: guardian.position.y + guardian.size.height * 0.5), in: self, count: 60)
        AudioManager.shared.play(.unlock)
        let info = options.island.guardian
        bridge.say(info.befriended, speaker: info.name) { [weak self] in self?.revealCrystal() }
    }

    private func revealCrystal() {
        let texture = Art.texture("crystal_shard")
        let height = min(play.height * 0.36, 280)
        let shard = SKSpriteNode(texture: texture, size: CGSize(width: height * texture.size().width / texture.size().height, height: height))
        shard.color = UIColor(hex: options.island.colour)
        shard.colorBlendFactor = 0.55
        shard.position = CGPoint(x: guardian.position.x - guardian.size.width * 0.2, y: guardian.position.y + guardian.size.height * 0.6)
        shard.zPosition = 48
        shard.setScale(0.2)
        addChild(shard)
        let home = CGPoint(x: play.midX, y: play.midY)
        shard.run(.group([SKAction.move(to: home, duration: 0.8).eased(), .scale(to: 1, duration: 0.8)]))
        if !Effects.reducedMotion {
            shard.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 10, duration: 0.8), .moveBy(x: 0, y: -10, duration: 0.8)]).eased()))
        }
        let glow = SKSpriteNode(texture: Art.glow, size: CGSize(width: height * 1.7, height: height * 1.7))
        glow.alpha = 0.6
        glow.color = UIColor(hex: options.island.colour)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.zPosition = -1
        shard.addChild(glow)
        crystal = shard
        bridge.caption = "Tap the crystal fragment!"
        AudioManager.shared.play(.portal)
    }

    private func collectCrystal() {
        guard let shard = crystal else { return }
        crystal = nil
        AudioManager.shared.play(.crystal)
        Effects.rainbowBurst(at: shard.position, in: self, count: 120)
        shard.removeAllActions()
        shard.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .rotate(byAngle: .pi, duration: 0.3)]), .group([.scale(to: 0, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        // The whole island floods back to colour under a rainbow.
        let arc = SKSpriteNode(texture: Art.rainbowArc(width: 600), size: CGSize(width: size.width * 0.9, height: size.width * 0.45))
        arc.anchorPoint = CGPoint(x: 0.5, y: 0)
        arc.position = CGPoint(x: size.width / 2, y: groundY)
        arc.zPosition = -50
        arc.alpha = 0
        addChild(arc)
        arc.run(.fadeAlpha(to: 0.7, duration: 1.2))
        bloom(count: 8)
        bridge.caption = "\(options.island.name) is full of colour again!"
        finishLevel(after: 0.5)
    }
}
