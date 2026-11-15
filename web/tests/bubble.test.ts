import { describe, expect, test } from "vitest";
import { placeBubble, type Rect } from "../src/core";

const stage = { width: 1000, height: 600 };
const bubble = { width: 300, height: 90 };
const clear = (spot: { x: number; y: number }, other: Rect) =>
  spot.x + bubble.width <= other.x || other.x + other.width <= spot.x || spot.y + bubble.height <= other.y || other.y + other.height <= spot.y;
const onStage = (spot: { x: number; y: number }) =>
  spot.x >= 0 && spot.y >= 0 && spot.x + bubble.width <= stage.width && spot.y + bubble.height <= stage.height;

describe("speech bubbles", () => {
  test("go above a speaker with room overhead, tail pointing down at them", () => {
    const speaker = { x: 400, y: 300, width: 200, height: 250 };
    const spot = placeBubble(stage, speaker, bubble);
    expect(spot.tail).toBe("down");
    expect(clear(spot, speaker)).toBe(true);
  });

  test("move beside a speaker near the top of the screen", () => {
    const speaker = { x: 780, y: 20, width: 180, height: 160 }; // like Nimbus, floating high on the right
    const spot = placeBubble(stage, speaker, bubble);
    expect(spot.tail).toBe("right");
    expect(clear(spot, speaker) && onStage(spot)).toBe(true);
  });

  test("never cover the speaker, wherever they stand", () => {
    for (let x = 0; x <= 800; x += 50) {
      for (let y = 0; y <= 350; y += 50) {
        const speaker = { x, y, width: 200, height: 250 };
        const spot = placeBubble(stage, speaker, bubble);
        expect(clear(spot, speaker), `speaker at ${x},${y}`).toBe(true);
        expect(onStage(spot), `speaker at ${x},${y}`).toBe(true);
      }
    }
  });

  test("keep out of the way of the Skip button", () => {
    const skip = { x: 880, y: 10, width: 110, height: 50 };
    const speaker = { x: 820, y: 200, width: 160, height: 300 };
    const spot = placeBubble(stage, speaker, bubble, { avoid: [skip] });
    expect(clear(spot, skip) && clear(spot, speaker)).toBe(true);
  });
});
