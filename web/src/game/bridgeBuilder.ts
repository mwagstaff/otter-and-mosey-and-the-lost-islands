import { Container, Sprite } from "pixi.js";
import { isCorrectChoice, subjectOf, type Question } from "../core";
import {
  call, easeIn, easeInOut, fadeIn, fadeOut, fadeTo, group, moveBy, moveTo, pop, remove, repeatForever, run, scaleTo, sequence, stop, wait,
  wobble,
} from "../engine/actions";
import { mix, panel, rainbow, rainbowArc, rainbowPlank, texture } from "../engine/art";
import { audio } from "./audio";
import { burst } from "./effects";
import { GameScene, type Sign } from "./gameScene";
import { options } from "./options";

const distance = (a: { x: number; y: number }, b: { x: number; y: number }) => Math.hypot(a.x - b.x, a.y - b.y);

/**
 * Game mode C. A canyon blocks the way. Tapping the right answer (or dragging it into the gap)
 * adds a rainbow plank; the last plank completes the bridge under a full rainbow.
 */
export class BridgeBuilderScene extends GameScene {
  private leftCliff!: Sprite;
  private rightCliff!: Sprite;
  private readonly planks: Sprite[] = [];
  private tiles: Sign[] = [];
  private homes: { x: number; y: number }[] = [];
  private slot!: Sprite;
  private sign?: Sign;
  private dragging?: Sign;
  private dragOffset = { x: 0, y: 0 };
  private dragStart = { x: 0, y: 0 };
  private locked = false;

  override art(): string[] {
    return [...super.art(), "cliff"];
  }

  protected build(): void {
    this.backdrop.showsForeground = false;
    this.leftCliff = new Sprite(texture("cliff"));
    this.rightCliff = new Sprite(texture("cliff"));
    for (const cliff of [this.leftCliff, this.rightCliff]) {
      cliff.anchor.set(0.5, 0);
      cliff.zIndex = 10;
      this.world.addChild(cliff);
    }
    this.slot = new Sprite(panel(120, 40, "rgba(255, 255, 255, 0.35)", "#FFE066", 10, 4));
    this.slot.anchor.set(0.5);
    this.slot.zIndex = 11;
    this.slot.visible = false;
    this.otter.zIndex = 14;
    this.mosey.zIndex = 8;
    this.mosey.restPose = "move";
    this.mosey.set("move", false);
    this.world.addChild(this.slot, this.otter, this.mosey);
  }

  // Geometry

  private get deckY(): number { return this.play.bottom - this.play.height * 0.56; }
  private get cliffWidth(): number { return this.play.width * 0.19; }
  private get gapStart(): number { return this.play.x + this.cliffWidth * 0.86; }
  private get gapEnd(): number { return this.play.right - this.cliffWidth * 0.86; }
  private get plankWidth(): number { return (this.gapEnd - this.gapStart) / this.session.total; }
  private get plankHeight(): number { return Math.min(this.play.height * 0.075, 30); }
  private get tileWidth(): number { return Math.min(this.play.width * 0.22, 210); }
  private get tileHeight(): number { return Math.min(this.play.height * 0.2, 84); }
  private get signY(): number { return this.play.y + this.play.height * 0.1; }

  /** Where plank `index` sits: the deck rises gently in the middle. */
  private plankPosition(index: number): { x: number; y: number } {
    const fraction = (index + 0.5) / this.session.total;
    return {
      x: this.gapStart + (this.gapEnd - this.gapStart) * fraction,
      y: this.deckY + this.plankHeight / 2 - Math.sin(Math.PI * fraction) * this.play.height * 0.045,
    };
  }

  protected layout(): void {
    const play = this.play;
    this.backdrop.resize(this.width, this.height, 0);
    const cliffHeight = (this.cliffWidth * this.leftCliff.texture.height) / this.leftCliff.texture.width;
    this.leftCliff.setSize(this.cliffWidth, cliffHeight);
    this.rightCliff.setSize(this.cliffWidth, cliffHeight);
    this.rightCliff.scale.x = -Math.abs(this.rightCliff.scale.x);
    this.leftCliff.position.set(play.x + this.cliffWidth / 2 - 4, this.deckY - cliffHeight * 0.12);
    this.rightCliff.position.set(play.right - this.cliffWidth / 2 + 4, this.deckY - cliffHeight * 0.12);
    this.otter.resize(Math.min(play.height * 0.27, 130));
    this.mosey.resize(Math.min(play.height * 0.3, 150));
    this.positionHeroes(false);
    this.planks.forEach((plank, index) => {
      plank.setSize(this.plankWidth, this.plankHeight);
      plank.position.copyFrom(this.plankPosition(index));
    });
    this.slot.setSize(this.plankWidth, this.plankHeight * 1.3);
    this.slot.position.copyFrom(this.plankPosition(Math.min(this.planks.length, this.session.total - 1)));
    this.sign?.position.set(play.midX, this.signY);
    this.homes = this.tiles.map((_, index) => this.tileHome(index, this.tiles.length));
    this.tiles.forEach((tile, index) => { if (tile !== this.dragging) tile.position.copyFrom(this.homes[index]!); });
  }

