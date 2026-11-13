import { Container, Sprite } from "pixi.js";
import { hasArt } from "../assets";
import type { Speaker } from "../core";
import {
  call, easeIn, easeInOut, easeOut, everyFrame, group, isRunning, moveBy, repeatForever, rotateTo, run, scaleTo, scaleToXY,
  sequence, stop, wait, wobble,
} from "../engine/actions";
import { circle, iconSprite, palette, speechBubble, texture } from "../engine/art";
import { speechStage } from "./audio";
import { options } from "./options";

/** A speech bubble with three bouncing dots that appears over a speaker while they talk. */
export class SpeechBadge extends Container {
  /** Scaled to pop the badge in and out, so the bubble's own size stays simple. */
  private readonly holder = new Container();
  private readonly bubble = new Sprite(speechBubble());
  private readonly dots: Sprite[] = [];
  private showing = false;
  private size = 0;
  private beat = 0;

  constructor(private readonly role: Speaker, private readonly onTick: (speaking: boolean) => void = () => {}) {
    super();
    this.zIndex = 70;
    this.addChild(this.holder);
    this.bubble.anchor.set(0.3, 1);
    this.holder.addChild(this.bubble);
    for (let index = 0; index < 3; index += 1) {
      const dot = new Sprite(circle(24, palette.teal, palette.ink, 3));
      dot.anchor.set(0.5);
      this.holder.addChild(dot);
      this.dots.push(dot);
    }
    this.holder.scale.set(0);
    this.visible = false;
    run(this, everyFrame((dt) => this.watch(dt)));
  }

  resize(width: number): void {
    if (width === this.size) return;
    this.size = width;
    this.bubble.setSize(width, (width * 110) / 132);
    for (const dot of this.dots) dot.setSize(width * 0.15);
    this.placeDots(0);
  }

  /** The dots hop one after another, and all lift a little with the loudness of the voice. */
  private placeDots(level: number): void {
    this.dots.forEach((dot, index) => {
      const hop = options.reducedMotion ? 0 : Math.max(0, Math.sin(this.beat * 7 - index * 0.9));
      dot.position.set(this.size * (index * 0.21 - 0.02), -(this.bubble.height * 0.58 + this.size * (0.05 * hop + 0.05 * level)));
    });
  }

  private watch(dt: number): void {
    const active = speechStage.speaker === this.role;
    if (active !== this.showing) {
      this.showing = active;
      if (active) {
        this.visible = true;
        run(this.holder, sequence(scaleTo(1.15, 0.1), scaleTo(1, 0.08)), "pop");
      } else {
        run(this.holder, sequence(scaleTo(0, 0.12), call(() => { this.visible = false; })), "pop");
      }
    }
    if (active) {
      this.beat += dt;
      this.placeDots(speechStage.level);
    }
    this.onTick(active);
  }
}

export type CharacterKind = "otter" | "mosey";
export type Pose = "idle" | "blink" | "cheer" | "think" | "oops" | "move";

/** Every picture a character can show, for loading before a level starts. */
export function characterArt(kind: CharacterKind): string[] {
  return ["idle", "blink", "cheer", "think", "oops", "talk", kind === "otter" ? "run" : "swim"].map((pose) => `${kind}_${pose}`);
}

/**
 * Otter or Mosey: a painted pose brought to life with code-driven movement
 * (breathing, bobbing, fidgets, jumps and pose changes).
 */
export class CharacterNode extends Container {
  /** Jumps and pops move this; the breathing layer inside it carries the picture. */
  private readonly body = new Container();
  private readonly breather = new Container();
  private readonly sprite = new Sprite();
  private readonly badge: SpeechBadge;
  private readonly hat?: Sprite;
  private readonly hasTalkFrame: boolean;
  private mouthOpen = false;
  private wasSpeaking = false;
  private unit = 1;
  pose: Pose = "idle";
  /** The pose the character returns to after a reaction. */
  restPose: Pose = "idle";
  private left = false;

  /** `size` is Otter's standing height, or Mosey's nose-to-tail length. */
  constructor(readonly kind: CharacterKind, public size: number, accessory?: string) {
    super();
    this.hasTalkFrame = hasArt(`${kind}_talk`);
    this.badge = new SpeechBadge(kind, (speaking) => this.speech(speaking));
    this.addChild(this.body, this.badge);
    this.body.addChild(this.breather);
    this.sprite.anchor.set(0.5, kind === "otter" ? 1 : 0.5);
    this.breather.addChild(this.sprite);
    if (accessory) {
      this.hat = iconSprite(accessory, 100);
      this.body.addChild(this.hat);
    }
    this.resize(size);
  }

