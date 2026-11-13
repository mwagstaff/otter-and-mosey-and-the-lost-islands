import { Container, Sprite } from "pixi.js";
import { call, fadeTo, moveTo, pop, repeatForever, run, sequence, wait, wobble } from "../engine/actions";
import { panel, palette } from "../engine/art";
import { GameLabel } from "../engine/label";
import { options } from "./options";

/**
 * A word laid out one letter per slot, with gaps the child fills in by typing.
 * Used wherever spelling is typed: word bubbles, guardians and the tutorial.
 */
export class WordSlots extends Container {
  private readonly labels: GameLabel[] = [];
  private readonly gaps: number[] = [];
  private readonly marker: Sprite;
  private readonly answer: string[];
  private filled = 0;

  /**
   * @param masked the word with `_` for each missing letter.
   * @param answer the complete word, used when the whole word is flashed up.
   */
  constructor(masked: string, answer: string, readonly letterWidth: number, private readonly ink: string, private readonly accent: string) {
    super();
    this.answer = [...answer];
    this.marker = new Sprite(panel(60, 76, "#FFE066", accent, 12, 4));
    this.marker.anchor.set(0.5);
    this.marker.setSize(letterWidth * 0.94, letterWidth * 1.3);
    this.addChild(this.marker);
    const characters = [...masked];
    characters.forEach((character, index) => {
      const isGap = character === "_";
      const label = new GameLabel(character, letterWidth * 1.12, isGap ? accent : ink, { tracking: 0 });
      label.position.set((index - (characters.length - 1) / 2) * letterWidth, 0);
      this.addChild(label);
      this.labels.push(label);
      if (isGap) this.gaps.push(index);
    });
    this.moveMarker(false);
    if (!options.reducedMotion) run(this.marker, repeatForever(sequence(fadeTo(0.55, 0.5), fadeTo(1, 0.5))), "pulse");
  }

  get isComplete(): boolean {
    return this.filled >= this.gaps.length;
  }

  private get current(): GameLabel | undefined {
    return this.labels[this.gaps[this.filled] ?? -1];
  }

  private moveMarker(animated: boolean): void {
    const target = this.current;
    if (!target) {
      this.marker.visible = false;
      return;
    }
    if (animated) run(this.marker, moveTo(target.x, target.y, 0.08), "move");
    else this.marker.position.copyFrom(target.position);
  }

  /** Puts the next letter into its gap. */
  fillNext(character: string): void {
    const label = this.current;
    if (!label) return;
    this.settle(label);
    label.string = character.toLowerCase();
    label.colour = "#1E9E52";
    run(label, pop(), "pop");
    this.filled += 1;
    this.moveMarker(true);
  }

  /** Puts a label back where it belongs if a wobble was cut short. */
  private settle(label: GameLabel): void {
    const index = this.labels.indexOf(label);
    run(label, call(() => {}), "wrong");
    label.x = (index - (this.labels.length - 1) / 2) * this.letterWidth;
  }

  /** Briefly shows a wrong letter in the current gap, then clears it. */
  flashWrong(character: string): void {
    const label = this.current;
    if (!label) return;
    this.settle(label);
    label.string = character.toLowerCase();
    label.colour = palette.coral;
    run(label, sequence(wobble(5), wait(0.15), call(() => {
      label.string = "_";
      label.colour = this.accent;
    })), "wrong");
  }

  /** Shows the whole word for a moment (look, cover, write), then hides the unfilled letters again. */
  flashWord(duration: number): void {
    const hidden = this.gaps.slice(this.filled);
    for (const index of hidden) {
      const letter = this.answer[index];
      if (letter === undefined) continue;
      this.labels[index]!.string = letter;
      this.labels[index]!.colour = this.ink;
    }
    this.marker.visible = false;
    run(this, sequence(wait(duration), call(() => {
      for (const index of this.gaps.slice(this.filled)) {
        this.labels[index]!.string = "_";
        this.labels[index]!.colour = this.accent;
      }
      this.marker.visible = !this.isComplete;
    })), "flash");
  }
}
