import type { AppModel } from "../app/model";
import {
  accuracyOf, allDifficultyModes, averageSecondsOf, averageTouchWordsPerMinuteOf, averageWordsPerMinuteOf, catalog,
  defaultTables, difficultyTitles, gameModeTitles, playSecondsOver, skillTitles, spellingTopics, starsFor, totalStars, trophy, trophyCount,
  typingAccuracyOf, type DifficultyMode, type Profile,
} from "../core";
import { h } from "./dom";
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
export function parentScreen(model: AppModel): Screen {
  const element = h("section.screen.parent");
  let cleanUp = () => {};

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
        dashboard();
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
    element.replaceChildren(h("div.gate", {},
      h("h1", {}, "Grown-ups only"),
      h("p.muted", {}, "To continue, please answer:"),
      sum,
      wrong,
      h("div.digits", {}, ...[..."1234567890"].map(digit), h("button.plain.digit", { type: "button", "aria-label": "Delete", onClick: erase }, "⌫")),
      h("div.gate-actions", {}, h("button.plain", { type: "button", onClick: () => model.leaveParentArea() }, "Back"), next),
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
        playtest(undefined)));
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
      overview(profile),
      skills(profile),
      practice(profile),
      recent(profile),
      learning(profile, refresh),
      playtest(profile),
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

  function learning(profile: Profile, refresh: () => void): HTMLElement {
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
    return section("Learning settings",
      row("Difficulty", difficulty),
      h("div.stack", {}, h("span", {}, "Times tables"), h("div.tables", {}, ...tables)),
      h("div.stack", {}, h("span", {}, "Spelling topics"), ...topics),
      row("Suggest a break after", breaks),
      h("label.toggle", {}, h("span", {}, "Timed bonus points"), timed),
      h("p.muted.small", {}, "Adaptive difficulty raises or lowers each skill separately based on recent answers. " +
        "Timed bonus points only add extra score for quick answers; nothing ever runs out of time."),
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

  /** Reset or delete a player, each behind its own confirmation. */
  function player(profile: Profile, refresh: () => void): HTMLElement {
    const askReset = h("button.plain.danger", { type: "button" }, `Reset ${profile.nickname}'s progress`);
    const askDelete = h("button.plain.danger", { type: "button" }, `Delete ${profile.nickname}`);
    const asks = h("div.confirm", {}, askReset, askDelete);
    const cancel = () => { sureReset.hidden = true; sureDelete.hidden = true; asks.hidden = false; };
    const sureReset = h("div.confirm", { hidden: true, role: "alertdialog", "aria-label": "Reset progress" },
      h("p", {}, `Reset all of ${profile.nickname}'s progress? Stars, crystals, treasures, trophies and learning history are cleared. This can't be undone.`),
      h("button.plain", { type: "button", onClick: cancel }, "Keep progress"),
      h("button.plain.danger.filled", { type: "button", onClick: () => { model.resetProgress(profile.id); refresh(); } }, "Reset progress"),
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
    askReset.addEventListener("click", () => { asks.hidden = true; sureReset.hidden = false; });
    askDelete.addEventListener("click", () => { asks.hidden = true; sureDelete.hidden = false; });
    return section("Player", asks, sureReset, sureDelete,
      h("p.muted.small", {}, "Resetting keeps the player and these settings but clears their stars, treasures and learning history. " +
        "Deleting removes the player completely. Everything is stored in this browser only. The game has no accounts, adverts or " +
        "purchases and collects no personal information."));
  }

  if (model.parentUnlocked) dashboard();
  else gate();
  return { element, destroy: () => cleanUp() };
}
