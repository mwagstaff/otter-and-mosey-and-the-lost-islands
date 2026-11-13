import type { AppModel } from "../app/model";
import {
  accuracyOf, achievements, allDifficultyModes, averageSecondsOf, averageWordsPerMinuteOf, defaultTables, difficultyTitles, skillTitles,
  spellingTopics, totalStars, typingAccuracyOf, type DifficultyMode, type Profile,
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
      h("div.gate-actions", {}, h("button.plain", { type: "button", onClick: () => model.go({ name: "title" }) }, "Back"), next),
    ));
    fresh();
  }

  const row = (title: string, value: Child) => h("div.row", {}, h("span", {}, title), h("span.value", {}, value));
  const section = (title: string, ...children: Child[]) => h("section.card", {}, h("h2", {}, title), ...children);

  function dashboard(chosen?: string): void {
    const profiles = model.save.profiles;
    const profile = profiles.find((each) => each.id === (chosen ?? model.save.activeProfileID));
    const done = h("button.plain", { type: "button", onClick: () => model.go({ name: "title" }) }, "Done");
    const header = h("header.parent-bar", {}, done, h("h1", {}, "Parent dashboard"), h("span.parent-spacer"));
    if (!profile) {
      element.replaceChildren(header, h("div.parent-body", {}, h("div.card", {},
        h("h2", {}, "No players yet"),
        h("p.muted", {}, "Create a player from the title screen to see their progress here."))));
      return;
    }
    const refresh = () => dashboard(profile.id);
    const picker = profiles.length > 1 && (() => {
      const select = h<"select">("select", { "aria-label": "Child" }, ...profiles.map((each) =>
        h("option", { value: each.id, selected: each.id === profile.id }, `${each.avatar} ${each.nickname}`)));
      select.addEventListener("change", () => dashboard(select.value));
      return h("section.card", {}, row("Child", select));
    })();
    element.replaceChildren(header, h("div.parent-body", {},
      picker,
      overview(profile),
      skills(profile),
      practice(profile),
      recent(profile),
      learning(profile, refresh),
      section("Sound and accessibility", settingsControls(model)),
      reset(profile, refresh),
    ));
  }

  function overview(profile: Profile): HTMLElement {
    const learner = profile.learner;
    const typing = learner.typing;
    return section("Overview",
      row("Total playtime", playtime(profile.playSeconds)),
      row("Stars and crystals", `${totalStars(profile)} stars, ${profile.crystals.length} of 6 crystals`),
      row("Spelling accuracy", percent(learner.accuracy("spelling"))),
      row("Maths accuracy", percent(learner.accuracy("maths"))),
      row("Typing accuracy", typing.keystrokes === 0 ? "No data yet" : percent(typingAccuracyOf(typing))),
      row("Typing speed", typing.samples.length === 0
        ? "Measured with a real keyboard"
        : `${Math.round(averageWordsPerMinuteOf(typing))} wpm average, best ${Math.round(typing.bestWordsPerMinute)}`),
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
    const earned = Object.entries(profile.achievements).sort((a, b) => (a[1] < b[1] ? 1 : -1)).slice(0, 5);
    return section("Recent achievements",
      earned.length === 0 && h("p.muted", {}, "None yet."),
      ...earned.map(([id, when]) => {
        const achievement = achievements.find((each) => each.id === id);
        const date = new Date(when).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
        return achievement && row(achievement.title, date);
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

  function reset(profile: Profile, refresh: () => void): HTMLElement {
    const ask = h("button.plain.danger", { type: "button" }, `Reset ${profile.nickname}'s progress`);
    const sure = h("div.confirm", { hidden: true },
      h("p", {}, "Reset all progress for this child? This cannot be undone."),
      h("button.plain", { type: "button", onClick: () => { sure.hidden = true; ask.hidden = false; } }, "Keep progress"),
      h("button.plain.danger.filled", { type: "button", onClick: () => { model.resetProgress(profile.id); refresh(); } }, "Reset progress"),
    );
    ask.addEventListener("click", () => {
      sure.hidden = false;
      ask.hidden = true;
    });
    return h("section.card", {}, ask, sure,
      h("p.muted.small", {}, "Everything is stored in this browser only. The game has no accounts, adverts or purchases and collects no personal information."));
  }

  gate();
  return { element, destroy: () => cleanUp() };
}
