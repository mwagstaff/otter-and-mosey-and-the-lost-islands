import LostIslandsCore
import SpriteKit
import UIKit

/// Everything a level scene needs to know about who is playing and how it should look.
struct SceneOptions {
    var settings: AppSettings
    var favourite: CharacterNode.Kind
    var accessory: String?
    var island: Island
    var inputProfile: InputProfile
    /// How colourful the island is when the level starts and ends (0 = grey, 1 = fully restored).
    var startRestoration: CGFloat
    var endRestoration: CGFloat
}

/// Shared behaviour for every playable level: scenery, the two heroes, asking questions,
/// reacting to right and wrong answers, hints, and the end-of-level celebration.
/// Subclasses supply the mechanic.
class GameScene: SKScene {
    let bridge: GameBridge
    var session: ChallengeSession
    let options: SceneOptions
    let theme: IslandTheme

    /// Space taken by the notch, the HUD and the on-screen keys.
    var insets = UIEdgeInsets.zero { didSet { if insets != oldValue { relayout() } } }
    private(set) var isBuilt = false
    private(set) var backdrop: Backdrop!
    private(set) var otter: CharacterNode!
    private(set) var mosey: CharacterNode!
    private let cameraNode = SKCameraNode()

    private(set) var current: Question?
    private(set) var firstTry = true
    private(set) var usedHint = false
    private(set) var slips = 0
    private var questionStart = Date()
    private var bloomCount = 0
    private var finished = false

    /// Whether this mode's scenery scrolls sideways.
    var scrollsBackdrop: Bool { false }

    init(session: ChallengeSession, bridge: GameBridge, options: SceneOptions) {
        self.session = session
        self.bridge = bridge
        self.options = options
        theme = IslandTheme.island(options.island.id)
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        bridge.scene = self
        bridge.total = session.total
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Geometry

    /// The area free for gameplay, inside the safe area, below the HUD and above the keys.
    var play: CGRect {
        CGRect(x: insets.left, y: insets.bottom, width: max(size.width - insets.left - insets.right, 10),
               height: max(size.height - insets.top - insets.bottom, 10))
    }

    /// True on phone-sized screens, where everything is drawn larger relative to the play area.
    var compact: Bool { size.height < 520 }

    /// Where characters stand.
    var groundY: CGFloat { play.minY + backdrop.foregroundHeight * 0.3 }

    var lead: CharacterNode { options.favourite == .otter ? otter : mosey }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        buildIfReady()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildIfReady()
        relayout()
    }

    private func buildIfReady() {
        guard !isBuilt, view != nil, size.width > 100, size.height > 100 else { return }
        isBuilt = true
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
        backdrop = Backdrop(theme: theme, scrolling: scrollsBackdrop)
        addChild(backdrop)
        backdrop.setRestoration(options.startRestoration, duration: 0)
        backdrop.resize(to: size, groundY: insets.bottom)
        otter = CharacterNode(kind: .otter, size: 100, accessory: options.favourite == .otter ? options.accessory : nil)
        mosey = CharacterNode(kind: .mosey, size: 160, accessory: options.favourite == .mosey ? options.accessory : nil)
        build()
        layout()
        otter.startIdle()
        mosey.startIdle()
        if wantsStart { beginIfReady() }
    }

    private var wantsStart = false
    private var hasStarted = false

    /// Called once the opening dialogue is out of the way.
    func begin() {
        wantsStart = true
        beginIfReady()
    }

    private func beginIfReady() {
        guard isBuilt, !hasStarted else { return }
        hasStarted = true
        start()
    }

    private func relayout() {
        guard isBuilt else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop.resize(to: size, groundY: insets.bottom)
        layout()
    }

    // MARK: - Subclass hooks

    /// Create nodes. Called once, when the scene has its real size.
    func build() {}
    /// Position nodes. Called after `build` and whenever the size or insets change.
    func layout() {}
    /// Begin play. The default asks the first question.
    func start() { askNext() }
    /// Show a new question.
    func present(_ question: Question) {}
    func handleKey(_ character: Character) {}
    func handleBackspace() {}
    /// Give extra visual help after a hint is requested.
    func applyHint() {}
    /// The HUD text for a question.
    func caption(for question: Question) -> String { question.prompt }

    // MARK: - Question flow

    func askNext() {
        guard !finished, let question = session.next() else { return }
        current = question
        firstTry = true
        usedHint = false
        slips = 0
        questionStart = Date()
        bridge.hintText = nil
        bridge.caption = caption(for: question)
        bridge.keyboard = keyboard(for: question)
        let spoken = shouldSpeak(question)
        bridge.speakable = spoken ? question.spoken : ""
        bridge.speakableKey = spoken ? question.audioKey : nil
        bridge.canSpeak = spoken && Narrator.shared.canSay(key: question.audioKey, fallback: question.spoken)
        if options.settings.spokenInstructions, spoken { Narrator.shared.say(key: question.audioKey, fallback: question.spoken) }
        present(question)
    }

    func shouldSpeak(_ question: Question) -> Bool { true }

    func keyboard(for question: Question) -> KeyboardKind {
        guard question.format == .typed else { return .none }
        if question.typingTarget.allSatisfy(\.isNumber) { return .numbers }
        let hasSpace = question.typingTarget.contains(" ")
        if options.inputProfile == .compactTouch, !hasSpace, session.level.mode != .typingTurbo {
            return .tray(Self.trayLetters(for: question.typingTarget))
        }
        return .qwerty(space: hasSpace)
    }

