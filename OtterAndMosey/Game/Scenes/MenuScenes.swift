import LostIslandsCore
import SpriteKit
import UIKit

/// A scene that fills the screen with one painted background and keeps it covering on resize.
class CoverScene: SKScene {
    let cover = SKSpriteNode()
    let greyCover = SKSpriteNode()
    private(set) var isBuilt = false
    var insets = UIEdgeInsets.zero { didSet { if isBuilt, insets != oldValue { layout() } } }

    init(background: String) {
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        cover.texture = Art.texture(background)
        greyCover.texture = Art.greyTexture(background)
        greyCover.alpha = 0
        cover.zPosition = -100
        greyCover.zPosition = -99
        addChild(cover)
        addChild(greyCover)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    var play: CGRect {
        CGRect(x: insets.left, y: insets.bottom, width: max(size.width - insets.left - insets.right, 10),
               height: max(size.height - insets.top - insets.bottom, 10))
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        buildIfReady()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildIfReady()
        if isBuilt { fit(); layout() }
    }

    private func buildIfReady() {
        guard !isBuilt, view != nil, size.width > 100, size.height > 100 else { return }
        isBuilt = true
        fit()
        build()
        layout()
    }

    private func fit() {
        guard let texture = cover.texture?.size() else { return }
        let scale = max(size.width / texture.width, size.height / texture.height)
        for sprite in [cover, greyCover] {
            sprite.size = CGSize(width: texture.width * scale, height: texture.height * scale)
            sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    func build() {}
    func layout() {}
}

/// The animated title screen: the home lagoon with Otter and Mosey, who react when tapped.
final class TitleScene: CoverScene {
    private let otter = CharacterNode(kind: .otter, size: 120)
    private let mosey = CharacterNode(kind: .mosey, size: 200)

    init() { super.init(background: "bg_title") }

    override func build() {
        addChild(Effects.ambient(.sparkles, size: size))
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
        otter.startIdle()
        mosey.startIdle()
        // Light glinting on the lagoon.
        let glints = Effects.ambient(.fireflies, size: CGSize(width: size.width, height: size.height * 0.3))
        glints.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        glints.particleBirthRate = 3
        addChild(glints)
    }

    override func layout() {
        otter.resize(min(play.height * 0.5, 300))
        mosey.resize(min(play.height * 0.72, 420))
        otter.position = CGPoint(x: play.minX + play.width * 0.13, y: play.minY + play.height * 0.04)
        mosey.position = CGPoint(x: play.maxX - play.width * 0.16, y: play.minY + play.height * 0.3)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        for character in [otter, mosey] where character.calculateAccumulatedFrame().contains(point) {
            character.celebrate()
            AudioManager.shared.play(character.kind == .otter ? .jump : .swim)
            Effects.rainbowBurst(at: point, in: self, count: 30)
            Haptics.shared.tap()
            return
        }
        Effects.burst(at: point, colour: .white, count: 10, in: self)
    }
}

/// What the map needs to know about one island.
struct IslandState: Equatable {
    var id: String
    var name: String
    var unlocked: Bool
    var hasCrystal: Bool
    /// 0 = grey, 1 = fully restored.
    var restoration: CGFloat
    var isCurrent: Bool
}

/// The archipelago map. Islands bob on the sea; locked ones are grey, restored ones glow.
final class WorldMapScene: CoverScene {
    var onSelect: ((String) -> Void)?
    private var states: [IslandState] = []
    private var islands: [String: SKNode] = [:]
    private var selected: String?
    private let boat = SKSpriteNode(texture: Art.texture("duo_ride"))
    private let pathLayer = SKNode()

    /// Island positions as fractions of the play area, laid out as a winding voyage.
    private let spots: [CGPoint] = [
        CGPoint(x: 0.11, y: 0.38), CGPoint(x: 0.27, y: 0.7), CGPoint(x: 0.44, y: 0.36),
        CGPoint(x: 0.6, y: 0.7), CGPoint(x: 0.76, y: 0.38), CGPoint(x: 0.9, y: 0.72),
    ]

    init() { super.init(background: "bg_map") }

    func configure(_ states: [IslandState]) {
        guard states != self.states else { return }
        self.states = states
        if isBuilt { rebuild() }
    }

    override func build() {
        addChild(pathLayer)
        boat.zPosition = 30
        addChild(boat)
        let glints = Effects.ambient(.sparkles, size: size)
        glints.particleBirthRate = 4
        addChild(glints)
        for index in 0..<3 {
            let cloud = SKSpriteNode(texture: Art.emoji("☁️", size: 160), size: CGSize(width: 150, height: 150))
            cloud.alpha = 0.5
            cloud.zPosition = 40
            cloud.position = CGPoint(x: CGFloat(index) * size.width * 0.4, y: size.height * (0.55 + 0.15 * CGFloat(index)))
            cloud.name = "cloud"
            addChild(cloud)
            if !Effects.reducedMotion {
                let drift = SKAction.sequence([.moveBy(x: size.width * 1.2, y: 0, duration: 70 + Double(index) * 20), .moveBy(x: -size.width * 1.2, y: 0, duration: 0)])
                cloud.run(.repeatForever(drift))
            }
        }
        rebuild()
    }

    private func point(_ index: Int) -> CGPoint {
        let spot = spots[index % spots.count]
        return CGPoint(x: play.minX + play.width * spot.x, y: play.minY + play.height * spot.y)
    }

    private var islandSize: CGFloat { min(play.width * 0.17, play.height * 0.44) }

    private func rebuild() {
        islands.values.forEach { $0.removeFromParent() }
        islands = [:]
        pathLayer.removeAllChildren()
        for (index, state) in states.enumerated() {
            let node = SKNode()
            node.name = state.id
            let art = "island_\(state.id)"
            let texture = Art.texture(art).size()
            let spriteSize = CGSize(width: islandSize, height: islandSize * texture.height / texture.width)
            let colour = SKSpriteNode(texture: Art.texture(art), size: spriteSize)
            let grey = SKSpriteNode(texture: Art.greyTexture(art), size: spriteSize)
            grey.alpha = state.unlocked ? 1 - state.restoration : 1
            grey.zPosition = 1
            node.addChild(colour)
            node.addChild(grey)
            if state.hasCrystal {
                let glow = SKSpriteNode(texture: Art.glow, size: CGSize(width: islandSize * 1.5, height: islandSize * 1.5))
                glow.color = UIColor(hex: Catalog.shared.island(state.id)?.colour ?? "#FFFFFF")
                glow.colorBlendFactor = 1
                glow.blendMode = .add
                glow.alpha = 0.55
                glow.zPosition = -1
                node.addChild(glow)
                let gem = SKSpriteNode(texture: Art.emoji("💎"), size: CGSize(width: islandSize * 0.26, height: islandSize * 0.26))
                gem.position = CGPoint(x: spriteSize.width * 0.36, y: spriteSize.height * 0.4)
                gem.zPosition = 3
                node.addChild(gem)
            }
            if !state.unlocked {
                let lock = SKSpriteNode(texture: Art.emoji("🔒"), size: CGSize(width: islandSize * 0.34, height: islandSize * 0.34))
                lock.zPosition = 3
                node.addChild(lock)
            }
            let fontSize = max(12, islandSize * 0.11)
            let plateSize = CGSize(width: CGFloat(state.name.count) * fontSize * 0.62 + 22, height: fontSize * 1.9)
            let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: "#FFF6E0"), radius: 10, lineWidth: 3), size: plateSize)
            plate.position = CGPoint(x: 0, y: -spriteSize.height * 0.56)
            plate.zPosition = 4
            let label = GameLabel(state.name, size: fontSize, colour: UIColor(hex: "#0E3B43"))
            label.zPosition = 1
            plate.addChild(label)
            node.addChild(plate)
            node.position = point(index)
            node.zPosition = 10
            addChild(node)
            islands[state.id] = node
            if !Effects.reducedMotion {
                let bob = SKAction.sequence([.moveBy(x: 0, y: 6, duration: 1.6 + Double(index) * 0.15), .moveBy(x: 0, y: -6, duration: 1.6 + Double(index) * 0.15)]).eased()
                colour.run(.repeatForever(bob))
                grey.run(.repeatForever(bob))
            }
            if index > 0 {
                // A dotted sea route from the previous island.
                let from = point(index - 1), to = point(index)
                let steps = max(Int(from.distance(to: to) / 26), 2)
                for step in 1..<steps {
                    let fraction = CGFloat(step) / CGFloat(steps)
                    let dot = SKSpriteNode(texture: Art.circle(diameter: 24, fill: .white, stroke: UIColor(hex: "#0E3B43"), lineWidth: 3), size: CGSize(width: 9, height: 9))
                    dot.alpha = state.unlocked ? 0.95 : 0.45
                    dot.position = CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
                    pathLayer.addChild(dot)
                }
            }
        }
        layoutBoat(animated: false)
        if let selected { highlight(selected) }
    }

