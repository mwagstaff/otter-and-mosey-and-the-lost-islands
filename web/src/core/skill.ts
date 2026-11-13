/** The broad subject a skill belongs to. Used for dashboards and accuracy totals. */
export type Subject = "spelling" | "typing" | "maths";

export const subjectTitles: Record<Subject, string> = { spelling: "Spelling", typing: "Typing", maths: "Maths" };

/** Every trackable skill, in display order. The names are stable: they are save-data keys. */
export const allSkills = [
  "exceptionWords", "prefixes", "suffixes", "homophones", "starterWords",
  "typing",
  "addition", "subtraction", "multiplication", "division",
  "fractions", "placeValue", "sequences", "wordProblems",
] as const;

export type Skill = (typeof allSkills)[number];

export function isSkill(value: unknown): value is Skill {
  return typeof value === "string" && (allSkills as readonly string[]).includes(value);
}

const spelling: readonly Skill[] = ["exceptionWords", "prefixes", "suffixes", "homophones", "starterWords"];

export function subjectOf(skill: Skill): Subject {
  if (spelling.includes(skill)) return "spelling";
  return skill === "typing" ? "typing" : "maths";
}

export const skillTitles: Record<Skill, string> = {
  exceptionWords: "Tricky words",
  prefixes: "Prefixes",
  suffixes: "Suffixes",
  homophones: "Homophones",
  starterWords: "Warm-up words",
  typing: "Typing",
  addition: "Addition",
  subtraction: "Subtraction",
  multiplication: "Times tables",
  division: "Division",
  fractions: "Fractions",
  placeValue: "Place value",
  sequences: "Number sequences",
  wordProblems: "Word problems",
};

export const spellingTopics: readonly Skill[] = ["starterWords", "exceptionWords", "prefixes", "suffixes", "homophones"];
export const mathsTopics: readonly Skill[] = allSkills.filter((skill) => subjectOf(skill) === "maths");

/** How the child is entering text. Typing content adapts to this. */
export type InputProfile =
  /** Phone-sized touch keyboard: short words, letter trays. */
  | "compactTouch"
  /** Tablet-sized touch keyboard: longer words and short sentences. */
  | "fullTouch"
  /** A real keyboard: full sentences, speed is measured. */
  | "hardware";
