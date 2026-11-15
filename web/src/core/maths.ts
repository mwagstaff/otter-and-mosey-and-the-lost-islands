import { makeQuestion, type AnswerFormat, type Question } from "./question";
import { pick, randomBool, randomInt, shuffled, type Rng } from "./rng";
import type { Skill } from "./skill";

// Generates Year 3 maths questions that always have exactly one right answer.

export const defaultTables: readonly number[] = [2, 3, 4, 5, 8, 10];
/** The numbers a times-table question can multiply or divide by. */
export const defaultMultipliers: readonly number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
/** The fractions a fraction question can use, by denominator: halves up to tenths. */
export const defaultDenominators: readonly number[] = [2, 3, 4, 5, 6, 7, 8, 9, 10];

/** The times tables a grown-up has chosen, plus what each one may be multiplied by. */
interface Limits {
  tables: readonly number[];
  multipliers: readonly number[];
}

/**
 * Whether a question may multiply by `value`: the grown-up picked it, and it isn't a table they
 * switched off. "8 × 3" reads as the 8 times table, so it is left out when 8× is off.
 */
export function allowsMultiplier(value: number, tables: readonly number[], multipliers: readonly number[]): boolean {
  return multipliers.includes(value) && (!defaultTables.includes(value) || tables.includes(value));
}

/**
 * The numbers from `low` to `high` a question may multiply by. When the grown-up's choices miss this
 * level's usual range, their choices win over the level.
 */
function multipliers(limits: Limits, low: number, high: number): number[] {
  const all = Array.from({ length: high - low + 1 }, (_, index) => low + index);
  const allowed = (values: readonly number[]) => values.filter((value) => allowsMultiplier(value, limits.tables, limits.multipliers));
  const inRange = allowed(all);
  if (inRange.length) return inRange;
  const chosen = allowed(limits.multipliers);
  return chosen.length ? chosen : all;
}

/**
 * Whether a spaced-repetition fact ("mul:8x3") still fits the grown-up's chosen tables and multipliers.
 * Anything that isn't a times-table or division fact is always allowed.
 */
