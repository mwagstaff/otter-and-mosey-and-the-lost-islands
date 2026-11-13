import { Container, Sprite } from "pixi.js";
import type { AnswerOutcome, ChallengeSession, InputProfile, Island, Question } from "../core";
import { call, clearActions, easeInOut, everyFrame, fadeOut, group, moveBy, remove, run, scaleTo, sequence, wait } from "../engine/actions";
import { loadArt, iconName, mix, palette, panel } from "../engine/art";
import { GameLabel } from "../engine/label";
import { audio, narrator } from "./audio";
import { Backdrop } from "./backdrop";
import type { GameBridge, KeyboardKind } from "./bridge";
import { characterArt, CharacterNode, type CharacterKind } from "./character";
import { bloom, burst, confetti, floatText } from "./effects";
import { options } from "./options";
import { islandTheme, type IslandTheme } from "./theme";

/** Everything a level scene needs to know about who is playing and how it should look. */
export interface SceneOptions {
  favourite: CharacterKind;
  /** The picture or emoji for the favourite's hat, if one is being worn. */
  accessory?: string;
  island: Island;
  inputProfile: InputProfile;
  /** How colourful the island is when the level starts and ends (0 = grey, 1 = fully restored). */
  startRestoration: number;
  endRestoration: number;
}

/** Space taken at each edge by the HUD and the on-screen keys. */
export interface Insets {
  top: number;
  left: number;
  bottom: number;
  right: number;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
  right: number;
  bottom: number;
  midX: number;
}

/** Text on a chunky panel. `words` can be changed afterwards. */
export class Sign extends Container {
  constructor(readonly boxWidth: number, readonly boxHeight: number, board: Sprite, readonly words: GameLabel) {
    super();
    this.addChild(board, words);
  }
}

/**
 * Shared behaviour for every playable level: scenery, the two heroes, asking questions,
 * reacting to right and wrong answers, hints, and the end-of-level celebration.
 * Subclasses supply the mechanic. Positions are in page pixels, measured from the top left.
 */
export abstract class GameScene {
  /** Add this to the stage. It holds the whole level. */
  readonly root = new Container();
  /** Everything in the level. Scaled about its centre for the camera punch. */
  protected readonly world = new Container();
  readonly theme: IslandTheme;
  width = 0;
  height = 0;
  private insets: Insets = { top: 0, left: 0, bottom: 0, right: 0 };
  private built = false;
  private wantsStart = false;
  private started = false;
  protected backdrop!: Backdrop;
  protected otter!: CharacterNode;
  protected mosey!: CharacterNode;

  protected current?: Question;
  protected firstTry = true;
  protected usedHint = false;
  protected slips = 0;
  private questionStart = 0;
  private bloomCount = 0;
  private finished = false;

  constructor(readonly session: ChallengeSession, readonly bridge: GameBridge, readonly options: SceneOptions) {
    this.theme = islandTheme(options.island.id);
    this.world.sortableChildren = true;
    this.root.addChild(this.world);
    bridge.set({ total: session.total });
    bridge.onKey = (character) => this.handleKey(character);
    bridge.onBackspace = () => this.handleBackspace();
    bridge.onHint = () => this.requestHint();
    bridge.onRepeatSpeech = () => { if (this.current) narrator.say(this.current.audioKey, this.current.spoken); };
    run(this.root, everyFrame((dt) => { if (this.built) this.update(dt); }));
  }

  /** The pictures to load before the scene is built. */
  art(): string[] {
    const blooms = this.theme.blooms.map(iconName).filter((name) => name !== undefined);
    const hat = this.options.accessory === undefined ? undefined : iconName(this.options.accessory);
    return [this.theme.background, this.theme.foreground, ...characterArt("otter"), ...characterArt("mosey"), ...blooms, ...(hat ? [hat] : [])];
  }

  async load(): Promise<void> {
    await loadArt(this.art());
  }

  // Geometry

  /** The area free for gameplay: below the HUD and above the keys. */
  get play(): Rect {
    const { top, left, bottom, right } = this.insets;
    const width = Math.max(this.width - left - right, 10);
    const height = Math.max(this.height - top - bottom, 10);
    return { x: left, y: top, width, height, right: left + width, bottom: top + height, midX: left + width / 2 };
  }

  /** True on phone-sized screens, where everything is drawn larger relative to the play area. */
  get compact(): boolean {
    return this.height < 520;
  }

  /** Where characters stand. */
  get groundY(): number {
    return this.play.bottom - this.backdrop.foregroundHeight * 0.3;
  }

  get lead(): CharacterNode {
    return this.options.favourite === "otter" ? this.otter : this.mosey;
  }

  // Lifecycle

