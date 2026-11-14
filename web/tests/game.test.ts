// Ported from Packages/LostIslandsCore/Tests/LostIslandsCoreTests/GameTests.swift.
import { describe, expect, test } from "vitest";
import {
  activeProfile, addPlaytime, dayKey, playHistoryDays, playSecondsOver, allGameModes, applyResult, catalog, ChallengeSession, currentSaveVersion, dialogueAudioKey, encodeSave,
  isLevelUnlocked, LearnerModel, loadSave, newAppSettings, newParentSettings, newProfile, newSaveFile, nextLevelFor,
  placeDecoration, SaveFromTheFutureError, SaveStore, starDecorations, starsFor, starsForAccuracy, subjectOf, timestamp,
  totalStars, voicedLines, type DialogueLine, type KeyValueStorage, type LevelDef, type LevelResult, type Question,
  type RewardSummary, type SaveFile, allTrophies, prepareTrophies, trophiesPerLevel, trophyProgress, trophy, wear,
} from "../src/core";

/** Asks every question in a session, handing each one to `body`. */
function play(session: ChallengeSession, body: (question: Question) => void): void {
  for (let question = session.next(); question; question = session.next()) body(question);
}

describe("catalogue", () => {
  test("six islands each end with a guardian", () => {
    expect(catalog.islands.map((island) => island.id)).toEqual(["woods", "bay", "dragon", "cloud", "candy", "star"]);
    for (const island of catalog.islands) {
      expect(island.levels.length).toBe(5);
      expect(island.levels.map((level) => level.mode === "guardian")).toEqual([false, false, false, false, true]);
      expect(island.guardian.phases.length).toBe(3);
      for (const level of island.levels) {
        expect(level.intro.length).toBeGreaterThan(0);
        expect(level.outro.length).toBeGreaterThan(0);
        expect(level.count).toBeGreaterThanOrEqual(5);
      }
    }
    expect(new Set(catalog.allLevels.map((level) => level.id)).size).toBe(30);
  });

  test("every game mode is used and rewards exist", () => {
    expect(new Set(catalog.allLevels.map((level) => level.mode))).toEqual(new Set(allGameModes));
    for (const level of catalog.allLevels) {
      if (level.reward !== undefined) expect(catalog.reward(level.reward), level.reward).toBeDefined();
    }
    for (const decoration of starDecorations) expect(catalog.reward(decoration.reward)).toBeDefined();
    expect(catalog.intro.length).toBeGreaterThan(0);
    expect(catalog.introAfter.length).toBeGreaterThan(0);
  });

  test("dialogue clip keys match the built script", () => {
    const script = voicedLines;
    expect(Object.keys(script).length).toBeGreaterThan(100);
    const lines: { line: DialogueLine; guardian?: string }[] = [...catalog.intro, ...catalog.introAfter, ...catalog.askGrownUp].map((line) => ({ line }));
    for (const island of catalog.islands) {
      const guardian = island.guardian.kind;
      const spoken = [...island.guardian.phases, ...island.guardian.befriended, ...island.levels.flatMap((level) => [...level.intro, ...level.outro])];
      lines.push(...spoken.map((line) => ({ line, guardian })));
    }
    for (const { line, guardian } of lines) {
      const entry = script[dialogueAudioKey(line)];
      expect(entry?.text, `no script entry for: ${line.text}`).toBe(line.text);
      // Guardian lines are recorded under their own voice.
      expect(entry?.speaker).toBe(line.speaker === "guardian" ? guardian : line.speaker);
    }
    for (const island of catalog.islands) {
      for (const line of island.guardian.befriended.filter((spoken) => spoken.speaker === "guardian")) {
        expect(script[dialogueAudioKey(line)]?.mood).toBe("befriended");
      }
      expect(Object.values(script).some((entry) => entry.speaker === island.guardian.kind)).toBe(true);
    }
    expect(Object.values(script).filter((entry) => entry.scene === "intro").length, "nine for Otter and Mosey, three story lines").toBe(12);
  });

  test("modes only get skills they can present", () => {
    for (const level of catalog.allLevels) {
      const subjects = level.skills.map(subjectOf);
      switch (level.mode) {
        case "mathsSplash":
        case "eggRescue":
          expect(subjects.every((subject) => subject === "maths"), level.id).toBe(true);
          break;
        case "wordBlaster":
          expect(subjects.every((subject) => subject === "spelling"), level.id).toBe(true);
          break;
        case "typingTurbo":
          expect(level.skills, level.id).toEqual(["typing"]);
          break;
        default:
          expect(subjects.includes("typing"), level.id).toBe(false);
      }
    }
  });
});

