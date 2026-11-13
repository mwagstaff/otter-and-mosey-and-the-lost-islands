import { Container, Sprite } from "pixi.js";
import { accepts, isCorrectChoice, subjectOf, type Question } from "../core";
import {
  call, easeIn, easeInOut, fadeOut, fadeTo, group, moveBy, moveTo, pop, remove, repeat, repeatForever, rotateBy, rotateTo, run, scaleTo,
  scaleToXY, sequence, stopAll, wait, wobble,
} from "../engine/actions";
import { circle, glow, iconSprite, mix, palette, rainbowArc, texture } from "../engine/art";
import { GameLabel } from "../engine/label";
import { audio } from "./audio";
import { SpeechBadge } from "./character";
import { floatPicture, rainbowBurst, trail } from "./effects";
import { GameScene, type Sign } from "./gameScene";
import { options } from "./options";
import { WordSlots } from "./wordSlots";

const distance = (a: { x: number; y: number }, b: { x: number; y: number }) => Math.hypot(a.x - b.x, a.y - b.y);

/**
 * Game mode F. The island's guardian is muddled, grumpy or lonely rather than dangerous.
 * Right answers charge the Friendship Power meter; when it is full, Otter and Mosey
 * perform a joint special move. Three rounds win the guardian over and reveal the crystal fragment.
 */
export class GuardianScene extends GameScene {
  /** Reactions turn and squash this; the breathing layer inside carries the picture. */
  private readonly guardian = new Container();
  private readonly breath = new Container();
  private readonly picture = new Sprite();
  private readonly badge = new SpeechBadge("guardian");
  private guardianWidth = 1;
  private sign?: Sign;
  private slots?: WordSlots;
  private orbs: Container[] = [];
  private typedIndex = 0;
  private phase = 0;
  private charge = 0;
  private powerButton?: Sign;
  private crystal?: Container;
  private acceptingAnswers = false;

  private get perPhase(): number { return Math.max(1, this.session.total / 3); }

  override art(): string[] {
    return [...super.art(), this.theme.guardian, this.theme.guardianHappy, "crystal_shard",
      "icon_1f300", "icon_1f496", "icon_1f49e", "icon_1f308", "icon_1f4ab", "icon_1f602"];
  }

  protected build(): void {
    this.picture.texture = texture(this.theme.guardian);
    this.picture.anchor.set(0.5, 1);
    this.breath.addChild(this.picture);
    this.guardian.addChild(this.breath);
    this.guardian.zIndex = 9;
    // Otter stands in front of Mosey, who floats just behind his shoulder.
    this.otter.zIndex = 1;
    this.world.addChild(this.otter, this.mosey, this.guardian, this.badge);
    this.bridge.set({ friendship: 0 });
    if (!options.reducedMotion) {
      run(this.breath, repeatForever(sequence(scaleToXY(1, 1.03, 1.4, easeInOut), scaleToXY(1, 1, 1.4, easeInOut))), "breathe");
    }
  }

  private get guardianHeight(): number { return Math.min(this.play.height * 0.74, 520); }
  private get signX(): number { return this.play.x + this.play.width * 0.5; }
  private get signY(): number { return this.play.y + this.play.height * 0.16; }
  private get orbSize(): number { return Math.min(this.play.height * 0.3, 170); }

  protected layout(): void {
    const play = this.play;
    const height = this.guardianHeight;
    this.guardianWidth = (height * this.picture.texture.width) / this.picture.texture.height;
    this.picture.setSize(this.guardianWidth, height);
    this.guardian.position.set(play.right - Math.max(this.guardianWidth * 0.52, play.width * 0.14), this.groundY);
    this.badge.resize(Math.min(Math.max(play.height * 0.22, 56), 120));
    this.badge.position.set(this.guardian.x - this.guardianWidth * 0.42, this.guardian.y - height * 0.78);
    this.otter.resize(Math.min(play.height * 0.36, 250));
    this.mosey.resize(Math.min(play.height * 0.46, 330));
    this.otter.position.set(play.x + play.width * 0.1, this.groundY);
    this.mosey.position.set(play.x + play.width * 0.2, this.groundY - play.height * 0.27);
    this.sign?.position.set(this.signX, this.signY);
    this.layoutOrbs();
  }

  protected override start(): void {
    audio.play("guardian");
    this.bridge.say([this.options.island.guardian.phases[0]!], () => this.askNext());
  }

  // Questions

  protected override caption(question: Question): string {
    if (subjectOf(question.skill) === "spelling") return question.prompt;
    return question.prompt.length <= 22 ? "Tap the right answer to charge Friendship Power!" : question.prompt;
  }

