import { artURL } from "../assets";
import type { AppModel } from "../app/model";
import {
  allTrophies, catalog, counterUnits, counterValue, isIslandUnlocked, isLevelUnlocked, totalStars, trophyCount, trophyGroups,
  trophyGroupTitles, trophyLadders, trophyProgress, type Island, type Profile, type Trophy, type TrophyGroup,
} from "../core";
import { button, h, picture, roundButton } from "./dom";
import type { Screen } from "./menus";

// The trophy cabinet and the small pieces shared with the results screen and the menus.

const rings = ["#c98a4b", "#c9d3db", "#ffc83d", "#ff7eb6", "#8fa8ff"];

/** One trophy's painting. A trophy still to be won shows as a soft silhouette of its shape. */
export function trophyBadge(item: Trophy, earned = true, className = ""): HTMLElement {
  const ring = item.tier > 0 ? rings[Math.min(item.tier, rings.length) - 1] : undefined;
  return h(`span.trophy-badge${earned ? "" : ".missing"}${ring ? ".ringed" : ""}${className ? "." + className : ""}`,
    { style: ring ? `--ring: ${ring}` : undefined, "aria-hidden": "true" },
    h("img", { src: artURL(item.art), alt: "", draggable: "false" }),
    item.badge && h("b", {}, item.badge),
  );
}

/** A wrapped parcel, for a trophy won but still waiting to be handed out. */
function parcel(className = ""): HTMLElement {
  return h(`span.trophy-badge.parcel${className ? "." + className : ""}`, { "aria-hidden": "true" },
    h("img", { src: artURL("trophy_parcel"), alt: "", draggable: "false" }));
}

/** The Trophies button used on the title screen and the map. */
export function trophiesButton(model: AppModel, className = "gold"): HTMLElement {
  const count = model.profile ? trophyCount(model.profile).won : 0;
  const made = button(`${className}.trophies-button`, [
    picture("trophy_champion"), h("span.trophies-word", {}, "Trophies"), h("span.count-pill", {}, String(count)),
  ], () => model.openTrophies(), { "aria-label": `Trophies, ${count} won${model.hasNewTrophies ? ", new ones to see" : ""}` });
  if (model.hasNewTrophies) made.append(h("span.new-tag", { "aria-hidden": "true" }, "New!"));
  return made;
}

/** The little cabinet in the corner of the results screen that trophies fly into. */
export function miniCabinet(won: number, total: number): { element: HTMLElement; set(won: number): void; bump(): void } {
  const count = h("span.count-pill", {}, `${won} / ${total}`);
  const cabinet = h("img.mini-cabinet-art", { src: artURL("trophy_cabinet"), alt: "", draggable: "false" });
  const element = h("div.mini-cabinet", { role: "img", "aria-label": `Trophy cabinet: ${won} of ${total} trophies` }, cabinet, count);
  return {
    element,
    set(value) {
      count.textContent = `${value} / ${total}`;
      element.setAttribute("aria-label", `Trophy cabinet: ${value} of ${total} trophies`);
    },
    bump() {
      cabinet.classList.remove("bump");
      void cabinet.offsetWidth;
      cabinet.classList.add("bump");
    },
  };
}

/** The island's crystal fragment, glowing in the island's colour. */
export function crystalShowcase(island: Island): HTMLElement {
  const shard = artURL("crystal_shard");
  return h("div.crystal-showcase", { style: `--tint: ${island.colour}`, role: "img", "aria-label": `The ${island.name} crystal fragment` },
    h("span.rays"),
    h("span.shard.big", {},
      h("img", { src: shard, alt: "", draggable: "false" }),
      h("span.shard-tint", { style: `background: ${island.colour}; -webkit-mask-image: url("${shard}"); mask-image: url("${shard}")` }),
    ),
    h("span.crystal-caption", {}, `${island.name} fragment`),
  );
}

/** Six fragment slots, filled in each island's colour once its fragment is back. */
export function fragmentRow(found: string[]): HTMLElement {
  const shard = artURL("crystal_shard");
  return h("div.fragments", { role: "img", "aria-label": `${found.length} of ${catalog.islands.length} crystal fragments found` },
    ...catalog.islands.map((island) => {
      const back = found.includes(island.id);
      return h(`span.shard.slot${back ? "" : ".empty"}`, {},
        h("img", { src: shard, alt: "", draggable: "false" }),
        back && h("span.shard-tint", { style: `background: ${island.colour}; -webkit-mask-image: url("${shard}"); mask-image: url("${shard}")` }),
      );
    }),
    h("span", {}, `${found.length} of ${catalog.islands.length} fragments back`),
  );
}

