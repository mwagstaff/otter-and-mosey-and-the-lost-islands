import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode C. A canyon blocks the way. Tapping the right answer (or dragging it into the gap) adds a
/// rainbow plank; the last plank completes the bridge under a full rainbow.
final class BridgeBuilderScene: GameScene {
    private let leftCliff = SKSpriteNode(texture: Art.texture("cliff"))
    private let rightCliff = SKSpriteNode(texture: Art.texture("cliff"))
    private var planks: [SKSpriteNode] = []
    private var tiles: [SKSpriteNode] = []
    private var homes: [CGPoint] = []
    private let slot = SKSpriteNode()
    private var sign: SKSpriteNode?
    private var dragging: SKSpriteNode?
    private var dragOffset = CGPoint.zero
    private var dragStart = CGPoint.zero
    private var locked = false

    override func build() {
        backdrop.showsForeground = false
        backdrop.resize(to: size, groundY: 0)
        rightCliff.xScale = -1
        for cliff in [leftCliff, rightCliff] {
            cliff.anchorPoint = CGPoint(x: 0.5, y: 1)
            cliff.zPosition = 10
            addChild(cliff)
        }
        slot.zPosition = 11
        addChild(slot)
        otter.zPosition = 14
        addChild(otter)
        mosey.zPosition = 8
        mosey.restPose = .move
        mosey.set(.move, pop: false)
        addChild(mosey)
    }

    // MARK: - Geometry

    private var deckY: CGFloat { play.minY + play.height * 0.56 }
    private var cliffWidth: CGFloat { play.width * 0.19 }
    private var gapStart: CGFloat { play.minX + cliffWidth * 0.86 }
    private var gapEnd: CGFloat { play.maxX - cliffWidth * 0.86 }
    private var plankSize: CGSize { CGSize(width: (gapEnd - gapStart) / CGFloat(session.total), height: min(play.height * 0.075, 30)) }

    private func plankPosition(_ index: Int) -> CGPoint {
        let fraction = (CGFloat(index) + 0.5) / CGFloat(session.total)
        return CGPoint(x: gapStart + (gapEnd - gapStart) * fraction, y: deckY - plankSize.height / 2 + sin(.pi * fraction) * play.height * 0.045)
    }

    private var tileSize: CGSize { CGSize(width: min(play.width * 0.22, 210), height: min(play.height * 0.2, 84)) }

    override func layout() {
        let texture = leftCliff.texture?.size() ?? CGSize(width: 2, height: 1)
        let cliffSize = CGSize(width: cliffWidth, height: cliffWidth * texture.height / texture.width)
        leftCliff.size = cliffSize
        rightCliff.size = cliffSize
        leftCliff.position = CGPoint(x: play.minX + cliffWidth / 2 - 4, y: deckY + cliffSize.height * 0.12)
        rightCliff.position = CGPoint(x: play.maxX - cliffWidth / 2 + 4, y: deckY + cliffSize.height * 0.12)
        otter.resize(min(play.height * 0.27, 130))
        mosey.resize(min(play.height * 0.3, 150))
        positionHeroes(animated: false)
        for (index, plank) in planks.enumerated() {
            plank.size = plankSize
            plank.position = plankPosition(index)
        }
        slot.texture = Art.panel(size: CGSize(width: 120, height: 40), fill: UIColor.white.withAlphaComponent(0.35), stroke: UIColor(hex: "#FFE066"), radius: 10, lineWidth: 4)
        slot.size = CGSize(width: plankSize.width, height: plankSize.height * 1.3)
        slot.position = plankPosition(min(planks.count, session.total - 1))
        sign?.position = signPosition
    }

    private var signPosition: CGPoint { CGPoint(x: play.midX, y: play.maxY - play.height * 0.1) }

    private func positionHeroes(animated: Bool) {
        let x = planks.isEmpty ? play.minX + cliffWidth * 0.42 : plankPosition(planks.count - 1).x
        let otterTarget = CGPoint(x: x, y: deckY)
        let moseyTarget = CGPoint(x: max(x, play.minX + cliffWidth + mosey.size * 0.4), y: play.minY + play.height * 0.34)
        guard animated else {
            otter.position = otterTarget
            mosey.position = moseyTarget
            return
        }
        otter.set(.move)
        AudioManager.shared.play(.jump, volume: 0.6)
        otter.run(.sequence([SKAction.move(to: otterTarget, duration: 0.45).eased(), .run { [weak self] in self?.otter.celebrate() }]))
        mosey.run(SKAction.move(to: moseyTarget, duration: 0.6).eased())
    }

    // MARK: - Questions

    override func caption(for question: Question) -> String {
        if question.skill.subject == .spelling { return question.prompt }
        return question.prompt.count <= 22 ? "Tap the right answer to fill the gap" : question.prompt
    }

    override func present(_ question: Question) {
        locked = false
        sign?.removeFromParent()
        let text = question.masked ?? (question.skill.subject == .maths && question.prompt.count <= 22 ? question.prompt : "?")
        let fontSize = min(play.height * 0.1, 40)
        let width = min(max(CGFloat(text.count) * fontSize * 0.7 + 50, 120), play.width * 0.6)
        let board = makeSign(text: text, size: CGSize(width: width, height: fontSize * 1.7), fontSize: fontSize)
        board.position = signPosition
        board.zPosition = 16
        board.setScale(0)
        board.run(.pop())
        addChild(board)
        sign = board

        tiles.forEach { $0.removeFromParent() }
        tiles = []
        homes = []
        let count = CGFloat(question.choices.count)
        let spacing = min(play.width / (count + 0.6), tileSize.width * 1.35)
        for (index, choice) in question.choices.enumerated() {
            let tile = makeSign(text: choice, size: tileSize, fill: theme.tint.mixed(with: .white, amount: 0.72), fontSize: tileSize.height * 0.5)
            tile.name = choice
            let home = CGPoint(x: play.midX + (CGFloat(index) - (count - 1) / 2) * spacing, y: play.minY + tileSize.height * 0.72)
            tile.position = CGPoint(x: home.x, y: play.minY - tileSize.height)
            tile.zPosition = 25
            addChild(tile)
            tile.run(.sequence([.wait(forDuration: 0.08 * Double(index)), SKAction.move(to: home, duration: 0.3).eased()]))
            tiles.append(tile)
            homes.append(home)
        }
        slot.isHidden = false
        slot.position = plankPosition(planks.count)
        slot.removeAllActions()
        if !Effects.reducedMotion {
            slot.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        }
    }