describe("session", () => {
  const level = (id: string) => catalog.level(id)!;

  test("every level runs to completion", () => {
    for (const each of catalog.allLevels) {
      const session = new ChallengeSession({ level: each, learner: new LearnerModel(), seed: 99 });
      let seen = 0;
      play(session, (question) => {
        seen += 1;
        expect(question.prompt).not.toBe("");
        switch (each.mode) {
          case "mathsSplash":
            expect(question.format, each.id).toBe("choice");
            expect(question.choices.length, each.id).toBe(3);
            break;
          case "bridgeBuilder":
            expect(question.format, each.id).toBe("choice");
            expect(question.choices.length, each.id).toBeGreaterThanOrEqual(2);
            break;
          case "guardian":
            expect(question.format).toBe(subjectOf(question.skill) === "maths" ? "choice" : "typed");
            break;
          default:
            expect(question.format, each.id).toBe("typed");
            expect(question.typingTarget, each.id).not.toBe("");
        }
        if (each.mode === "eggRescue") expect(question.typingTarget).toMatch(/^\d+$/);
        const outcome = session.complete(question, true, 3, false);
        expect(outcome.isLevelComplete).toBe(seen === each.count);
      });
      expect(seen).toBe(each.count);
      expect(session.isFinished).toBe(true);
      expect(session.result.stars).toBe(3);
      expect(session.learner.answerCount).toBe(each.count);
    }
  });

  test("same seed gives same questions", () => {
    const bay = level("bay-1");
    const a = new ChallengeSession({ level: bay, learner: new LearnerModel(), seed: 5 });
    const b = new ChallengeSession({ level: bay, learner: new LearnerModel(), seed: 5 });
    for (let index = 0; index < bay.count; index += 1) expect(a.next()?.prompt).toBe(b.next()?.prompt);
  });

  test("questions do not repeat within a level", () => {
    for (const id of ["woods-1", "woods-4", "bay-1", "dragon-1"]) {
      const prompts: string[] = [];
      play(new ChallengeSession({ level: level(id), learner: new LearnerModel(), seed: 31 }), (question) => prompts.push(question.answer + question.prompt));
      expect(new Set(prompts).size, id).toBe(prompts.length);
    }
  });

  test("grown-up help is suggested after repeated slips on one question", () => {
    const session = new ChallengeSession({ level: level("woods-1"), learner: new LearnerModel(), seed: 1 });
    session.next();
    expect([1, 2, 3].map(() => session.recordSlip())).toEqual([false, false, false]);
    expect(session.recordSlip()).toBe(true);
    expect(session.recordSlip(), "only suggested once per question").toBe(false);
  });

  test("grown-up help comes sooner after several tricky questions", () => {
    const session = new ChallengeSession({ level: level("woods-1"), learner: new LearnerModel(), seed: 1 });
    for (let index = 0; index < ChallengeSession.trickyStreakBeforeHelp; index += 1) {
      const question = session.next()!;
      session.recordSlip();
      session.complete(question, false, 10, false);
    }
    session.next();
    expect(session.recordSlip()).toBe(false);
    expect(session.recordSlip()).toBe(true);
  });

  test("grown-up help is offered again on later questions", () => {
    const session = new ChallengeSession({ level: level("woods-1"), learner: new LearnerModel(), seed: 1 });
    const suggestions: boolean[] = [];
    for (let index = 0; index < 4; index += 1) {
      const question = session.next()!;
      let suggested = false;
      for (let slip = 0; slip < ChallengeSession.slipsBeforeHelp; slip += 1) suggested = session.recordSlip() || suggested;
      suggestions.push(suggested);
      session.complete(question, false, 10, true);
    }
    expect(suggestions).toEqual([true, true, true, true]);
  });

  test("grown-up help lines come from Otter and Mosey", () => {
    expect(catalog.askGrownUp.length).toBeGreaterThanOrEqual(2);
    for (const line of catalog.askGrownUp) {
      expect(["otter", "mosey"]).toContain(line.speaker);
      expect(line.text).toContain("grown-up");
    }
  });

  test("mistakes lower stars but never below one", () => {
    const session = new ChallengeSession({ level: level("woods-1"), learner: new LearnerModel(), seed: 1 });
    play(session, (question) => {
      session.recordSlip();
      session.complete(question, false, 20, true);
    });
    expect(session.result.stars).toBe(1);
    expect(session.result.score).toBeGreaterThan(0);
    expect(session.bestCombo).toBe(0);
  });

  test("combos multiply points", () => {
    const session = new ChallengeSession({ level: level("bay-4"), learner: new LearnerModel(), seed: 1 });
    const points: number[] = [];
    play(session, (question) => points.push(session.complete(question, true, 8, false).points));
    expect(points[0]).toBe(100);
    expect(points.at(-1)!).toBeGreaterThan(points[0]!);
    expect(session.bestCombo).toBe(8);
  });

  test("due review items are brought back", () => {
    const learner = new LearnerModel();
    learner.record("mul:8x7", "multiplication", false, 9, false);
    for (let index = 0; index < 5; index += 1) learner.record("addition:L1", "addition", true, 2, false);
    let found = 0;
    for (let seed = 0; seed < 40; seed += 1) {
      play(new ChallengeSession({ level: level("dragon-1"), learner, seed }), (question) => {
        if (question.key === "mul:8x7") found += 1;
      });
    }
    expect(found, "the missed fact should usually return").toBeGreaterThanOrEqual(25);
  });

  test("a level in progress leaves the saved learner alone", () => {
    const learner = new LearnerModel();
    const session = new ChallengeSession({ level: level("bay-1"), learner, seed: 3 });
    play(session, (question) => session.complete(question, true, 3, false));
    expect(learner.answerCount).toBe(0);
    expect(session.learner.answerCount).toBe(session.total);
  });

  test("parent topic choices are respected", () => {
    const settings = { ...newParentSettings(), spellingTopics: ["prefixes" as const], tables: [4] };
    play(new ChallengeSession({ level: level("woods-4"), learner: new LearnerModel(), settings, seed: 2 }), (question) =>
      expect(question.skill).toBe("prefixes"));
    play(new ChallengeSession({ level: level("dragon-1"), learner: new LearnerModel(), settings, seed: 2 }), (question) =>
      expect(question.key).toMatch(/^mul:4x/));
  });

  test("typing levels are judged on accuracy, not speed", () => {
    const session = new ChallengeSession({ level: level("woods-3"), learner: new LearnerModel(), seed: 4 });
    play(session, (question) => {
      session.recordTyping(10, 10, 2);
      session.complete(question, true, 300, false);
    });
    expect(session.result.stars, "slow but accurate typing earns full stars").toBe(3);
    expect(session.result.wordsPerMinute).toBe(2);
  });
});

