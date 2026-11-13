// Ported from Packages/LostIslandsCore/Tests/LostIslandsCoreTests/EducationTests.swift.
import { describe, expect, test } from "vitest";
import {
  Chatter, isCorrectChoice, isCorrectTyped, LearnerModel, makeMaths, makeMathsFact, makeSpelling, makeTyping,
  mathsTopics, MouthGate, narration, SeededGenerator, spellingTopics, subjectOf, TypingMeter, wordBank as bank,
  type Question, type Skill, type SpellingStyle,
} from "../src/core";

const levels = [1, 2, 3, 4, 5];
const times = (count: number, body: (index: number) => void) => { for (let index = 0; index < count; index += 1) body(index); };
const wholeNumbers = (text: string) => text.split(" ").filter((part) => /^\d+$/.test(part)).map(Number);

/** Fills the gaps in a masked word with the given letters. */
function fill(masked: string, letters: string): { word: string; left: number } {
  const spare = [...letters];
  const word = [...masked].map((letter) => (letter === "_" ? (spare.shift() ?? "") : letter)).join("");
  return { word, left: spare.length };
}

describe("maths generator", () => {
  /** Independently evaluates simple "a op b = ?" prompts. */
  function evaluate(prompt: string): number | undefined {
    const parts = prompt.split(" ");
    if (parts.length !== 5 || parts[3] !== "=" || parts[4] !== "?" || !/^\d+$/.test(parts[0]!) || !/^\d+$/.test(parts[2]!)) return undefined;
    const a = Number(parts[0]), b = Number(parts[2]);
    switch (parts[1]) {
      case "+": return a + b;
      case "−": return a - b;
      case "×": return a * b;
      case "÷": return b !== 0 && a % b === 0 ? a / b : undefined;
      default: return undefined;
    }
  }

  test("every skill and level is well formed", () => {
    const rng = new SeededGenerator(42);
    for (const skill of mathsTopics) {
      for (const level of levels) {
        times(300, () => {
          const question = makeMaths(skill, level, rng);
          const label = `${skill} L${level}: ${question.prompt} ${question.choices}`;
          expect(question.answer, label).toMatch(/^\d+$/);
          expect(question.choices.length, label).toBe(3);
          expect(new Set(question.choices).size, label).toBe(3);
          expect(question.choices.filter((choice) => isCorrectChoice(question, choice)).length, label).toBe(1);
          expect(question.choices.every((choice) => /^\d+$/.test(choice)), label).toBe(true);
          expect(question.hint).not.toBe("");
          const expected = evaluate(question.prompt);
          if (expected !== undefined) expect(Number(question.answer), label).toBe(expected);
        });
      }
    }
  });

  test("arithmetic prompts are independently checkable", () => {
    const rng = new SeededGenerator(7);
    let checked = 0;
    for (const skill of ["addition", "subtraction", "division"] as Skill[]) {
      for (const level of levels) {
        times(100, () => {
          const question = makeMaths(skill, level, rng);
          expect(evaluate(question.prompt), question.prompt).toBe(Number(question.answer));
          checked += 1;
        });
      }
    }
    expect(checked).toBe(1500);
  });

  test("multiplication respects chosen tables", () => {
    const rng = new SeededGenerator(3);
    times(300, () => expect(makeMaths("multiplication", 4, rng, { tables: [8] }).key).toMatch(/^mul:8x/));
  });

  test("missing factor answers are consistent", () => {
    const rng = new SeededGenerator(11);
    let seen = 0;
    times(400, () => {
      const question = makeMaths("multiplication", 4, rng);
      if (!question.prompt.startsWith("?")) return;
      seen += 1;
      const parts = wholeNumbers(question.prompt);
      expect(parts.length, question.prompt).toBe(2);
      expect(Number(question.answer) * parts[0]!, question.prompt).toBe(parts[1]);
    });
    expect(seen).toBeGreaterThan(50);
  });

  test("fractions of amounts are whole", () => {
    const rng = new SeededGenerator(5);
    for (const level of [2, 3, 4]) {
      times(200, () => {
        const question = makeMaths("fractions", level, rng);
        // "n/d of w = ?"
        const numbers = wholeNumbers(question.prompt.replaceAll("/", " "));
        expect(numbers.length).toBe(3);
        expect(numbers[2]! % numbers[1]!).toBe(0);
        expect((numbers[2]! / numbers[1]!) * numbers[0]!).toBe(Number(question.answer));
      });
    }
  });

  test("fact keys rebuild the same fact", () => {
    const rng = new SeededGenerator(1);
    expect(makeMathsFact("mul:8x7", 3, rng)?.answer).toBe("56");
    const divide = makeMathsFact("div:4x9", 3, rng);
    expect(divide?.prompt).toBe("36 ÷ 4 = ?");
    expect(divide?.answer).toBe("9");
    expect(makeMathsFact("word:because", 3, rng)).toBeUndefined();
  });

  test("typed format uses the answer digits", () => {
    const question = makeMaths("multiplication", 3, new SeededGenerator(9), { format: "typed" });
    expect(question.format).toBe("typed");
    expect(question.typingTarget).toBe(question.answer);
    expect(isCorrectTyped(question, ` ${question.answer} `)).toBe(true);
  });
});

