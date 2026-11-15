// @vitest-environment happy-dom
import { describe, expect, test, vi } from "vitest";
vi.mock("../src/game/audio", () => ({ audio: { apply: vi.fn(), playMusic: vi.fn() }, narrator: { stop: vi.fn() } }));
import { LearnerModel } from "../src/core";
import { AppModel } from "../src/app/model";
import { parentScreen } from "../src/ui/parent";

function fixture() {
  const data = new Map<string, string>();
  const storage = { getItem: (key: string) => data.get(key) ?? null, setItem: (key: string, value: string) => { data.set(key, value); } };
  const model = new AppModel(storage);
  const profile = model.createProfile("Pip", "🦦");
  Object.assign(profile, {
    seenIntro: true, grownUpChecked: true, levels: { "woods-1": { stars: 3, bestScore: 600, plays: 2, flawless: true } },
    crystals: ["woods"], lastLevelID: "woods-1", playSeconds: 120, dailyPlaySeconds: { "2026-11-15": 120 },
    rewards: ["deco-palm", "pet-firefly"], achievements: { "first-star": "2026-11-15T00:00:00Z" },
    pendingTrophies: ["level-woods-1"], trophiesReady: true, trophiesSeen: 1,
    equippedAccessory: "hat-test", decorations: [{ id: "palm", reward: "deco-palm", x: 0.5, y: 0.5 }],
    bestCombo: 9, friendshipPowers: 3,
  });
  profile.parent.sessionMinutes = 15;
  profile.learner.record("mul:8x7", "multiplication", false, 9, false);
  const other = model.createProfile("Nova", "🐬");
  other.trophiesReady = true;
  model.selectProfile(profile.id);
  model.sessionSeconds = 120;
  model.unlockedIsland = "bay";
  model.persist();
  return { model, storage, profile, other };
}

describe("restart adventure", () => {
  test.each([true, false])("resets only the selected player's adventure and persists (keep rewards: %s)", (keep) => {
    const { model, storage, profile, other } = fixture();
    model.resetProgress(profile.id, keep);
    expect(model.sessionSeconds).toBe(0);
    expect(model.unlockedIsland).toBeUndefined();
    const loaded = new AppModel(storage);
    const fresh = loaded.profile!;
    expect(fresh.id).toBe(profile.id);
    expect(fresh.nickname).toBe("Pip");
    expect(fresh.parent).toEqual(profile.parent);
    expect(fresh.learner).toEqual(new LearnerModel());
    expect(fresh.levels).toEqual({});
    expect(fresh.crystals).toEqual([]);
    expect(fresh.seenIntro).toBe(false);
    expect(fresh.grownUpChecked).toBe(false);
    expect(fresh.lastLevelID).toBeUndefined();
    expect(fresh.playSeconds).toBe(0);
    expect(fresh.dailyPlaySeconds).toEqual({});
    expect(fresh.bestCombo).toBe(0);
    expect(fresh.friendshipPowers).toBe(0);
    expect(fresh.rewards).toEqual(keep ? profile.rewards : ["deco-palm"]);
    expect(fresh.achievements).toEqual(keep ? profile.achievements : {});
    expect(fresh.pendingTrophies).toEqual(keep ? profile.pendingTrophies : []);
    expect(fresh.decorations).toEqual(keep ? profile.decorations : []);
    expect(fresh.equippedAccessory).toBe(keep ? profile.equippedAccessory : undefined);
    expect(fresh.trophiesSeen).toBe(keep ? 1 : 0);
    expect(loaded.save.profiles.find(p => p.id === other.id)).toEqual(other);
    loaded.continueGame();
    expect(loaded.route.name).toBe("check");
  });
  test("requires confirmation, supports cancel and lets grown-ups clear rewards", () => {
    const { model, profile } = fixture();
    model.parentUnlocked = true;
    const screen = parentScreen(model);
    document.body.append(screen.element);
    const button = (text: string) => [...screen.element.querySelectorAll("button")].find(b => b.textContent === text)!;
    button("Restart Pip's adventure").click();
    expect(model.profile?.seenIntro).toBe(true);
    expect(screen.element.querySelector('[aria-label="Restart adventure"]')?.textContent).toContain("will be kept");
    button("Keep progress").click();
    expect(model.profile).toBe(profile);
    const keep = [...screen.element.querySelectorAll("label")].find(l => l.textContent?.includes("Keep trophies and treasures"))!.querySelector("input")!;
    keep.checked = false;
    button("Restart Pip's adventure").click();
    expect(screen.element.querySelector('[aria-label="Restart adventure"]')?.textContent).toContain("will also be cleared");
    button("Restart adventure").click();
    expect(model.profile?.seenIntro).toBe(false);
    expect(model.profile?.achievements).toEqual({});
    screen.destroy?.();
    screen.element.remove();
  });
});