describe("progression", () => {
  const perfect = (level: LevelDef): LevelResult =>
    ({ stars: 3, accuracy: 1, score: 900, bestCombo: level.count, correctFirstTry: level.count, total: level.count });

  test("star thresholds", () => {
    expect(starsForAccuracy(1)).toBe(3);
    expect(starsForAccuracy(0.7)).toBe(2);
    expect(starsForAccuracy(0)).toBe(1);
  });

  test("levels and islands unlock in order", () => {
    const profile = newProfile("Test");
    expect(isLevelUnlocked("woods-1", profile)).toBe(true);
    expect(isLevelUnlocked("woods-2", profile)).toBe(false);
    expect(isLevelUnlocked("bay-1", profile)).toBe(false);
    expect(nextLevelFor(profile)?.id).toBe("woods-1");
    for (const level of catalog.island("woods")!.levels) {
      expect(isLevelUnlocked(level.id, profile)).toBe(true);
      applyResult(perfect(level), level.id, profile.learner, profile);
    }
    expect(profile.crystals).toEqual(["woods"]);
    expect(isLevelUnlocked("bay-1", profile)).toBe(true);
    expect(isLevelUnlocked("dragon-1", profile)).toBe(false);
    expect(nextLevelFor(profile)?.id).toBe("bay-1");
  });

  test("rewards are granted once", () => {
    const profile = newProfile("Test");
    const level = catalog.level("woods-1")!;
    const first = applyResult(perfect(level), level.id, profile.learner, profile);
    expect(first.isFirstClear).toBe(true);
    expect(first.reward?.id).toBe("pet-firefly");
    expect(first.trophies.map((item) => item.id)).toEqual(["first-steps", "superstar-woods-1"]);
    expect(profile.pendingTrophies).toEqual(["flawless-woods-1", "combo-5"]);
    expect(first.decorations.map((decoration) => decoration.id)).toEqual(["deco-palm"]);
    const second = applyResult(perfect(level), level.id, profile.learner, profile);
    expect(second.isFirstClear).toBe(false);
    expect(second.reward).toBeUndefined();
    expect(second.trophies.map((item) => item.id)).toEqual(["flawless-woods-1", "combo-5"]);
    expect(second.decorations).toEqual([]);
    expect(profile.rewards.filter((reward) => reward === "pet-firefly").length).toBe(1);
    expect(profile.levels[level.id]?.plays).toBe(2);
  });

  test("a worse replay never loses stars", () => {
    const profile = newProfile("Test");
    const level = catalog.level("woods-1")!;
    applyResult(perfect(level), level.id, profile.learner, profile);
    applyResult({ ...perfect(level), stars: 1, score: 10 }, level.id, profile.learner, profile);
    expect(starsFor(profile, level.id)).toBe(3);
    expect(profile.levels[level.id]?.bestScore).toBe(900);
  });

  test("finishing every island completes the game", () => {
    const profile = newProfile("Test");
    let last: RewardSummary | undefined;
    for (const level of catalog.allLevels) {
      expect(isLevelUnlocked(level.id, profile), level.id).toBe(true);
      last = applyResult(perfect(level), level.id, profile.learner, profile, { usedFriendshipPower: level.mode === "guardian" ? 3 : 0 });
    }
    expect(last?.gameComplete).toBe(true);
    expect(profile.crystals.length).toBe(6);
    expect(totalStars(profile)).toBe(90);
    expect(profile.achievements["friend-star"], "the guardian's own trophy is never held back").toBeDefined();
    expect(Object.keys(profile.achievements).length + profile.pendingTrophies.length).toBeGreaterThanOrEqual(60);
    expect(nextLevelFor(profile)).toBeUndefined();
  });
});

