import { artURL } from "../assets";
import { playableModes, type AppModel } from "../app/model";
import { catalog, gameModeTitles, isIslandUnlocked, isLevelUnlocked, starsFor, totalStars, type Island, type LevelDef, type Profile } from "../core";
import { audio } from "../game/audio";
import { islandTheme } from "../game/theme";
import { art, button, h, picture, roundButton, symbol } from "./dom";
import { openSettings } from "./settings";

/** One of the game's screens: what to show, and how to tidy up when it is left. */
export interface Screen {
  element: HTMLElement;
  destroy?(): void;
}

const backdrop = (name: string) => `background-image: url("${artURL(name)}")`;

/** Three stars, with the ones not yet earned greyed out. */
export function starRow(stars: number, className = "stars"): HTMLElement {
  return h(`span.${className}`, { role: "img", "aria-label": `${stars} of 3 stars` },
    ...[1, 2, 3].map((star) => picture("⭐️", star <= stars ? "star" : "star.unearned")));
}

/**
 * The first thing on screen when the game opens: who it was made for, and by whom.
 * It stays for ten seconds, or until tapped, then gives way to the title screen.
 */
export function dedicationScreen(done: () => void): Screen {
  const timer = window.setTimeout(done, 10_000);
  const element = h("section.screen.dedication", { style: backdrop("bg_title"), onClick: done },
    h("div.veil"),
    h("div.dedication-body", {},
      h("div.heroes", {}, art("otter_cheer", "hero otter"), art("mosey_cheer", "hero mosey")),
      h("h1", {}, "For Skyla and Nova"),
      h("p", {}, "Developed by SkyNoLimit.dev"),
      button("cream", ["Tap to continue", symbol("play")], () => {}),
    ),
  );
  return { element, destroy: () => window.clearTimeout(timer) };
}

export function titleScreen(model: AppModel): Screen {
  const profile = model.profile;
  const started = profile?.seenIntro ?? false;
  const element = h("section.screen.title", { style: backdrop("bg_title") },
    art("logo", "logo"),
    h("div.heroes", {}, art("otter_idle", "hero otter bob"), art("mosey_idle", "hero mosey bob slow")),
    h("div.title-actions", {},
      started && button("teal.big", ["Continue", symbol("play")], () => model.continueGame()),
      started && button("gold", [picture("🗺️"), "World map"], () => model.play()),
      !started && button("teal.big", ["Play", symbol("play")], () => model.play()),
    ),
    h("footer.title-footer", {},
      ...(import.meta.env.VITE_GAMES_HOME ? [h("a.button.cream.small", { href: import.meta.env.VITE_GAMES_HOME }, "All adventures")] : []),
      button("cream", [picture(profile?.avatar ?? "🙂"), profile?.nickname ?? "Players"], () => model.go({ name: "profiles" }), { "aria-label": "Choose a player" }),
      h("span.grow"),
      button("cream.small", ["Grown-ups"], () => model.go({ name: "parent" })),
      roundButton("gear", "Settings", () => openSettings(model)),
    ),
  );
  return { element };
}

const avatars = ["🦦", "🐬", "🦄", "🦖", "👾", "👻", "👸", "🐢", "🦀", "🐲", "🦉", "🦋", "🐰", "⭐️", "🌈", "🚀", "🎨"];

