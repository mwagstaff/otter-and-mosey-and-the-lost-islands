import { Container, Sprite } from "pixi.js";
import { isCorrectChoice, type Question } from "../core";
import { easeIn, easeOut, fadeOut, fadeTo, group, moveTo, remove, run, sequence, wobble } from "../engine/actions";
import { iconName, iconSprite } from "../engine/art";
import type { Emitter } from "../engine/particles";
import { audio } from "./audio";
import { burst, rainbowBurst, trail } from "./effects";
import { GameScene } from "./gameScene";
import { options } from "./options";

type Phase = "cruising" | "arriving" | "choosing" | "dashing";

/**
 * Game mode B. Mosey swims along with Otter on his back. Three tunnels carry answers;
 * tapping the right one sends him through with a rainbow speed boost. Between questions
 * the player drags up and down to scoop pearls.
 */
export class MathsSplashScene extends GameScene {
  private phase: Phase = "cruising";
  private gates: Container[] = [];
  private pearls: Sprite[] = [];
  private originalGateSize = 1;
  private pace = 120;
  private targetPace = 120;
  private targetY = 0;
  private stream!: Emitter;

  protected override get scrollsBackdrop(): boolean { return true; }

  override art(): string[] {
    return [...super.art(), ...[this.theme.collectible, this.theme.gateDecoration].map(iconName).filter((name) => name !== undefined)];
  }

  protected build(): void {
    this.world.addChild(this.mosey);
    this.mosey.restPose = "move";
    this.mosey.set("move", false);
    this.mosey.zIndex = 20;
    // Otter rides on Mosey's back, tucked just behind him.
    this.mosey.sortableChildren = true;
    this.otter.zIndex = -1;
    this.mosey.addChild(this.otter);
    this.stream = trail(this.world);
    this.stream.zIndex = 19;
    this.world.addChild(this.stream);
  }

  /** The three lanes, top to bottom. */
  private get lanes(): [number, number, number] {
    const { y, height } = this.play;
    return [y + height * 0.2, y + height * 0.5, y + height * 0.8];
  }

  private get swimmerX(): number { return this.play.x + this.play.width * 0.22; }
  private get gateX(): number { return this.play.x + this.play.width * 0.74; }
  private get gateSize(): number { return Math.min(this.play.height * 0.34, 170); }

  protected layout(): void {
    const lanes = this.lanes;
    this.mosey.resize(Math.min(this.play.height * 0.5, 240));
    this.otter.resize(this.mosey.size * 0.42);
    this.otter.position.set(-this.mosey.size * 0.06, -this.mosey.size * 0.02);
    if (this.targetY === 0) this.targetY = lanes[1];
    // The play area shrinks when the speech panel appears; keep Mosey in view above it.
    this.targetY = Math.min(Math.max(this.targetY, lanes[0]), lanes[2]);
    this.mosey.position.set(this.swimmerX, this.targetY);
    if (this.phase === "choosing") this.gates.forEach((gate, index) => { gate.position.set(this.gateX, lanes[index]!); gate.scale.set(this.gateSize / this.originalGateSize); });
  }

  protected present(question: Question): void {
    this.phase = "arriving";
    this.gates.forEach((gate) => gate.destroy({ children: true }));
    const size = this.gateSize;
    this.originalGateSize = size;
    this.gates = question.choices.map((choice, index) => {
      const gate = new Container();
      gate.label = choice;
      for (let petal = 0; petal < 8; petal += 1) {
        const decoration = iconSprite(this.theme.gateDecoration, size * 0.28);
        const angle = petal * Math.PI / 4;
        decoration.position.set(Math.cos(angle) * size * 0.36, Math.sin(angle) * size * 0.36);
        gate.addChild(decoration);
      }
      const plate = this.makeSign(choice, size * 0.7, size * 0.46, size * 0.46 * 0.66);
      gate.addChild(plate);
      const y = this.lanes[index] ?? this.lanes[1];
      gate.position.set(this.width + size, y);
      gate.zIndex = 15;
      this.world.addChild(gate);
      run(gate, moveTo(this.gateX, y, options.reducedMotion ? 0.3 : 1, easeOut), "travel");
      return gate;
    });
    this.targetPace = 40;
    this.after(1, () => { if (this.phase === "arriving") { this.phase = "choosing"; this.layout(); } });
  }

  // Touch and mouse

  private lane(y: number): number {
    const distances = this.lanes.map((lane) => Math.abs(lane - y));
    return distances.indexOf(Math.min(...distances));
  }