  /** Tells the scene how big the page is and how much of it the controls cover. */
  resize(width: number, height: number, insets: Insets): void {
    this.width = width;
    this.height = height;
    this.insets = insets;
    if (width <= 100 || height <= 100) return;
    this.world.pivot.set(width / 2, height / 2);
    this.world.position.set(width / 2, height / 2);
    if (!this.built) {
      this.built = true;
      this.backdrop = new Backdrop(this.theme, this.scrollsBackdrop);
      this.world.addChild(this.backdrop);
      this.backdrop.setRestoration(this.options.startRestoration, 0);
      this.backdrop.resize(width, height, insets.bottom);
      const favourite = this.options.favourite;
      this.otter = new CharacterNode("otter", 100, favourite === "otter" ? this.options.accessory : undefined);
      this.mosey = new CharacterNode("mosey", 160, favourite === "mosey" ? this.options.accessory : undefined);
      this.build();
      this.layout();
      this.otter.startIdle();
      this.mosey.startIdle();
      if (this.wantsStart) this.beginIfReady();
    } else {
      this.backdrop.resize(width, height, insets.bottom);
      this.layout();
    }
  }

  /** Called once the opening dialogue is out of the way. */
  begin(): void {
    this.wantsStart = true;
    this.beginIfReady();
  }

  private beginIfReady(): void {
    if (!this.built || this.started) return;
    this.started = true;
    this.start();
  }

  /** Throws the scene away. */
  destroy(): void {
    narrator.stop();
    this.root.destroy({ children: true });
    clearActions();
  }

  // Subclass hooks

  /** Whether this mode's scenery scrolls sideways. */
  protected get scrollsBackdrop(): boolean { return false; }
  /** Called every frame with the seconds since the last one. */
  protected update(_dt: number): void {}
  /** A finger or the mouse button going down on the scene, in scene positions. */
  pointerDown(_x: number, _y: number): void {}
  /** The finger or held mouse moving. */
  pointerMove(_x: number, _y: number): void {}
  pointerUp(_x: number, _y: number): void {}
  pointerCancel(): void {}

  /** Create nodes. Called once, when the scene has its real size. */
  protected abstract build(): void;
  /** Position nodes. Called after `build` and whenever the size or insets change. */
  protected abstract layout(): void;
  /** Show a new question. */
  protected abstract present(question: Question): void;
  /** Begin play. The default asks the first question. */
  protected start(): void { this.askNext(); }
  protected handleKey(_character: string): void {}
  protected handleBackspace(): void {}
  /** Give extra visual help after a hint is requested. */
  protected applyHint(): void {}
  /** The HUD text for a question. */
  protected caption(question: Question): string { return question.prompt; }
  protected shouldSpeak(_question: Question): boolean { return true; }

  // Question flow

  /** Runs `body` after a pause, unless the scene has been thrown away by then. */
  protected after(seconds: number, body: () => void): void {
    run(this.root, sequence(wait(seconds), call(body)));
  }

  protected askNext(): void {
    if (this.finished) return;
    const question = this.session.next();
    if (!question) return;
    this.current = question;
    this.firstTry = true;
    this.usedHint = false;
    this.slips = 0;
    this.questionStart = performance.now();
    const spoken = this.shouldSpeak(question);
    this.bridge.set({
      hintText: undefined,
      caption: this.caption(question),
      keyboard: this.keyboard(question),
      canSpeak: spoken && narrator.canSay(question.audioKey, question.spoken),
    });
    if (options.settings.spokenInstructions && spoken) narrator.say(question.audioKey, question.spoken);
    this.present(question);
  }

  private keyboard(question: Question): KeyboardKind {
    if (question.format !== "typed") return { kind: "none" };
    if (/^\d+$/.test(question.typingTarget)) return { kind: "numbers" };
    const space = question.typingTarget.includes(" ");
    if (this.options.inputProfile === "compactTouch" && !space && this.session.level.mode !== "typingTurbo") {
      return { kind: "tray", letters: trayLetters(question.typingTarget) };
    }
    return { kind: "qwerty", space };
  }

  /** A wrong attempt: reassure, never punish. */
  protected slip(): void {
    this.session.recordSlip();
    this.firstTry = false;
    this.slips += 1;
    audio.play("wrong", 0.7);
    this.bridge.set({ combo: 0, multiplier: 1 });
    this.bridge.showToast(this.session.retryMessage());
    this.lead.oops();
    if (this.slips >= 2 && !this.usedHint) this.requestHint();
  }