/** Choose, add or remove a player. Only a nickname and a picture are ever asked for. */
export function profilesScreen(model: AppModel): Screen {
  const heading = h("h1.banner");
  const body = h("div.profiles-body");
  const element = h("section.screen.profiles", { style: backdrop("bg_title") },
    h("div.veil.soft"),
    h("header.bar", {}, roundButton("back", "Back", () => model.go({ name: "title" })), heading, h("span.spacer")),
    body,
  );

  function list(): void {
    heading.textContent = "Who is playing?";
    const cards = model.save.profiles.map((profile) => {
      const card = button(`player${profile.id === model.profile?.id ? ".current" : ""}`, [
        picture(profile.avatar, "avatar"),
        h("span.player-name", {}, profile.nickname),
        h("span.player-detail", {}, picture("⭐️", "star small"), String(totalStars(profile)), " ", picture("💎", "star small"), `${profile.crystals.length}/6`),
      ], () => {
        model.selectProfile(profile.id);
        model.play();
      });
      const remove = button("cream.remove", ["Remove"], () => confirmRemoval(profile), { "aria-label": `Remove ${profile.nickname}` });
      return h("div.player-slot", {}, card, remove);
    });
    const add = button("player.add", [symbol("plus"), h("span.player-name", {}, "New player")], form);
    body.replaceChildren(h("div.players", {}, ...cards, add));
  }

  function confirmRemoval(profile: Profile): void {
    const close = () => shade.remove();
    const shade = h("div.shade.top", {}, h("div.pause.panel", { role: "alertdialog", "aria-label": "Remove player" },
      h("h2", {}, `Remove ${profile.nickname}?`),
      h("p", {}, "All their stars and progress will be lost."),
      h("div.actions", {},
        button("cream", ["Keep"], close),
        button("coral", ["Remove player"], () => {
          close();
          model.deleteProfile(profile.id);
          if (model.save.profiles.length === 0) form();
          else list();
        }),
      ),
    ));
    element.append(shade);
  }

  function form(): void {
    heading.textContent = "New explorer";
    let avatar = avatars[0]!;
    let favourite = "otter";
    const shown = h("span.avatar-shown", {}, picture(avatar, "avatar"));
    const name = h<"input">("input.nickname", {
      type: "text", placeholder: "Nickname", maxlength: 12, autocomplete: "off", autocapitalize: "words", spellcheck: "false", "aria-label": "Nickname",
    });
    const choices = avatars.map((choice) => {
      const option = button(`avatar-choice${choice === avatar ? ".chosen" : ""}`, [picture(choice, "avatar")], () => {
        avatar = choice;
        shown.replaceChildren(picture(avatar, "avatar"));
        choices.forEach((each) => each.classList.toggle("chosen", each === option));
      }, { "aria-label": `Picture ${avatars.indexOf(choice) + 1}` });
      return option;
    });
    const favourites = ["otter", "mosey"].map((who) => {
      const option = button(`favourite${who === favourite ? ".chosen" : ""}`, [art(`${who}_idle`, "favourite-art"), who === "otter" ? "Otter" : "Mosey"], () => {
        favourite = who;
        favourites.forEach((each) => each.classList.toggle("chosen", each === option));
      });
      return option;
    });
    const go = () => {
      model.createProfile(name.value, avatar, favourite);
      model.play();
    };
    name.addEventListener("keydown", (event) => { if (event.key === "Enter") go(); });
    body.replaceChildren(h("div.profile-form.panel", {},
      h("div.name-row", {}, shown, name),
      h("div.avatar-row", {}, ...choices),
      h("div.favourite-row", {}, h("span", {}, "My favourite:"), ...favourites),
      h("div.actions", {},
        model.save.profiles.length > 0 && button("cream", ["Cancel"], list),
        button("teal.big", ["Let's go!", symbol("play")], go),
      ),
    ));
  }

  if (model.save.profiles.length === 0) form();
  else list();
  return { element };
}

/** The reward for restoring all six fragments. */
export function endingScreen(model: AppModel): Screen {
  audio.play("victory");
  const element = h("section.screen.ending", { style: backdrop("bg_ending") },
    h("div.ending-card.panel", {},
      h("h1", {}, "The Rainbow Crystal is whole again!"),
      h("p", {}, `Thank you, ${model.profile?.nickname ?? "explorer"}. Every island is full of colour because of you.`),
      button("teal.big", [picture("🗺️"), "Keep exploring"], () => model.go({ name: "map" })),
    ),
  );
  return { element };
}

