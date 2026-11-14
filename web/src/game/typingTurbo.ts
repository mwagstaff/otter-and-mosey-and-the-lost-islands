import { Container, Sprite } from "pixi.js";
import { accepts, TypingMeter, type Question } from "../core";
import { fadeOut, pop, remove, run, sequence, wait } from "../engine/actions";
import { iconSprite, palette, panel, texture } from "../engine/art";
import { GameLabel } from "../engine/label";
import type { Emitter } from "../engine/particles";
import { audio } from "./audio";
import { floatText, trail } from "./effects";
import { GameScene } from "./gameScene";
import { options } from "./options";

/** One character of the text to type: its label, and a visible mark for a space when it is next. */
interface Glyph {
  label: GameLabel;
  space?: GameLabel;
}

/**
 * Game mode E. Otter rides Mosey down a scrolling course. Every correct key is a burst of
 * speed; streaks light up a rainbow trail. Accuracy earns the stars: nothing here needs speed.
 */
export class TypingTurboScene extends GameScene {
  private rider!: Sprite;
  private stream!: Emitter;
  private board?: Container;
  private glyphs: Glyph[] = [];
  private highlight?: Sprite;
  private target: string[] = [];
  private typedIndex = 0;
  private meter = new TypingMeter();
  private streak = 0;
  private wrongFlash = false;
  private pace = 70;
  private bob = 0;
  private finishing = false;
  private flag?: Container;

  protected override get scrollsBackdrop(): boolean { return true; }

  override art(): string[] {
    return [...super.art(), "duo_ride", "icon_1f3c1"];
  }

  protected build(): void {
    this.rider = new Sprite(texture("duo_ride"));
    this.rider.anchor.set(0.5);
    this.rider.zIndex = 20;
    this.stream = trail(this.world);
    this.stream.zIndex = 19;
    this.world.addChild(this.rider, this.stream);
  }

  private get riderX(): number { return this.play.x + this.play.width * 0.26; }
  private get riderY(): number { return this.play.bottom - this.play.height * 0.3; }
  private get boardWidth(): number { return Math.min(this.play.width * 0.86, 820); }
  private get boardHeight(): number { return Math.min(Math.max(this.play.height * 0.4, 70), 150); }
  private get boardY(): number { return this.play.y + this.boardHeight * 0.58; }

  protected layout(): void {
    const width = Math.min(this.play.height * 0.75, 330);
    this.rider.setSize(width, (width * this.rider.texture.height) / this.rider.texture.width);
    this.rider.position.set(this.riderX, this.riderY);
    this.board?.position.set(this.play.midX, this.boardY);
  }

  protected override caption(): string {
    return this.options.inputProfile === "hardware" ? "Type the words on your keyboard to zoom!" : "Type the words to zoom!";
  }

  protected override shouldSpeak(): boolean { return false; }

  protected present(question: Question): void {
    this.target = [...question.typingTarget];
    this.typedIndex = 0;
    this.meter = new TypingMeter();
    this.board?.destroy({ children: true });
    const contrast = options.settings.highContrast;
    const board = new Container();
    const back = new Sprite(panel(this.boardWidth, this.boardHeight, contrast ? "#ffffff" : palette.cream));
    back.anchor.set(0.5);
    board.addChild(back);
    board.position.set(this.play.midX, this.boardY);
    board.zIndex = 25;
    this.world.addChild(board);
    this.board = board;
    this.layOutText(board);
    board.scale.set(0.8);
    run(board, pop());
    this.render();
  }

  /** Sets the text out one character at a time, wrapped onto two lines when it is long. */
  private layOutText(board: Container): void {
    const count = Math.max(this.target.length, 1);
    const lines = count > 30 ? 2 : 1;
    const fontSize = Math.min(this.boardHeight * (lines === 2 ? 0.32 : 0.6), ((this.boardWidth - 40) * lines) / (count * 0.66));
    const gap = 1.3;
    const spaceWidth = fontSize * 0.34;
    this.highlight = new Sprite(panel(40, 56, "#FFE066", "#FFE066", 8, 0));
    this.highlight.anchor.set(0.5);
    board.addChild(this.highlight);

    // Break into rows at spaces so no row is wider than the board.
    const widths: number[] = [];
    this.glyphs = this.target.map((character) => {
      const isSpace = character === " ";
      // White letters, coloured with a tint so each key press is cheap.
      const label = new GameLabel(isSpace ? "" : character, fontSize, "#ffffff", { tracking: 0 });
      widths.push(isSpace ? spaceWidth : label.width + gap);
      board.addChild(label);
      if (!isSpace) return { label };
      const space = new GameLabel("␣", fontSize, "#ffffff", { tracking: 0 });
      space.visible = false;
      board.addChild(space);
      return { label, space };
    });
    const limit = this.boardWidth - 36;
    const rows: number[][] = [[]];
    let rowWidth = 0;
    let index = 0;
    while (index < this.target.length) {
      let end = index;
      while (end < this.target.length && this.target[end] !== " ") end += 1;
      const word = Array.from({ length: Math.min(end + 1, this.target.length) - index }, (_, offset) => index + offset);
      const wordWidth = word.reduce((sum, at) => sum + widths[at]!, 0);
      if (rowWidth + wordWidth > limit && rows.at(-1)!.length > 0) {
        rows.push([]);
        rowWidth = 0;
      }
      rows.at(-1)!.push(...word);
      rowWidth += wordWidth;
      index += word.length;
    }
    const lineHeight = fontSize * 1.25;
    rows.forEach((row, rowIndex) => {
      let x = -row.reduce((sum, at) => sum + widths[at]!, 0) / 2;
      const y = (rowIndex - (rows.length - 1) / 2) * lineHeight;
      for (const at of row) {
        const glyph = this.glyphs[at]!;
        glyph.label.position.set(x + widths[at]! / 2, y);
        glyph.space?.position.set(x + widths[at]! / 2, y);
        x += widths[at]!;
      }
    });
    this.highlight.height = fontSize * 1.2;
  }