// The cabinet

export function trophyCabinetScreen(model: AppModel): Screen {
  const profile = model.profile!;
  const list = allTrophies();
  let group: TrophyGroup = "islands";
  const won = (item: Trophy) => profile.achievements[item.id] !== undefined;
  const waiting = (item: Trophy) => profile.pendingTrophies.includes(item.id);
  const badge = (item: Trophy, className = "") => (waiting(item) ? parcel(className) : trophyBadge(item, won(item), className));
  const glass = h("div.cabinet-glass");
  const detailLayer = h("div.trophy-detail-layer");

  const pick = (item: Trophy, child: HTMLElement, label?: string) =>
    button("trophy-pick", [child], () => showDetail(item), {
      "aria-label": label ?? `${item.title}${item.levelID ? `, ${catalog.level(item.levelID)?.title ?? ""}` : ""}. ${won(item) ? "Won" : item.detail}`,
    });

  function waitingNote(): HTMLElement | false {
    const count = profile.pendingTrophies.length;
    if (count === 0) return false;
    return h("div.waiting-note", {}, h("img", { src: artURL("trophy_parcel"), alt: "", draggable: "false" }),
      count === 1 ? "1 trophy is waiting! Finish any level to unwrap it." : `${count} trophies are waiting! Finish any level to unwrap them.`);
  }

  function islands(): HTMLElement {
    return h("div.shelves", {}, ...catalog.islands.map((island) => {
      const mine = list.filter((item) => item.islandID === island.id);
      return h("div.shelf", {},
        h("div.shelf-label", {}, h("img", { src: artURL(`island_${island.id}`), alt: "" }), island.name,
          h("small", {}, `${mine.filter(won).length} of ${mine.length}`)),
        h("div.shelf-row", {},
          ...island.levels.map((level) => h("div.level-medals", {},
            h("div.pair", {}, ...mine.filter((item) => item.levelID === level.id).map((item) => pick(item, badge(item)))),
            h("small", {}, level.title),
          )),
          h("span.grow"),
          ...mine.filter((item) => item.levelID === undefined).map((item) => h("div.level-medals.big", {}, pick(item, badge(item)), h("small", {}, item.title))),
        ),
      );
    }));
  }

  function ladders(): HTMLElement {
    return h("div.ladders", {}, ...trophyLadders.map((ladder) => {
      const rungs = list.filter((item) => item.ladder === ladder.id);
      const value = counterValue(ladder.counter, profile);
      const next = ladder.rungs.find((rung) => value < rung);
      const previous = [...ladder.rungs].reverse().find((rung) => value >= rung) ?? 0;
      const share = next === undefined ? 1 : (value - previous) / (next - previous);
      return h("div.ladder", {},
        h("div.ladder-title", {}, h("span", {}, ladder.title), h("small", {}, next === undefined ? "All done!" : `${value} of ${next} ${counterUnits[ladder.counter]}`)),
        h("div.rungs", {}, ...rungs.map((item) => pick(item, badge(item))),
          h("span.tmeter", {}, h("i", { style: `width: ${Math.round(Math.min(Math.max(share, 0), 1) * 100)}%` }))),
      );
    }));
  }

  function grid(items: Trophy[]): HTMLElement {
    return h("div.trophy-grid", {}, ...items.map((item) => {
      const hidden = item.group === "secret" && !won(item) && !waiting(item);
      const icon = hidden ? h("span.mystery", { "aria-hidden": "true" }, "?") : badge(item);
      return pick(item, h(`span.trophy-tile${won(item) ? ".won" : ""}`, {},
        icon, h("strong", {}, hidden ? "???" : item.title), h("span", {}, hidden ? item.riddle ?? "" : item.detail)),
        hidden ? `Secret trophy. ${item.riddle ?? ""}` : undefined);
    }));
  }

  function render(): void {
    tabButtons.forEach((each, index) => each.classList.toggle("chosen", trophyGroups[index] === group));
    const content = group === "islands" ? islands() : group === "milestones" ? ladders() : grid(list.filter((item) => item.group === group));
    glass.replaceChildren(h("div.cabinet-scroll", {}, waitingNote(), content));
  }

  function showDetail(item: Trophy): void {
    const earned = won(item);
    const hidden = item.group === "secret" && !earned && !waiting(item);
    const level = item.levelID ? catalog.level(item.levelID) : undefined;
    const island = item.islandID ? catalog.island(item.islandID) : undefined;
    const progress = earned ? undefined : trophyProgress(item, profile);
    const date = profile.achievements[item.id];
    let go: [string, () => void] | undefined;
    if (!earned && level && isLevelUnlocked(level.id, profile)) go = [`Play ${level.title}`, () => model.go({ name: "play", level: level.id })];
    else if (!earned && !level && island && isIslandUnlocked(island, profile)) go = [`Visit ${island.name}`, () => model.go({ name: "island", id: island.id })];
    const close = () => detailLayer.replaceChildren();
    const status = date
      ? h("p.detail-status.won", {}, `In your cabinet since ${new Date(date).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })}`)
      : waiting(item)
        ? h("p.detail-status", {}, "Won! It’s waiting for you at the end of your next level.")
        : progress && !hidden
          ? h("div.detail-progress", {}, h("span.tmeter.light", {}, h("i", { style: `width: ${Math.round((progress.now / Math.max(progress.needed, 1)) * 100)}%` })),
            h("span", {}, `${progress.now} of ${progress.needed}`))
          : false;
    detailLayer.replaceChildren(h("div.trophy-detail-shade", { onClick: (event: Event) => { if (event.target === event.currentTarget) close(); } },
      h("div.trophy-detail.panel", { role: "dialog", "aria-label": hidden ? "Secret trophy" : item.title },
        h("div.detail-head", {},
          hidden ? h("span.mystery.dark", { "aria-hidden": "true" }, "?") : (waiting(item) ? parcel("big") : trophyBadge(item, earned, "big")),
          h("div", {}, h("h2", {}, hidden ? "Secret trophy" : item.title),
            (level || island) && h("p", {}, level && island ? `${level.title} · ${island.name}` : (island?.name ?? ""))),
          h("span.grow"),
          roundButton("close", "Close", close),
        ),
        h("p.detail-text", {}, hidden ? item.riddle ?? "" : item.detail),
        status,
        go && button("teal", [go[0]], go[1]),
      )));
  }

  const count = trophyCount(profile);
  const tabButtons = trophyGroups.map((each) => button("cream.tab", [trophyGroupTitles[each]], () => {
    group = each;
    detailLayer.replaceChildren();
    render();
  }));
  const element = h("section.screen.trophies", { style: `background-image: url("${artURL("bg_title")}")` },
    h("div.veil.soft"),
    h("header.bar.trophies-bar", {},
      roundButton("back", "Back", () => model.go(model.trophiesReturn)),
      h("div.cabinet-plaque", {}, h("strong", {}, "Trophy Cabinet"),
        h("span.tmeter.plaque-bar", {}, h("i", { style: `width: ${Math.round((count.won / count.total) * 100)}%` })),
        h("small", {}, `${count.won} of ${count.total} trophies`)),
      h("span.grow"),
      h("div.tabs", {}, ...tabButtons),
    ),
    h("div.cabinet-body", {}, records(profile), h("div.cabinet-frame", {}, glass)),
    detailLayer,
  );
  render();
  model.markTrophiesSeen();
  return { element };
}

function records(profile: Profile): HTMLElement {
  const rows: [string, string, string, string?][] = [
    ["⭐️", "Stars", String(totalStars(profile)), `/ ${catalog.allLevels.length * 3}`],
    ["pearl", "Pearls", String(profile.stats.pearls)],
    ["badge_answers-50", "Right answers", String(counterValue("answers", profile))],
    ["badge_sharp-shooter", "Right first time", String(counterValue("firstTry", profile))],
    ["badge_combo-8", "Best streak", String(profile.bestCombo)],
    ["badge_fast-fingers", "Fastest typing", String(counterValue("typing", profile)), "wpm"],
    ["badge_adventurer", "Levels played", String(counterValue("levels", profile))],
    ["badge_explorer", "Days played", String(profile.stats.playDays)],
  ];
  return h("div.records.panel", {}, h("h2", {}, "My records"),
    ...rows.map(([key, title, value, unit]) => h("div.record", {}, picture(key), h("span", {}, title), h("strong", {}, value), unit && h("small", {}, unit))));
}