    // MARK: - Dragging

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !locked, let point = touches.first?.location(in: self) else { return }
        // Generous hit area: the nearest live tile within reach of the finger.
        let reach = tileSize.width * 0.75
        guard let tile = tiles.filter({ $0.alpha == 1 }).min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
              tile.position.distance(to: point) < reach else { return }
        dragging = tile
        dragStart = point
        dragOffset = CGPoint(x: tile.position.x - point.x, y: tile.position.y - point.y)
        tile.zPosition = 40
        tile.run(.scale(to: 1.1, duration: 0.08))
        AudioManager.shared.play(.tap, volume: 0.6)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tile = dragging, let point = touches.first?.location(in: self) else { return }
        tile.position = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tile = dragging, let point = touches.first?.location(in: self) else { return }
        dragging = nil
        let tapped = point.distance(to: dragStart) < 14
        let nearSlot = tile.position.distance(to: slot.position) < max(plankSize.width, 110)
        if tapped || nearSlot { drop(tile) } else { sendHome(tile) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tile = dragging { sendHome(tile) }
        dragging = nil
    }

    private func sendHome(_ tile: SKSpriteNode) {
        guard let index = tiles.firstIndex(of: tile) else { return }
        tile.zPosition = 25
        tile.run(.group([SKAction.move(to: homes[index], duration: 0.22).eased(), .scale(to: 1, duration: 0.15)]))
    }

    private func drop(_ tile: SKSpriteNode) {
        guard let question = current, let choice = tile.name else { return }
        if question.isCorrect(choice: choice) {
            locked = true
            let index = planks.count
            let target = plankPosition(index)
            slot.isHidden = true
            tile.run(.sequence([
                .group([SKAction.move(to: target, duration: 0.22).eased(), .scale(to: 0.5, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent(),
            ]))
            for other in tiles where other !== tile { other.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])) }
            tiles = []
            if let masked = question.masked, let label = sign.flatMap(signLabel) {
                var letters = Array(question.correctChoice)
                label.string = String(masked.map { $0 == "_" && !letters.isEmpty ? letters.removeFirst() : $0 })
            } else if question.skill == .homophones, let label = sign.flatMap(signLabel) {
                label.string = question.answer
            }
            let plank = SKSpriteNode(texture: Art.rainbowPlank(size: CGSize(width: 120, height: 36)), size: plankSize)
            plank.position = CGPoint(x: target.x, y: target.y + 60)
            plank.alpha = 0
            plank.zPosition = 12
            addChild(plank)
            planks.append(plank)
            let fall = SKAction.move(to: target, duration: 0.22)
            fall.timingMode = .easeIn
            plank.run(.sequence([.wait(forDuration: 0.15), .group([fall, .fadeIn(withDuration: 0.15)]), .run { [weak self] in
                AudioManager.shared.play(.plank)
                self?.cameraPunch()
            }]))
            let outcome = succeed(at: target)
            run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in self?.positionHeroes(animated: true) }]))
            if outcome?.isLevelComplete == true {
                run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.completeBridge() }]))
            } else {
                run(.sequence([.wait(forDuration: 1.5), .run { [weak self] in self?.askNext() }]))
            }
        } else {
            tile.run(.sequence([.wobble(), .group([.fadeAlpha(to: 0.4, duration: 0.2), .scale(to: 1, duration: 0.2)])]))
            sendHome(tile)
            slip()
        }
    }

    /// The spectacular finish: a full rainbow rises over the finished bridge and Otter runs across.
    private func completeBridge() {
        sign?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        let span = gapEnd - gapStart + cliffWidth
        let arc = SKSpriteNode(texture: Art.rainbowArc(width: 600), size: CGSize(width: span, height: span / 2))
        arc.anchorPoint = CGPoint(x: 0.5, y: 0)
        arc.position = CGPoint(x: play.midX, y: deckY - span * 0.08)
        arc.zPosition = 6
        arc.alpha = 0
        arc.setScale(0.6)
        addChild(arc)
        arc.run(.group([.fadeAlpha(to: 0.9, duration: 0.8), SKAction.scale(to: 1, duration: 0.8).eased()]))
        AudioManager.shared.play(.victory)
        for (index, plank) in planks.enumerated() {
            plank.run(.sequence([.wait(forDuration: 0.06 * Double(index)), .moveBy(x: 0, y: 12, duration: 0.1), .moveBy(x: 0, y: -12, duration: 0.14)]))
            Effects.burst(at: plank.position, colour: Art.rainbow[index % Art.rainbow.count], count: 10, in: self)
        }
        otter.set(.move)
        let far = CGPoint(x: play.maxX - cliffWidth * 0.42, y: deckY)
        otter.run(.sequence([SKAction.move(to: far, duration: 0.9).eased(), .run { [weak self] in self?.otter.celebrate() }]))
        mosey.run(SKAction.moveTo(x: play.maxX - cliffWidth - mosey.size * 0.2, duration: 1.0).eased())
        finishLevel(after: 0.9)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }
}
