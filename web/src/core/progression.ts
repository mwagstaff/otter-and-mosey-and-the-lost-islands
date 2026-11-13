import { starDecorations, type Catalog, type Island, type LevelDef, type Reward } from "./catalog";
import { catalog as bundled } from "./content";
import type { LearnerModel } from "./learner";
import { hasReward, newLevelRecord, starsFor, timestamp, totalStars, type Profile } from "./save";
import type { LevelResult } from "./session";
import { allSkills, subjectOf, type Subject } from "./skill";

// Unlock rules and achievements. Star ratings live in session.ts (`starsForAccuracy`).

export interface Achievement {
  id: string;
  title: string;
  detail: string;
  emoji: string;
}

/** What a child earned from finishing a level, for the celebration screen. */
export interface RewardSummary {
  stars: number;
  isFirstClear: boolean;
  isNewBest: boolean;
  reward?: Reward;
  crystalIsland?: Island;
  achievements: Achievement[];
  decorations: Reward[];
  gameComplete: boolean;
}

export function isIslandUnlocked(island: Island, profile: Profile, catalog: Catalog = bundled): boolean {
  const index = catalog.islands.findIndex((other) => other.id === island.id);
  if (index < 0) return false;
  return index === 0 || profile.crystals.includes(catalog.islands[index - 1]!.id);
}

export function isLevelUnlocked(levelID: string, profile: Profile, catalog: Catalog = bundled): boolean {
  const island = catalog.islandContaining(levelID);
  if (!island || !isIslandUnlocked(island, profile, catalog)) return false;
  const index = island.levels.findIndex((level) => level.id === levelID);
  return index === 0 || starsFor(profile, island.levels[index - 1]!.id) > 0;
}

/** The next level the child has not yet cleared, for the Continue button. */
export function nextLevelFor(profile: Profile, catalog: Catalog = bundled): LevelDef | undefined {
  return catalog.allLevels.find((level) => starsFor(profile, level.id) === 0 && isLevelUnlocked(level.id, profile, catalog));
}

export const achievements: readonly Achievement[] = [
  { id: "first-steps", title: "First Steps", detail: "Finish your first level", emoji: "👣" },
  { id: "three-stars", title: "Shining Bright", detail: "Earn three stars on a level", emoji: "🌟" },
  { id: "perfect", title: "Flawless", detail: "Finish a level with every answer right first time", emoji: "💯" },
  { id: "combo-5", title: "Combo Champion", detail: "Get 5 right in a row", emoji: "🔥" },
  { id: "combo-8", title: "Rainbow Streak", detail: "Get 8 right in a row", emoji: "🌈" },
  { id: "crystal-1", title: "Crystal Finder", detail: "Recover a crystal fragment", emoji: "💎" },
  { id: "crystal-3", title: "Halfway Hero", detail: "Recover three crystal fragments", emoji: "🏅" },
  { id: "crystal-6", title: "World Restorer", detail: "Restore the Great Rainbow Crystal", emoji: "👑" },
  { id: "friendship", title: "Best Friends", detail: "Use Friendship Power", emoji: "💞" },
  { id: "pets-5", title: "Animal Friend", detail: "Collect five pets", emoji: "🐾" },
  { id: "answers-50", title: "Busy Brain", detail: "Answer 50 questions", emoji: "🧠" },
  { id: "answers-250", title: "Unstoppable", detail: "Answer 250 questions", emoji: "🚀" },
  { id: "wordsmith", title: "Wordsmith", detail: "Spell 40 words", emoji: "📚" },
  { id: "number-ninja", title: "Number Ninja", detail: "Answer 40 maths questions", emoji: "🔢" },
  { id: "fast-fingers", title: "Fast Fingers", detail: "Type at 15 words per minute", emoji: "⌨️" },
  { id: "stars-30", title: "Star Collector", detail: "Collect 30 stars", emoji: "✨" },
];

/** Applies a finished level to the profile (changing it in place) and reports what was newly earned. */
export function applyResult(
  result: LevelResult, levelID: string, learner: LearnerModel, profile: Profile,
  options: { usedFriendshipPower?: number; catalog?: Catalog; now?: Date } = {},
): RewardSummary {
  const catalog = options.catalog ?? bundled;
  const summary: RewardSummary = {
    stars: result.stars, isFirstClear: false, isNewBest: false, achievements: [], decorations: [], gameComplete: false,
  };
  const level = catalog.level(levelID);
  const island = catalog.islandContaining(levelID);
  if (!level || !island) return summary;

  const record = profile.levels[levelID] ?? newLevelRecord();
  summary.isFirstClear = record.stars === 0;
  summary.isNewBest = result.stars > record.stars || result.score > record.bestScore;
  record.stars = Math.max(record.stars, result.stars);
  record.bestScore = Math.max(record.bestScore, result.score);
  record.plays += 1;
  profile.levels[levelID] = record;
  profile.learner = learner.clone();
  profile.lastLevelID = levelID;
  profile.bestCombo = Math.max(profile.bestCombo, result.bestCombo);
  profile.friendshipPowers += options.usedFriendshipPower ?? 0;

  const reward = level.reward === undefined ? undefined : catalog.reward(level.reward);
  if (summary.isFirstClear && reward && !hasReward(profile, reward.id)) {
    profile.rewards.push(reward.id);
    summary.reward = reward;
  }
  if (level.mode === "guardian" && !profile.crystals.includes(island.id)) {
    profile.crystals.push(island.id);
    summary.crystalIsland = island;
    summary.gameComplete = profile.crystals.length === catalog.islands.length;
  }
  for (const { stars, reward: id } of starDecorations) {
    const decoration = catalog.reward(id);
    if (totalStars(profile) >= stars && !hasReward(profile, id) && decoration) {
      profile.rewards.push(id);
      summary.decorations.push(decoration);
    }
  }
  summary.achievements = newAchievements(profile, result, catalog);
  const when = timestamp(options.now);
  for (const achievement of summary.achievements) profile.achievements[achievement.id] = when;
  return summary;
}

function newAchievements(profile: Profile, result: LevelResult, catalog: Catalog): Achievement[] {
  const learner = profile.learner;
  const correctIn = (subject: Subject) =>
    allSkills.filter((skill) => subjectOf(skill) === subject).reduce((sum, skill) => sum + learner.stats(skill).correct, 0);
  const pets = profile.rewards.filter((id) => catalog.reward(id)?.kind === "pet").length;
  const earned: Record<string, boolean> = {
    "first-steps": Object.keys(profile.levels).length > 0,
    "three-stars": result.stars >= 3,
    "perfect": result.total > 0 && result.correctFirstTry === result.total,
    "combo-5": profile.bestCombo >= 5,
    "combo-8": profile.bestCombo >= 8,
    "crystal-1": profile.crystals.length >= 1,
    "crystal-3": profile.crystals.length >= 3,
    "crystal-6": profile.crystals.length >= 6,
    "friendship": profile.friendshipPowers > 0,
    "pets-5": pets >= 5,
    "answers-50": learner.answerCount >= 50,
    "answers-250": learner.answerCount >= 250,
    "wordsmith": correctIn("spelling") >= 40,
    "number-ninja": correctIn("maths") >= 40,
    "fast-fingers": learner.typing.bestWordsPerMinute >= 15,
    "stars-30": totalStars(profile) >= 30,
  };
  return achievements.filter((achievement) => earned[achievement.id] && profile.achievements[achievement.id] === undefined);
}