    /// The answer's letters plus a few extras, shuffled, for the one-row phone keyboard.
    static func trayLetters(for target: String) -> [Character] {
        var letters: [Character] = []
        for letter in target.lowercased() where !letters.contains(letter) { letters.append(letter) }
        let wanted = min(max(letters.count + 3, 6), 10)
        var extras = Array("aeioutnsrlhdcm").shuffled()
        while letters.count < wanted, let extra = extras.popLast() {
            if !letters.contains(extra) { letters.append(extra) }
        }
        return letters.shuffled()
    }

    /// A wrong attempt: reassure, never punish.
    func slip() {
        session.recordSlip()
        firstTry = false
        slips += 1
        AudioManager.shared.play(.wrong, volume: 0.7)
        Haptics.shared.nudge()
        bridge.combo = 0
        bridge.multiplier = 1
        bridge.showToast(session.retryMessage())
        lead.oops()
        if slips >= 2, !usedHint { requestHint() }
    }

    /// The current question is done. Celebrates and returns the outcome so the mode can carry on.
    @discardableResult
    func succeed(at point: CGPoint) -> AnswerOutcome? {
        guard let question = current else { return nil }
        current = nil
        let outcome = session.complete(question, firstTry: firstTry, seconds: Date().timeIntervalSince(questionStart), usedHint: usedHint)
        AudioManager.shared.play(outcome.combo >= 3 ? .combo : .correct)
        Haptics.shared.success()
        Effects.burst(at: point, colour: theme.tint.mixed(with: .white, amount: 0.4), in: self)
        Effects.floatText("+\(outcome.points)", at: CGPoint(x: point.x, y: point.y + 30), colour: UIColor(hex: "#FFE066"), in: self)
        bridge.completed = session.completed
        bridge.combo = outcome.combo
        bridge.multiplier = outcome.multiplier
        bridge.score = session.score
        bridge.hintText = nil
        bridge.showToast(outcome.praise)
        otter.celebrate()
        mosey.celebrate()
        let progress = CGFloat(session.progress)
        backdrop.setRestoration(options.startRestoration + (options.endRestoration - options.startRestoration) * progress * 0.85)
        bloom()
        bridge.onLearnerChanged?(session.learner)
        return outcome
    }

    func requestHint() {
        guard let question = current else { return }
        usedHint = true
        bridge.hintText = question.hint
        AudioManager.shared.play(.nav)
        lead.think()
        applyHint()
    }

    /// Something from the island's theme pops up along the ground: the world coming back to life.
    func bloom(count: Int = 2) {
        guard bloomCount < 26 else { return }
        for _ in 0..<count {
            bloomCount += 1
            let x = CGFloat.random(in: (play.minX + 20)...(play.maxX - 20))
            let size = (compact ? 34 : 46) * CGFloat.random(in: 0.8...1.2)
            let point = CGPoint(x: x, y: play.minY + CGFloat.random(in: 2...14))
            Effects.bloom(theme.blooms.randomElement()!, at: point, size: size, in: self, z: 31)
            if scrollsBackdrop, let sprite = children.last(where: { $0.name == "bloom" }) {
                // In travelling levels the scenery moves on, so blooms drift away behind the heroes.
                bloomCount -= 1
                sprite.name = "passing"
                sprite.run(.sequence([.group([.moveBy(x: -size * 6, y: 0, duration: 1.8), .sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.6)])]), .removeFromParent()]))
            }
        }
    }

    /// Ends the level: the island brightens, confetti falls, then the results appear.
    func finishLevel(after delay: TimeInterval = 0.6) {
        guard !finished else { return }
        finished = true
        bridge.keyboard = .none
        Narrator.shared.stop()
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self else { return }
                self.backdrop.setRestoration(self.options.endRestoration, duration: 1.4)
                Effects.confetti(in: self)
                AudioManager.shared.play(.levelComplete)
                Haptics.shared.crescendo()
                self.cameraPunch(scale: 0.94, hold: 1.2)
                self.bloom(count: 6)
                self.otter.celebrate()
                self.mosey.celebrate()
            },
            .wait(forDuration: 2.4),
            .run { [weak self] in
                guard let self else { return }
                self.bridge.result = self.session.result
            },
        ]))
    }

    // MARK: - Helpers

    /// A quick camera push-in for impact. Skipped when motion is reduced.
    func cameraPunch(scale: CGFloat = 0.965, hold: TimeInterval = 0.0) {
        guard !Effects.reducedMotion else { return }
        cameraNode.removeAction(forKey: "punch")
        cameraNode.run(.sequence([
            SKAction.scale(to: scale, duration: 0.12).eased(), .wait(forDuration: hold), SKAction.scale(to: 1, duration: 0.3).eased(),
        ]), withKey: "punch")
    }

    /// Marks the current question as not perfect without any fuss (used for typing slips).
    func markImperfect() { firstTry = false }

    /// A sign showing text on a chunky panel.
    func makeSign(text: String, size: CGSize, fill: UIColor = UIColor(hex: "#FFF6E0"), ink: UIColor = UIColor(hex: "#0E3B43"), fontSize: CGFloat, radius: CGFloat = 18) -> SKSpriteNode {
        let fill = options.settings.highContrast ? UIColor.white : fill
        let ink = options.settings.highContrast ? UIColor.black : ink
        let sign = SKSpriteNode(texture: Art.panel(size: size, fill: fill, stroke: ink, radius: min(radius, size.height * 0.45)), size: size)
        // Sentences wrap; single words and numbers shrink to fit instead.
        let label = GameLabel(text, size: fontSize, colour: ink, maxWidth: text.contains(" ") && text.count > 14 ? size.width - 20 : nil)
        label.fitWidth = text.contains(" ") && text.count > 14 ? nil : size.width - 18
        label.name = "label"
        label.zPosition = 1
        sign.addChild(label)
        return sign
    }

    func signLabel(_ sign: SKNode) -> GameLabel? { sign.childNode(withName: "label") as? GameLabel }
}
