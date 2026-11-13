import { Container, Sprite } from "pixi.js";
import { hasArt } from "../assets";
import { isCorrectTyped, type Question } from "../core";
import {
  call, easeIn, easeInOut, fadeOut, group, moveBy, moveTo, pop, remove, repeat, rotateTo, run, scaleTo, scaleToXY, sequence, wait, wobble,
} from "../engine/actions";
import { texture, tintByTurn } from "../engine/art";
import { audio } from "./audio";
import { rainbowBurst } from "./effects";
import { GameScene, type Sign } from "./gameScene";
import { options } from "./options";

interface Look {
  art: string;
  turn: number;
  size: number;
}

/**
 * Game mode D. Something is locked away (a dragon egg, a treasure chest, a sweet jar).
 * Typing the answer on the number pad cracks it open and a new friend pops out to join
 * the rescued row. Recall, not multiple choice.
 */
export class EggRescueScene extends GameScene {
  private container?: Container;
  private sign?: Sign;
  private entryBoxes: Sign[] = [];
  private entry = "";
  private readonly rescued: Container[] = [];
  private busy = false;
  private looks: Look[] = [];

  override art(): string[] {
    return [...super.art(), this.theme.container, ...this.theme.friends];
  }

  /**
   * Deals friends from a shuffled set of every shape in a handful of colours, so the same
   * one does not come out twice until all the others have had a turn.
   */
  private nextLook(): Look {
    if (this.looks.length === 0) {
      const turns = [0, 0.12, 0.3, 0.5, 0.68, 0.85];
      const shapes = this.theme.friends.filter(hasArt);
      this.looks = shapes.flatMap((art) => turns.map((turn) => ({ art, turn, size: 0.8 + Math.random() * 0.35, order: Math.random() })))
        // Shuffled, but each level starts with the friends in their own colours (dealt from the end).
        .sort((a, b) => (a.turn === 0 ? 1 : 0) - (b.turn === 0 ? 1 : 0) || a.order - b.order);
    }
    return this.looks.pop()!;
  }

  protected build(): void {
    this.world.addChild(this.otter, this.mosey);
    this.mosey.facingLeft = true;
  }

  private get containerSize(): number { return Math.min(this.play.height * 0.46, 220); }
  private get homeX(): number { return this.play.midX; }
  private get homeY(): number { return this.groundY - this.containerSize * 0.5; }
  private get signY(): number { return this.play.y + this.play.height * 0.1; }
  private get friendSize(): number { return Math.min(this.play.height * 0.15, 64); }

  /** Rescued friends line up along the top-left, wrapping under if there are many. */
  private perch(index: number): { x: number; y: number } {
    const step = this.friendSize * 1.05;
    const perRow = Math.max(Math.floor((this.play.width * 0.3) / step), 3);
    return {
      x: this.play.x + this.friendSize * 0.7 + (index % perRow) * step,
      y: this.play.y + this.friendSize * 0.7 + Math.floor(index / perRow) * step,
    };
  }

  protected layout(): void {
    const play = this.play;
    this.otter.resize(Math.min(play.height * 0.4, 180));
    this.mosey.resize(Math.min(play.height * 0.56, 260));
    this.otter.position.set(play.midX - this.containerSize * 1.15, this.groundY);
    this.mosey.position.set(play.midX + this.containerSize * 1.3, this.groundY - this.mosey.size * 0.24);
    this.container?.position.set(this.homeX, this.homeY);
    this.sign?.position.set(play.midX, this.signY);
    this.rescued.forEach((friend, index) => friend.position.copyFrom(this.perch(index)));
    this.layoutEntry();
  }

  protected override caption(question: Question): string {
    return question.prompt.length <= 22 ? "Type the answer to open it!" : question.prompt;
  }

  protected present(question: Question): void {
    const play = this.play;
    this.busy = false;
    this.entry = "";
    this.sign?.destroy({ children: true });
    const text = question.prompt.length <= 22 ? question.prompt : "?";
    const fontSize = Math.min(play.height * 0.11, 44);
    const board = this.makeSign(text, Math.min(text.length * fontSize * 0.68 + 56, play.width * 0.6), fontSize * 1.7, fontSize);
    board.position.set(play.midX, this.signY);
    board.zIndex = 16;
    board.scale.set(0);
    this.world.addChild(board);
    run(board, pop());
    this.sign = board;

    this.container?.destroy({ children: true });
    const picture = new Sprite(texture(this.theme.container));
    picture.anchor.set(0.5);
    picture.scale.set(this.containerSize / Math.max(picture.texture.width, picture.texture.height));
    const node = new Container();
    node.addChild(picture);
    node.position.set(this.homeX, -this.containerSize);
    node.zIndex = 12;
    this.world.addChild(node);
    this.container = node;
    run(node, sequence(
      moveTo(this.homeX, this.homeY, options.reducedMotion ? 0.15 : 0.4, easeIn),
      scaleToXY(1.12, 0.88, 0.08), scaleToXY(1, 1, 0.12),
    ));
    this.buildEntry([...question.typingTarget].length);
  }

