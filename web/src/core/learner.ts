import { asObject, int, isBoolean, isNumber, list, num, record } from "./decode";
import { allSkills, isSkill, subjectOf, type Skill, type Subject } from "./skill";

/** A parent-selectable ceiling or floor on the adaptive level. */
export const allDifficultyModes = ["adaptive", "gentle", "steady", "stretch"] as const;
export type DifficultyMode = (typeof allDifficultyModes)[number];

export const difficultyTitles: Record<DifficultyMode, string> = {
  adaptive: "Adaptive (recommended)",
  gentle: "Gentle",
  steady: "Steady",
  stretch: "Stretch",
};

const limits: Record<DifficultyMode, [number, number]> = { adaptive: [1, 5], gentle: [1, 2], steady: [2, 4], stretch: [3, 5] };

export function clampLevel(mode: DifficultyMode, level: number): number {
  const [low, high] = limits[mode];
  return Math.min(Math.max(level, low), high);
}

/** Running record for one skill. */
export interface SkillStats {
  attempts: number;
  correct: number;
  streak: number;
  /** Continuous proficiency from 1.0 (just starting) to 5.0 (secure). The whole part is the level. */
  rating: number;
  totalSeconds: number;
  /** The most recent answers, newest last (true = right first time). */
  recent: boolean[];
}

export function newSkillStats(): SkillStats {
  return { attempts: 0, correct: 0, streak: 0, rating: 1, totalSeconds: 0, recent: [] };
}

function readSkillStats(value: unknown): SkillStats {
  const raw = asObject(value);
  return {
    attempts: int(raw.attempts, 0),
    correct: int(raw.correct, 0),
    streak: int(raw.streak, 0),
    rating: num(raw.rating, 1),
    totalSeconds: num(raw.totalSeconds, 0),
    recent: list(raw.recent, isBoolean, []),
  };
}

export function accuracyOf(stats: SkillStats): number {
  return stats.attempts === 0 ? 0 : stats.correct / stats.attempts;
}

export function averageSecondsOf(stats: SkillStats): number {
  return stats.attempts === 0 ? 0 : stats.totalSeconds / stats.attempts;
}

export function recentAccuracyOf(stats: SkillStats): number {
  return stats.recent.length === 0 ? 0 : stats.recent.filter(Boolean).length / stats.recent.length;
}

/** Leitner-style memory for one troublesome item (a word or a number fact). */
export interface ItemMemory {
  /** 0 = just missed … 4 = nearly secure. */
  box: number;
  /** The answer count at which this item should come back. */
  dueAt: number;
  lapses: number;
  skill: Skill;
}

export interface TypingStats {
  keystrokes: number;
  correctKeystrokes: number;
  bestWordsPerMinute: number;
  /** Recent words-per-minute samples, newest last. */
  samples: number[];
}

export function newTypingStats(): TypingStats {
  return { keystrokes: 0, correctKeystrokes: 0, bestWordsPerMinute: 0, samples: [] };
}

function readTypingStats(value: unknown): TypingStats {
  const raw = asObject(value);
  return {
    keystrokes: int(raw.keystrokes, 0),
    correctKeystrokes: int(raw.correctKeystrokes, 0),
    bestWordsPerMinute: num(raw.bestWordsPerMinute, 0),
    samples: list(raw.samples, isNumber, []),
  };
}

export function typingAccuracyOf(stats: TypingStats): number {
  return stats.keystrokes === 0 ? 0 : stats.correctKeystrokes / stats.keystrokes;
}

export function averageWordsPerMinuteOf(stats: TypingStats): number {
  return stats.samples.length === 0 ? 0 : stats.samples.reduce((sum, sample) => sum + sample, 0) / stats.samples.length;
}

export function recordTypingStats(stats: TypingStats, keystrokes: number, correct: number, wordsPerMinute?: number): void {
  stats.keystrokes += keystrokes;
  stats.correctKeystrokes += correct;
  if (wordsPerMinute !== undefined && wordsPerMinute > 0) {
    stats.samples.push(wordsPerMinute);
    if (stats.samples.length > 20) stats.samples.splice(0, stats.samples.length - 20);
    stats.bestWordsPerMinute = Math.max(stats.bestWordsPerMinute, wordsPerMinute);
  }
}

/**
 * Everything the game knows about how one child is getting on. Drives adaptive
 * difficulty and spaced repetition, and feeds the parent dashboard.
 */
export class LearnerModel {
  skills: Record<string, SkillStats> = {};
  items: Record<string, ItemMemory> = {};
  answerCount = 0;
  typing: TypingStats = newTypingStats();

  /** How many answers pass before an item in each box returns. */
  static readonly intervals = [3, 8, 20, 45, 100];
  static readonly recentWindow = 12;

