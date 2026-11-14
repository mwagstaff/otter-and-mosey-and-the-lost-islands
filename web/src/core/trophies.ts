import type { Catalog, GameMode } from "./catalog";
import { catalog as bundled } from "./content";
import { dayKey, hasReward, starsFor, timestamp, totalStars, type Profile } from "./save";
import type { LevelResult } from "./session";
import { allSkills, subjectOf, type Skill } from "./skill";

// The trophy cabinet, ported from `Trophies.swift`: every trophy there is, when each is won,
// and how many are handed out at the end of a level.

export type TrophyGroup = "islands" | "milestones" | "learning" | "collections" | "secret";
export const trophyGroups: readonly TrophyGroup[] = ["islands", "milestones", "learning", "collections", "secret"];
export const trophyGroupTitles: Record<TrophyGroup, string> = {
  islands: "Islands", milestones: "Milestones", learning: "Learning", collections: "Collections", secret: "Secret",
};

/** Lifetime counts that feed the milestone ladders. */
export type TrophyCounter =
  | "stars" | "pearls" | "answers" | "firstTry" | "words" | "maths" | "streak" | "typing" | "levels" | "friendship" | "days" | "crystals";

export const counterUnits: Record<TrophyCounter, string> = {
  stars: "stars", pearls: "pearls", answers: "right answers", firstTry: "right first time", words: "words spelt",
  maths: "maths answers", streak: "in a row", typing: "words a minute", levels: "levels played",
  friendship: "Friendship Power uses", days: "days played", crystals: "fragments",
};

export type TrophyRule =
  | { kind: "superstar"; level: string }
  | { kind: "flawless"; level: string }
  | { kind: "guardianFriend"; island: string }
  | { kind: "champion"; island: string }
  | { kind: "count"; counter: TrophyCounter; needed: number }
  | { kind: "skill"; skill: Skill }
  | { kind: "table"; table: number }
  | { kind: "pets"; needed: number }
  | { kind: "decorations"; needed: number }
  | { kind: "firstSteps" | "allPets" | "allHats" | "allTreasures" }
  | { kind: "comeback" | "neverGiveUp" | "pearlPerfect" | "turboAce" | "hatTrick" | "oldFriends" | "backForMore" | "weekend" | "noHints" | "rainbowDay" };

/** Won by one particular run rather than by something that stays true. */
function isMoment(rule: TrophyRule): boolean {
  return ["comeback", "neverGiveUp", "pearlPerfect", "turboAce", "oldFriends", "noHints"].includes(rule.kind);
}

export interface Trophy {
  id: string;
  title: string;
  /** How to win it, in words a child can follow. */
  detail: string;
  /** For a secret trophy, the riddle shown until it is won. */
  riddle?: string;
  group: TrophyGroup;
  /** The painted picture's asset name. */
  art: string;
  /** 0 for a one-off trophy; 1…5 for the rung of a milestone ladder. */
  tier: number;
  rule: TrophyRule;
  islandID?: string;
  levelID?: string;
  ladder?: string;
  /** The short label printed on a rung or learning badge, such as "250" or "×3". */
  badge?: string;
}

export interface TrophyLadder {
  id: string;
  title: string;
  counter: TrophyCounter;
  rungs: number[];
  art: (rung: number) => string;
}

/** The most trophies handed out at the end of one level. Any more wait for the next level. */
export const trophiesPerLevel = 2;
export const masteryTarget = 20;
export const trophyTables = [2, 3, 4, 5, 8, 10];