  protected present(question: Question): void {
    this.typedIndex = 0;
    this.acceptingAnswers = false;
    this.clearQuestion();

    // The guardian lobs a harmless muddle that becomes the question.
    const muddle = new Container();
    muddle.addChild(iconSprite("🌀", 44));
    muddle.position.set(this.guardian.x - this.guardianWidth * 0.3, this.guardian.y - this.guardianHeight * 0.6);
    muddle.zIndex = 30;
    this.world.addChild(muddle);
    run(this.guardian, sequence(rotateTo(-0.06, 0.1), rotateTo(0, 0.15)), "react");
    audio.play("whoosh", 0.5);
    run(muddle, sequence(
      group(moveTo(this.signX, this.signY, options.reducedMotion ? 0.15 : 0.45, easeInOut), rotateBy(-6, 0.45)),
      call(() => this.reveal(question)),
      remove(),
    ));
  }

  private reveal(question: Question): void {
    const play = this.play;
    this.acceptingAnswers = true;
    const fontSize = Math.min(play.height * 0.1, 56);
    if (question.format === "typed") {
      const masked = question.masked ?? "_".repeat([...question.typingTarget].length);
      const count = [...masked].length;
      const letterWidth = Math.min(fontSize * 0.95, (play.width * 0.5) / count);
      const board = this.makeSign("", count * letterWidth + 40, letterWidth * 1.9, fontSize);
      const contrast = options.settings.highContrast;
      const word = new WordSlots(masked, question.answer, letterWidth, contrast ? "#000000" : palette.ink, "#E8743B");
      board.addChild(word);
      this.slots = word;
      this.show(board);
      if (question.flashThenHide) word.flashWord(2.6);
      return;
    }
    const text = question.prompt.length <= 22 ? question.prompt : "?";
    this.show(this.makeSign(text, Math.min(text.length * fontSize * 0.7 + 56, play.width * 0.5), fontSize * 1.8, fontSize));
    const size = this.orbSize;
    this.orbs = question.choices.map((choice, index) => {
      const orb = new Container();
      orb.label = choice;
      const ball = new Sprite(circle(160, mix(this.theme.tint, "#ffffff", 0.25)));
      ball.anchor.set(0.5);
      ball.setSize(size, size);
      orb.addChild(ball, new GameLabel(choice, size * (choice.length > 3 ? 0.28 : 0.4), "#ffffff"));
      orb.zIndex = 22;
      orb.scale.set(0);
      this.world.addChild(orb);
      run(orb, sequence(wait(0.07 * (index + 1)), pop()), "pop");
      return orb;
    });
    this.layoutOrbs();
  }

  private show(board: Sign): void {
    board.position.set(this.signX, this.signY);
    board.zIndex = 21;
    board.scale.set(0);
    this.world.addChild(board);
    run(board, pop());
    this.sign = board;
  }

  private layoutOrbs(): void {
    const count = this.orbs.length;
    this.orbs.forEach((orb, index) => {
      orb.position.set(this.signX + (index - (count - 1) / 2) * this.orbSize * 1.25, this.signY + this.play.height * 0.36);
    });
  }

  private clearQuestion(): void {
    for (const node of [this.sign, ...this.orbs]) if (node) run(node, sequence(fadeOut(0.15), remove()), "leave");
    this.sign = undefined;
    this.slots = undefined;
    this.orbs = [];
  }

  // Input

  protected override handleKey(character: string): void {
    const question = this.current;
    if (!this.acceptingAnswers || !question || question.format !== "typed" || !this.slots || !/^\p{L}$/u.test(character)) return;
    if (accepts(question, character, this.typedIndex)) {
      this.typeNext(character, question, this.slots);
    } else {
      this.slots.flashWrong(character);
      this.giggle();
      this.slip();
    }
  }

  private typeNext(character: string, question: Question, slots: WordSlots): void {
    slots.fillNext(character);
    this.typedIndex += 1;
    audio.play("key", 0.6);
    if (this.typedIndex >= [...question.typingTarget].length) this.answered(this.signX, this.signY);
  }

  protected override applyHint(): void {
    const question = this.current;
    if (!question || question.format !== "typed" || !this.slots || !this.acceptingAnswers) return;
    if (question.flashThenHide) {
      this.slots.flashWord(2.2);
    } else {
      const next = [...question.typingTarget][this.typedIndex];
      if (next !== undefined) this.typeNext(next, question, this.slots);
    }
  }

