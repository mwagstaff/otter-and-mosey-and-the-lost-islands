import LostIslandsCore
import SpriteKit
import UIKit

/// Game mode B. Mosey swims along with Otter on her back. Three tunnels carry answers;
/// tapping the right one sends her through with a rainbow speed boost. Between questions
/// the player drags up and down to scoop pearls.
final class MathsSplashScene: GameScene {
    private enum Phase { case cruising, arriving, choosing, dashing }

    private var phase = Phase.cruising
    private var gates: [SKNode] = []
    private var pearls: [SKSpriteNode] = []
    private var pace: CGFloat = 120
    private var targetPace: CGFloat = 120
    private var targetY: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private let trail = Effects.trail()
    private var pearlCount = 0

    override var scrollsBackdrop: Bool { true }

    override func build() {
        addChild(mosey)
        mosey.restPose = .move
        mosey.set(.move, pop: false)
        mosey.zPosition = 20
        otter.zPosition = -1
        mosey.addChild(otter)
        trail.zPosition = 19
        trail.targetNode = self
        addChild(trail)
    }

    private var lanes: [CGFloat] { [0.8, 0.5, 0.2].map { play.minY + play.height * $0 } }
    private var swimmerX: CGFloat { play.minX + play.width * 0.22 }
    private var gateX: CGFloat { play.minX + play.width * 0.74 }
    private var gateSize: CGFloat { min(play.height * 0.34, 170) }

    override func layout() {
        mosey.resize(min(play.height * 0.5, 240))
        otter.resize(mosey.size * 0.42)
        otter.position = CGPoint(x: -mosey.size * 0.06, y: mosey.size * 0.02)
        if targetY == 0 { targetY = lanes[1] }
        mosey.position = CGPoint(x: swimmerX, y: targetY)
        for (index, gate) in gates.enumerated() where phase == .choosing { gate.position = CGPoint(x: gateX, y: lanes[index]) }
    }

    override func caption(for question: Question) -> String { question.prompt }

    override func present(_ question: Question) {
        phase = .arriving
        gates.forEach { $0.removeFromParent() }
        gates = []
        for (index, choice) in question.choices.enumerated() {
            let gate = SKNode()
            gate.name = choice
            let ring = SKSpriteNode(texture: Art.texture("ring"), size: CGSize(width: gateSize, height: gateSize))
            ring.name = "ring"
            gate.addChild(ring)
            let plateSize = CGSize(width: gateSize * 0.7, height: gateSize * 0.46)
            let plate = makeSign(text: choice, size: plateSize, fontSize: plateSize.height * 0.66)
            plate.zPosition = 1
            gate.addChild(plate)
            gate.position = CGPoint(x: size.width + gateSize, y: lanes[index])
            gate.zPosition = 15
            addChild(gate)
            gates.append(gate)
            let arrive = SKAction.moveTo(x: gateX, duration: Effects.reducedMotion ? 0.3 : 1.0)
            arrive.timingMode = .easeOut
            gate.run(arrive)
        }
        targetPace = 40
        run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in self?.phase = .choosing }]))
    }

    // MARK: - Touch

    private func lane(at y: CGFloat) -> Int {
        lanes.enumerated().min { abs($0.element - y) < abs($1.element - y) }?.offset ?? 1
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if phase == .choosing, point.x > swimmerX + mosey.size * 0.5 {
            choose(lane(at: point.y))
        } else {
            targetY = clampY(point.y)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), phase != .dashing else { return }
        // Swipe or drag anywhere to steer Mosey up and down.
        targetY = clampY(point.y)
    }

    private func clampY(_ y: CGFloat) -> CGFloat { min(max(y, play.minY + play.height * 0.14), play.maxY - play.height * 0.14) }

    private func choose(_ index: Int) {
        guard let question = current, gates.indices.contains(index) else { return }
        let gate = gates[index]
        guard gate.alpha == 1, let choice = gate.name else { return }
        targetY = lanes[index]
        AudioManager.shared.play(.swim, volume: 0.7)
        if question.isCorrect(choice: choice) {
            dash(through: gate)
        } else {
            // The tunnel fizzes shut and Mosey bobs back: no harm done.
            gate.run(.sequence([.wobble(), .fadeAlpha(to: 0.35, duration: 0.2)]))
            Effects.burst(at: gate.position, colour: .white, count: 10, in: self)
            mosey.run(.sequence([.moveBy(x: -18, y: 0, duration: 0.12), .moveBy(x: 18, y: 0, duration: 0.2)]))
            slip()
        }
    }

    private func dash(through gate: SKNode) {
        phase = .dashing
        targetPace = 620
        pace = 520
        trail.particleBirthRate = Effects.reducedMotion ? 30 : 160
        let point = CGPoint(x: swimmerX + mosey.size * 0.4, y: gate.position.y)
        let outcome = succeed(at: point)
        Effects.rainbowBurst(at: gate.position, in: self, count: 36)
        cameraPunch()
        for other in gates {
            let exit = SKAction.moveTo(x: -gateSize * 1.5, duration: 0.55)
            exit.timingMode = .easeIn
            other.run(.sequence([other === gate ? exit : .group([exit, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
        gates = []
        let done = outcome?.isLevelComplete == true
        run(.sequence([
            .wait(forDuration: 0.7),
            .run { [weak self] in
                guard let self else { return }
                self.trail.particleBirthRate = 0
                self.targetPace = 170
                self.phase = .cruising
                if done { self.finishLevel(after: 0.3) } else { self.spawnPearls() }
            },
            .wait(forDuration: done ? 0 : 3.6),
            .run { [weak self] in if !done { self?.askNext() } },
        ]))
    }

    private func spawnPearls() {
        bridge.caption = "Drag up and down to scoop the pearls!"
        let lane = Int.random(in: 0...2)
        for index in 0..<5 {
            let pearl = SKSpriteNode(texture: Art.texture("pearl"), size: CGSize(width: gateSize * 0.36, height: gateSize * 0.36))
            let wave = sin(CGFloat(index) * 0.9) * play.height * 0.12
            pearl.position = CGPoint(x: size.width + 30 + CGFloat(index) * gateSize * 0.6, y: clampY(lanes[lane] + wave))
            pearl.zPosition = 14
            addChild(pearl)
            pearls.append(pearl)
        }
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard isBuilt else { return }
        let delta = CGFloat(min(lastTime == 0 ? 0 : currentTime - lastTime, 1.0 / 20))
        lastTime = currentTime
        pace += (targetPace - pace) * min(delta * 3, 1)
        backdrop.scroll(by: pace * delta)
        let y = mosey.position.y + (targetY - mosey.position.y) * min(delta * 9, 1)
        mosey.position = CGPoint(x: swimmerX, y: y)
        mosey.zRotation = max(-0.3, min(0.3, (targetY - y) * 0.006))
        trail.position = CGPoint(x: swimmerX - mosey.size * 0.4, y: y)

        for pearl in pearls {
            pearl.position.x -= 280 * delta
            if abs(pearl.position.x - swimmerX) < mosey.size * 0.45, abs(pearl.position.y - y) < mosey.size * 0.3 {
                pearlCount += 1
                AudioManager.shared.play(.star, volume: 0.6)
                Effects.burst(at: pearl.position, colour: UIColor(hex: "#FFD9F0"), count: 8, in: self)
                pearl.removeFromParent()
            } else if pearl.position.x < -40 {
                pearl.removeFromParent()
            }
        }
        pearls.removeAll { $0.parent == nil }
    }
}