  get facingLeft(): boolean {
    return this.left;
  }

  set facingLeft(value: boolean) {
    this.left = value;
    this.applyTexture();
  }

  /** Moves the mouth and body with the voice while this character is the one speaking. */
  private speech(speaking: boolean): void {
    const open = speaking && speechStage.mouthOpen && this.hasTalkFrame;
    if (open !== this.mouthOpen) {
      this.mouthOpen = open;
      // Only the resting pose has a talking frame; reactions keep their own face.
      if (this.pose === "idle") this.applyTexture();
    }
    if (!speaking && !this.wasSpeaking) return;
    this.wasSpeaking = speaking;
    if (!options.reducedMotion && !isRunning(this.body, "pop")) this.body.scale.y = speaking ? 1 + 0.035 * speechStage.level : 1;
  }

  private textureName(pose: Pose): string {
    if (pose === "idle" && this.mouthOpen) return `${this.kind}_talk`;
    return `${this.kind}_${pose === "move" ? (this.kind === "otter" ? "run" : "swim") : pose}`;
  }

  resize(size: number): void {
    this.size = size;
    const idle = texture(`${this.kind}_idle`);
    this.unit = this.kind === "otter" ? size / idle.height : size / idle.width;
    this.applyTexture();
  }

  private applyTexture(): void {
    const sprite = this.sprite;
    sprite.texture = texture(this.textureName(this.pose));
    const side = this.left ? -1 : 1;
    sprite.scale.set(this.unit * side, this.unit);
    const width = sprite.texture.width * this.unit;
    const height = sprite.texture.height * this.unit;
    this.badge.resize(Math.max(this.size * (this.kind === "otter" ? 0.52 : 0.36), 50));
    if (this.kind === "otter") this.badge.position.set(side * this.size * 0.12, -height * 0.98);
    else this.badge.position.set(side * width * 0.3, -height * 0.36);
    if (!this.hat) return;
    this.hat.setSize(this.size * 0.3);
    if (this.kind === "otter") this.hat.position.set(side * this.size * 0.04, -height * 0.97);
    else this.hat.position.set(side * width * 0.3, -height * 0.38);
    this.hat.visible = !(this.pose === "move" && this.kind === "otter");
  }

  set(pose: Pose, popIn = true): void {
    if (pose === this.pose) return;
    this.pose = pose;
    this.applyTexture();
    if (popIn && !options.reducedMotion) {
      this.body.scale.set(0.93);
      run(this.body, scaleTo(1, 0.14), "pop");
    }
  }

  /** Starts the gentle always-on movement and occasional fidgets. */
  startIdle(): void {
    stop(this.breather, "breathe");
    stop(this, "fidget");
    if (options.reducedMotion) return;
    if (this.kind === "otter") {
      run(this.breather, repeatForever(sequence(scaleToXY(1, 1.03, 1.1, easeInOut), scaleToXY(1, 1, 1.1, easeInOut))), "breathe");
    } else {
      const rise = this.size * 0.035;
      run(this.breather, repeatForever(sequence(
        group(moveBy(0, -rise, 1.3, easeInOut), rotateTo(-0.035, 1.3, easeInOut)),
        group(moveBy(0, rise, 1.3, easeInOut), rotateTo(0.035, 1.3, easeInOut)),
      )), "breathe");
    }
    run(this, repeatForever(sequence(wait(5, 4), call(() => this.fidget()))), "fidget");
  }

  private fidget(): void {
    if (this.pose !== this.restPose || this.restPose !== "idle") return;
    // Otter scratches his head; Mosey gives a happy blink.
    this.react(this.kind === "otter" && Math.random() < 0.5 ? "think" : "blink", 1.1);
  }

  /** Shows a pose briefly and then settles back. */
  react(reaction: Pose, hold = 1): void {
    this.set(reaction);
    run(this, sequence(wait(hold), call(() => this.set(this.restPose))), "react");
  }

  celebrate(): void {
    this.react("cheer", 1.2);
    if (options.reducedMotion) return;
    this.body.position.set(0, 0);
    const jump = this.size * 0.22;
    const up = () => moveBy(0, -jump, 0.2, easeOut);
    const down = () => moveBy(0, jump, 0.2, easeIn);
    run(this.body, sequence(up(), down(), up(), down()), "jump");
  }

  oops(): void {
    this.react("oops", 0.9);
    if (!options.reducedMotion) run(this.body, wobble(this.size * 0.03), "wobble");
  }

  think(): void {
    this.react("think", 1.4);
  }
}