  /** The current question is done. Celebrates and returns the outcome so the mode can carry on. */
  protected succeed(x: number, y: number): AnswerOutcome | undefined {
    const question = this.current;
    if (!question) return undefined;
    this.current = undefined;
    const seconds = (performance.now() - this.questionStart) / 1000;
    const outcome = this.session.complete(question, this.firstTry, seconds, this.usedHint);
    audio.play(outcome.combo >= 3 ? "combo" : "correct");
    burst(this.world, x, y, mix(this.theme.tint, "#ffffff", 0.4));
    floatText(this.world, `+${outcome.points}`, x, y - 30, "#FFE066");
    this.bridge.set({
      completed: this.session.completed, combo: outcome.combo, multiplier: outcome.multiplier, score: this.session.score, hintText: undefined,
    });
    this.bridge.showToast(outcome.praise);
    this.otter.celebrate();
    this.mosey.celebrate();
    const { startRestoration, endRestoration } = this.options;
    this.backdrop.setRestoration(startRestoration + (endRestoration - startRestoration) * this.session.progress * 0.85);
    this.bloom();
    this.bridge.onLearnerChanged?.(this.session.learner);
    return outcome;
  }

  requestHint(): void {
    const question = this.current;
    if (!question) return;
    this.usedHint = true;
    this.bridge.set({ hintText: question.hint });
    audio.play("nav");
    this.lead.think();
    this.applyHint();
  }

  /** Something from the island's theme pops up along the ground: the world coming back to life. */
  protected bloom(count = 2): void {
    const play = this.play;
    for (let index = 0; index < count && this.bloomCount < 26; index += 1) {
      this.bloomCount += 1;
      const x = play.x + 20 + Math.random() * (play.width - 40);
      const size = (this.compact ? 34 : 46) * (0.8 + Math.random() * 0.4);
      const emoji = this.theme.blooms[Math.floor(Math.random() * this.theme.blooms.length)]!;
      const sprite = bloom(this.world, emoji, x, play.bottom - 2 - Math.random() * 12, size, 31);
      if (this.scrollsBackdrop) {
        // In travelling levels the scenery moves on, so blooms drift away behind the heroes.
        this.bloomCount -= 1;
        run(sprite, sequence(group(moveBy(-size * 6, 0, 1.8), sequence(wait(1.2), fadeOut(0.6))), remove()), "pass");
      }
    }
  }

  /** Ends the level: the island brightens, confetti falls, then the results appear. */
  protected finishLevel(delay = 0.6): void {
    if (this.finished) return;
    this.finished = true;
    this.bridge.set({ keyboard: { kind: "none" } });
    narrator.stop();
    this.after(delay, () => {
      this.backdrop.setRestoration(this.options.endRestoration, 1.4);
      confetti(this.world, this.width, this.height);
      audio.play("levelComplete");
      this.cameraPunch(0.94, 1.2);
      this.bloom(6);
      this.otter.celebrate();
      this.mosey.celebrate();
      this.after(2.4, () => this.bridge.set({ result: this.session.result }));
    });
  }

  // Helpers

  /** A quick camera push-in for impact. Skipped when motion is reduced. */
  protected cameraPunch(scale = 0.965, hold = 0): void {
    if (options.reducedMotion) return;
    run(this.world, sequence(scaleTo(1 / scale, 0.12, easeInOut), wait(hold), scaleTo(1, 0.3, easeInOut)), "punch");
  }

  /** Marks the current question as not perfect without any fuss (used for typing slips). */
  protected markImperfect(): void {
    this.firstTry = false;
  }

  /** A sign showing text on a chunky panel. */
  protected makeSign(text: string, width: number, height: number, fontSize: number, fill = palette.cream, ink = palette.ink, radius = 18): Sign {
    const contrast = options.settings.highContrast;
    const board = new Sprite(panel(width, height, contrast ? "#ffffff" : fill, contrast ? "#000000" : ink, Math.min(radius, height * 0.45)));
    board.anchor.set(0.5);
    // Sentences wrap; single words and numbers shrink to fit instead.
    const wraps = text.includes(" ") && text.length > 14;
    const label = new GameLabel(text, fontSize, contrast ? "#000000" : ink, wraps ? { maxWidth: width - 20 } : { fitWidth: width - 18 });
    return new Sign(width, height, board, label);
  }

  /** Pops a node away: a quick swell and fade, then it is gone. */
  protected popAway(node: Container): void {
    run(node, sequence(group(scaleTo(1.35, 0.16), fadeOut(0.18)), remove()), "pop");
  }
}

/** The answer's letters plus a few extras, shuffled, for the one-row phone keyboard. */
export function trayLetters(target: string): string[] {
  const letters = [...new Set(target.toLowerCase())];
  const wanted = Math.min(Math.max(letters.length + 3, 6), 10);
  const extras = [..."aeioutnsrlhdcm"].sort(() => Math.random() - 0.5);
  while (letters.length < wanted && extras.length > 0) {
    const extra = extras.pop()!;
    if (!letters.includes(extra)) letters.push(extra);
  }
  return letters.sort(() => Math.random() - 0.5);
}