  // Answer boxes

  private buildEntry(length: number): void {
    this.entryBoxes.forEach((box) => box.destroy({ children: true }));
    const side = Math.min(this.play.height * 0.17, 66);
    this.entryBoxes = Array.from({ length }, () => {
      const box = this.makeSign("", side, side * 1.1, side * 0.7, undefined, undefined, 10);
      box.zIndex = 18;
      this.world.addChild(box);
      return box;
    });
    this.layoutEntry();
  }

  private layoutEntry(): void {
    const first = this.entryBoxes[0];
    if (!first) return;
    const step = first.boxWidth * 1.12;
    this.entryBoxes.forEach((box, index) => {
      box.position.set(this.homeX + (index - (this.entryBoxes.length - 1) / 2) * step, this.homeY + this.containerSize * 0.08);
    });
  }

  private showEntry(): void {
    const digits = [...this.entry];
    this.entryBoxes.forEach((box, index) => { box.words.string = digits[index] ?? ""; });
  }

  protected override handleKey(character: string): void {
    const question = this.current;
    if (!question || this.busy || !/^\d$/.test(character)) return;
    const length = [...question.typingTarget].length;
    if (this.entry.length >= length) return;
    this.entry += character;
    this.showEntry();
    audio.play("key", 0.6);
    if (this.entry.length < length) return;
    this.busy = true;
    if (isCorrectTyped(question, this.entry)) {
      this.hatch();
      return;
    }
    if (this.container) run(this.container, wobble(10), "wobble");
    this.entryBoxes.forEach((box) => run(box, wobble(5), "wobble"));
    this.slip();
    this.after(0.5, () => {
      this.entry = "";
      this.showEntry();
      this.busy = false;
    });
  }

  protected override handleBackspace(): void {
    if (this.busy || this.entry === "") return;
    this.entry = this.entry.slice(0, -1);
    this.showEntry();
  }

  private hatch(): void {
    const node = this.container;
    if (!node) return;
    const { x, y } = node;
    const outcome = this.succeed(x, y);
    audio.play("crack");
    this.entryBoxes.forEach((box) => run(box, sequence(fadeOut(0.25), remove())));
    this.entryBoxes = [];
    if (this.sign) run(this.sign, sequence(fadeOut(0.25), remove()));
    this.sign = undefined;
    run(node, sequence(
      repeat(sequence(rotateTo(0.14, 0.06), rotateTo(-0.14, 0.06)), 4),
      rotateTo(0, 0.04),
      call(() => {
        rainbowBurst(this.world, x, y, 54);
        this.cameraPunch();
        audio.play("chirp");
      }),
      group(scaleTo(1.4, 0.18), fadeOut(0.18)),
      remove(),
    ));
    this.container = undefined;

    // Every rescue is a small surprise: a different friend, colour and size each time.
    const look = this.nextLook();
    const picture = new Sprite(texture(look.art));
    picture.anchor.set(0.5);
    tintByTurn(picture, look.turn);
    const big = (this.containerSize * 0.8) / Math.max(picture.texture.width, picture.texture.height);
    picture.scale.set(Math.random() < 0.5 ? -big : big, big);
    const friend = new Container();
    friend.addChild(picture);
    friend.position.set(x, y);
    friend.zIndex = 22;
    friend.scale.set(0);
    this.world.addChild(friend);
    const index = this.rescued.length;
    this.rescued.push(friend);
    const small = (this.friendSize * look.size) / (this.containerSize * 0.8);
    const hop = () => sequence(moveBy(0, -16, 0.14), moveBy(0, 16, 0.14));
    run(friend, sequence(
      wait(0.55),
      scaleTo(1.15, 0.18), scaleTo(1, 0.1),
      hop(), hop(),
      // Look up the perch when the time comes, in case the page was resized meanwhile.
      (target) => {
        const perch = this.perch(index);
        return group(moveTo(perch.x, perch.y, 0.45, easeInOut), scaleTo(small, 0.45))(target);
      },
    ));
    if (outcome?.isLevelComplete) this.finishLevel(1.8);
    else this.after(1.9, () => this.askNext());
  }
}