describe("playtime", () => {
  const day = (offset: number) => new Date(2026, 2, 10 + offset, 23, 30);

  test("playtime is tracked per day", () => {
    const profile = newProfile("Pip");
    addPlaytime(profile, 600, day(0));
    addPlaytime(profile, 300, day(-3));
    addPlaytime(profile, 120, day(-7));
    addPlaytime(profile, 60, day(0));
    expect(profile.playSeconds).toBe(1080);
    expect(dayKey(day(0))).toBe("2026-03-10");
    expect(playSecondsOver(profile, 1, day(0))).toBe(660);
    expect(playSecondsOver(profile, 7, day(0)), "a week ago is outside the last 7 days").toBe(960);
    expect(playSecondsOver(profile, 1, day(1))).toBe(0);
  });

  test("old daily playtime is pruned", () => {
    const profile = newProfile("Pip");
    for (let offset = 0; offset < 60; offset += 1) addPlaytime(profile, 10, day(offset));
    expect(Object.keys(profile.dailyPlaySeconds).length).toBeLessThanOrEqual(playHistoryDays);
    expect(profile.playSeconds, "the running total keeps everything").toBe(600);
  });
});

describe("saves", () => {
  class MemoryStorage implements KeyValueStorage {
    readonly items = new Map<string, string>();
    getItem(key: string): string | null { return this.items.get(key) ?? null; }
    setItem(key: string, value: string): void { this.items.set(key, value); }
  }

  function sampleFile(): SaveFile {
    const file = newSaveFile();
    const profile = newProfile("Pip", "🐬");
    profile.learner.record("mul:8x7", "multiplication", false, 4, false);
    profile.levels["woods-1"] = { stars: 2, bestScore: 0, plays: 0, flawless: false };
    profile.achievements["first-steps"] = timestamp(new Date(1_700_000_000_000));
    profile.decorations = [placeDecoration("deco-palm", 0.4, 0.6)];
    file.profiles = [profile, newProfile("Sam")];
    file.activeProfileID = profile.id;
    file.settings.easyReadFont = true;
    return file;
  }

  test("round trips everything", () => {
    const store = new SaveStore(new MemoryStorage());
    const file = sampleFile();
    store.save(file);
    expect(store.load()).toEqual(file);
    expect(activeProfile(store.load())?.nickname).toBe("Pip");
    expect(store.load().profiles[0]!.learner).toBeInstanceOf(LearnerModel);
  });

  test("writes the shape the iOS game reads", () => {
    const saved = JSON.parse(encodeSave(sampleFile()));
    expect(saved.version).toBe(2);
    expect(saved.profiles[0].id).toMatch(/^[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}$/);
    expect(saved.profiles[0].achievements["first-steps"]).toBe("2023-11-14T22:13:20Z");
    expect(saved.profiles[0].learner.items["mul:8x7"]).toEqual({ box: 0, dueAt: 4, lapses: 1, skill: "multiplication" });
    expect(saved.profiles[0].learner.skills.multiplication.attempts).toBe(1);
  });

  test("missing file gives a fresh save", () => {
    const file = new SaveStore(new MemoryStorage()).load();
    expect(file.profiles).toEqual([]);
    expect(file.version).toBe(currentSaveVersion);
  });

  test("corrupt file falls back to backup", () => {
    const storage = new MemoryStorage();
    const store = new SaveStore(storage);
    const file = sampleFile();
    store.save(file);
    file.settings.muted = true;
    store.save(file); // first save becomes the backup
    storage.setItem(store.key, "{ not json");
    const recovered = store.load();
    expect(recovered.profiles.length, "progress survives a corrupt main file").toBe(2);
    expect(recovered.settings.muted, "recovered from the previous good save").toBe(false);
  });

  test("a corrupt file is never copied over the backup", () => {
    const storage = new MemoryStorage();
    const store = new SaveStore(storage);
    store.save(sampleFile());
    store.save(sampleFile());
    storage.setItem(store.key, "garbage");
    store.save(newSaveFile());
    expect(loadSave(storage.getItem(store.backupKey)!).profiles.length).toBe(2);
  });

  test("older saves with missing fields still open", () => {
    const legacy = '{"version":1,"profiles":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","nickname":"Old","levels":{"woods-1":{"stars":3}}}]}';
    const file = loadSave(legacy);
    expect(file.version).toBe(currentSaveVersion);
    const profile = activeProfile(file);
    expect(profile?.nickname, "v1 files gain an active profile").toBe("Old");
    expect(starsFor(profile!, "woods-1")).toBe(3);
    expect(profile?.parent).toEqual(newParentSettings());
    expect(file.settings).toEqual(newAppSettings());
  });

  test("newer saves are rejected rather than mangled", () => {
    expect(() => loadSave('{"version":99,"profiles":[]}')).toThrow(SaveFromTheFutureError);
  });

  test("the active profile is edited in place", () => {
    const file = sampleFile();
    activeProfile(file)!.seenIntro = true;
    expect(file.profiles[0]!.seenIntro).toBe(true);
    expect(file.profiles.length).toBe(2);
  });
});

