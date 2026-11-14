import { starDecorations, type Catalog, type Island, type LevelDef, type Reward } from "./catalog";
import { catalog as bundled } from "./content";
import type { LearnerModel } from "./learner";
import { dayKey, hasReward, newLevelRecord, starsFor, totalStars, type Profile } from "./save";
import type { LevelResult } from "./session";
import { awardTrophies, prepareTrophies, trophyCount, type Trophy, type TrophyRun } from "./trophies";

// Unlock rules and what a finished level earns. Star ratings live in session.ts (`starsForAccuracy`).

/** What a child earned from finishing a level, for the celebration screen. */
export interface RewardSummary {
  stars: number;
  isFirstClear: boolean;
  isNewBest: boolean;
  reward?: Reward;
  crystalIsland?: Island;
  /** Trophies handed out at the end of this level, at most `trophiesPerLevel`. */
  trophies: Trophy[];
  /** Trophies won but held back for a later level. */
  trophiesWaiting: number;
  /** The cabinet after this level: trophies won, out of how many. */
  trophyCount: number;
  trophyTotal: number;
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

/** Applies a finished level to the profile (changing it in place) and reports what was newly earned. */
export function applyResult(
  result: LevelResult, levelID: string, learner: LearnerModel, profile: Profile,
  options: { usedFriendshipPower?: number; catalog?: Catalog; now?: Date } = {},
): RewardSummary {
  const catalog = options.catalog ?? bundled;
  const summary: RewardSummary = {
    stars: result.stars, isFirstClear: false, isNewBest: false, trophies: [], trophiesWaiting: 0, trophyCount: 0, trophyTotal: 0,
    decorations: [], gameComplete: false,
  };
  const level = catalog.level(levelID);
  const island = catalog.islandContaining(levelID);
  if (!level || !island) return summary;
  const now = options.now ?? new Date();
  prepareTrophies(profile, catalog, now);

  const record = profile.levels[levelID] ?? newLevelRecord();
  const run: TrophyRun = {
    levelID, islandID: island.id, mode: level.mode, result, previousStars: record.stars,
    guardianAlreadyFriend: level.mode === "guardian" && profile.crystals.includes(island.id),
  };
  summary.isFirstClear = record.stars === 0;
  if (result.total > 0 && result.correctFirstTry >= result.total) record.flawless = true;
  summary.isNewBest = result.stars > record.stars || result.score > record.bestScore;
  record.stars = Math.max(record.stars, result.stars);
  record.bestScore = Math.max(record.bestScore, result.score);
  record.plays += 1;
  profile.levels[levelID] = record;
  profile.learner = learner.clone();
  profile.lastLevelID = levelID;
  profile.bestCombo = Math.max(profile.bestCombo, result.bestCombo);
  profile.friendshipPowers += options.usedFriendshipPower ?? 0;
  tally(result, now, profile);

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
  summary.trophies = awardTrophies(profile, run, catalog, now);
  summary.trophiesWaiting = profile.pendingTrophies.length;
  const count = trophyCount(profile, catalog);
  summary.trophyCount = count.won;
  summary.trophyTotal = count.total;
  return summary;
}

/** Adds a finished level to the lifetime counts the trophy cabinet uses. */
function tally(result: LevelResult, now: Date, profile: Profile): void {
  const stats = profile.stats;
  stats.pearls += result.pearls ?? 0;
  for (const [table, count] of Object.entries(result.tableFirstTry ?? {})) stats.tableFirstTry[table] = (stats.tableFirstTry[table] ?? 0) + count;
  const today = dayKey(now);
  if (stats.lastPlayDay !== today) {
    stats.playDays += 1;
    stats.lastPlayDay = today;
  }
  // Weekdays are kept as iOS counts them: 1 is Sunday and 7 is Saturday.
  const weekday = now.getDay() + 1;
  if ((weekday === 1 || weekday === 7) && !stats.weekendDays.includes(weekday)) stats.weekendDays.push(weekday);
  stats.hatStreak = profile.equippedAccessory === undefined ? 0 : stats.hatStreak + 1;
}
