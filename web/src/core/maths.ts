import { makeQuestion, type AnswerFormat, type Question } from "./question";
import { pick, randomBool, randomInt, shuffled, type Rng } from "./rng";
import type { Skill } from "./skill";

// Generates Year 3 maths questions that always have exactly one right answer.

export const defaultTables: readonly number[] = [2, 3, 4, 5, 8, 10];

interface Draft {
  key?: string;
  prompt: string;
  answer: number;
  near: number[];
  hint: string;
  spoken?: string;
  audio?: string;
}

const positive = (value: number) => value > 0;
const clamp = (level: number) => Math.min(Math.max(level, 1), 5);

export function makeMaths(
  skill: Skill, level: number, rng: Rng,
  options: { tables?: readonly number[]; format?: AnswerFormat } = {},
): Question {
  const pitch = clamp(level);
  const tables = options.tables?.length ? options.tables : defaultTables;
  let draft: Draft;
  switch (skill) {
    case "subtraction": draft = subtraction(pitch, rng); break;
    case "multiplication": draft = multiplication(pitch, tables, rng); break;
    case "division": draft = division(pitch, tables, rng); break;
    case "fractions": draft = fractions(pitch, rng); break;
    case "placeValue": draft = placeValue(pitch, rng); break;
    case "sequences": draft = sequences(pitch, rng); break;
    case "wordProblems": draft = wordProblem(pitch, tables, rng); break;
    default: draft = addition(pitch, rng);
  }
  return finish(draft, skill, pitch, options.format ?? "choice", rng);
}

/** Rebuilds a specific times-table or division fact from its spaced-repetition key. */
export function makeMathsFact(key: string, level: number, rng: Rng, format: AnswerFormat = "choice"): Question | undefined {
  const parts = key.split(":");
  if (parts.length !== 2) return undefined;
  const numbers = parts[1]!.split("x").map(Number);
  if (numbers.length !== 2 || !numbers.every((value) => Number.isInteger(value) && value > 0)) return undefined;
  const [a, b] = numbers as [number, number];
  if (parts[0] === "mul") return finish(timesFact(a, b), "multiplication", level, format, rng);
  if (parts[0] === "div") return finish(divisionFact(a, b), "division", level, format, rng);
  return undefined;
}

function finish(draft: Draft, skill: Skill, level: number, format: AnswerFormat, rng: Rng): Question {
  return makeQuestion({
    key: draft.key ?? `${skill}:L${level}`,
    skill,
    format,
    prompt: draft.prompt,
    answer: String(draft.answer),
    choices: choices(draft.answer, draft.near, rng).map(String),
    hint: draft.hint,
    spoken: draft.spoken ?? speakable(draft.prompt),
    level,
    audioKey: draft.audio ?? `skill_${skill}`,
  });
}

/** Three distinct, non-negative options containing the answer. */
export function choices(answer: number, near: readonly number[], rng: Rng): number[] {
  const pool: number[] = [];
  const consider = (candidate: number) => {
    if (candidate >= 0 && candidate !== answer && !pool.includes(candidate)) pool.push(candidate);
  };
  shuffled(rng, near).forEach(consider);
  for (let offset = 1; pool.length < 2; offset += 1) {
    consider(answer + offset);
    consider(answer - offset);
  }
  return shuffled(rng, [answer, ...pool.slice(0, 2)]);
}

/**
 * Wrong answers a child might plausibly reach: one or two out, or a place-value slip
 * when the number is big enough for that to make sense.
 */
function slips(answer: number): number[] {
  const offsets = [1, -1, 2, -2];
  if (answer >= 20) offsets.push(10, -10);
  if (answer >= 150) offsets.push(100, -100);
  return offsets.map((offset) => answer + offset).filter((value) => value >= 0);
}

export function speakable(prompt: string): string {
  return prompt
    .replaceAll("×", " times ")
    .replaceAll("÷", " divided by ")
    .replaceAll("−", " take away ")
    .replaceAll("+", " plus ")
    .replaceAll("= ?", "")
    .replaceAll("?", " what ");
}

// Number operations

/** A ones, tens or hundreds amount, for adding to or taking from a three-digit number. */
function roundStep(rng: Rng): number {
  return pick(rng, [randomInt(rng, 2, 9), randomInt(rng, 1, 9) * 10, randomInt(rng, 1, 2) * 100]);
}

