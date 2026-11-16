#if DEBUG
import Foundation
import SpriteKit
import SwiftUI

/// Read-only scene diagnostics for the external UI runner; never completes answers.
@MainActor func playtestState(_ scene: GameScene) -> String {
    func field(_ name: String) -> Any? { Mirror(reflecting: scene).children.first { $0.label == name }?.value }
    func node(_ name: String) -> SKNode? {
        guard let value = field(name) else { return nil }
        return value as? SKNode
    }
    func point(_ node: SKNode?) -> [String: Double]? {
        guard let node, node.parent != nil, !node.isHidden else { return nil }
        let local = scene.convertPoint(toView: node.convert(.zero, to: scene))
        let p = scene.view?.convert(local, to: nil) ?? local
        return ["x": Double(p.x), "y": Double(p.y)]
    }
    let b = scene.bridge
    var state: [String: Any] = ["completed": b.completed, "total": b.total, "finished": b.result != nil, "stars": b.result?.stars ?? 0,
        "ready": (field("acceptingAnswers") as? Bool ?? true) && !(field("busy") as? Bool ?? false) && !(field("locked") as? Bool ?? false)]
    if let q = scene.current {
        state["typed"] = q.typingTarget
        state["choice"] = q.correctChoice
        state["choices"] = q.choices
    }
    for name in ["powerButton", "crystal", "slot"] { if let p = point(node(name)) { state[name] = p } }
    let targets = (field("tiles") as? [SKNode]) ?? (field("gates") as? [SKNode]) ?? (field("orbs") as? [SKNode]) ?? []
    state["targets"] = targets.map { point($0) ?? [:] }
    guard let data = try? JSONSerialization.data(withJSONObject: state), let text = String(data: data, encoding: .utf8) else { return "{}" }
    return text
}
struct PlaytestProbe: UIViewRepresentable {
    let scene: GameScene
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) { view.scene = scene }
    final class ProbeView: UIView {
        weak var scene: GameScene?
        override init(frame: CGRect) {
            super.init(frame: frame)
            isAccessibilityElement = true
            accessibilityIdentifier = "playtest-state"
            accessibilityLabel = "Playtest state"
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var accessibilityValue: String? {
            get { scene.map(playtestState) }
            set { }
        }
    }
}
#endif
