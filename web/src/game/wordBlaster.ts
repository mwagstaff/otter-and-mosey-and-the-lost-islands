import { Container, Sprite } from "pixi.js";
import { accepts, type Question } from "../core";
import { call, easeInOut, easeOut, moveBy, moveTo, repeatForever, run, scaleToXY, sequence, stopAll, wobble } from "../engine/actions";
import { bubble, mix, palette, panel } from "../engine/art";
import { Emitter } from "../engine/particles";
import { audio } from "./audio";
import { rainbowBurst } from "./effects";
import { GameScene } from "./gameScene";
import { options } from "./options";
import { WordSlots } from "./wordSlots";

/**
 * Game mode A. A magical bubble floats up holding a word with letters missing.
 * Typing the right letters pops it.
 */
export class WordBlasterScene extends GameScene {
  private bubble?: Container;
  private slots?: WordSlots;
  private typedIndex = 0;
  private drift!: Emitter;

  protected build(): void {
    this.world.addChild(this.otter, this.mosey);
    this.mosey.facingLeft = true;
    // Small empty bubbles drifting up behind the action.
    this.drift = new Emitter({
      texture: bubble(mix(this.theme.tint, "#ffffff", 0.6)), birthRate: options.reducedMotion ? 0.3 : 1.2, lifetime: 9,
      speed: 46, speedRange: 20, angle: Math.PI / 2, angleRange: 0.35, scale: 0.16, scaleRange: 0.1, alpha: 0.7, alphaSpeed: -0.06,
    });
    this.drift.zIndex = 2;
    this.world.addChild(this.drift);
  }

  protected layout(): void {
    const play = this.play;
    this.otter.resize(Math.min(play.height * 0.44, 250));
    this.mosey.resize(Math.min(play.height * 0.62, 370));
    this.otter.position.set(play.x + play.width * 0.1, this.groundY);
    this.mosey.position.set(play.right - play.width * 0.12, this.groundY - this.mosey.size * 0.26);
    this.drift.position.set(play.midX, play.bottom + 20);
    this.drift.positionRange = { x: play.width, y: 0 };
    if (this.bubble) {
      stopAll(this.bubble);
      this.bubble.position.set(play.midX, this.bubbleY);
      this.float(this.bubble);
    }
  }

  private get bubbleY(): number {
    return this.play.bottom - this.play.height * 0.56;
  }

  /** Bubbles bob gently while they wait. */
  private float(node: Container): void {
    if (options.reducedMotion) return;
    run(node, repeatForever(sequence(moveBy(0, -9, 1.2, easeInOut), moveBy(0, 9, 1.2, easeInOut))), "float");
  }

  protected present(question: Question): void {
    this.typedIndex = 0;
    const play = this.play;
    const masked = question.masked ?? "_".repeat(question.typingTarget.length);
    const count = [...masked].length;
    const diameter = Math.min(play.height * 0.7, 380);
    const letterWidth = Math.min(diameter * 0.2, (play.width * 0.6) / count);
    const width = Math.max(diameter, count * letterWidth + diameter * 0.42);
    const contrast = options.settings.highContrast;

    const node = new Container();
    const shell = new Container();
    const glass = new Sprite(bubble(mix(this.theme.tint, "#ffffff", 0.55)));
    glass.anchor.set(0.5);
    glass.setSize(width, diameter);
    shell.addChild(glass);
    const plate = new Sprite(panel(count * letterWidth + 26, letterWidth * 1.75, "#FFFDF3", palette.ink, 16, 3));
    plate.anchor.set(0.5);
    plate.alpha = contrast ? 1 : 0.94;
    const word = new WordSlots(masked, question.answer, letterWidth, contrast ? "#000000" : palette.ink, "#E8743B");
    node.addChild(shell, plate, word);
    this.slots = word;

    node.position.set(play.midX, play.bottom + diameter);
    node.zIndex = 20;
    this.world.addChild(node);
    this.bubble?.destroy({ children: true });
    this.bubble = node;

    run(node, sequence(moveTo(play.midX, this.bubbleY, options.reducedMotion ? 0.2 : 0.7, easeOut), call(() => {
      this.float(node);
      if (!options.reducedMotion) {
        run(shell, repeatForever(sequence(scaleToXY(1.03, 0.97, 0.9, easeInOut), scaleToXY(0.98, 1.02, 0.9, easeInOut))), "squish");
      }
    })), "rise");
    audio.play("whoosh", 0.5);
    if (question.flashThenHide) word.flashWord(2.6);
  }

  protected override caption(question: Question): string {
    return question.flashThenHide ? `Look, then spell it: ${question.prompt}` : question.prompt;
  }

  protected override handleKey(character: string): void {
    const question = this.current;
    if (!question || !this.slots || !/^\p{L}$/u.test(character)) return;
    if (accepts(question, character, this.typedIndex)) {
      this.accept(character, question, this.slots);
    } else {
      this.slots.flashWrong(character);
      if (this.bubble) run(this.bubble, wobble(), "wobble");
      this.slip();
    }
  }

  private accept(character: string, question: Question, slots: WordSlots): void {
    slots.fillNext(character);
    this.typedIndex += 1;
    audio.play("key", 0.6);
    if (this.typedIndex >= [...question.typingTarget].length) this.pop();
  }

  /**
   * A hint fills in the next letter, or shows the whole word again for look-cover-write.
   * It never types the final letter: that would finish the word for the child and count as a pop,
   * so the last letter is flashed up for them to type themselves.
   */
  protected override applyHint(): void {
    const question = this.current;
    if (!question || !this.slots) return;
    const target = [...question.typingTarget];
    const next = target[this.typedIndex];
    if (question.flashThenHide || next === undefined || this.typedIndex >= target.length - 1) {
      this.slots.flashWord(2.2);
    } else {
      this.accept(next, question, this.slots);
    }
  }

  private pop(): void {
    const node = this.bubble;
    if (!node) return;
    const outcome = this.succeed(node.x, node.y);
    audio.play("pop");
    rainbowBurst(this.world, node.x, node.y, 48);
    this.cameraPunch();
    stopAll(node);
    this.popAway(node);
    this.bubble = undefined;
    this.slots = undefined;
    if (outcome?.isLevelComplete) this.finishLevel();
    else this.after(0.9, () => this.askNext());
  }
}
