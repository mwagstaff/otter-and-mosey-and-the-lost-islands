import SpriteKit
import UIKit

/// Particle effects built in code so they can follow the reduced-motion setting.
enum Effects {
    /// Set from the accessibility settings. Fewer, calmer particles and no flashes.
    static var reducedMotion = false

    private static func scaled(_ count: Int) -> Int { reducedMotion ? max(4, count / 4) : count }

    /// A one-shot burst of sparkles. Removes itself.
    static func burst(at point: CGPoint, colour: UIColor, count: Int = 28, in parent: SKNode, z: CGFloat = 60) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.sparkle
        emitter.numParticlesToEmit = scaled(count)
        emitter.particleBirthRate = 600
        emitter.particleLifetime = 0.7
        emitter.particleLifetimeRange = 0.4
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 190
        emitter.particleSpeedRange = 120
        emitter.yAcceleration = -260
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.35
        emitter.particleScaleSpeed = -0.4
        emitter.particleAlphaSpeed = -1.1
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 3
        emitter.particleColor = colour
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.position = point
        emitter.zPosition = z
        parent.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))
    }

    /// A burst in every rainbow colour.
    static func rainbowBurst(at point: CGPoint, in parent: SKNode, count: Int = 60) {
        for colour in Art.rainbow { burst(at: point, colour: colour, count: count / Art.rainbow.count, in: parent) }
    }

    /// Confetti falling across the whole scene for a few seconds.
    static func confetti(in scene: SKScene, duration: TimeInterval = 3) {
        guard !reducedMotion else {
            rainbowBurst(at: CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.6), in: scene)
            return
        }
        for colour in Art.rainbow {
            let emitter = SKEmitterNode()
            emitter.particleTexture = Art.confettiPiece
            emitter.particleBirthRate = 14
            emitter.particleLifetime = 4
            emitter.particlePositionRange = CGVector(dx: scene.size.width, dy: 0)
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = 0.5
            emitter.particleSpeed = 150
            emitter.particleSpeedRange = 80
            emitter.yAcceleration = -60
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = 4
            emitter.particleScale = 1
            emitter.particleScaleRange = 0.5
            emitter.particleColor = colour
            emitter.particleColorBlendFactor = 1
            emitter.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 10)
            emitter.zPosition = 90
            scene.addChild(emitter)
            emitter.run(.sequence([.wait(forDuration: duration), .run { emitter.particleBirthRate = 0 }, .wait(forDuration: 4.2), .removeFromParent()]))
        }
    }

    /// Slow drifting motes that make a scene feel alive. Birth rate is scaled by how restored the island is.
    static func ambient(_ kind: IslandTheme.Ambient, size: CGSize) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.glow
        emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.particleLifetime = 5
        emitter.particleLifetimeRange = 2
        emitter.particleAlpha = 0
        emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0.9, 0], times: [0, 0.2, 0.7, 1])
        emitter.particleScale = 0.22
        emitter.particleScaleRange = 0.14
        emitter.particleSpeed = 14
        emitter.particleSpeedRange = 10
        emitter.emissionAngleRange = .pi * 2
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.zPosition = 4
        switch kind {
        case .fireflies:
            emitter.particleColor = UIColor(hex: "#F6FF8A")
        case .bubbles:
            emitter.particleTexture = Art.bubble()
            emitter.particleColorBlendFactor = 0
            emitter.particleBlendMode = .alpha
            emitter.particleScale = 0.07
            emitter.particleScaleRange = 0.05
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = 0.3
            emitter.particleSpeed = 34
        case .embers:
            emitter.particleColor = UIColor(hex: "#FF9A3D")
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = 0.6
            emitter.particleSpeed = 30
            emitter.particleScale = 0.14
        case .sparkles:
            emitter.particleTexture = Art.sparkle
            emitter.particleColor = .white
            emitter.particleScale = 0.3
        case .sprinkles:
            emitter.particleTexture = Art.confettiPiece
            emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: Art.rainbow, times: [0, 0.2, 0.4, 0.6, 0.8, 1])
            emitter.particleBlendMode = .alpha
            emitter.particleScale = 0.7
            emitter.emissionAngle = -.pi / 2
            emitter.particleSpeed = 26
            emitter.particleRotationSpeed = 2
        case .stars:
            emitter.particleTexture = Art.sparkle
            emitter.particleColor = UIColor(hex: "#DCCBFF")
            emitter.particleScale = 0.26
        }
        return emitter
    }

    /// A trailing stream behind something fast.
    static func trail(colours: [UIColor] = Art.rainbow) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Art.glow
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 0.6
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.35
        emitter.particleSpeed = 160
        emitter.particleSpeedRange = 60
        emitter.particleScale = 0.5
        emitter.particleScaleSpeed = -0.6
        emitter.particleAlphaSpeed = -1.4
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: colours, times: colours.indices.map { NSNumber(value: Double($0) / Double(max(colours.count - 1, 1))) })
        emitter.particleBlendMode = .add
        return emitter
    }

    /// Text that floats up and fades, for points and praise.
    static func floatText(_ text: String, at point: CGPoint, colour: UIColor = .white, size: CGFloat = 26, in parent: SKNode) {
        let label = GameLabel(text, size: size, colour: colour)
        label.position = point
        label.zPosition = 80
        label.setScale(0.4)
        parent.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.18), .moveBy(x: 0, y: 46, duration: 0.9), .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent(),
        ]))
    }

    /// Something small popping up out of the ground with a bounce.
    static func bloom(_ emoji: String, at point: CGPoint, size: CGFloat, in parent: SKNode, z: CGFloat = 6) {
        let sprite = SKSpriteNode(texture: Art.emoji(emoji), size: CGSize(width: size, height: size))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        sprite.position = point
        sprite.zPosition = z
        sprite.setScale(0)
        sprite.name = "bloom"
        parent.addChild(sprite)
        let sway = SKAction.sequence([.rotate(toAngle: 0.08, duration: 1.4), .rotate(toAngle: -0.08, duration: 1.4)])
        sway.timingMode = .easeInEaseOut
        sprite.run(.sequence([.scale(to: 1.25, duration: 0.22), .scale(to: 1, duration: 0.14)]))
        if !reducedMotion { sprite.run(.repeatForever(sway)) }
    }
}

extension SKAction {
    /// A quick left-right shake that says "not quite" without being harsh.
    static func wobble(distance: CGFloat = 8) -> SKAction {
        .sequence([
            .moveBy(x: -distance, y: 0, duration: 0.05), .moveBy(x: distance * 2, y: 0, duration: 0.09),
            .moveBy(x: -distance * 2, y: 0, duration: 0.09), .moveBy(x: distance, y: 0, duration: 0.05),
        ])
    }

    static func pop(to scale: CGFloat = 1) -> SKAction {
        .sequence([.scale(to: scale * 1.18, duration: 0.12), .scale(to: scale, duration: 0.1)])
    }

    func eased() -> SKAction {
        timingMode = .easeInEaseOut
        return self
    }
}
