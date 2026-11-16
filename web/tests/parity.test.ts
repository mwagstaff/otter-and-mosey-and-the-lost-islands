/// <reference types="node" />
import { test, expect } from "vitest";
import { readFileSync } from "node:fs";
import { catalog } from "../src/core/content";
import { starsForAccuracy } from "../src/core/session";
import { newProfile } from "../src/core/save";
import { applyResult, nextLevelFor, isLevelUnlocked } from "../src/core/progression";
import { allTrophies } from "../src/core/trophies";
test("Swift and web resolve the same level contract and star boundaries", () => {
  const stars = [0, .5499, .55, .8499, .85, 1].map(starsForAccuracy);
  expect(stars).toEqual([1, 1, 2, 2, 3, 3]);
  if (!process.env.PLAYTEST_OUTPUT) return;
  const native = JSON.parse(readFileSync(`${process.env.PLAYTEST_OUTPUT}/swift-contract.json`, "utf8"));
  const profile = newProfile("Parity");
  const campaign = catalog.allLevels.map(level => {
    expect(isLevelUnlocked(level.id, profile)).toBe(true);
    const summary = applyResult({ stars: 3, accuracy: 1, score: 900, bestCombo: level.count, correctFirstTry: level.count, total: level.count }, level.id, profile.learner, profile, { now: new Date(1794787200000) });
    return { id: level.id, next: nextLevelFor(profile)?.id ?? "", rewards: [...profile.rewards].sort(), crystals: [...profile.crystals].sort(), trophies: summary.trophies.map(t => t.id), waiting: [...profile.pendingTrophies], complete: summary.gameComplete };
  });
  expect(profile.crystals).toHaveLength(6);
  const trophies = allTrophies().map(({id, title, detail, art}) => ({id, title, detail, art}));
  expect({ campaign, trophies, levels: catalog.allLevels.map(l => ({ id: l.id, mode: l.mode, count: String(l.count) })), stars }).toEqual(native);
});