function addition(level: number, rng: Rng): Draft {
  let a: number, b: number;
  switch (level) {
    case 1: a = randomInt(rng, 2, 10); b = randomInt(rng, 2, 9); break;
    case 2: a = randomInt(rng, 11, 60); b = randomInt(rng, 2, 9); break;
    case 3: a = randomInt(rng, 12, 55); b = randomInt(rng, 11, 44); break;
    case 4: a = randomInt(rng, 110, 780); b = roundStep(rng); break;
    default: a = randomInt(rng, 120, 560); b = randomInt(rng, 25, 380);
  }
  const answer = a + b;
  return {
    prompt: `${a} + ${b} = ?`, answer, near: slips(answer),
    hint: level <= 2 ? `Start at ${Math.max(a, b)} and count on ${Math.min(a, b)}.` : "Add the tens first, then the ones.",
  };
}

function subtraction(level: number, rng: Rng): Draft {
  let a: number, b: number;
  switch (level) {
    case 1: a = randomInt(rng, 6, 20); b = randomInt(rng, 1, Math.min(9, a - 1)); break;
    case 2: a = randomInt(rng, 21, 80); b = randomInt(rng, 2, 9); break;
    case 3: a = randomInt(rng, 40, 99); b = randomInt(rng, 11, a - 8); break;
    case 4: a = randomInt(rng, 230, 900); b = roundStep(rng); break;
    default: a = randomInt(rng, 300, 900); b = randomInt(rng, 25, a - 100);
  }
  const answer = a - b;
  return {
    prompt: `${a} − ${b} = ?`, answer, near: [...slips(answer), a + b],
    hint: level <= 2 ? `Start at ${a} and count back ${b}.` : "Take away the tens first, then the ones.",
  };
}

function timesFact(table: number, other: number): Draft {
  const answer = table * other;
  const steps = [1, 2, 3].map((step) => table * step).join(", ");
  return {
    key: `mul:${table}x${other}`,
    prompt: `${other} × ${table} = ?`, answer,
    near: [answer + table, answer - table, answer + other, answer - other, answer + 1, answer - 1, answer + 10].filter(positive),
    hint: `Count in ${table}s, ${other} times: ${steps}, …`,
    audio: recordedFact("mul", table, other),
  };
}

function divisionFact(table: number, quotient: number): Draft {
  const dividend = table * quotient;
  return {
    key: `div:${table}x${quotient}`,
    prompt: `${dividend} ÷ ${table} = ?`, answer: quotient,
    near: [quotient + 1, quotient - 1, quotient + 2, quotient - 2, table, quotient * 2].filter(positive),
    hint: `How many ${table}s make ${dividend}? Count in ${table}s.`,
    audio: recordedFact("div", table, quotient),
  };
}

/** The narrator clip for a times-table fact, when that fact is one of the recorded ones. */
function recordedFact(kind: string, table: number, other: number): string | undefined {
  return defaultTables.includes(table) && other >= 1 && other <= 12 ? `${kind}_${table}x${other}` : undefined;
}

function tablesFor(level: number, enabled: readonly number[]): readonly number[] {
  const wanted = level === 1 ? [2, 5, 10] : level === 2 ? [2, 5, 10, 3] : level === 3 ? [3, 4, 8] : enabled;
  const usable = wanted.filter((table) => enabled.includes(table));
  return usable.length === 0 ? enabled : usable;
}

function multiplication(level: number, tables: readonly number[], rng: Rng): Draft {
  const table = pick(rng, tablesFor(level, tables));
  if (level === 5 && randomBool(rng)) {
    // Year 3 extension: a multiple of ten times a single digit.
    const tens = randomInt(rng, 2, 8) * 10;
    const answer = tens * table;
    return {
      prompt: `${tens} × ${table} = ?`, answer,
      near: [answer + 10, answer - 10, answer / 10, answer + table * 10, answer - table].filter(positive),
      hint: `Work out ${tens / 10} × ${table} first, then make it ten times bigger.`,
    };
  }
  const other = level === 1 ? randomInt(rng, 1, 6) : randomInt(rng, 2, 12);
  if (level >= 4 && randomBool(rng)) {
    const product = table * other;
    return {
      key: `mul:${table}x${other}`,
      prompt: `? × ${table} = ${product}`, answer: other,
      near: [other + 1, other - 1, other + 2, other - 2, table].filter(positive),
      hint: `Count in ${table}s until you reach ${product}. How many jumps?`,
      spoken: `What times ${table} equals ${product}?`,
      audio: recordedFact("mulq", table, other),
    };
  }
  return timesFact(table, other);
}

