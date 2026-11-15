import { ColorMatrixFilter, Container, Sprite } from "pixi.js";
import { catalog } from "../core";
import {
  call, clearActions, easeInOut, everyFrame, fadeOut, group, moveBy, moveTo, pop, remove, repeatForever, rotateBy, run, scaleTo,
  scaleToXY, sequence, stop, wait, wobble,
} from "../engine/actions";
import { bubble, iconName, iconSprite, loadArt, mix, palette, panel, texture } from "../engine/art";
import { GameLabel } from "../engine/label";
import { audio, narrator } from "./audio";
import { applyWash } from "./backdrop";
import { characterArt, CharacterNode } from "./character";
import { bloom, rainbowBurst } from "./effects";
import type { Insets, Rect } from "./gameScene";
import { options } from "./options";
import { WordSlots } from "./wordSlots";

/** One question in the practice round that follows the opening story. */
export interface PracticeQuestion {
  /** Type the missing letters on a one-row tray, or tap the right answer from a few choices. */
  answer:
    | { kind: "letters"; masked: string; word: string; tray: string[] }
    | { kind: "choice"; prompt: string; answer: string; choices: string[] };
  /** A picture clue shown above the question. */
  clue?: string;
  instruction: string;
  speechKey: string;
  speech: string;
}

/**
 * The practice round: one missing letter, then two, then a times-tables question to tap.
 * Each right answer brings a little more colour back.
 */
export const practice: PracticeQuestion[] = [
  {
    answer: { kind: "letters", masked: "s_n", word: "sun", tray: ["a", "u", "o", "e", "i", "t"] }, clue: "☀️",
    instruction: "Tap the missing letter to bring the flower back!", speechKey: "word_sun", speech: "Sun. The sun is hot and bright.",
  },
  {
    answer: { kind: "letters", masked: "f__h", word: "fish", tray: ["s", "a", "i", "t", "o", "e"] }, clue: "🐟",
    instruction: "Two letters are missing now. Fill them in one at a time!", speechKey: "word_fish", speech: "Fish. A fish swims in the sea.",
  },
  {
    answer: { kind: "choice", prompt: "5 × 2 = ?", answer: "10", choices: ["7", "10", "12"] },
    instruction: "Now a sum! Tap the right answer.", speechKey: "mul_2x5", speech: "5 times 2.",
  },
];

const pictures = ["🥀", "☀️", "🐟", "🌻", "🌸", "🌼", "🌷", "🌺", "🦋"];

/**
 * The opening story: the Great Rainbow Crystal shatters and the colour drains away, then a
 * three-question practice round brings it back.
 */
export class IntroScene {
  readonly root = new Container();
  /** Called as each practice question appears, with its index. */
  onQuestion?: (index: number) => void;
  /** Called when a second wrong letter brings up a peek at the whole word. */
  onPeek?: () => void;
  onTutorialDone?: () => void;

  private readonly cover = new Sprite();
  private readonly wash = new ColorMatrixFilter();
  private colour = 1;
  private colourTarget = 1;
  private colourSpeed = 0;
  private otter!: CharacterNode;
  private mosey!: CharacterNode;
  private readonly crystal = new Container();
  private readonly gem = new Sprite();
  private flower?: Container;
  private bubble?: Container;
  private slots?: WordSlots;
  private question = 0;
  /** The letters still to fill in the current word, in order. */
  private expected: string[] = [];
  private slips = 0;
  private started = false;
  private tutorialActive = false;
  private shattered = false;
  private built = false;
  private width = 0;
  private height = 0;
  private insets: Insets = { top: 0, left: 0, bottom: 0, right: 0 };

  constructor() {
    this.root.sortableChildren = true;
    run(this.root, everyFrame((dt) => this.fadeColour(dt)));
  }

  async load(): Promise<void> {
    const icons = pictures.map(iconName).filter((name) => name !== undefined);
    await loadArt(["bg_title", "crystal_whole", "crystal_shard", ...characterArt("otter"), ...characterArt("mosey"), ...icons]);
  }