export function allowsFact(key: string, tables: readonly number[], multipliers: readonly number[] = defaultMultipliers): boolean {
  const parts = key.split(":");
  if (parts.length !== 2 || (parts[0] !== "mul" && parts[0] !== "div")) return true;
  const numbers = parts[1]!.split("x").map(Number);
  if (numbers.length !== 2 || !numbers.every(Number.isInteger)) return true;
  const [table, multiplier] = numbers as [number, number];
  const enabled = tables.length ? tables : defaultTables;
  return enabled.includes(table) && allowsMultiplier(multiplier, enabled, multipliers.length ? multipliers : defaultMultipliers);
}

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
  options: {
    tables?: readonly number[]; multipliers?: readonly number[]; denominators?: readonly number[]; format?: AnswerFormat;
  } = {},
): Question {
  const pitch = clamp(level);
  const tables = options.tables?.length ? options.tables : defaultTables;
  const limits: Limits = { tables, multipliers: options.multipliers?.length ? options.multipliers : defaultMultipliers };
  const chosenDenominators = (options.denominators ?? []).filter((each) => each >= 2);
  const denominators = chosenDenominators.length ? chosenDenominators : defaultDenominators;
  let draft: Draft;
  switch (skill) {
    case "subtraction": draft = subtraction(pitch, rng); break;
    case "multiplication": draft = multiplication(pitch, limits, rng); break;
    case "division": draft = division(pitch, limits, rng); break;
    case "fractions": draft = fractions(pitch, denominators, rng); break;
    case "placeValue": draft = placeValue(pitch, rng); break;
    case "sequences": draft = sequences(pitch, tables, rng); break;
    case "wordProblems": draft = wordProblem(pitch, limits, rng); break;
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

/** Partition by place value, including hundreds and regrouping across a ten. */
export function additionHint(a: number, b: number): string {
  const parts = [100, 10, 1].filter((place) => Math.floor(a / place) % 10 || Math.floor(b / place) % 10);
  return parts.map((place) => {
    const x = Math.floor(a / place) % 10 * place, y = Math.floor(b / place) % 10 * place;
    return `${place === 100 ? "Hundreds" : place === 10 ? "Tens" : "Ones"}: ${x} + ${y} = ${x + y}.`;
  }).join(" ") + " Add these totals together.";
}

export function subtractionHint(a: number, b: number): string {
  let remaining = a;
  const steps = [100, 10, 1].map((place) => Math.floor(b / place) % 10 * place).filter((part) => part > 0);
  return `Start at ${a}. ` + steps.map((part, index) => {
    const start = remaining;
    remaining -= part;
    return index === steps.length - 1 ? `Then take away ${part}.` : `${start} − ${part} = ${remaining}.`;
  }).join(" ");
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
    hint: level <= 2 ? `Start at ${Math.max(a, b)} and count on ${Math.min(a, b)}.` : additionHint(a, b),
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
    hint: level <= 2 ? `Start at ${a} and count back ${b}.` : subtractionHint(a, b),
  };
}

function timesFact(table: number, other: number): Draft {
  const answer = table * other;
  const steps = Array.from({ length: Math.min(3, other) }, (_, index) => index + 1).map((step) => table * step).join(", ");
  return {
    key: `mul:${table}x${other}`,
    prompt: `${other} × ${table} = ?`, answer,
    near: [answer + table, answer - table, answer + other, answer - other, answer + 1, answer - 1, answer + 10].filter(positive),
    hint: `Start at 0. Make ${other} ${other === 1 ? "jump" : "jumps"} of ${table}: ${steps}${other > 3 ? ", …" : "."} Count one jump on each finger.`,
    audio: recordedFact("mul", table, other),
  };
}

function divisionFact(table: number, quotient: number): Draft {
  const dividend = table * quotient;
  return {
    key: `div:${table}x${quotient}`,
    prompt: `${dividend} ÷ ${table} = ?`, answer: quotient,
    near: [quotient + 1, quotient - 1, quotient + 2, quotient - 2, table, quotient * 2].filter(positive),
    hint: `Start at 0 and add ${table} each time until ${dividend}. Count your jumps: that is how many groups.`,
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

function multiplication(level: number, limits: Limits, rng: Rng): Draft {
  const table = pick(rng, tablesFor(level, limits.tables));
  if (level === 5 && randomBool(rng)) {
    // Year 3 extension: a multiple of ten times a single digit.
    const tens = pick(rng, multipliers(limits, 2, 8)) * 10;
    const answer = tens * table;
    return {
      prompt: `${tens} × ${table} = ?`, answer,
      near: [answer + 10, answer - 10, answer / 10, answer + table * 10, answer - table].filter(positive),
      hint: `Work out ${tens / 10} × ${table} first, then make it ten times bigger.`,
    };
  }
  const other = pick(rng, level === 1 ? multipliers(limits, 1, 6) : multipliers(limits, 2, 12));
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

function division(level: number, limits: Limits, rng: Rng): Draft {
  const table = pick(rng, tablesFor(level, limits.tables));
  const quotient = pick(rng, level === 1 ? multipliers(limits, 1, 6) : multipliers(limits, 2, 12));
  return divisionFact(table, quotient);
}

// Fractions, place value, sequences

function fractions(level: number, denominators: readonly number[], rng: Rng): Draft {
  /** One of the denominators this level normally uses, if allowed; otherwise any allowed one big enough. */
  const choose = (wanted: readonly number[], smallest: number): number | undefined => {
    const usable = wanted.filter((each) => denominators.includes(each));
    const pool = usable.length ? usable : denominators.filter((each) => each >= smallest);
    return pool.length ? pick(rng, pool) : undefined;
  };
  if (level === 1) return unitFraction(choose([2], 2)!, 2, denominators.includes(2) ? 10 : 5, rng);
  if (level === 2) return unitFraction(choose([3, 4], 2)!, 2, 6, rng);
  if (level === 3) return unitFraction(choose([3, 4, 5, 8, 10], 2)!, 2, 9, rng);
  if (level === 4) {
    const denominator = choose([3, 4, 5], 3);
    return denominator === undefined ? unitFraction(2, 2, 10, rng) : nonUnitFraction(denominator, rng);
  }
  const denominator = choose([5, 6, 7, 8, 9, 10], 4);
  if (denominator === undefined) {
    const third = choose([3], 3);
    return third === undefined ? unitFraction(2, 2, 10, rng) : nonUnitFraction(third, rng);
  }
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

/** "Half of 12" or "1/4 of 20". */
function unitFraction(denominator: number, low: number, high: number, rng: Rng): Draft {
  const part = randomInt(rng, low, high);
  const whole = denominator * part;
  if (denominator === 2) {
    return {
      prompt: `Half of ${whole} = ?`, answer: part, near: [part + 1, part - 1, whole, part + 2],
      hint: `Split ${whole} into 2 equal groups.`,
    };
  }
  return {
    prompt: `1/${denominator} of ${whole} = ?`, answer: part,
    near: [part + 1, part - 1, denominator, part * 2, whole - denominator].filter(positive),
    hint: `Share ${whole} into ${denominator} equal groups.`,
    spoken: `What is one ${ordinal(denominator)} of ${whole}?`,
  };
}

/** "2/3 of 15". */
function nonUnitFraction(denominator: number, rng: Rng): Draft {
  const numerator = randomInt(rng, 2, denominator - 1);
  const part = randomInt(rng, 2, 6);
  const whole = denominator * part;
  const answer = numerator * part;
  return {
    prompt: `${numerator}/${denominator} of ${whole} = ?`, answer,
    near: [part, whole - part, answer + part, answer - 1, answer + 1].filter(positive),
    hint: `First share ${whole} into ${denominator} groups: ${whole} ÷ ${denominator} = ${part}. Then add ${numerator} lots of ${part}.`,
    spoken: `What is ${numerator} ${ordinal(denominator)}s of ${whole}?`,
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

function sequences(level: number, tables: readonly number[], rng: Rng): Draft {
  const steps = level === 1 ? [2, 5, 10] : level === 2 ? [3, 4] : level === 3 ? [4, 8] : level === 4 ? [50, 100] : [3, 4, 8, 50];
  // Counting in 8s is the 8 times table, so skip steps from tables that are switched off.
  const allowed = steps.filter((each) => !defaultTables.includes(each) || tables.includes(each));
  const step = pick(rng, allowed.length === 0 ? tables : allowed);
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

function wordProblem(level: number, limits: Limits, rng: Rng): Draft {
  const things = pick(rng, ["shells", "pearls", "berries", "acorns", "starfish", "pebbles"]);
  const easy = level <= 2;
  switch (randomInt(rng, 0, level >= 4 ? 4 : 3)) {
    case 0: {
      const a = easy ? randomInt(rng, 5, 20) : randomInt(rng, 20, 70);
      const b = easy ? randomInt(rng, 3, 9) : randomInt(rng, 11, 28);
      return {
        prompt: `Otter has ${a} ${things}. Mosey gives him ${b} more. How many now?`, answer: a + b,
        near: [a + b + 1, a + b - 1, a - b, a + b + 10, a + b - 10].filter(positive),
        hint: `More means add. ${additionHint(a, b)}`,
      };
    }
    case 1: {
      const a = easy ? randomInt(rng, 10, 20) : randomInt(rng, 30, 90);
      const b = easy ? randomInt(rng, 2, 8) : randomInt(rng, 11, 25);
      return {
        prompt: `Mosey has ${a} ${things}. He gives ${b} away. How many are left?`, answer: a - b,
        near: [a - b + 1, a - b - 1, a + b, a - b + 10, a - b - 10].filter(positive),
        hint: `Giving away means subtract. ${subtractionHint(a, b)}`,
      };
    }
    case 2: {
      const table = pick(rng, tablesFor(Math.max(level, 2), limits.tables));
      const groups = pick(rng, multipliers(limits, 2, easy ? 5 : 9));
      const answer = groups * table;
      return {
        key: `mul:${table}x${groups}`,
        prompt: `${groups} baby dragons eat ${table} ${things} each. How many altogether?`, answer,
        near: [groups + table, answer + table, answer - table, answer + 1].filter(positive),
        hint: `${groups} lots of ${table} is ${groups} × ${table}.`,
      };
    }
    case 3: {
      const table = pick(rng, tablesFor(Math.max(level, 2), limits.tables));
      const each = pick(rng, multipliers(limits, 2, easy ? 5 : 9));
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