  /** Reads a saved learner, filling in anything missing or unreadable. */
  static fromJSON(value: unknown): LearnerModel {
    const raw = asObject(value);
    const learner = new LearnerModel();
    learner.skills = record(raw.skills, readSkillStats);
    for (const [key, entry] of Object.entries(asObject(raw.items))) {
      const item = asObject(entry);
      if (!isSkill(item.skill)) continue;
      learner.items[key] = { box: int(item.box, 0), dueAt: int(item.dueAt, 0), lapses: int(item.lapses, 1), skill: item.skill };
    }
    learner.answerCount = int(raw.answerCount, 0);
    learner.typing = readTypingStats(raw.typing);
    return learner;
  }

  toJSON(): unknown {
    return { skills: this.skills, items: this.items, answerCount: this.answerCount, typing: this.typing };
  }

  /** An independent copy, so a level in progress cannot change the saved profile until it ends. */
  clone(): LearnerModel {
    return LearnerModel.fromJSON(structuredClone(this.toJSON()));
  }

  stats(skill: Skill): SkillStats {
    const stats = this.skills[skill];
    return stats ? { ...stats, recent: [...stats.recent] } : newSkillStats();
  }

  /** The level (1–5) to pitch the next question at. */
  level(skill: Skill, mode: DifficultyMode = "adaptive"): number {
    return clampLevel(mode, Math.floor(this.stats(skill).rating));
  }

  /** Records a first attempt at a question. */
  record(key: string, skill: Skill, correct: boolean, seconds: number, usedHint: boolean): void {
    this.answerCount += 1;
    const stats = this.stats(skill);
    stats.attempts += 1;
    stats.totalSeconds += Math.min(Math.max(seconds, 0), 120);
    const cleanCorrect = correct && !usedHint;
    stats.recent.push(cleanCorrect);
    if (stats.recent.length > LearnerModel.recentWindow) stats.recent.splice(0, stats.recent.length - LearnerModel.recentWindow);

    if (correct) {
      stats.correct += 1;
      stats.streak += 1;
      const quick = seconds < 6;
      let gain = usedHint ? 0.04 : quick ? 0.18 : 0.12;
      if (stats.streak >= 5 && !usedHint) gain += 0.05;
      stats.rating = Math.min(5, stats.rating + gain);
    } else {
      stats.streak = 0;
      // Mistakes ease the level down gently; two in a row eases a little more.
      const recentMisses = stats.recent.slice(-3).filter((right) => !right).length;
      stats.rating = Math.max(1, stats.rating - (recentMisses >= 2 ? 0.3 : 0.2));
    }
    this.skills[skill] = stats;
    this.updateMemory(key, skill, cleanCorrect);
  }

  private updateMemory(key: string, skill: Skill, correct: boolean): void {
    // Only specific facts and words are worth revisiting; generic "topic at level" keys are not.
    if (!(key.startsWith("word:") || key.startsWith("mul:") || key.startsWith("div:"))) return;
    const existing = this.items[key];
    if (correct) {
      if (!existing) return;
      const box = existing.box + 1;
      if (box >= LearnerModel.intervals.length) {
        delete this.items[key];
      } else {
        this.items[key] = { ...existing, box, dueAt: this.answerCount + LearnerModel.intervals[box]! };
      }
    } else {
      this.items[key] = {
        skill: existing?.skill ?? skill,
        lapses: existing ? existing.lapses + 1 : 1,
        box: 0,
        dueAt: this.answerCount + LearnerModel.intervals[0]!,
      };
    }
  }

  /** Troublesome items that are ready to be practised again, most overdue first. */
  dueKeys(skills: readonly Skill[]): string[] {
    return Object.entries(this.items)
      .filter(([, item]) => skills.includes(item.skill) && item.dueAt <= this.answerCount)
      .sort(([keyA, a], [keyB, b]) => a.dueAt - b.dueAt || (keyA < keyB ? -1 : keyA > keyB ? 1 : 0))
      .map(([key]) => key);
  }

  /** Words and facts the child has slipped on more than once, for the parent dashboard. */
  get troublesomeItems(): { key: string; lapses: number }[] {
    return Object.entries(this.items)
      .filter(([, item]) => item.lapses >= 2)
      .sort(([keyA, a], [keyB, b]) => b.lapses - a.lapses || (keyA < keyB ? -1 : keyA > keyB ? 1 : 0))
      .map(([key, item]) => ({ key, lapses: item.lapses }));
  }

  /** Accuracy across a subject, or undefined when nothing has been attempted yet. */
  accuracy(subject: Subject): number | undefined {
    const relevant = allSkills.filter((skill) => subjectOf(skill) === subject).map((skill) => this.stats(skill));
    const attempts = relevant.reduce((sum, stats) => sum + stats.attempts, 0);
    if (attempts === 0) return undefined;
    return relevant.reduce((sum, stats) => sum + stats.correct, 0) / attempts;
  }

  get practisedSkills(): Skill[] {
    return allSkills.filter((skill) => this.stats(skill).attempts > 0);
  }

  /** Skills with enough evidence to say they need more practice. */
  get skillsNeedingPractice(): Skill[] {
    return allSkills.filter((skill) => {
      const stats = this.stats(skill);
      return stats.attempts >= 5 && recentAccuracyOf(stats) < 0.6;
    });
  }
}
