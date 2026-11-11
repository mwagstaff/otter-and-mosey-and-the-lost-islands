import LostIslandsCore
import SpriteKit
import UIKit

/// A speech bubble with three bouncing dots that appears over a speaker while they talk.
/// It watches `SpeechStage` itself, so any node can carry one.
final class SpeechBadge: SKNode {
    private let role: Speaker
    /// Scaled to pop the badge in and out, so the bubble's own size stays simple.
    private let holder = SKNode()
    private let bubble = SKSpriteNode(texture: Art.speechBubble)
    private var dots: [SKSpriteNode] = []
    private var showing = false
    /// Called about 30 times a second with the stage and whether this badge's owner is speaking.
    var onTick: ((SpeechStage, Bool) -> Void)?

    init(role: Speaker, width: CGFloat) {
        self.role = role
        super.init()
        zPosition = 70
        addChild(holder)
        bubble.anchorPoint = CGPoint(x: 0.3, y: 0)
        holder.addChild(bubble)
        for _ in 0..<3 {
            let dot = SKSpriteNode(texture: Art.circle(diameter: 24, fill: UIColor(hex: "#17B8A6"), stroke: UIColor(hex: "#0E3B43"), lineWidth: 3))
            dot.zPosition = 1
            holder.addChild(dot)
            dots.append(dot)
        }
        resize(width)
        holder.setScale(0)
        isHidden = true
        run(.repeatForever(.sequence([.wait(forDuration: 1.0 / 30), .run { [weak self] in self?.tick() }])), withKey: "watch")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private var width: CGFloat = 0
    private var beat = 0.0

    func resize(_ newWidth: CGFloat) {
        guard newWidth != width else { return }
        width = newWidth
        bubble.size = CGSize(width: width, height: width * 110 / 132)
        for dot in dots { dot.size = CGSize(width: width * 0.15, height: width * 0.15) }
        placeDots(level: 0)
    }

    /// The dots hop one after another, and all lift a little with the loudness of the voice.
    private func placeDots(level: CGFloat) {
        for (index, dot) in dots.enumerated() {
            let hop = Effects.reducedMotion ? 0 : max(0, sin(beat * 7 - Double(index) * 0.9))
            dot.position = CGPoint(x: width * (CGFloat(index) * 0.21 - 0.02),
                                   y: bubble.size.height * 0.58 + width * (0.05 * CGFloat(hop) + 0.05 * level))
        }
    }

    private func tick() {
        let stage = SpeechStage.shared
        let active = stage.speaker == role
        if active != showing {
            showing = active
            holder.removeAction(forKey: "pop")
            if active {
                isHidden = false
                holder.run(.sequence([.scale(to: 1.15, duration: 0.1), .scale(to: 1, duration: 0.08)]), withKey: "pop")
            } else {
                holder.run(.sequence([.scale(to: 0, duration: 0.12), .run { [weak self] in self?.isHidden = true }]), withKey: "pop")
            }
        }
        if active {
            beat += 1.0 / 30
            placeDots(level: CGFloat(stage.level))
        }
        onTick?(stage, active)
    }
}

/// Otter or Mosey: a painted pose sprite brought to life with code-driven movement
/// (breathing, bobbing, fidgets, jumps and pose changes).
final class CharacterNode: SKNode {
    enum Kind: String { case otter, mosey }
    enum Pose: String { case idle, blink, cheer, think, oops, move }

    let kind: Kind
    private let body = SKNode()
    private let sprite = SKSpriteNode()
    private var accessory: SKSpriteNode?
    private let badge: SpeechBadge
    private var mouthOpen = false
    private var wasSpeaking = false
    private let hasTalkFrame: Bool
    private var unitScale: CGFloat = 1
    private(set) var size: CGFloat
    private(set) var pose: Pose = .idle
    /// The pose the character returns to after a reaction.
    var restPose: Pose = .idle

    var facingLeft = false { didSet { applyFacing() } }

