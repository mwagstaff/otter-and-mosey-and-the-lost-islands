import { difficultyTitles } from "./learner";
import { allowsMultiplier, defaultDenominators, defaultMultipliers, defaultTables } from "./maths";
import { newParentSettings, type ParentSettings } from "./session";
import { skillTitles, spellingTopics, type Skill } from "./skill";

// Ported from Packages/LostIslandsCore/Sources/LostIslandsCore/Education/SettingsSummary.swift.

/** One line of the grown-ups' settings in plain words, for the check before a new player's first adventure. */
export interface SettingsLine {
  label: string;
  value: string;
  /** True when it differs from what a new player starts with. */
  changed: boolean;
}

const fractionNames: Record<number, string> = {
  2: "halves", 3: "thirds", 4: "quarters", 5: "fifths", 6: "sixths", 7: "sevenths", 8: "eighths", 9: "ninths", 10: "tenths",
};

// "×" and its number are joined by a non-breaking space so a narrow screen never splits them.
const capitalised = (text: string) => text.charAt(0).toUpperCase() + text.slice(1);

/** "a", "a and b", "a, b and c". */
function listed(items: readonly string[], last = "and"): string {
  if (items.length <= 1) return items[0] ?? "";
  return `${items.slice(0, -1).join(", ")} ${last} ${items[items.length - 1]}`;
}

const sameSet = (a: readonly unknown[], b: readonly unknown[]) => a.length === b.length && a.every((item) => b.includes(item));

interface Wording<T> {
  name: (item: T) => string;
  everything: string;
  /** "× 1 to × 10" or "halves to quarters", for a run with nothing missing. */
  range?: (low: T, high: T) => string;
}

/**
 * The chosen items in as few words as possible: everything, "Only …", a range, a range or
 * "All but" with one or two gaps, or else a plain list.
 */
function describeChoices<T>(chosen: readonly T[], all: readonly T[], wording: Wording<T>): string {
  const picked = all.filter((item) => chosen.includes(item));
  if (picked.length === all.length) return wording.everything;
  if (picked.length === 0) return "None";
  if (picked.length === 1) return `Only ${wording.name(picked[0]!)}`;
  const start = all.indexOf(picked[0]!);
  const end = all.indexOf(picked[picked.length - 1]!);
  const span = wording.range ? all.slice(start, end + 1) : all;
  const missing = span.filter((item) => !picked.includes(item));
  const full = span.length === all.length;
  if (wording.range && missing.length === 0) return capitalised(wording.range(picked[0]!, picked[picked.length - 1]!));
  if (missing.length <= 2) {
    const gaps = missing.map(wording.name);
    if (full) return `All but ${listed(gaps)}`;
    return capitalised(`${wording.range!(picked[0]!, picked[picked.length - 1]!)}, but not ${listed(gaps, "or")}`);
  }
  return capitalised(listed(picked.map(wording.name)));
}

/** The numbers times-table and division questions can actually use, once switched-off tables are left out. */
export function usableMultipliers(settings: ParentSettings): number[] {
  return defaultMultipliers.filter((value) => allowsMultiplier(value, settings.tables, settings.multipliers));
}

/** A grown-up's learning settings in plain words, in the order the quick setup shows them. */
export function settingsSummary(settings: ParentSettings): SettingsLine[] {
  const fresh = newParentSettings();
  const tables = defaultTables.filter((table) => settings.tables.includes(table));
  const multipliers = usableMultipliers(settings);
  const denominators = defaultDenominators.filter((denominator) => settings.denominators.includes(denominator));
  const topics = spellingTopics.filter((topic) => settings.spellingTopics.includes(topic));
  const topicName = (topic: Skill) => skillTitles[topic].toLowerCase();
  return [
    {
      label: "Difficulty",
      value: difficultyTitles[settings.difficulty].replace(/\s*\(.*\)$/, ""),
      changed: settings.difficulty !== fresh.difficulty,
    },
    {
      label: "Times tables",
      value: listed(tables.map(String)),
      changed: !sameSet(tables, fresh.tables),
    },
    {
      label: "Multiply and divide by",
      value: describeChoices(multipliers, defaultMultipliers, {
        name: (value) => `×\u00a0${value}`,
        everything: "Everything from ×\u00a01 to ×\u00a012",
        range: (low, high) => `×\u00a0${low} to ×\u00a0${high}`,
      }),
      changed: multipliers.length !== defaultMultipliers.length,
    },
    {
      label: "Fractions",
      value: describeChoices(denominators, defaultDenominators, {
        name: (denominator) => fractionNames[denominator]!,
        everything: "Halves to tenths",
        range: (low, high) => `${fractionNames[low]} to ${fractionNames[high]}`,
      }),
      changed: denominators.length !== defaultDenominators.length,
    },
    {
      label: "Spelling",
      value: describeChoices(topics, spellingTopics, { name: topicName, everything: `All ${spellingTopics.length} topics` }),
      changed: topics.length !== spellingTopics.length,
    },
  ];
}