function division(level: number, tables: readonly number[], rng: Rng): Draft {
  const table = pick(rng, tablesFor(level, tables));
  const quotient = level === 1 ? randomInt(rng, 1, 6) : randomInt(rng, 2, 12);
  return divisionFact(table, quotient);
}

// Fractions, place value, sequences

function fractions(level: number, rng: Rng): Draft {
  if (level === 1) {
    const half = randomInt(rng, 2, 10);
    return {
      prompt: `Half of ${half * 2} = ?`, answer: half, near: [half + 1, half - 1, half * 2, half + 2],
      hint: `Split ${half * 2} into 2 equal groups.`,
    };
  }
  if (level <= 3) {
    const denominator = pick(rng, level === 2 ? [3, 4] : [3, 4, 5, 8, 10]);
    const part = randomInt(rng, 2, level === 2 ? 6 : 9);
    const whole = denominator * part;
    return {
      prompt: `1/${denominator} of ${whole} = ?`, answer: part,
      near: [part + 1, part - 1, denominator, part * 2, whole - denominator].filter(positive),
      hint: `Share ${whole} into ${denominator} equal groups.`,
      spoken: `What is one ${ordinal(denominator)} of ${whole}?`,
    };
  }
  if (level === 4) {
    const denominator = pick(rng, [3, 4, 5]);
    const numerator = randomInt(rng, 2, denominator - 1);
    const part = randomInt(rng, 2, 6);
    const whole = denominator * part;
    const answer = numerator * part;
    return {
      prompt: `${numerator}/${denominator} of ${whole} = ?`, answer,
      near: [part, whole - part, answer + part, answer - 1, answer + 1].filter(positive),
      hint: `Find 1/${denominator} of ${whole} first, then multiply by ${numerator}.`,
      spoken: `What is ${numerator} ${ordinal(denominator)}s of ${whole}?`,
    };
  }
  const denominator = pick(rng, [5, 6, 7, 8, 9, 10]);
  const a = randomInt(rng, 1, denominator - 3);
  const b = randomInt(rng, 1, denominator - a - 1);
  const name = ordinal(denominator);
  return {
    prompt: `${a}/${denominator} + ${b}/${denominator} = ?/${denominator}`, answer: a + b,
    near: [a + b + 1, a + b - 1, denominator, a * b, a + b + 2].filter(positive),
    hint: "The bottom number stays the same. Just add the top numbers.",
    spoken: `${a} ${name}s plus ${b} ${name}s. How many ${name}s?`,
  };
}

function ordinal(denominator: number): string {
  return ["half", "third", "quarter", "fifth", "sixth", "seventh", "eighth", "ninth"][denominator - 2] ?? "tenth";
}

function threeDigits(rng: Rng): [number, number, number] {
  return shuffled(rng, [1, 2, 3, 4, 5, 6, 7, 8, 9]).slice(0, 3) as [number, number, number];
}

function placeValue(level: number, rng: Rng): Draft {
  switch (level) {
    case 1: {
      const n = randomInt(rng, 12, 85);
      const more = randomBool(rng);
      const answer = more ? n + 10 : n - 10;
      return {
        prompt: `10 ${more ? "more" : "less"} than ${n} = ?`, answer,
        near: [n + 1, n - 1, more ? n - 10 : n + 10, answer + 10],
        hint: "Only the tens digit changes.",
      };
    }
    case 2: {
      const n = randomInt(rng, 120, 850);
      const more = randomBool(rng);
      const answer = more ? n + 100 : n - 100;
      return {
        prompt: `100 ${more ? "more" : "less"} than ${n} = ?`, answer,
        near: [more ? n + 10 : n - 10, more ? n - 100 : n + 100, answer + 10, answer - 10],
        hint: "Only the hundreds digit changes.",
      };
    }
    case 3: {
      const digits = threeDigits(rng);
      const n = digits[0] * 100 + digits[1] * 10 + digits[2];
      const index = randomInt(rng, 0, 2);
      const scale = [100, 10, 1][index]!;
      const digit = digits[index]!;
      return {
        prompt: `In ${n}, the ${digit} is worth ?`, answer: digit * scale,
        near: [digit, digit * 10, digit * 100],
        hint: `Is the ${digit} in the hundreds, tens or ones place?`,
        spoken: `In the number ${n}, what is the ${digit} worth?`,
      };
    }
    case 4: {
      const h = randomInt(rng, 1, 9), t = randomInt(rng, 1, 9), o = randomInt(rng, 1, 9);
      const answer = h * 100 + t * 10 + o;
      return {
        prompt: `${h * 100} + ${t * 10} + ${o} = ?`, answer,
        near: [h * 100 + o * 10 + t, t * 100 + h * 10 + o, h * 100 + t + o, answer + 10].filter((value) => value !== answer),
        hint: "Put the hundreds, tens and ones side by side.",
      };
    }
    default: {
      const [h, t, o] = threeDigits(rng);
      return {
        prompt: `${t} tens, ${o} ones and ${h} hundreds = ?`, answer: h * 100 + t * 10 + o,
        near: [t * 100 + o * 10 + h, o * 100 + t * 10 + h, h * 100 + o * 10 + t],
        hint: "Hundreds come first, then tens, then ones.",
      };
    }
  }
}

