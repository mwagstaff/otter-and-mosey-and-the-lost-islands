import type { AppModel } from "../app/model";
import {
  accuracyOf, allDifficultyModes, averageSecondsOf, averageTouchWordsPerMinuteOf, averageWordsPerMinuteOf, catalog,
  defaultDenominators, defaultMultipliers, defaultTables, difficultyTitles, gameModeTitles, playSecondsOver, skillTitles, spellingTopics, starsFor, totalStars, trophy, trophyCount,
  typingAccuracyOf, type DifficultyMode, type Profile,
} from "../core";
import { h, picture, symbol } from "./dom";
import type { Screen } from "./menus";
import { settingsControls } from "./settings";

type Child = Node | string | false | undefined;

const percent = (value: number | undefined) => (value === undefined ? "No data yet" : `${Math.round(value * 100)}%`);

function playtime(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const plural = (count: number, unit: string) => `${count} ${unit}${count === 1 ? "" : "s"}`;
  return hours > 0 ? `${plural(hours, "hour")}, ${plural(minutes % 60, "minute")}` : plural(minutes, "minute");
}

/** `mul:8x7` as "7 × 8", `div:4x9` as "36 ÷ 4", `word:because` as "because". */
function describe(key: string): string {
  const [kind, rest] = key.split(":");
  if (rest === undefined) return key;
  const numbers = rest.split("x").map(Number);
  if (kind === "mul" && numbers.length === 2) return `${numbers[1]} × ${numbers[0]}`;
  if (kind === "div" && numbers.length === 2) return `${numbers[0]! * numbers[1]!} ÷ ${numbers[0]}`;
  return rest;
}

/**
 * The grown-ups' area. Kept behind a gate and styled plainly so it reads as separate from play.
 */
