import CoreGraphics

/// Where a speech bubble goes so it never covers the character who is speaking.
/// Mirrors web/src/core/bubble.ts.
public enum BubblePlacement {
    /// Which way the tail points: `.down` means the bubble sits above the speaker.
    public enum Tail: Sendable { case down, up, left, right }

    public struct Spot: Equatable, Sendable {
        public var origin: CGPoint
        public var tail: Tail
        /// How far along its edge the tail sits, from the bubble's left (down/up) or top (left/right).
        public var tailAt: CGFloat
    }

    /// Tries above the speaker, then to the right, the left and below. A spot counts only if the
    /// whole bubble is on the stage, clear of the speaker and clear of everything in `avoid` (such
    /// as the Skip button). If nothing fits, the bubble goes above and is pushed on to the stage.
    public static func place(stage: CGSize, speaker: CGRect, bubble: CGSize,
                             margin: CGFloat = 8, gap: CGFloat = 14, avoid: [CGRect] = []) -> Spot {
        // The tail aims at the speaker's head: the top middle of the picture.
        let head = CGPoint(x: speaker.midX, y: speaker.minY + speaker.height * 0.2)
        let edge: CGFloat = 18
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { min(max(value, low), max(low, high)) }
        func along(_ point: CGFloat, _ start: CGFloat, _ size: CGFloat) -> CGFloat { clamp(point - start, edge, size - edge) }

        let aboveX = clamp(head.x - bubble.width / 2, margin, stage.width - margin - bubble.width)
        let sideY = clamp(head.y - bubble.height * 0.4, margin, stage.height - margin - bubble.height)
        let candidates = [
            Spot(origin: CGPoint(x: aboveX, y: speaker.minY - gap - bubble.height), tail: .down, tailAt: along(head.x, aboveX, bubble.width)),
            Spot(origin: CGPoint(x: speaker.maxX + gap, y: sideY), tail: .left, tailAt: along(head.y, sideY, bubble.height)),
            Spot(origin: CGPoint(x: speaker.minX - gap - bubble.width, y: sideY), tail: .right, tailAt: along(head.y, sideY, bubble.height)),
            Spot(origin: CGPoint(x: aboveX, y: speaker.maxY + gap), tail: .up, tailAt: along(head.x, aboveX, bubble.width)),
        ]
        let room = CGRect(origin: .zero, size: stage).insetBy(dx: margin, dy: margin)
        for spot in candidates {
            let box = CGRect(origin: spot.origin, size: bubble)
            if room.contains(box), !box.intersects(speaker), !avoid.contains(where: { box.intersects($0) }) { return spot }
        }
        var fallback = candidates[0]
        fallback.origin.y = clamp(fallback.origin.y, margin, stage.height - margin - bubble.height)
        return fallback
    }
}