export function mapScreen(model: AppModel): Screen {
  const profile = model.profile;
  const cards = catalog.islands.map((island, index) => {
    const unlocked = profile !== undefined && isIslandUnlocked(island, profile);
    const stars = profile ? island.levels.reduce((sum, level) => sum + starsFor(profile, level.id), 0) : 0;
    const found = profile?.crystals.includes(island.id) ?? false;
    const saturation = unlocked ? 0.25 + 0.75 * model.restoration(island) : 0;
    const picked = art(islandTheme(island.id).islandArt, "island-art");
    picked.style.filter = `saturate(${saturation})`;
    const detail = unlocked
      ? h("span.island-detail", {}, `${island.focus} · `, picture("⭐️", "star small"), `${stars}/15`, found && " · ", found && picture("💎", "star small"), found && "found")
      : h("span.island-detail", {}, picture("🔒", "star small"), `Find the ${catalog.islands[Math.max(index - 1, 0)]!.name} crystal first`);
    return button(`island-card${unlocked ? "" : ".locked"}`, [picked, h("span.island-name", {}, island.name), detail],
      () => model.go({ name: "island", id: island.id }), { disabled: !unlocked });
  });
  const chip = (key: string, text: string) => h("span.count-chip", {}, picture(key), text);
  const element = h("section.screen.map", { style: backdrop("bg_map") },
    h("header.bar.map-bar", {},
      roundButton("home", "Title screen", () => model.go({ name: "title" })),
      chip(profile?.avatar ?? "🙂", profile?.nickname ?? ""),
      h("span.grow"),
      chip("⭐️", String(profile ? totalStars(profile) : 0)),
      chip("💎", `${profile?.crystals.length ?? 0}/6`),
      button("gold", [picture("🎒"), "Treasures"], () => model.go({ name: "collection" })),
      button("cream", [picture("🏝️"), "Home"], () => model.go({ name: "home" })),
    ),
    h("div.islands", {}, ...cards),
    model.breakSuggested
      ? h("p.map-note.break", {}, picture("🌙"), "Great playing today! This is a good moment for a break.")
      : h("p.map-note", {}, "Tap an island to explore"),
  );
  return { element };
}

export function islandScreen(model: AppModel, island: Island): Screen {
  const profile = model.profile;
  const theme = islandTheme(island.id);
  const cleared = profile?.crystals.includes(island.id) ?? false;

  const node = (level: LevelDef, index: number) => {
    const stars = profile ? starsFor(profile, level.id) : 0;
    const unlocked = profile !== undefined && isLevelUnlocked(level.id, profile);
    const built = playableModes.has(level.mode);
    const isGuardian = level.mode === "guardian";
    const face = isGuardian
      ? art(stars > 0 ? theme.guardianHappy : theme.guardian, "level-face")
      : h("span.level-number", {}, unlocked ? String(index + 1) : picture("🔒", "lock"));
    const note = !unlocked ? "Finish the one before first" : !built ? `${gameModeTitles[level.mode]} is coming soon` : level.blurb;
    return button(`level${unlocked && built ? "" : ".locked"}${isGuardian ? ".guardian" : ""}`, [
      h("span.level-disc", {}, face),
      h("span.level-title", {}, level.title),
      h("span.level-note", {}, note),
      starRow(stars),
    ], () => model.go({ name: "play", level: level.id }), { disabled: !(unlocked && built) });
  };

  const element = h("section.screen.island", { style: backdrop(theme.background) },
    h("div.veil.light"),
    h("header.bar", {},
      roundButton("back", "World map", () => model.go({ name: "map" })),
      h("div.banner", {}, h("h1", {}, island.name), h("p", {}, cleared ? "Crystal fragment found!" : island.tagline)),
      h("span.spacer"),
    ),
    h("div.levels", {}, ...island.levels.map(node)),
  );
  return { element };
}