  private get play(): Rect {
    const { top, left, bottom, right } = this.insets;
    const width = Math.max(this.width - left - right, 10);
    const height = Math.max(this.height - top - bottom, 10);
    return { x: left, y: top, width, height, right: left + width, bottom: top + height, midX: left + width / 2 };
  }

  resize(width: number, height: number, insets: Insets): void {
    this.width = width;
    this.height = height;
    this.insets = insets;
    if (width <= 100 || height <= 100) return;
    if (!this.built) {
      this.built = true;
      this.cover.texture = texture("bg_title");
      this.cover.anchor.set(0.5);
      this.cover.zIndex = -100;
      this.gem.texture = texture("crystal_whole");
      this.gem.anchor.set(0.5);
      this.crystal.addChild(this.gem);
      this.crystal.zIndex = 5;
      this.otter = new CharacterNode("otter", 120);
      this.mosey = new CharacterNode("mosey", 200);
      this.mosey.facingLeft = true;
      this.root.addChild(this.cover, this.otter, this.mosey, this.crystal);
      this.otter.startIdle();
      this.mosey.startIdle();
      if (!options.reducedMotion) {
        run(this.gem, repeatForever(sequence(moveBy(0, -8, 1.2, easeInOut), moveBy(0, 8, 1.2, easeInOut))), "float");
      }
    }
    this.cover.scale.set(Math.max(width / this.cover.texture.width, height / this.cover.texture.height));
    this.cover.position.set(width / 2, height / 2);
    const play = this.play;
    this.otter.resize(Math.min(play.height * 0.44, 260));
    this.mosey.resize(Math.min(play.height * 0.6, 360));
    this.otter.position.set(play.x + play.width * 0.14, play.bottom - play.height * 0.05);
    this.mosey.position.set(play.right - play.width * 0.17, play.bottom - play.height * 0.3);
    if (!this.shattered) {
      const height = Math.min(play.height * 0.42, 240);
      this.gem.setSize((height * this.gem.texture.width) / this.gem.texture.height, height);
      this.crystal.position.set(play.midX, play.bottom - play.height * 0.66);
    }
    this.flower?.position.set(play.midX, this.flowerY);
    this.bubble?.position.set(play.midX, this.flowerY - play.height * 0.42);
  }

  private get flowerY(): number {
    return this.play.bottom - this.play.height * 0.08;
  }

  /** Fades the scenery towards `colour` (0 = grey, 1 = full colour) over `seconds`. */
  private setColour(colour: number, seconds: number): void {
    this.colourTarget = colour;
    this.colourSpeed = Math.abs(colour - this.colour) / Math.max(seconds, 0.01);
  }

  private fadeColour(dt: number): void {
    if (this.colour === this.colourTarget) return;
    const step = this.colourSpeed * dt;
    this.colour = Math.abs(this.colourTarget - this.colour) <= step ? this.colourTarget : this.colour + Math.sign(this.colourTarget - this.colour) * step;
    applyWash(this.cover, this.wash, this.colour);
  }

  /** The crystal starts to tremble. */
  rumble(): void {
    if (!this.built || this.shattered) return;
    audio.play("guardian", 0.6);
    this.otter.react("oops", 2);
    this.mosey.react("oops", 2);
    if (options.reducedMotion) return;
    run(this.crystal, repeatForever(sequence(moveBy(5, 0, 0.04), moveBy(-10, 0, 0.08), moveBy(5, 0, 0.04))), "rumble");
  }

