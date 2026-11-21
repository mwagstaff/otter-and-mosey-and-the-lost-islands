import { describe, expect, test, vi } from "vitest";
import { Container, Sprite, Texture } from "pixi.js";
vi.mock("../src/game/audio", () => ({ audio: { play: vi.fn() }, narrator: {} }));
vi.mock("../src/game/effects", () => ({ burst: vi.fn() }));
import { MathsSplashScene } from "../src/game/mathsSplash";
import { islandTheme } from "../src/game/theme";

function fixture(island = "candy") {
  // Exercise the actual scene input and collection path without a GPU or audio device.
  const scene = Object.create(MathsSplashScene.prototype);
  const world = new Container();
  const item = new Sprite(Texture.WHITE);
  item.setSize(30, 30); item.position.set(600, 200); world.addChild(item);
  Object.assign(scene, {
    world, pearls: [item], pearlsScooped: 0, pearlsOffered: 1,
    theme: islandTheme(island), phase: "cruising", targetY: 200,
    width: 844, height: 390, insets: { top: 70, bottom: 0, left: 8, right: 8 },
    mosey: { size: 100, chew: vi.fn() },
  });
  return { scene, item };
}

describe("themed collection", () => {
  test("a direct tap collects once, including during the next answer phase", () => {
    const { scene, item } = fixture();
    scene.phase = "choosing";
    scene.pointerDown(600, 200);
    expect(scene.pearlsScooped).toBe(1);
    expect(scene.pearlsOffered).toBe(1);
    expect(scene.pearls).toHaveLength(0);
    expect(scene.mosey.chew).toHaveBeenCalledOnce();
    expect(item.destroyed).toBe(true);
    scene.phase = "cruising";
    scene.pointerDown(600, 200);
    expect(scene.pearlsScooped).toBe(1);
  });
  test.each(["woods", "bay", "dragon", "cloud", "candy", "star"])("Mosey only chews edible pickups on %s", (island) => {
    const { scene } = fixture(island);
    scene.pointerDown(600, 200);
    if (island === "woods" || island === "candy") {
      expect(scene.mosey.chew).toHaveBeenCalledWith(0.44, island === "woods");
    } else {
      expect(scene.mosey.chew).not.toHaveBeenCalled();
    }
  });
  test("near misses steer without granting a collectible", () => {
    const { scene } = fixture();
    scene.pointerDown(560, 240);
    expect(scene.pearlsScooped).toBe(0);
    expect(scene.targetY).toBe(240);
    scene.pointerMove(560, 180);
    expect(scene.targetY).toBe(180);
  });
  test("steering into an item uses the same collection count and removes it once", () => {
    const { scene, item } = fixture();
    item.position.set(scene.swimmerX, 200);
    Object.assign(scene, {
      pace: 120, targetPace: 120,
      backdrop: { scroll: vi.fn() }, stream: { position: { set: vi.fn() } },
      mosey: { ...scene.mosey, y: 200, position: { set: vi.fn() } },
    });
    scene.update(0);
    expect(scene.pearlsScooped).toBe(1);
    expect(scene.pearls).toHaveLength(0);
    scene.update(0);
    expect(scene.pearlsScooped).toBe(1);
    expect(scene.mosey.chew).toHaveBeenCalledOnce();
  });
  test("all six islands have suitable objects, number decorations and snacks", () => {
    const themes = ["woods", "bay", "dragon", "cloud", "candy", "star"].map(islandTheme);
    expect(themes.map((theme) => theme.collectible)).toEqual(["🍓", "pearl", "💎", "☁️", "🍬", "⭐️"]);
    expect(themes.map((theme) => theme.gateDecoration)).toEqual(["🌸", "🐚", "💎", "🌈", "🍬", "⭐️"]);
    expect(themes.every((theme) => theme.snack && theme.snackName && theme.collectInstruction.includes("Tap"))).toBe(true);
  });
});