export function parentScreen(model: AppModel, setup = false): Screen {
  const element = h("section.screen.parent");
  let cleanUp = () => {};
  const unlocked = () => (setup ? quickSetup() : dashboard());
  const leave = () => (setup ? model.leaveQuickSetup(false) : model.leaveParentArea());

  // A sum most Year 3 children cannot yet do in their head.
  function gate(): void {
    let a = 0, b = 0, entry = "";
    const sum = h("p.gate-sum");
    const wrong = h("p.gate-wrong", { hidden: true }, "That's not right. Here's a new one.");
    const next = h<"button">("button.plain.primary", { type: "button", disabled: true }, "Continue");
    const show = () => {
      sum.textContent = `${a} × ${b} = ${entry === "" ? "?" : entry}`;
      next.disabled = entry === "";
    };
    const fresh = () => {
      a = 13 + Math.floor(Math.random() * 7);
      b = 6 + Math.floor(Math.random() * 4);
      entry = "";
      show();
    };
    const type = (digit: string) => {
      if (entry.length < 3) entry += digit;
      show();
    };
    const erase = () => {
      entry = entry.slice(0, -1);
      show();
    };
    const submit = () => {
      if (entry === "") return;
      if (Number(entry) === a * b) {
        cleanUp();
        model.parentUnlocked = true;
        unlocked();
      } else {
        wrong.hidden = false;
        fresh();
      }
    };
    const onKey = (event: KeyboardEvent) => {
      if (/^\d$/.test(event.key)) type(event.key);
      else if (event.key === "Backspace") erase();
      else if (event.key === "Enter") submit();
    };
    window.addEventListener("keydown", onKey);
    cleanUp = () => window.removeEventListener("keydown", onKey);
    next.addEventListener("click", submit);
    const digit = (value: string) => h("button.plain.digit", { type: "button", onClick: () => type(value) }, value);
    const who = setup ? model.profile : undefined;
    element.replaceChildren(h("div.gate", {},
      who && h("p.gate-context", {}, `Setting up the game for ${who.nickname}`),
      h("h1", {}, "Grown-ups only"),
      h("p.muted", {}, "To continue, please answer:"),
      sum,
      wrong,
      h("div.digits", {}, ...[..."1234567890"].map(digit), h("button.plain.digit", { type: "button", "aria-label": "Delete", onClick: erase }, "⌫")),
      h("div.gate-actions", {}, h("button.plain", { type: "button", onClick: () => { cleanUp(); leave(); } }, "Back"), next),
    ));
    fresh();
  }

  const row = (title: string, value: Child) => h("div.row", {}, h("span", {}, title), h("span.value", {}, value));
  const section = (title: string, ...children: Child[]) => h("section.card", {}, h("h2", {}, title), ...children);

  function dashboard(): void {
    const profiles = model.save.profiles;
    const profile = profiles.find((each) => each.id === model.dashboardProfileID)
      ?? profiles.find((each) => each.id === model.save.activeProfileID)
      ?? profiles[0];
    const done = h("button.plain", { type: "button", onClick: () => model.leaveParentArea() }, "Done");
    const header = h("header.parent-bar", {}, done, h("h1", {}, "Parent dashboard"), h("span.parent-spacer"));
    if (!profile) {
      element.replaceChildren(header, h("div.parent-body", {},
        h("div.card", {},
          h("h2", {}, "No players yet"),
          h("p.muted", {}, "Create a player from the title screen to see their progress here.")),
        playtest(undefined), section("Sound and accessibility", settingsControls(model))));
      return;
    }
    const refresh = () => dashboard();
    const picker = profiles.length > 1 && (() => {
      const select = h<"select">("select", { "aria-label": "Child" }, ...profiles.map((each) =>
        h("option", { value: each.id, selected: each.id === profile.id }, `${each.avatar} ${each.nickname}`)));
      select.addEventListener("change", () => {
        model.dashboardProfileID = select.value;
        dashboard();
      });
      return h("section.card", {}, row("Child", select));
    })();
    element.replaceChildren(header, h("div.parent-body", {},
      picker,
      learning(profile, refresh),
      overview(profile),
      skills(profile),
      practice(profile),
      recent(profile),
      playtest(profile),
      ending(profile),
      section("Sound and accessibility", settingsControls(model)),
      player(profile, refresh),
    ));
  }

  function overview(profile: Profile): HTMLElement {
    const learner = profile.learner;
    const typing = learner.typing;
    const speed = (average: number, best: number) => `${Math.round(average)} wpm average, best ${Math.round(best)}`;
    return section("Overview",
      row("Playtime today", playtime(playSecondsOver(profile, 1))),
      row("Playtime, last 7 days", playtime(playSecondsOver(profile, 7))),
      row("Total playtime", playtime(profile.playSeconds)),
      row("Stars and crystals", `${totalStars(profile)} stars, ${profile.crystals.length} of 6 crystals`),
      row("Spelling accuracy", percent(learner.accuracy("spelling"))),
      row("Maths accuracy", percent(learner.accuracy("maths"))),
      row("Typing accuracy", typing.keystrokes === 0 ? "No data yet" : percent(typingAccuracyOf(typing))),
      typing.samples.length === 0 && typing.touchSamples.length === 0 && row("Typing speed", "No data yet"),
      typing.samples.length > 0 && row("Typing speed, keyboard", speed(averageWordsPerMinuteOf(typing), typing.bestWordsPerMinute)),
      typing.touchSamples.length > 0
        && row("Typing speed, on-screen keys", speed(averageTouchWordsPerMinuteOf(typing), typing.bestTouchWordsPerMinute)),
      h("p.muted.small", {}, "Typing speed is measured in Typing Turbo levels. Tapping on-screen keys is naturally slower than " +
        "typing on a keyboard, so the two are shown separately."),
    );
  }

  function skills(profile: Profile): HTMLElement {
    const practised = profile.learner.practisedSkills;
    return section("Skills practised",
      practised.length === 0 && h("p.muted", {}, "Nothing practised yet."),
      ...practised.map((skill) => {
        const stats = profile.learner.stats(skill);
        const accuracy = accuracyOf(stats);
        const colour = accuracy >= 0.8 ? "good" : accuracy >= 0.6 ? "fair" : "low";
        return h("div.skill", {},
          h("div.row", {}, h("strong", {}, skillTitles[skill]),
            h("span.value", {}, `Level ${profile.learner.level(skill)} of 5 · ${stats.correct}/${stats.attempts} right first time`)),
          h("div.bar-track", { role: "img", "aria-label": `${Math.round(accuracy * 100)}% right first time` },
            h(`span.bar-fill.${colour}`, { style: `width: ${Math.round(accuracy * 100)}%` })),
          h("p.muted.small", {}, `Average answer time ${averageSecondsOf(stats).toFixed(1)} s`),
        );
      }),
    );
  }

  function practice(profile: Profile): HTMLElement {
    const weak = profile.learner.skillsNeedingPractice;
    const tricky = profile.learner.troublesomeItems.slice(0, 12);
    return section("Areas needing practice",
      weak.length === 0 && tricky.length === 0 && h("p.muted", {}, "Nothing stands out yet. The game brings back anything missed automatically."),
      ...weak.map((skill) => h("p", {}, skillTitles[skill])),
      tricky.length > 0 && h("p", {}, "Being revisited: " + tricky.map((item) => describe(item.key)).join(", ")),
    );
  }

  function recent(profile: Profile): HTMLElement {
    const earned = Object.entries(profile.achievements).sort((a, b) => (a[1] < b[1] ? 1 : -1))
      .flatMap(([id, when]) => { const item = trophy(id); return item ? [[item, when] as const] : []; }).slice(0, 5);
    const count = trophyCount(profile);
    return section("Recent trophies",
      row("Trophy cabinet", `${count.won} of ${count.total}`),
      earned.length === 0 && h("p.muted", {}, "None yet."),
      ...earned.map(([item, when]) => {
        const date = new Date(when).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
        const level = item.levelID ? catalog.level(item.levelID) : undefined;
        return row(level ? `${item.title}: ${level.title}` : item.title, date);
      }),
    );
  }

  /** The controls for one player's learning settings, in groups the dashboard and quick setup lay out differently. */
  function learningControls(profile: Profile, refresh: () => void) {
    const parent = profile.parent;
    const change = (apply: () => void) => {
      apply();
      model.persist();
      refresh();
    };
    const difficulty = h<"select">("select", { "aria-label": "Difficulty" }, ...allDifficultyModes.map((mode) =>
      h("option", { value: mode, selected: mode === parent.difficulty }, difficultyTitles[mode])));
    difficulty.addEventListener("change", () => change(() => { parent.difficulty = difficulty.value as DifficultyMode; }));
    const tables = defaultTables.map((table) => {
      const on = parent.tables.includes(table);
      return h(`button.plain.table${on ? ".on" : ""}`, {
        type: "button", "aria-pressed": String(on),
        onClick: () => {
          const next = on ? parent.tables.filter((each) => each !== table) : [...parent.tables, table];
          // At least one table always stays on.
          if (next.length > 0) change(() => { parent.tables = next.sort((a, b) => a - b); });
        },
      }, `${table}×`);
    });
    /** The list with `value` switched on or off, kept sorted. At least one value always stays on. */
    const toggled = (values: number[], value: number): number[] => {
      const next = values.includes(value) ? values.filter((each) => each !== value) : [...values, value].sort((a, b) => a - b);
      return next.length > 0 ? next : values;
    };
    const multipliers = defaultMultipliers.map((value) => {
      // A switched-off table is never used as the other number either, so its button is off too.
      const blocked = defaultTables.includes(value) && !parent.tables.includes(value);
      const on = !blocked && parent.multipliers.includes(value);
      return h(`button.plain.table${on ? ".on" : ""}`, {
        type: "button", "aria-pressed": String(on), disabled: blocked,
        title: blocked ? `Switch the ${value}× table on to use this` : undefined,
        onClick: () => change(() => { parent.multipliers = toggled(parent.multipliers, value); }),
      }, `× ${value}`);
    });
    const fractionNames = ["halves", "thirds", "quarters", "fifths", "sixths", "sevenths", "eighths", "ninths", "tenths"];
    const denominators = defaultDenominators.map((denominator) => {
      const on = parent.denominators.includes(denominator);
      return h(`button.plain.table${on ? ".on" : ""}`, {
        type: "button", "aria-pressed": String(on), "aria-label": fractionNames[denominator - 2],
        onClick: () => change(() => { parent.denominators = toggled(parent.denominators, denominator); }),
      }, `1/${denominator}`);
    });
    const topics = spellingTopics.map((topic) => {
      const input = h<"input">("input", { type: "checkbox", role: "switch", checked: parent.spellingTopics.includes(topic) });
      input.addEventListener("change", () => {
        const next = input.checked ? [...parent.spellingTopics, topic] : parent.spellingTopics.filter((each) => each !== topic);
        // At least one topic always stays on.
        if (next.length > 0) change(() => { parent.spellingTopics = next; });
        else input.checked = true;
      });
      return h("label.toggle", {}, h("span", {}, skillTitles[topic]), input);
    });
    const breaks = h<"select">("select", { "aria-label": "Suggest a break after" },
      ...[0, 10, 15, 20, 30, 45].map((minutes) =>
        h("option", { value: minutes, selected: minutes === parent.sessionMinutes }, minutes === 0 ? "Never" : `${minutes} minutes`)));
    breaks.addEventListener("change", () => change(() => { parent.sessionMinutes = Number(breaks.value); }));
    const timed = h<"input">("input", { type: "checkbox", role: "switch", checked: parent.timedChallenges });
    timed.addEventListener("change", () => change(() => { parent.timedChallenges = timed.checked; }));
    return {
      maths: [
        row("Difficulty", difficulty),
        h("div.stack", {}, h("span", {}, "Times tables"), h("div.tables", {}, ...tables)),
        h("div.stack", {}, h("span", {}, "Multiply and divide by"), h("div.tables", {}, ...multipliers)),
        h("div.stack", {}, h("span", {}, "Fractions"), h("div.tables", {}, ...denominators)),
      ],
      topics,
      play: [row("Suggest a break after", breaks), h("label.toggle", {}, h("span", {}, "Timed bonus points"), timed)],
    };
  }

  const learningHelp = "Adaptive difficulty raises or lowers each skill separately based on recent answers. " +
    "Switching a times table off also leaves it out as the other number, so with 8× off there's no 8 × 3 either. " +
    "“Multiply and divide by” picks the other number: switch off × 11 and × 12 to keep things gentler. " +
    "“Fractions” picks which fractions come up, from halves to tenths. " +
    "Timed bonus points only add extra score for quick answers; nothing ever runs out of time.";

  function learning(profile: Profile, refresh: () => void): HTMLElement {
    const controls = learningControls(profile, refresh);
    return section("Learning settings",
      ...controls.maths,
      h("div.stack", {}, h("span", {}, "Spelling topics"), ...controls.topics),
      ...controls.play,
      h("p.muted.small", {}, learningHelp),
    );
  }

  /** Just the learning settings for a new player, then straight back to the grown-up check. */
  function quickSetup(): void {
    const profile = model.profile;
    if (!profile) return model.leaveQuickSetup(false);
    const body = h("div.setup-body");
    const draw = () => {
      const scroll = body.scrollTop;
      const controls = learningControls(profile, draw);
      body.replaceChildren(
        h("p.setup-intro", {}, h("span.setup-who", {}, picture(profile.avatar), profile.nickname),
          h("span", {}, `Check these suit ${profile.nickname}, then hand the game back. You can change them later in the parent dashboard.`)),
        h("div.setup-cards", {},
          section("Maths", ...controls.maths),
          section("Spelling", ...controls.topics),
          section("Play", ...controls.play),
          h("p.muted.small.setup-help", {}, learningHelp),
        ),
      );
      body.scrollTop = scroll;
    };
    draw();
    element.classList.add("setup");
    element.replaceChildren(
      h("header.parent-bar", {}, h("button.plain", { type: "button", onClick: () => model.leaveQuickSetup(false) }, "Back"),
        h("h1", {}, "Quick setup"), h("span.parent-spacer")),
      body,
      h("footer.setup-foot", {},
        h("p", {}, "Progress reports, sound and accessibility settings are in the parent dashboard, from the title screen."),
        h("button.plain.primary.big", { type: "button", onClick: () => model.leaveQuickSetup(true) }, `Hand back to ${profile.nickname}`, symbol("arrow"))),
    );
  }

  /** Any level, locked or not, for a grown-up to try. Nothing played here is saved. */
  function playtest(profile: Profile | undefined): HTMLElement {
    const islands = catalog.islands.map((island) => h("details.playtest-island", {},
      h("summary", {}, island.name),
      ...island.levels.map((level) => {
        const stars = profile ? starsFor(profile, level.id) : 0;
        return h("button.plain.playtest-level", {
          type: "button", "aria-label": `Play-test ${level.title}`,
          onClick: () => { cleanUp(); model.startPlaytest(level.id, profile?.id); },
        },
        h("span.playtest-text", {},
          h("strong", {}, level.title),
          h("span.muted.small", {}, `${gameModeTitles[level.mode]} · ${level.count} questions · ${level.skills.map((skill) => skillTitles[skill]).join(", ")}`)),
        stars > 0 && h("span.playtest-stars", { "aria-label": `${stars} stars` }, "★".repeat(stars)),
        h("span.playtest-play", { "aria-hidden": "true" }, "▶"));
      })));
    return section("Play-test a level",
      ...islands,
      h("p.muted.small", {}, (profile
        ? `Opens any level, even a locked one, with ${profile.nickname}'s learning settings and current skill levels, so you see the questions they would get. `
        : "Opens any level, even a locked one, as a new player would see it. ")
        + "Nothing is saved: no stars, treasures, playtime or learning progress."),
    );
  }

  /** Replays the finale for this child, for anyone who missed a bit of it. */
  function ending(profile: Profile): HTMLElement {
    const finished = profile.crystals.length === catalog.islands.length;
    return section("The ending",
      h("p.muted.small", {}, finished
        ? `Plays the end-of-game celebration again, with ${profile.nickname}'s name and totals. Watch it as often as you like.`
        : `${profile.nickname} hasn't found all six crystal pieces yet, so this will show how the story ends before they get there.`),
      h("button.plain.playtest-level", {
        type: "button", "aria-label": `Watch the ending with ${profile.nickname}`,
        onClick: () => { cleanUp(); model.watchEnding(profile.id); },
      },
      h("span.playtest-text", {}, h("strong", {}, "Watch the ending"), h("span.muted.small", {}, "Nothing is saved or changed.")),
      h("span.playtest-play", { "aria-hidden": "true" }, "▶")),
    );
  }

  /** Reset or delete a player, each behind its own confirmation. */
  function player(profile: Profile, refresh: () => void): HTMLElement {
    const askReset = h("button.plain.danger", { type: "button" }, `Restart ${profile.nickname}'s adventure`);
    const askDelete = h("button.plain.danger", { type: "button" }, `Delete ${profile.nickname}`);
    const asks = h("div.confirm", {}, askReset, askDelete);
    const keepRewards = h<"input">("input", { type: "checkbox", checked: true });
    const keepChoice = h("label", {}, keepRewards, " Keep trophies and treasures");
    const resetMessage = h("p");
    const cancel = () => {
      const wasReset = !sureReset.hidden;
      sureReset.hidden = true; sureDelete.hidden = true; asks.hidden = false;
      keepRewards.disabled = false;
      (wasReset ? askReset : askDelete).focus();
    };
    const sureReset = h("div.confirm", { hidden: true, role: "alertdialog", "aria-label": "Restart adventure" },
      resetMessage,
      h("button.plain", { type: "button", onClick: cancel }, "Keep progress"),
      h("button.plain.danger.filled", { type: "button", onClick: () => { model.resetProgress(profile.id, keepRewards.checked); refresh(); } }, "Restart adventure"),
    );
    const sureDelete = h("div.confirm", { hidden: true, role: "alertdialog", "aria-label": "Delete player" },
      h("p", {}, `Delete ${profile.nickname}? They and all their progress will be removed from this browser. This can't be undone.`),
      h("button.plain", { type: "button", onClick: cancel }, "Cancel"),
      h("button.plain.danger.filled", { type: "button", onClick: () => {
        model.deleteProfile(profile.id);
        model.dashboardProfileID = undefined;
        refresh();
      } }, "Delete"),
    );
    askReset.addEventListener("click", () => {
      resetMessage.textContent = `Restart ${profile.nickname}'s adventure? The story, levels, stars, crystals, playtime and learning history will start again. `
        + (keepRewards.checked ? "Trophies, achievements, treasures, accessories and home decorations will be kept. "
          : "Trophies, achievements, treasures, accessories and home decorations will also be cleared. ")
        + "The player and settings will be kept. This can't be undone.";
      keepRewards.disabled = true;
      asks.hidden = true; sureReset.hidden = false;
      sureReset.querySelector("button")?.focus();
    });
    sureReset.addEventListener("keydown", (event) => { if ((event as KeyboardEvent).key === "Escape") cancel(); });
    askDelete.addEventListener("click", () => { asks.hidden = true; sureDelete.hidden = false; });
    return section("Player", keepChoice, asks, sureReset, sureDelete,
      h("p.muted.small", {}, "Restarting returns to the opening story and clears levels, stars, crystals, playtime and learning history. Keep trophies and treasures to save achievements, accessories and home decorations. The player and settings are always kept. " +
        "Deleting removes the player completely. Everything is stored in this browser only. The game has no accounts, adverts or " +
        "purchases and collects no personal information."));
  }

  if (model.parentUnlocked) unlocked();
  else gate();
  return { element, destroy: () => cleanUp() };
}
