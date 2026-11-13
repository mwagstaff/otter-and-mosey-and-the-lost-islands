import type { LevelDef } from "./catalog";
import { wordBank } from "./content";
import { asObject, bool, int, isInteger, list } from "./decode";
import { allDifficultyModes, LearnerModel, recordTypingStats, type DifficultyMode } from "./learner";
import { defaultTables, makeMaths, makeMathsFact } from "./maths";
import type { AnswerFormat, Question } from "./question";
import { pick, randomInt, SeededGenerator } from "./rng";
import { isSkill, spellingTopics, subjectOf, type InputProfile, type Skill } from "./skill";
import { makeSpelling, makeTyping, type WordBank } from "./wordbank";

/** Parent-controlled limits on what a session may ask. */
export interface ParentSettings {
  difficulty: DifficultyMode;
  tables: number[];
  spellingTopics: Skill[];
  /** Suggested play time in minutes before a gentle break reminder. 0 means no reminder. */
  sessionMinutes: number;
  /** Optional speed bonuses. Off by default: nothing in the game requires speed. */
  timedChallenges: boolean;
}

export function newParentSettings(): ParentSettings {
  return { difficulty: "adaptive", tables: [...defaultTables], spellingTopics: [...spellingTopics], sessionMinutes: 0, timedChallenges: false };
}

export function readParentSettings(value: unknown): ParentSettings {
  const raw = asObject(value);
  const fresh = newParentSettings();
  return {
    difficulty: (allDifficultyModes as readonly unknown[]).includes(raw.difficulty) ? (raw.difficulty as DifficultyMode) : fresh.difficulty,
    tables: list(raw.tables, isInteger, fresh.tables),
    spellingTopics: list(raw.spellingTopics, isSkill, fresh.spellingTopics),
    sessionMinutes: int(raw.sessionMinutes, 0),
    timedChallenges: bool(raw.timedChallenges, false),
  };
}

export interface AnswerOutcome {
  points: number;
  combo: number;
  multiplier: number;
  praise: string;
  isLevelComplete: boolean;
}

export interface LevelResult {
  stars: number;
  accuracy: number;
  score: number;
  bestCombo: number;
  correctFirstTry: number;
  total: number;
  wordsPerMinute?: number;
  typingAccuracy?: number;
}

export const Encouragement = {
  praise: ["Brilliant!", "Super!", "You did it!", "Fantastic!", "Spot on!", "Wonderful!", "Amazing!", "Great thinking!"],
  retry: [
    "Nearly! Have another go.", "Good try. Try again!", "So close!", "Keep going, you can do it!",
    "Not quite. Take your time.", "Mistakes help us learn!",
  ],
  combo: ["Combo!", "On fire!", "Unstoppable!", "Rainbow streak!"],
};

/** Finishing always earns at least one star: effort is never shown as failure. */
export function starsForAccuracy(accuracy: number): number {
  if (accuracy >= 0.85) return 3;
  return accuracy >= 0.55 ? 2 : 1;
}

export interface SessionOptions {
  level: LevelDef;
  learner: LearnerModel;
  settings?: ParentSettings;
  inputProfile?: InputProfile;
  seed?: number | bigint;
  bank?: WordBank;
  /** Optional cap on the number of questions, for shorter sessions. */
  questionLimit?: number;
}

/**
 * Runs one level's worth of questions. Pure logic: scenes ask it for questions and tell
 * it what happened, so every game mode shares the same scoring and adaptive behaviour.
 */
export class ChallengeSession {
  readonly level: LevelDef;
  readonly settings: ParentSettings;
  readonly inputProfile: InputProfile;
  /** The session's own copy: the saved profile only changes when the level is finished. */
  readonly learner: LearnerModel;
  asked = 0;
  completed = 0;
  correctFirstTry = 0;
  combo = 0;
  bestCombo = 0;
  score = 0;
  keystrokes = 0;
  correctKeystrokes = 0;
  readonly wordsPerMinuteSamples: number[] = [];

  private readonly rng: SeededGenerator;
  private readonly usedKeys = new Set<string>();
  private readonly usedTexts = new Set<string>();
  private readonly bank: WordBank;
  private readonly questionLimit?: number;

  constructor(options: SessionOptions) {
    this.level = options.level;
    this.learner = options.learner.clone();
    this.settings = options.settings ?? newParentSettings();
    this.inputProfile = options.inputProfile ?? "compactTouch";
    this.bank = options.bank ?? wordBank;
    this.questionLimit = options.questionLimit;
    this.rng = new SeededGenerator(options.seed);
  }

  get total(): number {
    return this.questionLimit === undefined ? this.level.count : Math.max(1, Math.min(this.questionLimit, this.level.count));
  }

  get isFinished(): boolean {
    return this.completed >= this.total;
  }

  get progress(): number {
    return this.total === 0 ? 1 : this.completed / this.total;
  }

  get multiplier(): number {
    return Math.min(1 + Math.floor(this.combo / 3), 4);
  }

  /** Skills this level may use after applying the parent's topic choices. */
  private get activeSkills(): Skill[] {
    const allowed = this.level.skills.filter((skill) => subjectOf(skill) !== "spelling" || this.settings.spellingTopics.includes(skill));
    return allowed.length === 0 ? this.level.skills : allowed;
  }

  /** The next question, or undefined once the level has asked everything. */
  next(): Question | undefined {
    if (this.asked >= this.total) return undefined;
    this.asked += 1;
    const skills = this.activeSkills;

    // Spaced repetition: bring back something the child found tricky.
    if (this.asked > 1 && this.rng.next() < 0.35) {
      const key = this.learner.dueKeys(skills).find((due) => !this.usedKeys.has(due));
      const review = key === undefined ? undefined : this.review(key);
      if (key !== undefined && review) {
        this.usedKeys.add(key);
        return review;
      }
    }

    const skill = skills[(this.asked - 1 + randomInt(this.rng, 0, skills.length - 1)) % skills.length]!;
    const question = this.fresh(skill);
    this.usedKeys.add(question.key);
    return question;
  }