export const trophyLadders: readonly TrophyLadder[] = [
  { id: "stars", title: "Star Collector", counter: "stars", rungs: [10, 30, 60, 90], art: () => "badge_stars-30" },
  { id: "pearls", title: "Pearl Diver", counter: "pearls", rungs: [25, 100, 250, 500], art: () => "badge_pearls" },
  { id: "answers", title: "Busy Brain", counter: "answers", rungs: [50, 100, 250, 500, 1000], art: (rung) => (rung < 250 ? "badge_answers-50" : "badge_answers-250") },
  { id: "first-try", title: "Sharp Shooter", counter: "firstTry", rungs: [25, 100, 250, 500], art: () => "badge_sharp-shooter" },
  { id: "words", title: "Wordsmith", counter: "words", rungs: [40, 150, 400], art: () => "badge_wordsmith" },
  { id: "maths", title: "Number Ninja", counter: "maths", rungs: [40, 150, 400], art: () => "badge_number-ninja" },
  { id: "combo", title: "Streak Star", counter: "streak", rungs: [5, 8, 9], art: (rung) => `badge_combo-${rung}` },
  { id: "typing", title: "Fast Fingers", counter: "typing", rungs: [8, 12, 15, 20], art: () => "badge_fast-fingers" },
  { id: "levels", title: "Adventurer", counter: "levels", rungs: [10, 30, 60, 100], art: () => "badge_adventurer" },
  { id: "friends", title: "Best Friends", counter: "friendship", rungs: [1, 10, 30], art: () => "badge_friendship" },
  { id: "days", title: "Explorer", counter: "days", rungs: [2, 5, 10, 20], art: () => "badge_explorer" },
  { id: "crystals", title: "Crystal Keeper", counter: "crystals", rungs: [3, 6], art: (rung) => `badge_crystal-${rung}` },
];

const skillTitles: Partial<Record<Skill, string>> = {
  prefixes: "prefixes", suffixes: "suffixes", homophones: "homophones", exceptionWords: "tricky words",
  fractions: "fractions", division: "division", placeValue: "place value", wordProblems: "word problems",
};