function sequences(level: number, rng: Rng): Draft {
  const steps = level === 1 ? [2, 5, 10] : level === 2 ? [3, 4] : level === 3 ? [4, 8] : level === 4 ? [50, 100] : [3, 4, 8, 50];
  const step = pick(rng, steps);
  const start = step * (level >= 4 ? randomInt(rng, 0, 4) : randomInt(rng, 1, 6));
  const terms = [0, 1, 2, 3, 4].map((index) => start + step * index);
  if (level === 5 && randomBool(rng)) terms.reverse();
  const hole = level >= 5 ? randomInt(rng, 2, 3) : 4;
  const answer = terms[hole]!;
  return {
    prompt: terms.map((term, index) => (index === hole ? "?" : String(term))).join(", "), answer,
    near: [answer + step, answer - step, answer + 1, answer - 1, answer + 2, answer + 10].filter((value) => value >= 0),
    hint: `The numbers ${terms[1]! > terms[0]! ? "go up" : "go down"} by ${step} each time.`,
    spoken: "Which number is missing from the pattern?",
  };
}

// Word problems

function wordProblem(level: number, tables: readonly number[], rng: Rng): Draft {
  const things = pick(rng, ["shells", "pearls", "berries", "acorns", "starfish", "pebbles"]);
  const easy = level <= 2;
  switch (randomInt(rng, 0, level >= 4 ? 4 : 3)) {
    case 0: {
      const a = easy ? randomInt(rng, 5, 20) : randomInt(rng, 20, 70);
      const b = easy ? randomInt(rng, 3, 9) : randomInt(rng, 11, 28);
      return {
        prompt: `Otter has ${a} ${things}. Mosey gives him ${b} more. How many now?`, answer: a + b,
        near: [a + b + 1, a + b - 1, a - b, a + b + 10, a + b - 10].filter(positive),
        hint: `More means add: ${a} + ${b}.`,
      };
    }
    case 1: {
      const a = easy ? randomInt(rng, 10, 20) : randomInt(rng, 30, 90);
      const b = easy ? randomInt(rng, 2, 8) : randomInt(rng, 11, 25);
      return {
        prompt: `Mosey has ${a} ${things}. She gives ${b} away. How many are left?`, answer: a - b,
        near: [a - b + 1, a - b - 1, a + b, a - b + 10, a - b - 10].filter(positive),
        hint: `Giving away means subtract: ${a} − ${b}.`,
      };
    }
    case 2: {
      const table = pick(rng, tablesFor(Math.max(level, 2), tables));
      const groups = randomInt(rng, 2, easy ? 5 : 9);
      const answer = groups * table;
      return {
        key: `mul:${table}x${groups}`,
        prompt: `${groups} baby dragons eat ${table} ${things} each. How many altogether?`, answer,
        near: [groups + table, answer + table, answer - table, answer + 1].filter(positive),
        hint: `${groups} lots of ${table} is ${groups} × ${table}.`,
      };
    }
    case 3: {
      const table = pick(rng, tablesFor(Math.max(level, 2), tables));
      const each = randomInt(rng, 2, easy ? 5 : 9);
      return {
        key: `div:${table}x${each}`,
        prompt: `Otter shares ${table * each} ${things} equally between ${table} friends. How many each?`, answer: each,
        near: [each + 1, each - 1, table, each + 2, table * each - table].filter(positive),
        hint: `Sharing equally means divide: ${table * each} ÷ ${table}.`,
      };
    }
    default: {
      const a = randomInt(rng, 20, 60), b = randomInt(rng, 11, 30), c = randomInt(rng, 5, 15);
      const answer = a + b - c;
      return {
        prompt: `Otter has ${a} ${things}. He finds ${b} more, then drops ${c}. How many now?`, answer,
        near: [a + b, a + b + c, a - b + c, answer + 10, answer - 1].filter(positive),
        hint: `Two steps: first ${a} + ${b}, then take away ${c}.`,
      };
    }
  }
}
