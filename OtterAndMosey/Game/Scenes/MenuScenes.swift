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

    private var wildlife: IslandWildlife?

    func setSceneryMotion(_ enabled: Bool) {
        cover.shader = enabled ? RainbowIslandBackdrop.shader(saturation: 1) : nil
        wildlife?.removeFromParent()
        wildlife = nil
        if enabled {
            let layer = IslandWildlife()
            layer.zPosition = 1
            cover.addChild(layer)
            layer.fit(to: cover)
            layer.start()
            wildlife = layer
        }
    }

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
        wildlife?.fit(to: cover)
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
        if let wildlife, wildlife.greet(at: wildlife.convert(point, from: self)) { return }
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

/// The archipelago map: Rainbow Island in the middle with the six islands ringed around it.
/// Islands bob on the sea; locked ones are grey, restored ones glow.
final class WorldMapScene: CoverScene {
    var onSelect: ((String) -> Void)?
    private var states: [IslandState] = []
    private var islands: [String: SKNode] = [:]
    private var selected: String?
    private let boat = SKSpriteNode(texture: Art.texture("duo_ride"))
    private let pathLayer = SKNode()
    private let home = SKNode()

    /// Island positions as fractions of the play area, in a ring around Rainbow Island: up the left,
    /// across the top and down the right, so the voyage circles the player's own island.
    private let spots: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.22), CGPoint(x: 0.16, y: 0.7), CGPoint(x: 0.34, y: 0.8),
        CGPoint(x: 0.66, y: 0.8), CGPoint(x: 0.84, y: 0.7), CGPoint(x: 0.88, y: 0.22),
    ]
    /// The player's own island sits in the middle of the ring.
    private var homeCentre: CGPoint { CGPoint(x: play.midX, y: play.minY + play.height * 0.3) }

    /// The id `onSelect` reports when the player's own island is tapped.
    static let homeID = "home"
    static let homeName = "Rainbow Island"

    init() { super.init(background: "bg_map") }

    func configure(_ states: [IslandState]) {
        guard states != self.states else { return }
        self.states = states
        if isBuilt { rebuild() }
    }

    override func build() {
        addChild(pathLayer)
        home.zPosition = 10
        addChild(home)
        boat.zPosition = 30
        addChild(boat)
        let glints = Effects.ambient(.sparkles, size: size)
        glints.particleBirthRate = 4
        addChild(glints)
        for index in 0..<3 {
            let cloud = SKSpriteNode(texture: Art.emoji("☁️", size: 160), size: CGSize(width: 150, height: 150))
            cloud.alpha = 0.35
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

    private var islandSize: CGFloat { min(play.width * 0.15, play.height * 0.36) }

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
            // Unlocked islands always keep a hint of colour, so they never look like the locked ones.
            grey.alpha = state.unlocked ? 0.7 * (1 - state.restoration) : 1
            grey.zPosition = 1
            node.addChild(colour)
            node.addChild(grey)
            let isNext = state.isCurrent && state.unlocked
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
            // The plate is cut to the measured name, so every typeface gets the same margin.
            let label = GameLabel(state.name, size: fontSize, colour: UIColor(hex: "#0E3B43"))
            let plateSize = CGSize(width: label.frame.width + fontSize * 2.2, height: fontSize * 2.1)
            let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: isNext ? "#FFC83D" : "#FFF6E0"), radius: 10, lineWidth: 3), size: plateSize)
            plate.position = CGPoint(x: 0, y: -spriteSize.height * 0.58)
            plate.zPosition = 4
            label.zPosition = 1
            plate.addChild(label)
            node.addChild(plate)
            if isNext {
                addPlayHereMarker(to: node, spot: spots[index % spots.count], spriteSize: spriteSize, plateBottom: plate.position.y - plateSize.height / 2)
            }
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
        buildHome()
        layoutBoat(animated: false)
        if let selected { highlight(selected) }
    }

    override func layout() {
        if !states.isEmpty { rebuild() }
    }

    /// Rainbow Island, the player's own island, where their decorations, pets and trophy cabinet are.
    /// It is always in full colour and always open, so it is easy to find from the very first visit.
    private func buildHome() {
        home.removeAllChildren()
        home.position = homeCentre
        let texture = Art.texture("island_home")
        let width = islandSize * 1.15
        let spriteSize = CGSize(width: width, height: width * texture.size().height / max(texture.size().width, 1))
        let island = SKSpriteNode(texture: texture, size: spriteSize)
        home.addChild(island)
        let fontSize = max(12, islandSize * 0.11)
        let label = GameLabel(Self.homeName, size: fontSize, colour: UIColor(hex: "#0E3B43"))
        let plateSize = CGSize(width: label.frame.width + fontSize * 2.2, height: fontSize * 2.1)
        let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: "#FFF6E0"), radius: 10, lineWidth: 3), size: plateSize)
        plate.position = CGPoint(x: 0, y: -spriteSize.height * 0.58)
        plate.zPosition = 4
        label.zPosition = 1
        plate.addChild(label)
        home.addChild(plate)
        if !Effects.reducedMotion {
            island.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 6, duration: 1.8), .moveBy(x: 0, y: -6, duration: 1.8)]).eased()))
        }
    }

    /// Picks out the island to play next: a pulsing gold glow and a bouncing "Play here!" sign.
    /// The two bottom corner islands have open sea towards Rainbow Island, so their sign sits beside
    /// them on that side; every other island has its sign under its name, clear of its neighbours.
    private func addPlayHereMarker(to node: SKNode, spot: CGPoint, spriteSize: CGSize, plateBottom: CGFloat) {
        let glow = SKSpriteNode(texture: Art.glow, size: CGSize(width: islandSize * 1.7, height: islandSize * 1.7))
        glow.color = UIColor(hex: "#FFC83D")
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.75
        glow.zPosition = -2
        node.addChild(glow)

        let ink = UIColor(hex: "#0E3B43")
        let fontSize = max(13, islandSize * 0.12)
        let label = GameLabel("Play here!", size: fontSize, colour: ink)
        label.zPosition = 1
        let signSize = CGSize(width: label.frame.width + fontSize * 1.8, height: fontSize * 2.1)
        let sign = SKSpriteNode(texture: Art.panel(size: signSize, fill: UIColor(hex: "#FFC83D"), stroke: ink, radius: 12, lineWidth: 3), size: signSize)
        sign.addChild(label)
        // A little pointer on the sign's near edge, aimed back at the island.
        let tip = fontSize * 0.7
        let beside = spot.y < 0.5
        // Beside: +1 points the sign right (towards the middle from the left), -1 left.
        let side: CGFloat = spot.x < 0.5 ? 1 : -1
        let path = CGMutablePath()
        if beside {
            path.move(to: CGPoint(x: 0, y: -tip))
            path.addLine(to: CGPoint(x: 0, y: tip))
            path.addLine(to: CGPoint(x: -tip * side, y: 0))
        } else {
            path.move(to: CGPoint(x: -tip, y: 0))
            path.addLine(to: CGPoint(x: tip, y: 0))
            path.addLine(to: CGPoint(x: 0, y: tip))
        }
        path.closeSubpath()
        let pointer = SKShapeNode(path: path)
        pointer.fillColor = UIColor(hex: "#FFC83D")
        pointer.strokeColor = ink
        pointer.lineWidth = 3
        pointer.position = beside ? CGPoint(x: -(signSize.width / 2 - 1.5) * side, y: 0) : CGPoint(x: 0, y: signSize.height / 2 - 1.5)
        pointer.zPosition = -1
        sign.addChild(pointer)

        let marker = SKNode()
        marker.position = beside
            ? CGPoint(x: side * (spriteSize.width * 0.5 + tip + signSize.width * 0.5), y: spriteSize.height * 0.08)
            : CGPoint(x: 0, y: plateBottom - signSize.height * 0.5 - tip)
        marker.zPosition = 6
        marker.addChild(sign)
        node.addChild(marker)

        guard !Effects.reducedMotion else { return }
        glow.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.8), .fadeAlpha(to: 0.95, duration: 0.8)]),
            .group([.scale(to: 0.94, duration: 0.8), .fadeAlpha(to: 0.6, duration: 0.8)]),
        ]).eased()))
        let bounce = beside
            ? SKAction.sequence([.moveBy(x: 8 * side, y: 0, duration: 0.45), .moveBy(x: -8 * side, y: 0, duration: 0.45)])
            : SKAction.sequence([.moveBy(x: 0, y: -8, duration: 0.45), .moveBy(x: 0, y: 8, duration: 0.45)])
        marker.run(.repeatForever(bounce.eased()))
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
        for (key, node) in islands.merging([Self.homeID: home], uniquingKeysWith: { first, _ in first }) {
            node.removeAction(forKey: "select")
            node.run(SKAction.scale(to: key == id ? 1.14 : 1, duration: 0.2).eased(), withKey: "select")
            node.zPosition = key == id ? 12 : 10
        }
    }

    func select(_ id: String?) {
        selected = id
        highlight(id ?? "")
    }

    /// The moment a newly unlocked island comes into play: it is picked out and sparkles.
    func celebrateUnlock(_ id: String) {
        select(id)
        guard let node = islands[id] else { return }
        AudioManager.shared.play(.unlock)
        Haptics.shared.success()
        let colour = UIColor(hex: Catalog.shared.island(id)?.colour ?? "#FFC83D")
        Effects.burst(at: node.position, colour: colour, count: 26, in: self)
        Effects.burst(at: node.position, colour: UIColor(hex: "#FFE066"), count: 18, in: self)
        guard !Effects.reducedMotion else { return }
        node.run(.sequence([SKAction.scale(to: 1.3, duration: 0.25).eased(), SKAction.scale(to: 1.14, duration: 0.3).eased()]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        // Forgiving touch: the nearest island (the player's own one included) within a generous radius.
        let targets = islands.merging([Self.homeID: home], uniquingKeysWith: { first, _ in first })
        let nearest = targets.min { $0.value.position.distance(to: point) < $1.value.position.distance(to: point) }
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
/// One question in the practice round that follows the opening story.
struct PracticeQuestion {
    enum Answer {
        /// Type the missing letters, offered on a one-row tray as in the word levels.
        case letters(masked: String, word: String, tray: [Character])
        /// Tap the right answer from a few choices, as in the maths levels.
        case choice(prompt: String, answer: String, choices: [String])
    }

    var answer: Answer
    /// A picture clue shown above the question.
    var clue: String?
    var instruction: String
    var speechKey: String
    var speech: String
}

final class IntroScene: CoverScene {
    /// The practice round: one missing letter, then two, then a times-tables question to tap.
    /// Each right answer brings a little more colour back.
    static let practice: [PracticeQuestion] = [
        PracticeQuestion(answer: .letters(masked: "s_n", word: "sun", tray: ["a", "u", "o", "e", "i", "t"]), clue: "☀️",
                         instruction: "Tap the missing letter to bring the flower back!",
                         speechKey: "word_sun", speech: "Sun. The sun is hot and bright."),
        PracticeQuestion(answer: .letters(masked: "f__h", word: "fish", tray: ["s", "a", "i", "t", "o", "e"]), clue: "🐟",
                         instruction: "Two letters are missing now. Fill them in one at a time!",
                         speechKey: "word_fish", speech: "Fish. A fish swims in the sea."),
        PracticeQuestion(answer: .choice(prompt: "5 × 2 = ?", answer: "10", choices: ["7", "10", "12"]), clue: nil,
                         instruction: "Now a sum! Tap the right answer.",
                         speechKey: "mul_2x5", speech: "5 times 2."),
    ]

    /// Called as each practice question appears, with its index.
    var onQuestion: ((Int) -> Void)?
    /// Called when a second wrong letter brings up a peek at the whole word.
    var onPeek: (() -> Void)?
    var onTutorialDone: (() -> Void)?
    private let otter = CharacterNode(kind: .otter, size: 120)
    private let mosey = CharacterNode(kind: .mosey, size: 200)
    private let crystal = SKSpriteNode(texture: Art.texture("crystal_whole"))
    private var flower: SKSpriteNode?
    private var bubble: SKNode?
    private var slots: WordSlotsNode?
    private var question = 0
    /// The letters still to fill in the current word, in order.
    private var expected: [Character] = []
    private var slips = 0
    private var started = false
    private var tutorialActive = false

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
        bubble?.position = bubblePosition
    }

    private var flowerPosition: CGPoint { CGPoint(x: play.midX, y: play.minY + play.height * 0.08) }
    private var bubblePosition: CGPoint { CGPoint(x: flowerPosition.x, y: flowerPosition.y + play.height * 0.42) }

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

    /// One grey flower, then the first practice question.
    func startTutorial() {
        guard !started else { return }
        started = true
        let bloom = SKSpriteNode(texture: Art.emoji("🥀", size: 160), size: CGSize(width: play.height * 0.24, height: play.height * 0.24))
        bloom.anchorPoint = CGPoint(x: 0.5, y: 0)
        bloom.position = flowerPosition
        bloom.zPosition = 10
        bloom.color = .gray
        bloom.colorBlendFactor = 0.8
        addChild(bloom)
        flower = bloom
        present(0)
    }

    /// A word bubble for practice question `index`.
    private func present(_ index: Int) {
        question = index
        slips = 0
        let item = Self.practice[index]
        let ink = UIColor(hex: "#0E3B43")
        let node = SKNode()
        let diameter = min(play.height * 0.46, 220)
        node.addChild(SKSpriteNode(texture: Art.bubble(), size: CGSize(width: diameter * 1.25, height: diameter)))
        let letterWidth = diameter * 0.24
        let plateY = item.clue == nil ? 0 : -diameter * 0.12
        switch item.answer {
        case let .letters(masked, word, _):
            let plateSize = CGSize(width: letterWidth * CGFloat(masked.count) + 26, height: letterWidth * 1.75)
            node.addChild(plate(size: plateSize, y: plateY))
            let slots = WordSlotsNode(masked: masked, answer: word, letterWidth: letterWidth, ink: ink, accent: UIColor(hex: "#E8743B"))
            slots.zPosition = 2
            slots.position.y = plateY
            node.addChild(slots)
            self.slots = slots
            expected = zip(masked, word).filter { $0.0 == "_" }.map(\.1)
        case let .choice(prompt, _, _):
            let plateSize = CGSize(width: diameter * 0.95, height: letterWidth * 1.75)
            node.addChild(plate(size: plateSize, y: plateY))
            let label = GameLabel(prompt, size: letterWidth * 0.95, colour: ink, tracking: 0)
            label.fitWidth = plateSize.width - 20
            label.zPosition = 2
            label.position.y = plateY
            node.addChild(label)
            slots = nil
            expected = []
        }
        if let clue = item.clue {
            // A picture clue: without it "s_n" could just as well be "son" or "sin".
            let picture = SKSpriteNode(texture: Art.emoji(clue, size: 160), size: CGSize(width: diameter * 0.3, height: diameter * 0.3))
            picture.position.y = diameter * 0.27
            picture.zPosition = 1
            node.addChild(picture)
        }
        node.position = bubblePosition
        node.zPosition = 15
        node.setScale(0)
        addChild(node)
        node.run(.pop())
        bubble = node
        AudioManager.shared.play(.whoosh, volume: 0.5)
        tutorialActive = true
        onQuestion?(index)
    }

    private func plate(size: CGSize, y: CGFloat) -> SKSpriteNode {
        let plate = SKSpriteNode(texture: Art.panel(size: size, fill: UIColor(hex: "#FFFDF3"), radius: 16, lineWidth: 3), size: size)
        plate.zPosition = 1
        plate.position.y = y
        return plate
    }

    func handleKey(_ character: Character) {
        guard tutorialActive, let slots, let next = expected.first, character.isLetter else { return }
        if Character(character.lowercased()) == next {
            expected.removeFirst()
            slots.fillNext(with: next)
            if expected.isEmpty { complete() } else { AudioManager.shared.play(.pop, volume: 0.5) }
        } else {
            // Even here a wrong key is just a friendly wobble.
            slots.flashWrong(character)
            slip()
        }
    }

    /// Answers the tap-the-answer question. Returns whether `choice` was right.
    func choose(_ choice: String) -> Bool {
        guard tutorialActive, case let .choice(_, answer, _) = Self.practice[question].answer else { return false }
        if choice == answer {
            complete()
            return true
        }
        slip()
        return false
    }

    private func slip() {
        slips += 1
        bubble?.run(.wobble())
        AudioManager.shared.play(.wrong, volume: 0.5)
        // As in the levels, a second slip brings help: here a peek at the whole word.
        if slips == 2, let slots {
            slots.flashWord(for: 1.6)
            onPeek?()
        }
    }

    private func complete() {
        tutorialActive = false
        guard let node = bubble else { return }
        AudioManager.shared.play(.correct)
        AudioManager.shared.play(.pop)
        Haptics.shared.success()
        Effects.rainbowBurst(at: node.position, in: self, count: 60)
        node.run(.sequence([.wait(forDuration: 0.35), .group([.scale(to: 1.4, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        bubble = nil
        slots = nil
        otter.celebrate()
        mosey.celebrate()
        // Colour returns a little more with every answer: a flower, a meadow, then butterflies.
        let last = question == Self.practice.count - 1
        greyCover.run(.fadeAlpha(to: [0.75, 0.6, 0.45][min(question, 2)], duration: 1.6))
        switch question {
        case 0: bloomFlower()
        case 1: bloomMeadow()
        default: releaseButterflies()
        }
        run(.sequence([.wait(forDuration: last ? 2.2 : 1.8), .run { [weak self] in
            guard let self else { return }
            if last { self.onTutorialDone?() } else { self.present(self.question + 1) }
        }]))
    }

    private func bloomFlower() {
        guard let flower else { return }
        flower.texture = Art.emoji("🌻", size: 160)
        flower.colorBlendFactor = 0
        flower.run(.pop())
        for index in 0..<4 {
            let x = flowerPosition.x + CGFloat(index < 2 ? index - 2 : index - 1) * play.width * 0.05
            run(.sequence([.wait(forDuration: 0.1 * Double(index)), .run { [weak self] in
                guard let self else { return }
                Effects.bloom(["🌸", "🌼"].randomElement()!, at: CGPoint(x: x, y: self.flowerPosition.y + .random(in: -6...10)), size: self.play.height * 0.1, in: self)
            }]))
        }
    }

    private func bloomMeadow() {
        for index in 0..<12 {
            let x = play.minX + play.width * (0.08 + 0.84 * CGFloat(index) / 11) + .random(in: -10...10)
            run(.sequence([.wait(forDuration: 0.08 * Double(index)), .run { [weak self] in
                guard let self else { return }
                Effects.bloom(["🌸", "🌼", "🌷", "🌺"].randomElement()!, at: CGPoint(x: x, y: self.flowerPosition.y + .random(in: -6...10)), size: self.play.height * 0.1, in: self)
            }]))
        }
    }

    private func releaseButterflies() {
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
    }
}