function build(catalog: Catalog): Trophy[] {
  const list: Trophy[] = [];
  for (const island of catalog.islands) {
    for (const level of island.levels) {
      list.push({ id: `superstar-${level.id}`, title: "Superstar", detail: `Earn three stars in ${level.title}.`, group: "islands",
        art: "badge_three-stars", tier: 0, rule: { kind: "superstar", level: level.id }, islandID: island.id, levelID: level.id });
      list.push({ id: `flawless-${level.id}`, title: "Flawless", detail: `Get every answer right first time in ${level.title}.`, group: "islands",
        art: "badge_perfect", tier: 0, rule: { kind: "flawless", level: level.id }, islandID: island.id, levelID: level.id });
    }
    list.push({ id: `friend-${island.id}`, title: `${island.guardian.name}’s Friend`,
      detail: `Befriend ${island.guardian.name} and find the ${island.name} crystal fragment.`, group: "islands",
      art: "badge_crystal-1", tier: 0, rule: { kind: "guardianFriend", island: island.id }, islandID: island.id });
    list.push({ id: `champion-${island.id}`, title: `${island.name} Champion`, detail: `Earn three stars on every level of ${island.name}.`,
      group: "islands", art: "trophy_champion", tier: 0, rule: { kind: "champion", island: island.id }, islandID: island.id });
  }
  for (const ladder of trophyLadders) {
    ladder.rungs.forEach((rung, index) => {
      const detail = (() => {
        switch (ladder.counter) {
          case "streak": return rung === 9 ? "Get all 9 right in a row in a guardian battle." : `Get ${rung} right in a row.`;
          case "typing": return `Type at ${rung} words a minute.`;
          case "friendship": return rung === 1 ? "Use Friendship Power." : `Use Friendship Power ${rung} times.`;
          case "days": return `Play on ${rung} different days.`;
          case "crystals": return rung === 6 ? "Restore the Great Rainbow Crystal." : `Recover ${rung} crystal fragments.`;
          case "levels": return `Finish ${rung} levels.`;
          default: return `Collect ${rung} ${counterUnits[ladder.counter]}.`;
        }
      })();
      list.push({ id: `${ladder.id}-${rung}`, title: ladder.title, detail, group: "milestones", art: ladder.art(rung), tier: index + 1,
        rule: { kind: "count", counter: ladder.counter, needed: rung }, ladder: ladder.id, badge: String(rung) });
    });
  }
  for (const table of trophyTables) {
    list.push({ id: `table-${table}`, title: `×${table} table`, detail: `Get ${masteryTarget} answers in the ${table} times table right first time.`,
      group: "learning", art: "badge_tables", tier: 0, rule: { kind: "table", table }, badge: `×${table}` });
  }
  const topics: [Skill, string, string][] = [
    ["prefixes", "Prefix Pro", "badge_prefixes"], ["suffixes", "Suffix Star", "badge_suffixes"],
    ["homophones", "Homophone Hero", "badge_homophones"], ["exceptionWords", "Tricky Word Tamer", "badge_tricky-words"],
    ["fractions", "Fraction Finder", "badge_fractions"], ["division", "Fair Sharer", "badge_division"],
    ["placeValue", "Place Value Pal", "badge_place-value"], ["wordProblems", "Puzzle Solver", "badge_word-problems"],
  ];
  for (const [skill, title, art] of topics) {
    list.push({ id: `skill-${skill}`, title, detail: `Get ${masteryTarget} ${skillTitles[skill]} questions right first time.`,
      group: "learning", art, tier: 0, rule: { kind: "skill", skill } });
  }
  const pets = catalog.rewards.filter((reward) => reward.kind === "pet").length;
  list.push(
    { id: "first-steps", title: "First Steps", detail: "Finish your first level.", group: "collections", art: "badge_first-steps", tier: 0, rule: { kind: "firstSteps" } },
    { id: "pets-5", title: "Animal Friend", detail: "Collect five pets.", group: "collections", art: "badge_pets-5", tier: 0, rule: { kind: "pets", needed: 5 } },
    { id: "pets-all", title: "Animal Park", detail: `Collect all ${pets} pets.`, group: "collections", art: "badge_pets-all", tier: 0, rule: { kind: "allPets" } },
    { id: "hats-all", title: "Dress-up", detail: "Try on every hat.", group: "collections", art: "badge_hats-all", tier: 0, rule: { kind: "allHats" } },
    { id: "decorator", title: "Home Designer", detail: "Put 8 decorations on your Home island.", group: "collections", art: "badge_decorator", tier: 0, rule: { kind: "decorations", needed: 8 } },
    { id: "treasure-all", title: "Treasure Hunter", detail: "Collect every treasure in the game.", group: "collections", art: "badge_treasure-all", tier: 0, rule: { kind: "allTreasures" } },
  );
  const secrets: [string, string, string, string, TrophyRule["kind"]][] = [
    ["comeback", "Comeback Kid", "Get a question right after two wrong tries.", "Try, try and try again…", "comeback"],
    ["never-give-up", "Never Give Up", "Turn a one-star level into three stars.", "One becomes three…", "neverGiveUp"],
    ["pearl-perfect", "Pearl Perfect", "Scoop every pearl in a Maths Splash level.", "Every pearl, every time…", "pearlPerfect"],
    ["turbo-ace", "Turbo Ace", "Type with no slips at all in Typing Turbo.", "Faster than a comet, with no slips…", "turboAce"],
    ["hat-trick", "Hat Trick", "Finish three levels in a row wearing a hat.", "Wear it, wear it, wear it!", "hatTrick"],
    ["old-friends", "Old Friends", "Visit a guardian you’ve already befriended.", "Pop in on a friend…", "oldFriends"],
    ["back-for-more", "Back for More", "Play the same level three times.", "Once more, with feeling…", "backForMore"],
    ["weekend", "Weekend Explorer", "Play on a Saturday and on a Sunday.", "Saturday… and Sunday?", "weekend"],
    ["no-hints", "No Help Needed", "Beat a guardian without a single hint.", "No help needed…", "noHints"],
    ["rainbow-day", "Rainbow Day", "Win trophies on three different islands in one day.", "Three islands, one day…", "rainbowDay"],
  ];
  for (const [id, title, detail, riddle, kind] of secrets) {
    list.push({ id, title, detail, riddle, group: "secret", art: `badge_${id}`, tier: 0, rule: { kind } as TrophyRule });
  }
  return list;
}

const cache = new WeakMap<Catalog, Trophy[]>();

/** Every trophy, in cabinet order. */
export function allTrophies(catalog: Catalog = bundled): Trophy[] {
  let list = cache.get(catalog);
  if (!list) {
    list = build(catalog);
    cache.set(catalog, list);
  }
  return list;
}

export function trophy(id: string, catalog: Catalog = bundled): Trophy | undefined {
  return allTrophies(catalog).find((each) => each.id === id);
}

// Counting