describe("word bank", () => {
  test("bank is substantial and clean", () => {
    expect(bank.words.length).toBeGreaterThanOrEqual(250);
    expect(new Set(bank.words.map((entry) => entry.word)).size).toBe(bank.words.length);
    for (const entry of bank.words) {
      expect(entry.word).toMatch(/^[a-z]+$/);
      expect(entry.sentence.split("___").length, entry.word).toBe(2);
      expect(entry.level).toBeGreaterThanOrEqual(1);
      expect(entry.level).toBeLessThanOrEqual(5);
      expect(subjectOf(entry.topic)).toBe("spelling");
      expect(entry.sentence.toLowerCase().includes(` ${entry.word} `), `sentence gives away ${entry.word}`).toBe(false);
    }
    for (const topic of spellingTopics) {
      expect(bank.words.filter((entry) => entry.topic === topic).length, topic).toBeGreaterThanOrEqual(20);
    }
  });

  test("UK spellings are present", () => {
    expect(bank.contains("favourite")).toBe(true);
    expect(bank.contains("favorite")).toBe(false);
    const text = bank.words.map((entry) => entry.sentence).join(" ") + bank.sentences.map((sentence) => sentence.text).join(" ");
    expect(text).toContain("colour");
    expect(text).not.toContain("color ");
  });

  test("homophones have partners and different spellings", () => {
    for (const entry of bank.words.filter((word) => word.topic === "homophones")) {
      expect(entry.partner, entry.word).toBeTruthy();
      expect(entry.partner).not.toBe(entry.word);
    }
  });

  test("typed challenges rebuild the word", () => {
    const rng = new SeededGenerator(21);
    for (const entry of bank.words) {
      for (const level of levels) {
        const question = makeSpelling(entry, "typed", level, bank, rng);
        expect(question.format).toBe("typed");
        const rebuilt = fill(question.masked ?? "", question.typingTarget);
        expect(rebuilt.word, `${entry.word} L${level}: ${question.masked} + ${question.typingTarget}`).toBe(entry.word);
        expect(rebuilt.left).toBe(0);
        expect(isCorrectTyped(question, question.typingTarget.toUpperCase())).toBe(true);
      }
    }
  });

  test("choice challenges have exactly one real word", () => {
    const rng = new SeededGenerator(22);
    for (const entry of bank.words) {
      for (const level of [1, 2, 3, 4]) {
        const question = makeSpelling(entry, "choice", level, bank, rng);
        expect(question.choices.length, entry.word).toBeGreaterThanOrEqual(2);
        expect(new Set(question.choices).size, entry.word).toBe(question.choices.length);
        expect(question.choices.filter((choice) => isCorrectChoice(question, choice)).length, entry.word).toBe(1);
        const masked = question.masked;
        if (masked === undefined) continue;
        const real = question.choices.filter((choice) => bank.isRealWord(fill(masked, choice).word));
        expect(real, `${entry.word}: ${question.choices}`).toEqual([question.correctChoice]);
      }
    }
  });

  test("wrong choices never spell another real word", () => {
    expect(bank.isRealWord("sum") && bank.isRealWord("sin"), "common lookalikes are known").toBe(true);
    const rng = new SeededGenerator(77);
    const sun = bank.entry("sun")!;
    times(200, () => {
      const question = makeSpelling(sun, "choice", 1, bank, rng);
      expect(question.choices.length).toBe(3);
      for (const choice of question.choices.filter((option) => option !== question.correctChoice)) {
        const filled = fill(question.masked ?? "", choice).word;
        expect(bank.isRealWord(filled), `${filled} is a real word`).toBe(false);
      }
    });
  });

  test("every spoken question has a narration line", () => {
    expect(Object.keys(narration).length).toBeGreaterThan(480);
    const rng = new SeededGenerator(12);
    for (const entry of bank.words) {
      for (const style of ["typed", "choice"] as SpellingStyle[]) {
        const question = makeSpelling(entry, style, 3, bank, rng);
        expect(question.audioKey).toBe(`word_${entry.word}`);
        expect(narration[question.audioKey ?? ""]?.toLowerCase(), entry.word).toContain(entry.word);
      }
    }
    let specific = 0;
    for (const skill of mathsTopics) {
      for (const level of levels) {
        times(200, () => {
          const question: Question = makeMaths(skill, level, rng);
          const key = question.audioKey ?? "none";
          expect(narration[key], `no narration for ${key}: ${question.prompt}`).toBeDefined();
          if (!key.startsWith("skill_")) specific += 1;
        });
      }
    }
    expect(specific, "times-table and division facts get their own recordings").toBeGreaterThan(1000);
    expect(narration["mul_8x7"]).toBe("7 times 8.");
    expect(narration["div_4x9"]).toBe("36 divided by 4.");
    expect(makeTyping(2, "hardware", bank, rng).audioKey).toBeUndefined();
  });

  test("typing content adapts to input method", () => {
    const rng = new SeededGenerator(8);
    times(50, () => {
      expect(makeTyping(2, "compactTouch", bank, rng).answer, "phones get single words at low levels").not.toContain(" ");
      expect(makeTyping(2, "hardware", bank, rng).answer, "hardware keyboards get sentences").toContain(" ");
    });
    for (const sentence of bank.sentences) expect(sentence.text).toMatch(/^[a-z ]+$/);
  });
});

