// Where a speech bubble goes so it never covers the character who is speaking.
// Mirrors BubblePlacement.swift in LostIslandsCore.

export interface Rect { x: number; y: number; width: number; height: number }
export type TailSide = "down" | "up" | "left" | "right";

export interface BubbleSpot {
  x: number;
  y: number;
  /** Which way the tail points: "down" means the bubble sits above the speaker. */
  tail: TailSide;
  /** How far along its edge the tail sits, from the bubble's left (down/up) or top (left/right). */
  tailAt: number;
}

const overlaps = (a: Rect, b: Rect) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
const clamp = (value: number, low: number, high: number) => Math.min(Math.max(value, low), Math.max(low, high));

/**
 * Tries above the speaker, then to the right, the left and below. A spot counts only if the whole
 * bubble is on the stage, clear of the speaker and clear of anything in `avoid` (such as the
 * Skip button). If nothing fits, the bubble goes above and is pushed on to the stage.
 */
export function placeBubble(stage: { width: number; height: number }, speaker: Rect, bubble: { width: number; height: number },
  options: { margin?: number; gap?: number; avoid?: Rect[] } = {}): BubbleSpot {
  const margin = options.margin ?? 8;
  const gap = options.gap ?? 14;
  const avoid = options.avoid ?? [];
  // The tail aims at the speaker's head: the top middle of the picture.
  const head = { x: speaker.x + speaker.width / 2, y: speaker.y + speaker.height * 0.2 };
  const edge = 18;
  const along = (point: number, start: number, size: number) => clamp(point - start, edge, size - edge);

  const aboveX = clamp(head.x - bubble.width / 2, margin, stage.width - margin - bubble.width);
  const sideY = clamp(head.y - bubble.height * 0.4, margin, stage.height - margin - bubble.height);
  const candidates: BubbleSpot[] = [
    { x: aboveX, y: speaker.y - gap - bubble.height, tail: "down", tailAt: along(head.x, aboveX, bubble.width) },
    { x: speaker.x + speaker.width + gap, y: sideY, tail: "left", tailAt: along(head.y, sideY, bubble.height) },
    { x: speaker.x - gap - bubble.width, y: sideY, tail: "right", tailAt: along(head.y, sideY, bubble.height) },
    { x: aboveX, y: speaker.y + speaker.height + gap, tail: "up", tailAt: along(head.x, aboveX, bubble.width) },
  ];
  const fits = (spot: BubbleSpot) => {
    const box = { x: spot.x, y: spot.y, width: bubble.width, height: bubble.height };
    return box.x >= margin && box.y >= margin && box.x + box.width <= stage.width - margin && box.y + box.height <= stage.height - margin
      && !overlaps(box, speaker) && !avoid.some((each) => overlaps(box, each));
  };
  const chosen = candidates.find(fits);
  if (chosen) return chosen;
  const fallback = candidates[0]!;
  return { ...fallback, y: clamp(fallback.y, margin, stage.height - margin - bubble.height) };
}
