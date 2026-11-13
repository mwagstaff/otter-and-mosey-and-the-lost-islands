import { ColorMatrixFilter, Container, Sprite } from "pixi.js";
import { everyFrame, run } from "../engine/actions";
import { texture } from "../engine/art";
import type { Emitter } from "../engine/particles";
import { ambient } from "./effects";
import type { IslandTheme } from "./theme";

/**
 * Drains a node's colour: `colour` runs from 0 (almost grey, slightly flatter and darker)
 * to 1 (untouched, with no filter at all).
 */
export function applyWash(target: Container, wash: ColorMatrixFilter, colour: number): void {
  if (colour >= 0.999) {
    target.filters = [];
    return;
  }
  const saturation = 0.06 + 0.94 * colour;
  const contrast = 0.9 + 0.1 * colour;
  const offset = (1 - contrast) / 2 - 0.02 * (1 - colour);
  const [r, g, b] = [0.2126, 0.7152, 0.0722];
  const row = (index: number) =>
    [r, g, b].map((weight, at) => contrast * (weight * (1 - saturation) + (at === index ? saturation : 0)));
  wash.matrix = [
    ...row(0), 0, offset,
    ...row(1), 0, offset,
    ...row(2), 0, offset,
    0, 0, 0, 1, 0,
  ] as unknown as ColorMatrixFilter["matrix"];
  target.filters = [wash];
}

/**
 * The layered scenery behind a level: a painted far layer, a foreground strip and drifting
 * particles. A colour filter drains the scenery by however much colour the island has lost,
 * so restoring the world is a simple fade.
 */
export class Backdrop extends Container {
  private readonly scenery = new Container();
  private readonly wash = new ColorMatrixFilter();
  private farTiles: Sprite[] = [];
  private nearTiles: Sprite[] = [];
  private farWidth = 1;
  private nearWidth = 1;
  private farOffset = 0;
  private nearOffset = 0;
  private motes?: Emitter;
  private shown = 0;
  private from = 0;
  private fadeTime = 0;
  private fadeLength = 0;
  private built = "";
  private sceneWidth = 0;
  private sceneHeight = 0;
  private ground = 0;
  restoration = 0;
  /** Height of the foreground strip, so scenes can stand characters on it. */
  foregroundHeight = 0;
  /** Set to false before the first `resize` for a scene with no ground strip. */
  showsForeground = true;

  /** @param scrolling whether this level's scenery moves sideways (see `scroll`). */
  constructor(private readonly theme: IslandTheme, private readonly scrolling = false) {
    super();
    this.zIndex = -100;
    this.addChild(this.scenery);
    run(this, everyFrame((dt) => this.advance(dt)));
  }

  /** Rebuilds the layers for a scene size. `ground` is how far above the bottom edge the foreground sits. */
  resize(width: number, height: number, ground: number): void {
    const key = `${width}x${height}:${ground}:${this.showsForeground}`;
    if (width <= 10 || key === this.built) return;
    this.built = key;
    this.sceneWidth = width;
    this.sceneHeight = height;
    this.ground = ground;
    this.scenery.removeChildren().forEach((child) => child.destroy());

    // Every other tile is mirrored so a row of them joins up without a visible seam.
    const tile = (name: string, scale: number, anchorY: number, index: number) => {
      const sprite = new Sprite(texture(name));
      sprite.anchor.set(0.5, anchorY);
      sprite.scale.set(index % 2 === 1 ? -scale : scale, scale);
      this.scenery.addChild(sprite);
      return sprite;
    };
    const evenCount = (tileWidth: number) => {
      const needed = Math.ceil((width + 2 * tileWidth) / tileWidth);
      return needed + (needed % 2);
    };

    const far = texture(this.theme.background);
    const farScale = this.scrolling ? height / far.height : Math.max(width / far.width, height / far.height);
    this.farWidth = far.width * farScale - 1;
    const farCount = this.scrolling ? evenCount(this.farWidth) : 1;
    this.farTiles = Array.from({ length: farCount }, (_, index) => tile(this.theme.background, farScale, 0.5, index));

    this.nearTiles = [];
    this.foregroundHeight = 0;
    if (this.showsForeground) {
      const near = texture(this.theme.foreground);
      this.foregroundHeight = Math.min(height * 0.2, 130);
      const nearScale = this.foregroundHeight / near.height;
      this.nearWidth = near.width * nearScale - 1;
      this.nearTiles = Array.from({ length: evenCount(this.nearWidth) }, (_, index) => tile(this.theme.foreground, nearScale, 1, index));
    }

    this.motes?.destroy({ children: true });
    this.motes = ambient(this.theme.ambient, width, height);
    this.addChild(this.motes);
    this.show(this.shown);
    this.place();
  }

  private place(): void {
    const { sceneWidth: width, sceneHeight: height } = this;
    this.farTiles.forEach((tile, index) => {
      tile.position.set(this.scrolling ? index * this.farWidth - this.farOffset + this.farWidth / 2 : width / 2, height / 2);
    });
    const start = this.scrolling ? -this.nearOffset : -(this.nearTiles.length * this.nearWidth - width) / 2;
    this.nearTiles.forEach((tile, index) => {
      tile.position.set(start + index * this.nearWidth + this.nearWidth / 2, height - this.ground);
    });
  }

  /** Moves the world left by `distance`; the far layer follows more slowly. */
  scroll(distance: number): void {
    if (!this.scrolling) return;
    this.farOffset = (this.farOffset + distance * 0.35) % (this.farWidth * 2);
    this.nearOffset = (this.nearOffset + distance) % (this.nearWidth * 2);
    this.place();
  }

  /** How colourful the island is, from 0 (grey) to 1 (fully restored). */
  setRestoration(value: number, duration = 0.9): void {
    this.restoration = Math.min(Math.max(value, 0), 1);
    this.from = this.shown;
    this.fadeTime = 0;
    this.fadeLength = duration;
    if (duration <= 0) this.show(this.restoration);
  }

  private advance(dt: number): void {
    if (this.shown === this.restoration) return;
    this.fadeTime += dt;
    const progress = this.fadeLength <= 0 ? 1 : Math.min(this.fadeTime / this.fadeLength, 1);
    this.show(this.from + (this.restoration - this.from) * progress);
  }

  private show(colour: number): void {
    this.shown = colour;
    if (this.motes) this.motes.birthRate = 0.6 + 9 * colour;
    applyWash(this.scenery, this.wash, colour);
  }
}