    override func layout() {
        if !states.isEmpty { rebuild() }
    }

    private func layoutBoat(animated: Bool) {
        guard let index = states.firstIndex(where: { $0.isCurrent }) else {
            boat.isHidden = true
            return
        }
        boat.isHidden = false
        let texture = boat.texture?.size() ?? CGSize(width: 2, height: 1)
        boat.size = CGSize(width: islandSize * 0.62, height: islandSize * 0.62 * texture.height / texture.width)
        let target = CGPoint(x: point(index).x - islandSize * 0.5, y: point(index).y - islandSize * 0.3)
        if animated {
            boat.run(SKAction.move(to: target, duration: 0.8).eased())
        } else {
            boat.position = target
            boat.removeAction(forKey: "bob")
            if !Effects.reducedMotion {
                boat.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 5, duration: 0.9), .moveBy(x: 0, y: -5, duration: 0.9)]).eased()), withKey: "bob")
            }
        }
    }

    private func highlight(_ id: String) {
        for (key, node) in islands {
            node.removeAction(forKey: "select")
            node.run(SKAction.scale(to: key == id ? 1.14 : 1, duration: 0.2).eased(), withKey: "select")
            node.zPosition = key == id ? 12 : 10
        }
    }

    func select(_ id: String?) {
        selected = id
        highlight(id ?? "")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        // Forgiving touch: the nearest island within a generous radius.
        let nearest = islands.min { $0.value.position.distance(to: point) < $1.value.position.distance(to: point) }
        guard let nearest, nearest.value.position.distance(to: point) < islandSize * 0.75 else { return }
        AudioManager.shared.play(.tap)
        Haptics.shared.tap()
        Effects.burst(at: nearest.value.position, colour: .white, count: 12, in: self)
        select(nearest.key)
        onSelect?(nearest.key)
    }
}