  private tileHome(index: number, count: number): { x: number; y: number } {
    const spacing = Math.min(this.play.width / (count + 0.6), this.tileWidth * 1.35);
    return { x: this.play.midX + (index - (count - 1) / 2) * spacing, y: this.play.bottom - this.tileHeight * 0.72 };
  }

  private positionHeroes(animated: boolean): void {
    const play = this.play;
    const x = this.planks.length === 0 ? play.x + this.cliffWidth * 0.42 : this.plankPosition(this.planks.length - 1).x;
    const moseyX = Math.max(x, play.x + this.cliffWidth + this.mosey.size * 0.4);
    const moseyY = play.bottom - play.height * 0.34;
    if (!animated) {
      stop(this.otter, "walk");
      stop(this.mosey, "swim");
      this.otter.position.set(x, this.deckY);
      this.mosey.position.set(moseyX, moseyY);
      return;
    }
    this.otter.set("move");
    audio.play("jump", 0.6);
    run(this.otter, sequence(moveTo(x, this.deckY, 0.45, easeInOut), call(() => this.otter.celebrate())), "walk");
    run(this.mosey, moveTo(moseyX, moseyY, 0.6, easeInOut), "swim");
  }

  // Questions

  protected override caption(question: Question): string {
    if (subjectOf(question.skill) === "spelling") return question.prompt;
    return question.prompt.length <= 22 ? "Tap the right answer to fill the gap" : question.prompt;
  }

  protected present(question: Question): void {
    const play = this.play;
    this.locked = false;
    this.sign?.destroy({ children: true });
    const text = question.masked ?? (subjectOf(question.skill) === "maths" && question.prompt.length <= 22 ? question.prompt : "?");
    const fontSize = Math.min(play.height * 0.1, 40);
    const width = Math.min(Math.max(text.length * fontSize * 0.7 + 50, 120), play.width * 0.6);
    const board = this.makeSign(text, width, fontSize * 1.7, fontSize);
    board.position.set(play.midX, this.signY);
    board.zIndex = 16;
    board.scale.set(0);
    this.world.addChild(board);
    run(board, pop());
    this.sign = board;

    this.tiles.forEach((tile) => tile.destroy({ children: true }));
    const count = question.choices.length;
    this.homes = question.choices.map((_, index) => this.tileHome(index, count));
    this.tiles = question.choices.map((choice, index) => {
      const tile = this.makeSign(choice, this.tileWidth, this.tileHeight, this.tileHeight * 0.5, mix(this.theme.tint, "#ffffff", 0.72));
      tile.label = choice;
      const home = this.homes[index]!;
      tile.position.set(home.x, play.bottom + this.tileHeight);
      tile.zIndex = 25;
      this.world.addChild(tile);
      run(tile, sequence(wait(0.08 * index), (target) => {
        const settled = this.homes[index] ?? home;
        return moveTo(settled.x, settled.y, 0.3, easeInOut)(target);
      }), "move");
      return tile;
    });
    this.slot.visible = true;
    this.slot.alpha = 1;
    this.slot.position.copyFrom(this.plankPosition(this.planks.length));
    if (!options.reducedMotion) run(this.slot, repeatForever(sequence(fadeTo(0.4, 0.5), fadeTo(1, 0.5))), "pulse");
  }

  // Dragging

  override pointerDown(x: number, y: number): void {
    if (this.locked) return;
    const point = { x, y };
    // Generous hit area: the nearest live tile within reach of the finger.
    const live = this.tiles.filter((tile) => tile.alpha === 1).sort((a, b) => distance(a, point) - distance(b, point));
    const tile = live[0];
    if (!tile || distance(tile, point) >= this.tileWidth * 0.75) return;
    this.dragging = tile;
    this.dragStart = point;
    this.dragOffset = { x: tile.x - x, y: tile.y - y };
    tile.zIndex = 40;
    stop(tile, "move");
    run(tile, scaleTo(1.1, 0.08), "scale");
    audio.play("tap", 0.6);
  }

