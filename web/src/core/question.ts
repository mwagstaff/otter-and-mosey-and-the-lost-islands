import type { Skill } from "./skill";

/** How a question expects to be answered. */
export type AnswerFormat =
  /** Pick one of `choices` (tap, drag, swim through). */
  | "choice"
  /** Type `typingTarget` one character at a time. */
  | "typed";

/** One educational challenge, independent of how any game mode presents it. */
export interface Question {
  id: string;
  /** Stable key for spaced repetition, e.g. `mul:7x8` or `word:because`. */
  key: string;
  skill: Skill;
  format: AnswerFormat;
  /** What to show: `7 × 8 = ?`, or a sentence with a gap. */
  prompt: string;
  /** The canonical full answer (`56`, `because`). */
  answer: string;
  /** For `choice`: shuffled options including the right one. */
  choices: string[];
  /** The right entry in `choices` (may differ from `answer`, e.g. missing letters `au`). */
  correctChoice: string;
  /** For spelling: the word with `_` where letters are missing. */
  masked?: string;
  /** For `typed`: exactly the characters the child must type, in order. */
  typingTarget: string;
  /** A gentle nudge shown on request or after repeated slips. */
  hint: string;
  /** What the narrator should say aloud. */
  spoken: string;
  level: number;
  /** The pre-recorded narrator clip that reads this question, if one exists (see narration.json). */
  audioKey?: string;
  /** True when the full word should be shown briefly and then hidden (look, cover, write). */
  flashThenHide: boolean;
}

type QuestionParts = Pick<Question, "key" | "skill" | "format" | "prompt" | "answer" | "hint" | "level"> &
  Partial<Omit<Question, "id">>;

let nextQuestion = 0;

export function makeQuestion(parts: QuestionParts): Question {
  nextQuestion += 1;
  return {
    id: `q${nextQuestion}`,
    choices: [],
    flashThenHide: false,
    ...parts,
    correctChoice: parts.correctChoice ?? parts.answer,
    typingTarget: parts.typingTarget ?? parts.answer,
    spoken: parts.spoken ?? parts.prompt,
  };
}

export function isCorrectChoice(question: Question, choice: string): boolean {
  return choice === question.correctChoice;
}

/** Lenient comparison for typed input: case and surrounding spaces never count against a child. */
export function isCorrectTyped(question: Question, typed: string): boolean {
  return normalise(typed) === normalise(question.typingTarget);
}

export function normalise(text: string): string {
  return text.trim().toLowerCase().replaceAll("’", "'");
}

/** Whether `character` is the right key for position `index` of the typing target. */
export function accepts(question: Question, character: string, index: number): boolean {
  const target = [...question.typingTarget];
  if (index < 0 || index >= target.length) return false;
  return normalise(character) === normalise(target[index]!);
}