describe("learner", () => {
  const repeat = (learner: LearnerModel, count: number, key: string, skill: Skill, correct: boolean, seconds: number, usedHint = false) =>
    times(count, () => learner.record(key, skill, correct, seconds, usedHint));

  test("rating rises with success and eases with mistakes", () => {
    const learner = new LearnerModel();
    expect(learner.level("addition")).toBe(1);
    repeat(learner, 12, "addition:L1", "addition", true, 3);
    const raised = learner.level("addition");
    expect(raised).toBeGreaterThanOrEqual(3);
    repeat(learner, 6, "addition:L3", "addition", false, 10);
    expect(learner.level("addition")).toBeLessThan(raised);
    repeat(learner, 100, "x", "addition", false, 1);
    expect(learner.stats("addition").rating).toBe(1);
    repeat(learner, 100, "x", "addition", true, 1);
    expect(learner.stats("addition").rating).toBe(5);
  });

  test("hints count as learning, not mastery", () => {
    const hinted = new LearnerModel(), clean = new LearnerModel();
    repeat(hinted, 5, "k", "division", true, 3, true);
    repeat(clean, 5, "k", "division", true, 3, false);
    expect(hinted.stats("division").rating).toBeLessThan(clean.stats("division").rating);
  });

  test("difficulty modes clamp the level", () => {
    const learner = new LearnerModel();
    repeat(learner, 60, "k", "fractions", true, 2);
    expect(learner.level("fractions", "adaptive")).toBe(5);
    expect(learner.level("fractions", "gentle")).toBe(2);
    expect(learner.level("fractions", "steady")).toBe(4);
    expect(new LearnerModel().level("fractions", "stretch")).toBe(3);
  });

  test("troublesome items come back after a gap", () => {
    const learner = new LearnerModel();
    learner.record("mul:8x7", "multiplication", false, 9, false);
    expect(learner.dueKeys(["multiplication"]), "not due straight away").toEqual([]);
    repeat(learner, 3, "addition:L1", "addition", true, 2);
    expect(learner.dueKeys(["multiplication"])).toEqual(["mul:8x7"]);
    expect(learner.dueKeys(["addition"])).toEqual([]);
  });

  test("items are retired once secure", () => {
    const learner = new LearnerModel();
    learner.record("word:because", "exceptionWords", false, 9, false);
    repeat(learner, LearnerModel.intervals.length, "word:because", "exceptionWords", true, 4);
    expect(learner.items["word:because"]).toBeUndefined();
  });

  test("gaps grow after each success", () => {
    const learner = new LearnerModel();
    learner.record("word:friend", "exceptionWords", false, 9, false);
    const first = learner.items["word:friend"]!.dueAt - learner.answerCount;
    learner.record("word:friend", "exceptionWords", true, 4, false);
    const second = learner.items["word:friend"]!.dueAt - learner.answerCount;
    expect(second).toBeGreaterThan(first);
  });

  test("dashboard summaries", () => {
    const learner = new LearnerModel();
    expect(learner.accuracy("maths")).toBeUndefined();
    times(10, (index) => learner.record("k", "subtraction", index < 3, 5, false));
    expect(learner.accuracy("maths")).toBe(0.3);
    expect(learner.skillsNeedingPractice).toEqual(["subtraction"]);
    expect(learner.practisedSkills).toEqual(["subtraction"]);
  });

  test("a copy does not change the original", () => {
    const learner = new LearnerModel();
    learner.record("mul:8x7", "multiplication", false, 9, false);
    const copy = learner.clone();
    copy.record("mul:8x7", "multiplication", false, 9, false);
    expect(copy).not.toEqual(learner);
    expect(learner.answerCount).toBe(1);
    expect(learner.items["mul:8x7"]!.lapses).toBe(1);
  });

  test("typing meter measures speed and accuracy", () => {
    const meter = new TypingMeter();
    times(50, (index) => meter.record(index % 10 !== 0, index * 0.6));
    expect(meter.accuracy).toBe(0.9);
    // 45 correct characters = 9 words in 29.4 seconds.
    expect(meter.wordsPerMinute).toBeCloseTo(9 / (29.4 / 60), 2);
    expect(new TypingMeter().wordsPerMinute).toBeUndefined();
  });
});