export function counterValue(counter: TrophyCounter, profile: Profile): number {
  const learner = profile.learner;
  const sum = (skills: readonly Skill[], field: "correct" | "attempts") => skills.reduce((total, skill) => total + learner.stats(skill)[field], 0);
  switch (counter) {
    case "stars": return totalStars(profile);
    case "pearls": return profile.stats.pearls;
    case "answers": return learner.answerCount;
    case "firstTry": return sum(allSkills, "correct");
    case "words": return sum(allSkills.filter((skill) => subjectOf(skill) === "spelling"), "attempts");
    case "maths": return sum(allSkills.filter((skill) => subjectOf(skill) === "maths"), "attempts");
    case "streak": return profile.bestCombo;
    case "typing": return Math.floor(Math.max(learner.typing.bestWordsPerMinute, learner.typing.bestTouchWordsPerMinute));
    case "levels": return Object.values(profile.levels).reduce((total, level) => total + level.plays, 0);
    case "friendship": return profile.friendshipPowers;
    case "days": return profile.stats.playDays;
    case "crystals": return profile.crystals.length;
  }
}

function petCount(profile: Profile, catalog: Catalog): number {
  return profile.rewards.filter((id) => catalog.reward(id)?.kind === "pet").length;
}

function hatsTried(profile: Profile, catalog: Catalog): number {
  return catalog.rewards.filter((reward) => reward.kind === "accessory" && profile.stats.hatsWorn.includes(reward.id)).length;
}

/** Progress towards a trophy, for the cabinet's progress bars. */
export function trophyProgress(item: Trophy, profile: Profile, catalog: Catalog = bundled): { now: number; needed: number } | undefined {
  const rule = item.rule;
  const of = (kind: string) => catalog.rewards.filter((reward) => reward.kind === kind).length;
  switch (rule.kind) {
    case "count": return { now: Math.min(counterValue(rule.counter, profile), rule.needed), needed: rule.needed };
    case "skill": return { now: Math.min(profile.learner.stats(rule.skill).correct, masteryTarget), needed: masteryTarget };
    case "table": return { now: Math.min(profile.stats.tableFirstTry[String(rule.table)] ?? 0, masteryTarget), needed: masteryTarget };
    case "pets": return { now: Math.min(petCount(profile, catalog), rule.needed), needed: rule.needed };
    case "allPets": return { now: petCount(profile, catalog), needed: of("pet") };
    case "allHats": return { now: hatsTried(profile, catalog), needed: of("accessory") };
    case "decorations": return { now: Math.min(profile.decorations.length, rule.needed), needed: rule.needed };
    case "allTreasures": return { now: catalog.rewards.filter((reward) => hasReward(profile, reward.id)).length, needed: catalog.rewards.length };
    case "champion": {
      const island = catalog.island(rule.island);
      return island && { now: island.levels.filter((level) => starsFor(profile, level.id) === 3).length, needed: island.levels.length };
    }
    default: return undefined;
  }
}

// Winning

/** Facts about the level that has just finished, for trophies won by a single run. */
export interface TrophyRun {
  levelID: string;
  islandID: string;
  mode: GameMode;
  result: LevelResult;
  previousStars: number;
  guardianAlreadyFriend: boolean;
}

function isMet(item: Trophy, profile: Profile, run: TrophyRun | undefined, catalog: Catalog): boolean {
  const rule = item.rule;
  switch (rule.kind) {
    case "superstar": return starsFor(profile, rule.level) >= 3;
    case "flawless": return profile.levels[rule.level]?.flawless === true;
    case "guardianFriend": return profile.crystals.includes(rule.island);
    case "champion": {
      const island = catalog.island(rule.island);
      return !!island && island.levels.every((level) => starsFor(profile, level.id) >= 3);
    }
    case "count": return counterValue(rule.counter, profile) >= rule.needed;
    case "skill": return profile.learner.stats(rule.skill).correct >= masteryTarget;
    case "table": return (profile.stats.tableFirstTry[String(rule.table)] ?? 0) >= masteryTarget;
    case "firstSteps": return Object.keys(profile.levels).length > 0;
    case "pets": return petCount(profile, catalog) >= rule.needed;
    case "allPets": return petCount(profile, catalog) >= catalog.rewards.filter((reward) => reward.kind === "pet").length;
    case "allHats": return hatsTried(profile, catalog) >= catalog.rewards.filter((reward) => reward.kind === "accessory").length;
    case "decorations": return profile.decorations.length >= rule.needed;
    case "allTreasures": return catalog.rewards.every((reward) => hasReward(profile, reward.id));
    case "hatTrick": return profile.stats.hatStreak >= 3;
    case "backForMore": return Object.values(profile.levels).some((level) => level.plays >= 3);
    case "weekend": return profile.stats.weekendDays.includes(1) && profile.stats.weekendDays.includes(7);
    case "rainbowDay": return profile.stats.trophyDayIslands.length >= 3;
    case "comeback": return run?.result.comeback === true;
    case "neverGiveUp": return !!run && run.previousStars === 1 && run.result.stars === 3;
    case "pearlPerfect": {
      if (!run || run.mode !== "mathsSplash") return false;
      const offered = run.result.pearlsOffered ?? 0;
      return offered > 0 && (run.result.pearls ?? 0) >= offered;
    }
    case "turboAce": return !!run && run.mode === "typingTurbo" && run.result.typingAccuracy !== undefined && run.result.typingAccuracy >= 1;
    case "oldFriends": return !!run && run.mode === "guardian" && run.guardianAlreadyFriend;
    case "noHints": return !!run && run.mode === "guardian" && (run.result.hintsUsed ?? 0) === 0 && run.result.total > 0;
  }
}