    /// `size` is Otter's standing height, or Mosey's nose-to-tail length.
    init(kind: Kind, size: CGFloat, accessory: String? = nil) {
        self.kind = kind
        self.size = size
        badge = SpeechBadge(role: kind == .otter ? .otter : .mosey, width: size * 0.34)
        hasTalkFrame = Art.hasAsset("\(kind.rawValue)_talk")
        super.init()
        addChild(body)
        addChild(badge)
        badge.onTick = { [weak self] stage, speaking in self?.speech(stage, speaking: speaking) }
        sprite.anchorPoint = kind == .otter ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0.5, y: 0.5)
        body.addChild(sprite)
        if let accessory {
            let hat = SKSpriteNode(texture: Art.emoji(accessory))
            hat.zPosition = 1
            body.addChild(hat)
            self.accessory = hat
        }
        resize(size)
        set(.idle, pop: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Moves the mouth and body with the voice while this character is the one speaking.
    private func speech(_ stage: SpeechStage, speaking: Bool) {
        let open = speaking && stage.mouthOpen && hasTalkFrame
        if open != mouthOpen {
            mouthOpen = open
            // Only the resting pose has a talking frame; reactions keep their own face.
            if pose == .idle { applyTexture() }
        }
        guard speaking || wasSpeaking else { return }
        wasSpeaking = speaking
        if !Effects.reducedMotion, body.action(forKey: "pop") == nil {
            body.yScale = speaking ? 1 + 0.035 * CGFloat(stage.level) : 1
        }
    }

    private func textureName(_ pose: Pose) -> String {
        if pose == .idle, mouthOpen { return "\(kind.rawValue)_talk" }
        let suffix = pose == .move ? (kind == .otter ? "run" : "swim") : pose.rawValue
        return "\(kind.rawValue)_\(suffix)"
    }

    func resize(_ newSize: CGFloat) {
        size = newSize
        let idle = Art.texture(textureName(.idle)).size()
        unitScale = kind == .otter ? newSize / idle.height : newSize / idle.width
        applyTexture()
    }

    private func applyTexture() {
        let texture = Art.texture(textureName(pose))
        sprite.texture = texture
        sprite.size = CGSize(width: texture.size().width * unitScale, height: texture.size().height * unitScale)
        applyFacing()
        let side: CGFloat = facingLeft ? -1 : 1
        badge.resize(max(size * (kind == .otter ? 0.52 : 0.36), 50))
        badge.position = kind == .otter
            ? CGPoint(x: side * size * 0.12, y: sprite.size.height * 0.98)
            : CGPoint(x: side * sprite.size.width * 0.3, y: sprite.size.height * 0.36)
        guard let accessory else { return }
        accessory.size = CGSize(width: size * 0.3, height: size * 0.3)
        if kind == .otter {
            accessory.position = CGPoint(x: side * size * 0.04, y: sprite.size.height * 0.97)
        } else {
            accessory.position = CGPoint(x: side * sprite.size.width * 0.3, y: sprite.size.height * 0.38)
        }
        accessory.isHidden = pose == .move && kind == .otter
    }

    private func applyFacing() {
        sprite.xScale = facingLeft ? -abs(sprite.xScale) : abs(sprite.xScale)
    }

    func set(_ newPose: Pose, pop: Bool = true) {
        guard newPose != pose || sprite.texture == nil else { return }
        pose = newPose
        applyTexture()
        if pop, !Effects.reducedMotion {
            body.removeAction(forKey: "pop")
            body.setScale(0.93)
            body.run(.scale(to: 1, duration: 0.14), withKey: "pop")
        }
    }

    /// Starts the gentle always-on movement and occasional fidgets.
    func startIdle() {
        sprite.removeAction(forKey: "breathe")
        removeAction(forKey: "fidget")
        guard !Effects.reducedMotion else { return }
        if kind == .otter {
            let breathe = SKAction.sequence([.scaleY(to: 1.03, duration: 1.1), .scaleY(to: 1.0, duration: 1.1)]).eased()
            sprite.run(.repeatForever(breathe), withKey: "breathe")
        } else {
            let bob = SKAction.sequence([
                .group([.moveBy(x: 0, y: size * 0.035, duration: 1.3), .rotate(toAngle: 0.035, duration: 1.3)]),
                .group([.moveBy(x: 0, y: -size * 0.035, duration: 1.3), .rotate(toAngle: -0.035, duration: 1.3)]),
            ]).eased()
            sprite.run(.repeatForever(bob), withKey: "breathe")
        }
        let fidget = SKAction.sequence([
            .wait(forDuration: 5, withRange: 4),
            .run { [weak self] in self?.fidget() },
        ])
        run(.repeatForever(fidget), withKey: "fidget")
    }

    private func fidget() {
        guard pose == restPose, restPose == .idle else { return }
        // Otter scratches his head; Mosey gives a happy blink.
        react(kind == .otter && Bool.random() ? .think : .blink, hold: 1.1)
    }

    /// Shows a pose briefly and then settles back.
    func react(_ reaction: Pose, hold: TimeInterval = 1.0) {
        removeAction(forKey: "react")
        set(reaction)
        run(.sequence([.wait(forDuration: hold), .run { [weak self] in
            guard let self else { return }
            self.set(self.restPose)
        }]), withKey: "react")
    }

    func celebrate() {
        react(.cheer, hold: 1.2)
        guard !Effects.reducedMotion else { return }
        body.removeAction(forKey: "jump")
        body.position = .zero
        let up = SKAction.moveBy(x: 0, y: size * 0.22, duration: 0.2)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -size * 0.22, duration: 0.2)
        down.timingMode = .easeIn
        body.run(.sequence([up, down, up, down]), withKey: "jump")
    }

    func oops() {
        react(.oops, hold: 0.9)
        if !Effects.reducedMotion { body.run(.wobble(distance: size * 0.03)) }
    }

    func think() { react(.think, hold: 1.4) }
}