  /** The crystal breaks into six fragments that fly away, and the colour drains from the world. */
  shatter(): void {
    if (!this.built || this.shattered) return;
    this.shattered = true;
    stop(this.crystal, "rumble");
    const { x, y } = this.crystal;
    audio.play("crack");
    audio.play("whoosh");
    rainbowBurst(this.root, x, y, 140);
    run(this.crystal, sequence(group(scaleTo(1.5, 0.12), fadeOut(0.15)), remove()));
    catalog.islands.forEach((island, index) => {
      const shard = new Sprite(texture("crystal_shard"));
      shard.anchor.set(0.5);
      shard.setSize((68 * shard.texture.width) / shard.texture.height, 68);
      shard.tint = mix("#ffffff", island.colour, 0.6);
      shard.position.set(x, y);
      shard.zIndex = 20;
      this.root.addChild(shard);
      const angle = (index / 6) * Math.PI * 2 + 0.4;
      run(shard, sequence(group(moveTo(x + Math.cos(angle) * this.width, y - Math.sin(angle) * this.width, 1.1), rotateBy(9, 1.1)), remove()));
    });
    this.setColour(0.08, 2.2);
  }

  /** One grey flower, then the first practice question. */
  startTutorial(): void {
    if (!this.built || this.started) return;
    this.started = true;
    const play = this.play;
    const flower = new Container();
    const wilted = iconSprite("🥀", play.height * 0.24);
    wilted.anchor.set(0.5, 1);
    wilted.tint = "#9a9a9a";
    flower.addChild(wilted);
    flower.position.set(play.midX, this.flowerY);
    flower.zIndex = 10;
    this.root.addChild(flower);
    this.flower = flower;
    this.present(0);
  }

  /** A word bubble for practice question `index`. */
  private present(index: number): void {
    this.question = index;
    this.slips = 0;
    const item = practice[index]!;
    const play = this.play;
    const node = new Container();
    const diameter = Math.min(play.height * 0.46, 220);
    const glass = new Sprite(bubble());
    glass.anchor.set(0.5);
    glass.setSize(diameter * 1.25, diameter);
    node.addChild(glass);
    const letterWidth = diameter * 0.24;
    const plateY = item.clue ? diameter * 0.12 : 0;
    const plate = (width: number) => {
      const sprite = new Sprite(panel(width, letterWidth * 1.75, "#FFFDF3", palette.ink, 16, 3));
      sprite.anchor.set(0.5);
      sprite.y = plateY;
      return sprite;
    };
    if (item.answer.kind === "letters") {
      const { masked, word } = item.answer;
      const slots = new WordSlots(masked, word, letterWidth, palette.ink, "#E8743B");
      slots.y = plateY;
      node.addChild(plate(letterWidth * masked.length + 26), slots);
      this.slots = slots;
      this.expected = [...masked].flatMap((character, at) => (character === "_" ? [word[at]!] : []));
    } else {
      const width = diameter * 0.95;
      const label = new GameLabel(item.answer.prompt, letterWidth * 0.95, palette.ink, { tracking: 0, fitWidth: width - 20 });
      label.y = plateY;
      node.addChild(plate(width), label);
      this.slots = undefined;
      this.expected = [];
    }
    if (item.clue) {
      // A picture clue: without it "s_n" could just as well be "son" or "sin".
      const clue = iconSprite(item.clue, diameter * 0.3);
      clue.y = -diameter * 0.27;
      node.addChild(clue);
    }
    node.position.set(play.midX, this.flowerY - play.height * 0.42);
    node.zIndex = 15;
    node.scale.set(0);
    this.root.addChild(node);
    run(node, pop(), "pop");
    this.bubble = node;
    audio.play("whoosh", 0.5);
    this.tutorialActive = true;
    this.onQuestion?.(index);
  }

  handleKey(character: string): void {
    const next = this.expected[0];
    if (!this.tutorialActive || !this.slots || !next || !/^\p{L}$/u.test(character)) return;
    if (character.toLowerCase() === next) {
      this.expected.shift();
      this.slots.fillNext(next);
      if (this.expected.length === 0) this.complete();
      else audio.play("pop", 0.5);
    } else {
      // Even here a wrong key is just a friendly wobble.
      this.slots.flashWrong(character);
      this.slip();
    }
  }