describe("speech", () => {
  test("mouth opens on loud and closes on quiet", () => {
    const gate = new MouthGate();
    expect(gate.update(0.1, 0)).toBe(false);
    expect(gate.update(0.8, 0.1)).toBe(true);
    expect(gate.update(0.25, 0.3), "between the thresholds it stays as it was").toBe(true);
    expect(gate.update(0.05, 0.5)).toBe(false);
  });

  test("mouth does not flicker on noisy input", () => {
    const gate = new MouthGate();
    let changes = 0;
    let last = false;
    // Loudness that jumps above and below the thresholds on every 1/30 s reading.
    times(60, (step) => {
      const open = gate.update(step % 2 === 0 ? 0.9 : 0, step / 30);
      if (open !== last) changes += 1;
      last = open;
    });
    expect(changes, "state changes are limited by the hold time").toBeLessThanOrEqual(2 / 0.07 + 1);
    expect(changes, "far fewer changes than readings").toBeLessThan(30);
  });

  test("chatter lasts for the line and then stops", () => {
    expect(Chatter.duration(3)).toBe(1);
    expect(Chatter.duration(30)).toBeCloseTo(1.8, 4);
    expect(Chatter.duration(500)).toBe(4);
    const duration = Chatter.duration(40);
    const gate = new MouthGate();
    let opens = 0;
    let last = false;
    let peak = 0;
    times(Math.floor(duration * 30), (step) => {
      const time = step / 30;
      const level = Chatter.level(time, duration);
      expect(level).toBeGreaterThanOrEqual(0);
      expect(level).toBeLessThanOrEqual(1);
      peak = Math.max(peak, level);
      const open = gate.update(level, time);
      if (open && !last) opens += 1;
      last = open;
    });
    expect(peak).toBeGreaterThan(0.6);
    expect(opens, "the mouth opens several times over a line").toBeGreaterThanOrEqual(6);
    expect(Chatter.level(duration, duration)).toBe(0);
    expect(Chatter.level(duration + 1, duration)).toBe(0);
  });
});
