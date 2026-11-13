import type { DialogueLine, LearnerModel, LevelResult } from "../core";

/** Which on-screen keys the current question needs. */
export type KeyboardKind =
  | { kind: "none" }
  /** A single row of big letter tiles (phones, short answers). */
  | { kind: "tray"; letters: string[] }
  | { kind: "qwerty"; space: boolean }
  | { kind: "numbers" };

/**
 * The link between a level's scene and the page controls drawn over it. The scene publishes
 * HUD state here with `set`; the page listens with `onChange` and forwards key presses back.
 */
export class GameBridge {
  completed = 0;
  total = 0;
  combo = 0;
  multiplier = 1;
  score = 0;
  /** The question or instruction shown at the top of the screen. */
  caption = "";
  hintText?: string;
  toast = "";
  toastID = 0;
  keyboard: KeyboardKind = { kind: "none" };
  /** Friendship Power charge from 0 to 1, or undefined when the meter is hidden. */
  friendship?: number;
  friendshipUses = 0;
  /** Lines the scene wants spoken before play continues. */
  dialogue: DialogueLine[] = [];
  /** Set when the level is over and the celebration should appear. */
  result?: LevelResult;
  /** False when the listen button would be silent for this question. */
  canSpeak = false;

  onKey?: (character: string) => void;
  onBackspace?: () => void;
  onHint?: () => void;
  onRepeatSpeech?: () => void;
  onLearnerChanged?: (learner: LearnerModel) => void;
  private onDialogueDone?: () => void;
  private readonly listeners = new Set<() => void>();

  onChange(listener: () => void): void {
    this.listeners.add(listener);
  }

  set(changes: Partial<Pick<GameBridge,
    "completed" | "total" | "combo" | "multiplier" | "score" | "caption" | "hintText" | "keyboard" | "friendship" | "result" | "canSpeak">>): void {
    Object.assign(this, changes);
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }

  showToast(text: string): void {
    this.toast = text;
    this.toastID += 1;
    this.notify();
  }

  say(lines: DialogueLine[], then: () => void): void {
    if (lines.length === 0) return then();
    this.onDialogueDone = then;
    this.dialogue = lines;
    this.notify();
  }

  finishDialogue(): void {
    this.dialogue = [];
    const done = this.onDialogueDone;
    this.onDialogueDone = undefined;
    this.notify();
    done?.();
  }
}