  private format(skill: Skill): AnswerFormat {
    switch (this.level.mode) {
      case "wordBlaster":
      case "typingTurbo":
      case "eggRescue":
        return "typed";
      case "mathsSplash":
      case "bridgeBuilder":
        return "choice";
      case "guardian":
        return subjectOf(skill) === "maths" ? "choice" : "typed";
    }
  }

  private fresh(skill: Skill): Question {
    const pitch = this.learner.level(skill, this.settings.difficulty);
    switch (subjectOf(skill)) {
      case "maths": {
        const make = () => makeMaths(skill, pitch, this.rng, { tables: this.settings.tables, format: this.format(skill) });
        for (let attempt = 0; attempt < 8; attempt += 1) {
          const candidate = make();
          if (!this.usedTexts.has(candidate.prompt)) {
            this.usedTexts.add(candidate.prompt);
            return candidate;
          }
        }
        return make();
      }
      case "typing": {
        const question = makeTyping(pitch, this.inputProfile, this.bank, this.rng, this.usedTexts);
        this.usedTexts.add(question.answer);
        return question;
      }
      case "spelling": {
        const pool = this.bank.pool([skill], pitch);
        const unused = pool.filter((entry) => !this.usedTexts.has(entry.word));
        const entry = pick(this.rng, unused.length === 0 ? pool : unused);
        this.usedTexts.add(entry.word);
        return makeSpelling(entry, this.format(skill), pitch, this.bank, this.rng);
      }
    }
  }

  private review(key: string): Question | undefined {
    const entry = key.startsWith("word:") ? this.bank.entry(key.slice(5)) : undefined;
    if (entry) {
      if (this.usedTexts.has(entry.word)) return undefined;
      this.usedTexts.add(entry.word);
      const pitch = Math.max(1, this.learner.level(entry.topic, this.settings.difficulty) - 1);
      return makeSpelling(entry, this.format(entry.topic), pitch, this.bank, this.rng);
    }
    const skill: Skill = key.startsWith("div:") ? "division" : "multiplication";
    return makeMathsFact(key, this.learner.level(skill, this.settings.difficulty), this.rng, this.format(skill));
  }

  /** A wrong attempt. The question stays open; only the combo is lost. */
  recordSlip(): void {
    this.combo = 0;
  }

  /** The question has been answered correctly (possibly after slips or a hint). */
  complete(question: Question, firstTry: boolean, seconds: number, usedHint: boolean): AnswerOutcome {
    this.completed += 1;
    this.learner.record(question.key, question.skill, firstTry, seconds, usedHint);
    let points = 40;
    if (firstTry) {
      this.correctFirstTry += 1;
      this.combo += 1;
      this.bestCombo = Math.max(this.bestCombo, this.combo);
      points = 100 * this.multiplier + (this.settings.timedChallenges && seconds < 5 ? 50 : 0);
    } else {
      this.combo = 0;
    }
    this.score += points;
    const praise = pick(this.rng, this.combo >= 3 && this.combo % 3 === 0 ? Encouragement.combo : Encouragement.praise);
    return { points, combo: this.combo, multiplier: this.multiplier, praise, isLevelComplete: this.isFinished };
  }

  retryMessage(): string {
    return pick(this.rng, Encouragement.retry);
  }

  /** Typing measurements for one finished word or sentence. */
  recordTyping(keystrokes: number, correct: number, wordsPerMinute?: number): void {
    this.keystrokes += keystrokes;
    this.correctKeystrokes += correct;
    if (wordsPerMinute !== undefined) this.wordsPerMinuteSamples.push(wordsPerMinute);
    recordTypingStats(this.learner.typing, keystrokes, correct, wordsPerMinute);
  }

  get result(): LevelResult {
    const accuracy = this.total === 0 ? 1 : this.correctFirstTry / this.total;
    const typingAccuracy = this.keystrokes === 0 ? undefined : this.correctKeystrokes / this.keystrokes;
    // Typing levels are judged on key accuracy, never on speed.
    const judged = this.level.mode === "typingTurbo" ? (typingAccuracy ?? accuracy) : accuracy;
    const samples = this.wordsPerMinuteSamples;
    return {
      stars: starsForAccuracy(judged),
      accuracy: judged,
      score: this.score,
      bestCombo: this.bestCombo,
      correctFirstTry: this.correctFirstTry,
      total: this.total,
      wordsPerMinute: samples.length === 0 ? undefined : samples.reduce((sum, sample) => sum + sample, 0) / samples.length,
      typingAccuracy,
    };
  }
}

/** Measures typing accuracy and speed for one piece of text. Times are in seconds. */
export class TypingMeter {
  keystrokes = 0;
  correct = 0;
  private firstKey?: number;
  private lastKey?: number;

  record(isCorrect: boolean, time: number = Date.now() / 1000): void {
    this.keystrokes += 1;
    if (isCorrect) this.correct += 1;
    this.firstKey ??= time;
    this.lastKey = time;
  }

  get accuracy(): number {
    return this.keystrokes === 0 ? 1 : this.correct / this.keystrokes;
  }

  /** Standard words per minute (five characters per word). Undefined until there is enough to measure. */
  get wordsPerMinute(): number | undefined {
    if (this.firstKey === undefined || this.lastKey === undefined || this.correct < 5) return undefined;
    const minutes = (this.lastKey - this.firstKey) / 60;
    return minutes > 0.01 ? this.correct / 5 / minutes : undefined;
  }
}