  private clampY(y: number): number {
    const { y: top, height, bottom } = this.play;
    return Math.min(Math.max(y, top + height * 0.14), bottom - height * 0.14);
  }

  override pointerDown(x: number, y: number): void {
    const hit = this.pearls.find((item) => Math.hypot(item.x - x, item.y - y) <= Math.max(24, item.width * 0.6));
    if (hit) {
      this.collect(hit);
      this.pearls = this.pearls.filter((item) => item !== hit);
      return;
    }
    if (this.phase === "choosing" && x > this.swimmerX + this.mosey.size * 0.5) this.choose(this.lane(y));
    else this.targetY = this.clampY(y);
  }

  override pointerMove(_x: number, y: number): void {
    // Swipe or drag anywhere to steer Mosey up and down.
    if (this.phase !== "dashing") this.targetY = this.clampY(y);
  }

  private choose(index: number): void {
    const question = this.current;
    const gate = this.gates[index];
    if (!question || !gate || gate.alpha !== 1) return;
    this.targetY = this.lanes[index]!;
    audio.play("swim", 0.7);
    if (isCorrectChoice(question, gate.label)) {
      this.dash(gate);
    } else {
      // The tunnel fizzes shut: no harm done.
      run(gate, sequence(wobble(), fadeTo(0.35, 0.2)), "shut");
      burst(this.world, gate.x, gate.y, "#ffffff", 10);
      this.slip();
    }
  }

  private dash(gate: Container): void {
    this.phase = "dashing";
    this.targetPace = 620;
    this.pace = 520;
    this.stream.birthRate = options.reducedMotion ? 30 : 160;
    const outcome = this.succeed(this.swimmerX + this.mosey.size * 0.4, gate.y);
    rainbowBurst(this.world, gate.x, gate.y, 36);
    this.cameraPunch();
    for (const other of this.gates) {
      const exit = moveTo(-this.gateSize * 1.5, other.y, 0.55, easeIn);
      run(other, sequence(other === gate ? exit : group(exit, fadeOut(0.3)), remove()), "travel");
    }
    this.gates = [];
    const done = outcome?.isLevelComplete ?? false;
    this.after(0.7, () => {
      this.stream.birthRate = 0;
      this.targetPace = 170;
      this.phase = "cruising";
      if (done) {
        this.finishLevel(0.3);
        return;
      }
      this.spawnPearls();
      this.after(3.6, () => this.askNext());
    });
  }

  private spawnPearls(): void {
    this.bridge.set({ caption: this.theme.collectInstruction });
    const lane = this.lanes[Math.floor(Math.random() * 3)]!;
    const size = this.gateSize * 0.36;
    this.pearlsOffered += 5;
    for (let index = 0; index < 5; index += 1) {
      const pearl = iconSprite(this.theme.collectible, size);
      pearl.anchor.set(0.5);

      const wave = Math.sin(index * 0.9) * this.play.height * 0.12;
      pearl.position.set(this.width + 30 + index * this.gateSize * 0.6, this.clampY(lane - wave));
      pearl.zIndex = 14;
      this.world.addChild(pearl);
      this.pearls.push(pearl);
    }
  }

  private collect(item: Sprite): void {
    if (this.theme.id === "woods" || this.theme.id === "candy") this.mosey.chew(0.44, this.theme.id === "woods");
    this.pearlsScooped += 1;
    audio.play("pop", 0.6);
    burst(this.world, item.x, item.y, this.theme.tint, 8);
    item.destroy();
  }

  // Frame loop

  protected override update(dt: number): void {
    const delta = Math.min(dt, 1 / 20);
    this.pace += (this.targetPace - this.pace) * Math.min(delta * 3, 1);
    this.backdrop.scroll(this.pace * delta);
    const mosey = this.mosey;
    const y = mosey.y + (this.targetY - mosey.y) * Math.min(delta * 9, 1);
    mosey.position.set(this.swimmerX, y);
    // Nose up when climbing, down when diving.
    mosey.rotation = Math.max(-0.3, Math.min(0.3, (this.targetY - y) * 0.006));
    this.stream.position.set(this.swimmerX - mosey.size * 0.4, y);

    this.pearls = this.pearls.filter((pearl) => {
      pearl.x -= 280 * delta;
      const scooped = Math.abs(pearl.x - this.swimmerX) < mosey.size * 0.45 && Math.abs(pearl.y - y) < mosey.size * 0.3;
      if (scooped) {
        this.collect(pearl);
        return false;
      }
      if (!scooped && pearl.x >= -40) return true;
      pearl.destroy();
      return false;
    });
  }
}