/// The opening story: the crystal shatters, the world fades, and one tiny, very easy
/// challenge shows that answers bring the colour back.
final class IntroScene: CoverScene {
    var onTutorialDone: (() -> Void)?
    private let otter = CharacterNode(kind: .otter, size: 120)
    private let mosey = CharacterNode(kind: .mosey, size: 200)
    private let crystal = SKSpriteNode(texture: Art.texture("crystal_whole"))
    private var flower: SKSpriteNode?
    private var bubble: SKNode?
    private var slots: WordSlotsNode?
    private var tutorialActive = false
    static let tutorialLetters: [Character] = ["a", "u", "o", "e", "i", "t"]

    init() { super.init(background: "bg_title") }

    override func build() {
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
        otter.startIdle()
        mosey.startIdle()
        crystal.zPosition = 5
        addChild(crystal)
        if !Effects.reducedMotion {
            crystal.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 8, duration: 1.2), .moveBy(x: 0, y: -8, duration: 1.2)]).eased()), withKey: "float")
        }
    }

    override func layout() {
        otter.resize(min(play.height * 0.44, 260))
        mosey.resize(min(play.height * 0.6, 360))
        otter.position = CGPoint(x: play.minX + play.width * 0.14, y: play.minY + play.height * 0.05)
        mosey.position = CGPoint(x: play.maxX - play.width * 0.17, y: play.minY + play.height * 0.3)
        let texture = crystal.texture?.size() ?? CGSize(width: 1, height: 2)
        let height = min(play.height * 0.42, 240)
        crystal.size = CGSize(width: height * texture.width / texture.height, height: height)
        crystal.position = CGPoint(x: play.midX, y: play.minY + play.height * 0.66)
        flower?.position = flowerPosition
        bubble?.position = CGPoint(x: flowerPosition.x, y: flowerPosition.y + play.height * 0.42)
    }

    private var flowerPosition: CGPoint { CGPoint(x: play.midX, y: play.minY + play.height * 0.08) }

    /// The crystal starts to tremble.
    func rumble() {
        AudioManager.shared.play(.guardian, volume: 0.6)
        otter.react(.oops, hold: 2)
        mosey.react(.oops, hold: 2)
        guard !Effects.reducedMotion else { return }
        crystal.run(.repeatForever(.sequence([.moveBy(x: 5, y: 0, duration: 0.04), .moveBy(x: -10, y: 0, duration: 0.08), .moveBy(x: 5, y: 0, duration: 0.04)])), withKey: "rumble")
    }

    /// The crystal breaks into six fragments that fly away, and the colour drains from the world.
    func shatter() {
        crystal.removeAllActions()
        let centre = crystal.position
        AudioManager.shared.play(.crack)
        AudioManager.shared.play(.whoosh)
        Haptics.shared.crescendo()
        Effects.rainbowBurst(at: centre, in: self, count: 140)
        crystal.run(.sequence([.group([.scale(to: 1.5, duration: 0.12), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
        for (index, island) in Catalog.shared.islands.enumerated() {
            let texture = Art.texture("crystal_shard")
            let shard = SKSpriteNode(texture: texture, size: CGSize(width: 34 * texture.size().width / texture.size().height * 2, height: 68))
            shard.color = UIColor(hex: island.colour)
            shard.colorBlendFactor = 0.6
            shard.position = centre
            shard.zPosition = 20
            addChild(shard)
            let angle = CGFloat(index) / 6 * .pi * 2 + 0.4
            let far = CGPoint(x: centre.x + cos(angle) * size.width, y: centre.y + sin(angle) * size.width)
            shard.run(.sequence([
                .group([SKAction.move(to: far, duration: 1.1), .rotate(byAngle: 9, duration: 1.1)]),
                .removeFromParent(),
            ]))
        }
        greyCover.run(.fadeAlpha(to: 0.92, duration: 2.2))
    }

    /// One grey flower and a word bubble with a single missing letter.
    func startTutorial() {
        tutorialActive = true
        let bloom = SKSpriteNode(texture: Art.emoji("🥀", size: 160), size: CGSize(width: play.height * 0.24, height: play.height * 0.24))
        bloom.anchorPoint = CGPoint(x: 0.5, y: 0)
        bloom.position = flowerPosition
        bloom.zPosition = 10
        bloom.color = .gray
        bloom.colorBlendFactor = 0.8
        addChild(bloom)
        flower = bloom

        let node = SKNode()
        let diameter = min(play.height * 0.46, 220)
        node.addChild(SKSpriteNode(texture: Art.bubble(), size: CGSize(width: diameter * 1.25, height: diameter)))
        let letterWidth = diameter * 0.24
        let plateSize = CGSize(width: letterWidth * 3 + 26, height: letterWidth * 1.75)
        let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: "#FFFDF3"), radius: 16, lineWidth: 3), size: plateSize)
        plate.zPosition = 1
        node.addChild(plate)
        let word = WordSlotsNode(masked: "s_n", answer: "sun", letterWidth: letterWidth, ink: UIColor(hex: "#0E3B43"), accent: UIColor(hex: "#E8743B"))
        word.zPosition = 2
        node.addChild(word)
        slots = word
        node.position = CGPoint(x: flowerPosition.x, y: flowerPosition.y + play.height * 0.42)
        node.zPosition = 15
        node.setScale(0)
        addChild(node)
        node.run(.pop())
        bubble = node
        AudioManager.shared.play(.whoosh, volume: 0.5)
    }

    func handleKey(_ character: Character) {
        guard tutorialActive, let slots else { return }
        if character == "u" || character == "U" {
            tutorialActive = false
            slots.fillNext(with: "u")
            finishTutorial()
        } else {
            // Even here a wrong key is just a friendly wobble.
            slots.flashWrong(character)
            bubble?.run(.wobble())
            AudioManager.shared.play(.wrong, volume: 0.5)
        }
    }

    private func finishTutorial() {
        guard let bubble, let flower else { return }
        AudioManager.shared.play(.correct)
        AudioManager.shared.play(.pop)
        Haptics.shared.success()
        Effects.rainbowBurst(at: bubble.position, in: self, count: 60)
        bubble.run(.sequence([.wait(forDuration: 0.35), .group([.scale(to: 1.4, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        flower.texture = Art.emoji("🌻", size: 160)
        flower.colorBlendFactor = 0
        flower.run(.pop())
        // Colour returns to part of the world: flowers bloom and butterflies appear.
        greyCover.run(.fadeAlpha(to: 0.45, duration: 1.6))
        for index in 0..<10 {
            let x = flowerPosition.x + CGFloat(index - 5) * play.width * 0.05 + CGFloat.random(in: -10...10)
            run(.sequence([.wait(forDuration: 0.1 * Double(index)), .run { [weak self] in
                guard let self else { return }
                Effects.bloom(["🌸", "🌼", "🌷", "🌺"].randomElement()!, at: CGPoint(x: x, y: self.flowerPosition.y + .random(in: -6...10)), size: self.play.height * 0.1, in: self)
            }]))
        }
        for index in 0..<4 {
            let butterfly = SKSpriteNode(texture: Art.emoji("🦋"), size: CGSize(width: 40, height: 40))
            butterfly.position = flowerPosition
            butterfly.zPosition = 25
            addChild(butterfly)
            let target = CGPoint(x: flowerPosition.x + CGFloat(index - 2) * 110 + 50, y: flowerPosition.y + play.height * (0.35 + 0.1 * CGFloat(index % 2)))
            butterfly.run(.sequence([.wait(forDuration: 0.5 + 0.2 * Double(index)), SKAction.move(to: target, duration: 1.4).eased()]))
            if !Effects.reducedMotion {
                butterfly.run(.repeatForever(.sequence([.scaleX(to: 0.5, duration: 0.15), .scaleX(to: 1, duration: 0.15)])))
            }
        }
        otter.celebrate()
        mosey.celebrate()
        run(.sequence([.wait(forDuration: 2.2), .run { [weak self] in self?.onTutorialDone?() }]))
    }
}
