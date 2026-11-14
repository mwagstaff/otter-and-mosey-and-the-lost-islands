import SpriteKit
import UIKit

/// A word laid out one letter per slot, with gaps the child fills in by typing.
/// Used wherever spelling is typed: word bubbles, guardians and the tutorial.
final class WordSlotsNode: SKNode {
    private var labels: [GameLabel] = []
    private var gaps: [Int] = []
    private var filled = 0
    private let marker: SKSpriteNode
    private let ink: UIColor
    private let accent: UIColor
    let letterWidth: CGFloat
    private let answer: [Character]

    var isComplete: Bool { filled >= gaps.count }
    var totalWidth: CGFloat { CGFloat(labels.count) * letterWidth }

    /// - Parameters:
    ///   - masked: the word with `_` for each missing letter.
    ///   - answer: the complete word, used when the whole word is flashed up.
    init(masked: String, answer: String, letterWidth: CGFloat, ink: UIColor, accent: UIColor) {
        self.letterWidth = letterWidth
        self.ink = ink
        self.accent = accent
        self.answer = Array(answer)
        marker = SKSpriteNode(texture: Art.panel(size: CGSize(width: 60, height: 76), fill: UIColor(hex: "#FFE066"), stroke: accent, radius: 12, lineWidth: 4))
        super.init()
        let characters = Array(masked)
        marker.size = CGSize(width: letterWidth * 0.94, height: letterWidth * 1.3)
        marker.zPosition = -1
        addChild(marker)
        for (index, character) in characters.enumerated() {
            let isGap = character == "_"
            let label = GameLabel(isGap ? "_" : String(character), size: letterWidth * 1.12, colour: isGap ? accent : ink, tracking: 0)
            label.position = CGPoint(x: (CGFloat(index) - CGFloat(characters.count - 1) / 2) * letterWidth, y: 0) // matches home(_:)
            addChild(label)
            labels.append(label)
            if isGap { gaps.append(index) }
        }
        moveMarker(animated: false)
        if !Effects.reducedMotion {
            marker.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func moveMarker(animated: Bool) {
        guard filled < gaps.count else {
            marker.isHidden = true
            return
        }
        let target = labels[gaps[filled]].position
        if animated { marker.run(.move(to: target, duration: 0.08)) } else { marker.position = target }
    }

    /// Puts the next letter into its gap.
    func fillNext(with character: Character) {
        guard filled < gaps.count else { return }
        let label = labels[gaps[filled]]
        settle(label, at: gaps[filled])
        label.string = String(character).lowercased()
        label.colour = UIColor(hex: "#1E9E52")
        label.run(.pop())
        filled += 1
        moveMarker(animated: true)
    }

    /// Where the letter at `index` sits when nothing is moving it.
    private func home(_ index: Int) -> CGPoint {
        CGPoint(x: (CGFloat(index) - CGFloat(labels.count - 1) / 2) * letterWidth, y: 0)
    }

    /// Stops any wobble and puts the label back in place. Cutting a wobble short would otherwise
    /// leave the letter nudged sideways, and quick wrong taps would push it further each time.
    private func settle(_ label: GameLabel, at index: Int) {
        label.removeAction(forKey: "wrong")
        label.position = home(index)
    }

    /// Briefly shows a wrong letter in the current gap, then clears it.
    func flashWrong(_ character: Character) {
        guard filled < gaps.count else { return }
        let label = labels[gaps[filled]]
        settle(label, at: gaps[filled])
        label.string = String(character).lowercased()
        label.colour = UIColor(hex: "#E8743B")
        let letter = answer.indices.contains(gaps[filled]) ? answer[gaps[filled]] : nil
        label.run(.sequence([.wobble(distance: 5), .wait(forDuration: 0.15), .run { [weak self, weak label] in
            guard let self, let label else { return }
            // A hint may have flashed the word up meanwhile: leave the right letter showing, not a gap.
            if self.action(forKey: "flash") != nil, let letter {
                label.string = String(letter)
                label.colour = self.ink
            } else {
                label.string = "_"
                label.colour = self.accent
            }
        }]), withKey: "wrong")
    }

    /// Shows the whole word for a moment (look, cover, write), then hides the unfilled letters again.
    func flashWord(for duration: TimeInterval) {
        removeAction(forKey: "flash")
        for index in gaps.dropFirst(filled) where index < answer.count {
            labels[index].string = String(answer[index])
            labels[index].colour = ink
        }
        marker.isHidden = true
        run(.sequence([.wait(forDuration: duration), .run { [weak self] in
            guard let self else { return }
            for index in self.gaps.dropFirst(self.filled) {
                self.labels[index].string = "_"
                self.labels[index].colour = self.accent
            }
            self.marker.isHidden = self.isComplete
        }]), withKey: "flash")
    }
}