  override pointerDown(x: number, y: number): void {
    const point = { x, y };
    if (this.crystal && distance(this.crystal, point) < Math.max(this.play.height * 0.36, 90)) {
      this.collectCrystal();
      return;
    }
    const button = this.powerButton;
    if (button && Math.abs(x - button.x) < button.boxWidth / 2 + 24 && Math.abs(y - button.y) < button.boxHeight / 2 + 24) {
      this.unleashFriendshipPower();
      return;
    }
    const question = this.current;
    if (!this.acceptingAnswers || !question || question.format !== "choice") return;
    const orb = this.orbs.filter((each) => each.alpha === 1).sort((a, b) => distance(a, point) - distance(b, point))[0];
    if (!orb || distance(orb, point) >= this.orbSize * 0.8) return;
    if (isCorrectChoice(question, orb.label)) {
      run(orb, pop(1.15), "pop");
      this.answered(orb.x, orb.y);
    } else {
      run(orb, sequence(wobble(), fadeTo(0.35, 0.2)), "pop");
      this.giggle();
      this.slip();
    }
  }

  private giggle(): void {
    if (options.reducedMotion) return;
    run(this.guardian, sequence(rotateTo(0.05, 0.08), rotateTo(-0.05, 0.08), rotateTo(0, 0.08)), "react");
  }

  private answered(x: number, y: number): void {
    this.acceptingAnswers = false;
    const outcome = this.succeed(x, y);
    this.charge = Math.min(1, this.charge + 1 / this.perPhase);
    this.bridge.set({ friendship: this.charge });
    // A spark of friendship flies to the heroes each time.
    const spark = new Container();
    spark.addChild(iconSprite("💖", 36));
    spark.position.set(x, y);
    spark.zIndex = 40;
    this.world.addChild(spark);
    run(spark, sequence(moveTo(this.otter.x, this.otter.y - this.otter.size * 0.7, 0.45, easeInOut), remove()));
    const full = this.charge >= 0.999 || (outcome?.isLevelComplete ?? false);
    this.after(0.9, () => {
      this.clearQuestion();
      if (full) this.offerFriendshipPower();
      else this.askNext();
    });
  }

  // Friendship Power

  private offerFriendshipPower(): void {
    const play = this.play;
    this.bridge.set({ keyboard: { kind: "none" }, friendship: 1, caption: "Friendship Power is ready. Tap it!" });
    audio.play("portal");
    const width = Math.min(play.width * 0.46, 380);
    const height = Math.min(play.height * 0.24, 96);
    const button = this.makeSign("Friendship Power!", width, height, height * 0.36, "#FF7EB6", "#ffffff");
    for (const side of [-1, 1]) {
      const hearts = iconSprite("💞", height * 0.62);
      hearts.position.set(side * width * 0.5, -height * 0.34);
      hearts.rotation = side * 0.25;
      button.addChild(hearts);
    }
    button.position.set(play.midX, play.y + play.height / 2);
    button.zIndex = 50;
    button.scale.set(0);
    this.world.addChild(button);
    const pulse = options.reducedMotion ? [] : [repeatForever(sequence(scaleTo(1.07, 0.45, easeInOut), scaleTo(1, 0.45, easeInOut)))];
    run(button, sequence(pop(), ...pulse), "pulse");
    this.powerButton = button;
  }

  private unleashFriendshipPower(): void {
    const button = this.powerButton;
    if (!button) return;
    this.powerButton = undefined;
    run(button, sequence(group(scaleTo(1.5, 0.2), fadeOut(0.2)), remove()), "pulse");
    this.bridge.friendshipUses += 1;
    this.bridge.set({ caption: "Friendship Power!" });
    audio.play("friendship");
    this.otter.celebrate();
    this.mosey.celebrate();

    // Otter and Mosey spin a rainbow between them and send it across to the guardian.
    const fromX = (this.otter.x + this.mosey.x) / 2;
    const toX = this.guardian.x;
    const toY = this.guardian.y - this.guardianHeight * 0.55;
    const beam = trail(this.world, {
      birthRate: options.reducedMotion ? 40 : 320, lifetime: 0.9, scale: 0.8, angleRange: Math.PI * 2, speed: 60,
    });
    beam.position.set(fromX, this.mosey.y);
    beam.zIndex = 45;
    const bow = iconSprite("🌈", 80);
    beam.addChild(bow);
    this.world.addChild(beam);
    run(beam, sequence(
      moveTo(fromX + 40, this.play.y + 60, 0.35, easeInOut),
      moveTo(toX, toY, 0.4, easeIn),
      call(() => {
        this.guardianReacts(toX, toY);
        beam.birthRate = 0;
        bow.visible = false;
      }),
      wait(1),
      remove(),
    ));
    run(bow, rotateBy(Math.PI * 2, 0.35));
  }