const renamed: Record<string, string> = {
  "wordsmith": "words-40", "number-ninja": "maths-40", "fast-fingers": "typing-15",
  "friendship": "friends-1", "crystal-3": "crystals-3", "crystal-6": "crystals-6",
};

/**
 * Renames stickers from before the cabinet and puts in every trophy the player had already
 * won, so a returning player starts with a cabinet that reflects what they've done.
 */
export function prepareTrophies(profile: Profile, catalog: Catalog = bundled, now: Date = new Date()): void {
  if (profile.trophiesReady) return;
  const known = new Set(allTrophies(catalog).map((item) => item.id));
  const trophies: Record<string, string> = {};
  for (const [id, when] of Object.entries(profile.achievements)) {
    const newID = renamed[id] ?? id;
    if (known.has(newID)) trophies[newID] = when;
  }
  const when = timestamp(now);
  for (const item of allTrophies(catalog)) {
    if (trophies[item.id] === undefined && !isMoment(item.rule) && isMet(item, profile, undefined, catalog)) trophies[item.id] = when;
  }
  profile.achievements = trophies;
  profile.trophiesReady = true;
}

/** Hands out trophies at the end of a level: this level's own first, then waiting ones, then the rest. */
export function awardTrophies(profile: Profile, run: TrophyRun, catalog: Catalog = bundled, now: Date = new Date(), limit = trophiesPerLevel): Trophy[] {
  const list = allTrophies(catalog);
  const byID = new Map(list.map((item) => [item.id, item]));
  const waiting = profile.pendingTrophies.filter((id) => byID.has(id) && profile.achievements[id] === undefined);
  const newlyMet = list.filter((item) => profile.achievements[item.id] === undefined && !waiting.includes(item.id) && isMet(item, profile, run, catalog));
  const rank = (item: Trophy): number => {
    const rule = item.rule;
    if ((rule.kind === "guardianFriend" && rule.island === run.islandID) || rule.kind === "firstSteps") return 0;
    if ((rule.kind === "superstar" || rule.kind === "flawless") && rule.level === run.levelID) return 1;
    return isMoment(rule) ? 2 : 4;
  };
  const fresh = newlyMet
    .map((item, index) => ({ item, index }))
    .sort((a, b) => rank(a.item) - rank(b.item) || a.item.tier - b.item.tier || a.index - b.index)
    .map(({ item }) => item);
  const ordered = [...fresh.filter((item) => rank(item) < 4), ...waiting.map((id) => byID.get(id)!), ...fresh.filter((item) => rank(item) >= 4)];
  const given = ordered.slice(0, limit);
  const when = timestamp(now);
  for (const item of given) profile.achievements[item.id] = when;
  profile.pendingTrophies = ordered.slice(limit).map((item) => item.id);
  if (given.length > 0) {
    const today = dayKey(now);
    if (profile.stats.trophyDay !== today) {
      profile.stats.trophyDay = today;
      profile.stats.trophyDayIslands = [];
    }
    if (!profile.stats.trophyDayIslands.includes(run.islandID)) profile.stats.trophyDayIslands.push(run.islandID);
  }
  return given;
}

/** How many trophies the player has, out of how many. */
export function trophyCount(profile: Profile, catalog: Catalog = bundled): { won: number; total: number } {
  const list = allTrophies(catalog);
  return { won: list.filter((item) => profile.achievements[item.id] !== undefined).length, total: list.length };
}