  override pointerMove(x: number, y: number): void {
    this.dragging?.position.set(x + this.dragOffset.x, y + this.dragOffset.y);
  }

  override pointerUp(x: number, y: number): void {
    const tile = this.dragging;
    if (!tile) return;
    this.dragging = undefined;
    const tapped = distance({ x, y }, this.dragStart) < 14;
    const nearSlot = distance(tile, this.slot) < Math.max(this.plankWidth, 110);
    if (tapped || nearSlot) this.drop(tile);
    else this.sendHome(tile);
  }

  override pointerCancel(): void {
    if (this.dragging) this.sendHome(this.dragging);
    this.dragging = undefined;
  }

  private sendHome(tile: Sign): void {
    const home = this.homes[this.tiles.indexOf(tile)];
    if (!home) return;
    tile.zIndex = 25;
    run(tile, moveTo(home.x, home.y, 0.22, easeInOut), "move");
    run(tile, scaleTo(1, 0.15), "scale");
  }

  private drop(tile: Sign): void {
    const question = this.current;
    if (!question) return;
    if (!isCorrectChoice(question, tile.label)) {
      run(tile, sequence(wobble(), fadeTo(0.4, 0.2)), "wrong");
      this.sendHome(tile);
      this.slip();
      return;
    }
    this.locked = true;
    const index = this.planks.length;
    const target = this.plankPosition(index);
    this.slot.visible = false;
    stop(this.slot, "pulse");
    stop(tile, "scale");
    run(tile, sequence(group(moveTo(target.x, target.y, 0.22, easeInOut), scaleTo(0.5, 0.22), fadeOut(0.22)), remove()), "move");
    for (const other of this.tiles) if (other !== tile) run(other, sequence(fadeOut(0.2), remove()), "move");
    this.tiles = [];
    this.homes = [];
    if (this.sign && question.masked !== undefined) {
      // Show the finished word with the chosen letters in place.
      const letters = [...question.correctChoice];
      this.sign.words.string = [...question.masked].map((letter) => (letter === "_" ? (letters.shift() ?? letter) : letter)).join("");
    } else if (this.sign && question.skill === "homophones") {
      this.sign.words.string = question.answer;
    }

    const plank = new Sprite(rainbowPlank(120, 36));
    plank.anchor.set(0.5);
    plank.setSize(this.plankWidth, this.plankHeight);
    plank.position.set(target.x, target.y - 60);
    plank.alpha = 0;
    plank.zIndex = 12;
    this.world.addChild(plank);
    this.planks.push(plank);
    run(plank, sequence(wait(0.15), group(moveTo(target.x, target.y, 0.22, easeIn), fadeIn(0.15)), call(() => {
      audio.play("plank");
      this.cameraPunch();
    })), "fall");

    const outcome = this.succeed(target.x, target.y);
    this.after(0.45, () => this.positionHeroes(true));
    if (outcome?.isLevelComplete) this.after(1.2, () => this.completeBridge());
    else this.after(1.5, () => this.askNext());
  }

  /** The spectacular finish: a full rainbow rises over the finished bridge and Otter runs across. */
  private completeBridge(): void {
    const play = this.play;
    if (this.sign) run(this.sign, sequence(fadeOut(0.3), remove()));
    this.sign = undefined;
    const span = this.gapEnd - this.gapStart + this.cliffWidth;
    const arc = new Container();
    const bow = new Sprite(rainbowArc());
    bow.anchor.set(0.5, 1);
    bow.setSize(span, span / 2);
    arc.addChild(bow);
    arc.position.set(play.midX, this.deckY + span * 0.08);
    arc.zIndex = 6;
    arc.alpha = 0;
    arc.scale.set(0.6);
    this.world.addChild(arc);
    run(arc, group(fadeTo(0.9, 0.8), scaleTo(1, 0.8, easeInOut)));
    audio.play("victory");
    this.planks.forEach((plank, index) => {
      run(plank, sequence(wait(0.06 * index), moveBy(0, -12, 0.1), moveBy(0, 12, 0.14)), "hop");
      burst(this.world, plank.x, plank.y, rainbow[index % rainbow.length]!, 10);
    });
    this.otter.set("move");
    run(this.otter, sequence(moveTo(play.right - this.cliffWidth * 0.42, this.deckY, 0.9, easeInOut), call(() => this.otter.celebrate())), "walk");
    run(this.mosey, moveTo(play.right - this.cliffWidth - this.mosey.size * 0.2, this.mosey.y, 1, easeInOut), "swim");
    this.finishLevel(0.9);
  }
}