  /** Typed letters turn green, the next one sits on a highlight, the rest wait in ink. */
  private render(): void {
    const ink = options.settings.highContrast ? "#000000" : palette.ink;
    this.glyphs.forEach((glyph, index) => {
      const next = index === this.typedIndex;
      glyph.label.tint = index < this.typedIndex ? "#1E9E52" : next && this.wrongFlash ? "#E8743B" : ink;
      glyph.label.alpha = index > this.typedIndex ? 0.55 : 1;
      if (glyph.space) {
        glyph.space.visible = next;
        glyph.space.tint = this.wrongFlash ? "#E8743B" : ink;
      }
      if (next && this.highlight) {
        const shown = glyph.space ?? glyph.label;
        this.highlight.position.copyFrom(shown.position);
        this.highlight.width = Math.max(shown.width + 6, 14);
      }
    });
    if (this.highlight) this.highlight.visible = this.typedIndex < this.glyphs.length;
  }

  protected override handleKey(character: string): void {
    const question = this.current;
    const wanted = this.target[this.typedIndex];
    if (!question || wanted === undefined) return;
    const correct = accepts(question, character, this.typedIndex) || (wanted === " " && character === " ");
    this.meter.record(correct);
    if (correct) {
      this.typedIndex += 1;
      this.streak += 1;
      this.wrongFlash = false;
      this.pace = Math.min(this.pace + 60, 560);
      audio.play("key", 0.55);
      if (this.streak % 10 === 0) {
        floatText(this.world, `${this.streak} in a row!`, this.rider.x, this.rider.y - this.rider.height * 0.7, "#FFE066");
        audio.play("combo", 0.7);
      }
      this.render();
      if (this.typedIndex >= this.target.length) this.completeText();
    } else {
      // A slip costs nothing but the streak. No toast, no fuss: just try the key again.
      this.streak = 0;
      this.wrongFlash = true;
      audio.play("wrong", 0.35);
      this.render();
    }
  }

  private completeText(): void {
    if (this.meter.accuracy < 0.9) this.markImperfect();
    // Tapping on-screen keys is far slower than typing, so its speed is recorded separately.
    this.session.recordTyping(this.meter.keystrokes, this.meter.correct, this.meter.wordsPerMinute, this.options.inputProfile !== "hardware");
    const outcome = this.succeed(this.rider.x + this.rider.width * 0.3, this.rider.y - this.rider.height * 0.4);
    this.pace = Math.min(this.pace + 160, 640);
    if (this.board) run(this.board, sequence(wait(0.25), fadeOut(0.2), remove()), "leave");
    this.board = undefined;
    this.glyphs = [];
    this.highlight = undefined;
    if (outcome?.isLevelComplete) this.crossFinishLine();
    else this.after(0.6, () => this.askNext());
  }

  private crossFinishLine(): void {
    this.finishing = true;
    const size = this.play.height * 0.4;
    const post = new Container();
    post.addChild(iconSprite("🏁", size));
    post.position.set(this.width + size, this.riderY - size * 0.3);
    post.zIndex = 18;
    this.world.addChild(post);
    this.flag = post;
    audio.play("victory");
    this.finishLevel(1);
  }

  protected override update(dt: number): void {
    const delta = Math.min(dt, 1 / 20);
    // Speed eases back to a steady cruise, so the ride never stops and never punishes a pause.
    const cruise = this.finishing ? 240 : 70;
    this.pace += (cruise - this.pace) * Math.min(delta * 0.9, 1);
    this.backdrop.scroll(this.pace * delta);
    this.bob += delta * (2 + this.pace / 120);
    const lift = options.reducedMotion ? 0 : Math.sin(this.bob) * 6;
    const lean = Math.min(Math.max((this.pace - 70) / 500, 0), 1);
    const rider = this.rider;
    rider.position.set(this.riderX + lean * this.play.width * 0.1, this.riderY - lift);
    rider.rotation = -lean * 0.08;
    this.stream.position.set(rider.x - rider.width * 0.42, rider.y + rider.height * 0.1);
    this.stream.birthRate = this.pace > 150 ? (options.reducedMotion ? 20 : Math.min(this.pace / 3, 180)) : 0;
    if (this.flag) {
      this.flag.x -= this.pace * 1.4 * delta;
      if (this.flag.x < -this.play.height * 0.4) {
        this.flag.destroy({ children: true });
        this.flag = undefined;
      }
    }
  }
}