describe("trophies", () => {
  const monday = new Date(2026, 10, 9, 10);
  const result = (level: LevelDef, firstTry = level.count): LevelResult => ({
    stars: starsForAccuracy(firstTry / level.count), accuracy: firstTry / level.count, score: 100, bestCombo: firstTry,
    correctFirstTry: firstTry, total: level.count,
  });

  test("there are 145 trophies with unique ids, the same as on iOS", () => {
    const all = allTrophies();
    expect(all.length).toBe(145);
    expect(new Set(all.map((item) => item.id)).size).toBe(all.length);
    const count = (group: string) => all.filter((item) => item.group === group).length;
    expect([count("islands"), count("milestones"), count("learning"), count("collections"), count("secret")]).toEqual([72, 43, 14, 6, 10]);
  });

  test("no more than two are handed out and the rest wait", () => {
    const profile = newProfile("Pip");
    const level = catalog.level("woods-1")!;
    let awarded = 0;
    for (let run = 0; run < 12; run += 1) {
      const summary = applyResult(result(level), level.id, profile.learner, profile, { now: monday });
      expect(summary.trophies.length).toBeLessThanOrEqual(trophiesPerLevel);
      awarded += summary.trophies.length;
    }
    expect(awarded).toBe(Object.keys(profile.achievements).length);
    expect(profile.achievements["back-for-more"]).toBeDefined();
    expect(profile.achievements["levels-10"]).toBeDefined();
  });

  test("this level's medals come before waiting ones", () => {
    const profile = newProfile("Pip");
    profile.pendingTrophies = ["first-steps"];
    profile.levels["woods-1"] = { stars: 0, bestScore: 0, plays: 0, flawless: false };
    profile.trophiesReady = true;
    const level = catalog.level("woods-2")!;
    const summary = applyResult(result(level), level.id, profile.learner, profile, { now: monday });
    expect(summary.trophies.map((item) => item.id)).toEqual(["superstar-woods-2", "flawless-woods-2"]);
    expect(profile.pendingTrophies[0]).toBe("first-steps");
  });

  test("old stickers move into the cabinet", () => {
    const profile = newProfile("Pip");
    const when = timestamp(monday);
    profile.achievements = { "wordsmith": when, "first-steps": when, "three-stars": when };
    profile.levels["woods-1"] = { stars: 3, bestScore: 0, plays: 1, flawless: false };
    prepareTrophies(profile, catalog, monday);
    expect(profile.achievements["words-40"]).toBeDefined();
    expect(profile.achievements["three-stars"]).toBeUndefined();
    expect(profile.achievements["superstar-woods-1"]).toBeDefined();
    expect(profile.trophiesReady).toBe(true);
  });

  test("lifetime counts add up, with weekdays counted as on iOS", () => {
    const profile = newProfile("Pip");
    const level = catalog.level("bay-1")!;
    const run = { ...result(level), pearls: 12, tableFirstTry: { "3": 2 } };
    const saturday = new Date(2026, 10, 14, 9);
    const sunday = new Date(2026, 10, 15, 9);
    applyResult(run, level.id, profile.learner, profile, { now: saturday });
    applyResult(run, level.id, profile.learner, profile, { now: saturday });
    applyResult(run, level.id, profile.learner, profile, { now: sunday });
    expect(profile.stats.pearls).toBe(36);
    expect(profile.stats.tableFirstTry["3"]).toBe(6);
    expect(profile.stats.playDays).toBe(2);
    expect([...profile.stats.weekendDays].sort()).toEqual([1, 7]);
    expect(trophyProgress(trophy("pearls-100")!, profile)).toEqual({ now: 36, needed: 100 });
  });

  test("sessions count hints, comebacks and times tables", () => {
    const session = new ChallengeSession({ level: catalog.level("dragon-1")!, learner: new LearnerModel(), seed: 7 });
    const question = session.next()!;
    session.recordSlip();
    session.recordSlip();
    session.complete(question, false, 3, true);
    session.complete(session.next()!, true, 2, false);
    expect(session.result.hintsUsed).toBe(1);
    expect(session.result.comeback).toBe(true);
    expect(ChallengeSession.tableOf("mul:8x7")).toBe(8);
    expect(ChallengeSession.tableOf("word:said")).toBeUndefined();
  });

  test("hats tried are remembered and survive a save", () => {
    const file = newSaveFile();
    const profile = newProfile("Pip");
    wear(profile, "hat-leaf");
    wear(profile, undefined);
    wear(profile, "hat-crown");
    file.profiles = [profile];
    const loaded = loadSave(encodeSave(file)).profiles[0]!;
    expect(loaded.stats.hatsWorn).toEqual(["hat-leaf", "hat-crown"]);
    expect(loaded.equippedAccessory).toBe("hat-crown");
  });
});
