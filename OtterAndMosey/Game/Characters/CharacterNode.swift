import SpriteKit
import UIKit

/// Otter or Mosey: a painted pose sprite brought to life with code-driven movement
/// (breathing, bobbing, fidgets, jumps and pose changes).
final class CharacterNode: SKNode {
    enum Kind: String { case otter, mosey }
    enum Pose: String { case idle, blink, cheer, think, oops, move }

    let kind: Kind
    private let body = SKNode()
    private let sprite = SKSpriteNode()
    private var accessory: SKSpriteNode?
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
        super.init()
        addChild(body)
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

    private func textureName(_ pose: Pose) -> String {
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
        guard let accessory else { return }
        let side: CGFloat = facingLeft ? -1 : 1
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