  private guardianReacts(x: number, y: number): void {
    rainbowBurst(this.world, x, y, 90);
    this.cameraPunch(0.93, 0.15);
    audio.play("guardian");
    const emoji = ["💫", "😂", "💖"][Math.min(this.phase, 2)]!;
    floatPicture(this.world, emoji, x, y - this.guardianHeight * 0.35, Math.min(this.play.height * 0.26, 110));
    if (!options.reducedMotion) {
      run(this.guardian, sequence(
        scaleToXY(1.15, 0.85, 0.1), scaleToXY(0.92, 1.1, 0.12), scaleToXY(1, 1, 0.12),
        repeat(sequence(rotateTo(0.09, 0.09), rotateTo(-0.09, 0.09)), 3),
        rotateTo(0, 0.08),
      ), "react");
    }
    const { startRestoration, endRestoration, island } = this.options;
    this.backdrop.setRestoration(startRestoration + ((endRestoration - startRestoration) * (this.phase + 1) * 0.9) / 3);
    this.bloom(4);
    this.phase += 1;
    this.charge = 0;
    this.after(1.3, () => {
      this.bridge.set({ friendship: 0 });
      if (this.phase < 3 && !this.session.isFinished) {
        const lines = island.guardian.phases;
        this.bridge.say([lines[Math.min(this.phase, lines.length - 1)]!], () => this.askNext());
      } else {
        this.befriend();
      }
    });
  }

  // Ending

  private befriend(): void {
    this.bridge.set({ friendship: undefined });
    this.picture.texture = texture(this.theme.guardianHappy);
    this.layout();
    run(this.guardian, pop(), "react");
    rainbowBurst(this.world, this.guardian.x, this.guardian.y - this.guardianHeight * 0.5, 60);
    audio.play("unlock");
    this.bridge.say(this.options.island.guardian.befriended, () => this.revealCrystal());
  }

  private revealCrystal(): void {
    const play = this.play;
    const colour = this.options.island.colour;
    const height = Math.min(play.height * 0.36, 280);
    const shard = new Container();
    const halo = new Sprite(glow());
    halo.anchor.set(0.5);
    halo.setSize(height * 1.7, height * 1.7);
    halo.alpha = 0.6;
    halo.tint = colour;
    halo.blendMode = "add";
    const gem = new Sprite(texture("crystal_shard"));
    gem.anchor.set(0.5);
    gem.setSize((height * gem.texture.width) / gem.texture.height, height);
    gem.tint = mix("#ffffff", colour, 0.55);
    shard.addChild(halo, gem);
    shard.position.set(this.guardian.x - this.guardianWidth * 0.2, this.guardian.y - this.guardianHeight * 0.6);
    shard.zIndex = 48;
    shard.scale.set(0.2);
    this.world.addChild(shard);
    const float = options.reducedMotion ? [] : [repeatForever(sequence(moveBy(0, -10, 0.8, easeInOut), moveBy(0, 10, 0.8, easeInOut)))];
    run(shard, sequence(group(moveTo(play.midX, play.y + play.height / 2, 0.8, easeInOut), scaleTo(1, 0.8)), ...float), "float");
    this.crystal = shard;
    this.bridge.set({ caption: "Tap the crystal fragment!" });
    audio.play("portal");
  }

  private collectCrystal(): void {
    const shard = this.crystal;
    if (!shard) return;
    this.crystal = undefined;
    audio.play("crystal");
    rainbowBurst(this.world, shard.x, shard.y, 120);
    stopAll(shard);
    run(shard, sequence(group(scaleTo(1.8, 0.3), rotateBy(Math.PI, 0.3)), group(scaleTo(0, 0.3), fadeOut(0.3)), remove()));
    // The whole island floods back to colour under a rainbow.
    const arc = new Sprite(rainbowArc());
    arc.anchor.set(0.5, 1);
    arc.setSize(this.width * 0.9, this.width * 0.45);
    arc.position.set(this.width / 2, this.groundY);
    arc.zIndex = -50;
    arc.alpha = 0;
    this.world.addChild(arc);
    run(arc, fadeTo(0.7, 1.2));
    this.bloom(8);
    this.bridge.set({ caption: `${this.options.island.name} is full of colour again!` });
    this.finishLevel(0.5);
  }
}