  /** Answers the tap-the-answer question. Returns whether `choice` was right. */
  choose(choice: string): boolean {
    const item = practice[this.question]!;
    if (!this.tutorialActive || item.answer.kind !== "choice") return false;
    if (choice === item.answer.answer) {
      this.complete();
      return true;
    }
    this.slip();
    return false;
  }

  private slip(): void {
    this.slips += 1;
    if (this.bubble) run(this.bubble, wobble(), "wobble");
    audio.play("wrong", 0.5);
    // As in the levels, a second slip brings help: here a peek at the whole word.
    if (this.slips === 2 && this.slots) {
      this.slots.flashWord(1.6);
      this.onPeek?.();
    }
  }

  private complete(): void {
    this.tutorialActive = false;
    const node = this.bubble;
    if (!node) return;
    audio.play("correct");
    audio.play("pop");
    rainbowBurst(this.root, node.x, node.y, 60);
    run(node, sequence(wait(0.35), group(scaleTo(1.4, 0.16), fadeOut(0.16)), remove()), "pop");
    this.bubble = undefined;
    this.slots = undefined;
    this.otter.celebrate();
    this.mosey.celebrate();
    // Colour returns a little more with every answer: a flower, a meadow, then butterflies.
    const question = this.question;
    const last = question === practice.length - 1;
    this.setColour([0.25, 0.4, 0.55][Math.min(question, 2)]!, 1.6);
    if (question === 0) this.bloomFlower();
    else if (question === 1) this.bloomMeadow();
    else this.releaseButterflies();
    run(this.root, sequence(wait(last ? 2.2 : 1.8), call(() => {
      if (last) this.onTutorialDone?.();
      else this.present(question + 1);
    })));
  }

  private randomBloom(x: number, delay: number, kinds: string[]): void {
    const play = this.play;
    run(this.root, sequence(wait(delay), call(() => {
      bloom(this.root, kinds[Math.floor(Math.random() * kinds.length)]!, x, this.flowerY + 6 - Math.random() * 16, play.height * 0.1);
    })));
  }

  private bloomFlower(): void {
    const flower = this.flower;
    if (!flower) return;
    const play = this.play;
    const sunflower = iconSprite("🌻", play.height * 0.24);
    sunflower.anchor.set(0.5, 1);
    flower.removeChildren().forEach((child) => child.destroy());
    flower.addChild(sunflower);
    run(flower, pop(), "pop");
    [-2, -1, 1, 2].forEach((step, index) => this.randomBloom(flower.x + step * play.width * 0.05, 0.1 * index, ["🌸", "🌼"]));
  }

  private bloomMeadow(): void {
    const play = this.play;
    for (let index = 0; index < 12; index += 1) {
      const x = play.x + play.width * (0.08 + (0.84 * index) / 11) + (Math.random() - 0.5) * 20;
      this.randomBloom(x, 0.08 * index, ["🌸", "🌼", "🌷", "🌺"]);
    }
  }

  private releaseButterflies(): void {
    const play = this.play;
    const flowerX = play.midX;
    const flowerY = this.flowerY;
    for (let index = 0; index < 4; index += 1) {
      const butterfly = new Container();
      butterfly.addChild(iconSprite("🦋", 40));
      butterfly.position.set(flowerX, flowerY);
      butterfly.zIndex = 25;
      this.root.addChild(butterfly);
      const targetY = flowerY - play.height * (0.35 + 0.1 * (index % 2));
      run(butterfly, sequence(wait(0.5 + 0.2 * index), moveTo(flowerX + (index - 2) * 110 + 50, targetY, 1.4, easeInOut)), "fly");
      if (!options.reducedMotion) run(butterfly, repeatForever(sequence(scaleToXY(0.5, 1, 0.15), scaleToXY(1, 1, 0.15))), "flap");
    }
  }

  destroy(): void {
    narrator.stop();
    this.root.destroy({ children: true });
    clearActions();
  }
}
