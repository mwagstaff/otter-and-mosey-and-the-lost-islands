import { animateLagoon } from "./lagoon";
import { artURL } from "../assets";
import { playableModes, type AppModel } from "../app/model";
import { catalog, gameModeTitles, isIslandUnlocked, isLevelUnlocked, nextLevelFor, starsFor, totalStars, type Island, type LevelDef, type Profile } from "../core";
import { audio } from "../game/audio";
import { islandTheme } from "../game/theme";
import { art, button, h, picture, roundButton, symbol } from "./dom";
import { bindNameKeyboard, editName, keyboardRows } from "./keyboard";
import { photoButton } from "./photo";
import { trophiesButton } from "./trophies";

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
      h("h1.visually-hidden", {}, "Chief playtesters: Skyla and Nova"),
      h("div.dedication-row", { "aria-hidden": "true" },
        rosette("Skyla", "teal"),
        h("div.heroes", {}, art("otter_cheer", "hero otter"), art("mosey_cheer", "hero mosey")),
        rosette("Nova", "coral"),
      ),
      h("p", {}, "Developed by SkyNoLimit.dev"),
      button("cream", ["Tap to continue", symbol("play")], () => {}),
    ),
  );
  return { element, destroy: () => window.clearTimeout(timer) };
}

/** A prize rosette with a playtester's name in the middle. */
function rosette(name: string, ribbon: "teal" | "coral"): HTMLElement {
  return h(`div.rosette.${ribbon}`, {},
    h("div.rosette-disc", {}, h("div.rosette-face", {}, h("small", {}, "Chief", h("br"), "playtester"), h("strong", {}, name))),
    h("div.rosette-tails", {}, h("i"), h("i")),
  );
}

export function titleScreen(model: AppModel): Screen {
  const profile = model.profile;
  const started = profile?.seenIntro ?? false;
  const element = h("section.screen.title", { style: backdrop("bg_title") },
    art("logo", "logo"),
    h("div.heroes", {}, art("otter_idle", "hero otter bob"), art("mosey_idle", "hero mosey bob slow")),
    h("div.title-actions", {},
      started && button("teal.big", ["Continue", symbol("play")], () => model.continueGame()),
      started && trophiesButton(model),
      !started && button("teal.big", ["Play", symbol("play")], () => model.play()),
    ),
    h("header.title-header", {},
      ...(import.meta.env.VITE_GAMES_HOME ? [h("a.button.cream.small", { href: import.meta.env.VITE_GAMES_HOME }, symbol("back"), "All adventures")] : []),
      h("span.grow"),
      button("cream", [picture(profile?.avatar ?? "🙂"), profile?.nickname ?? "Players"], () => model.go({ name: "profiles" }), { "aria-label": "Choose a player" }),
    ),
    h("footer.title-footer", {},
      h("span.grow"),
      button("cream.small", [symbol("gear"), "Grown-ups"], () => model.go({ name: "parent" })),
    ),
  );
  return { element, destroy: animateLagoon(element) };
}

const avatars = ["🦦", "🐬", "🦄", "🦖", "👾", "👻", "👸", "🐢", "🦀", "🐲", "🦉", "🦋", "🐰", "⭐️", "🌈", "🚀", "🎨"];

/** Choose, add or remove a player. Only a nickname and a picture are ever asked for. */
export function profilesScreen(model: AppModel): Screen {
  const heading = h("h1.banner");
  const body = h("div.profiles-body");
  let step: "players" | "character" | "name" = "players";
  let avatar = avatars[0]!;
  let nickname = "";
  const back = () => {
    if (step === "name") characterStep();
    else if (step === "character" && model.save.profiles.length > 0) list();
    else model.go({ name: "title" });
  };
  const element = h("section.screen.profiles", { style: backdrop("bg_title") },
    h("div.veil.soft"),
    h("header.bar", {}, roundButton("back", "Back", back), heading, h("span.spacer")),
    body,
  );

  function list(): void {
    step = "players";
    heading.textContent = "Who's playing?";
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
    avatar = avatars[0]!;
    nickname = "";
    characterStep();
  }

  function characterStep(): void {
    step = "character";
    heading.textContent = "New explorer";
    const choices = avatars.map((choice) => {
      const option = button(`avatar-choice${choice === avatar ? ".chosen" : ""}`, [picture(choice, "avatar")], () => {
        avatar = choice;
        choices.forEach((each) => {
          each.classList.toggle("chosen", each === option);
          each.setAttribute("aria-pressed", String(each === option));
        });
      }, { "aria-label": `Picture ${avatars.indexOf(choice) + 1}`, "aria-pressed": String(choice === avatar) });
      return option;
    });
    body.replaceChildren(h("div.profile-form.character-step.panel", {},
      h("p.explorer-step", {}, "1 of 2 · Choose your character"),
      h("div.avatar-grid", { role: "group", "aria-label": "Choose your character" }, ...choices),
      h("div.actions", {},
        button("cream", ["Cancel"], back),
        button("teal.big", ["Next", symbol("arrow")], nameStep),
      ),
    ));
    // Restore keyboard focus when returning from the name step.
    body.querySelector<HTMLButtonElement>('.avatar-choice[aria-pressed="true"]')?.focus({ preventScroll: true });
  }

  function nameStep(): void {
    step = "name";
    const shown = h("span.avatar-shown", {}, picture(avatar, "avatar"));
    const name = h<"input">("input.nickname", {
      type: "text", required: true, inputmode: "none", "aria-describedby": "name-help name-hint", placeholder: "Nickname", maxlength: 12, autocomplete: "off", autocapitalize: "words", spellcheck: "false", "aria-label": "Nickname",
    });
    name.value = nickname;
    // Filled in only when "Let's go!" is pressed with no name, so screen readers hear it then.
    const hint = h("p.name-hint", { id: "name-hint", "aria-live": "polite" });
    const askForName = () => {
      hint.replaceChildren(art("otter_idle", "name-hint-art"), h("span", {}, "What shall we call you? Type your name in the box!"));
      hint.classList.add("shown");
      name.setAttribute("aria-invalid", "true");
      // Restart the wiggle even if it is already playing.
      name.classList.remove("wobble");
      void name.offsetWidth;
      name.classList.add("wobble");
      name.focus();
    };
    name.addEventListener("animationend", () => name.classList.remove("wobble"));
    name.addEventListener("input", () => {
      nickname = name.value;
      if (!name.value.trim() || !hint.classList.contains("shown")) return;
      hint.classList.remove("shown");
      hint.replaceChildren();
      name.removeAttribute("aria-invalid");
    });
    const go = () => {
      if (!name.value.trim()) return askForName();
      model.createProfile(name.value, avatar);
      model.play();
    };
    name.addEventListener("keydown", (event) => { if (event.key === "Enter") go(); });
    body.replaceChildren(h("div.profile-form.name-step.panel", {},
      h("p.name-help.explorer-step", { id: "name-help" }, "2 of 2 · What shall we call you?"),
      h("div.name-row", {}, shown, name),
      hint,
      h("div.name-keyboard", { role: "group", "aria-label": "Nickname keyboard" },
        ...keyboardRows({ kind: "qwerty", space: true }, (key) => editName(name, key), () => editName(name, "Backspace")),
        h("div.key-row", {}, ...["-", "’"].map((key) => button("cream.name-punctuation", [key], () => editName(name, key)))),
      ),
      h("div.actions", {},
        button("cream", ["Back"], characterStep),
        button("teal.big", ["Let's go!", symbol("play")], go),
      ),
    ));
    name.focus({ preventScroll: true });
    name.setSelectionRange(name.value.length, name.value.length);
    bindNameKeyboard(name, body.querySelector<HTMLElement>(".name-keyboard")!);
  }

  if (model.save.profiles.length === 0) form();
  else list();
  return { element };
}

export function mapScreen(model: AppModel): Screen {
  const profile = model.profile;
  // An island just unlocked by "Next adventure" is shown off once, on arrival.
  const newlyUnlocked = model.unlockedIsland;
  model.unlockedIsland = undefined;
  const unlockedName = newlyUnlocked ? catalog.island(newlyUnlocked)?.name : undefined;
  if (unlockedName) window.setTimeout(() => audio.play("unlock"), 500);
  // The island to play next is picked out, so it is obvious where to tap.
  const nextLevelID = profile ? (nextLevelFor(profile)?.id ?? profile.lastLevelID) : undefined;
  const current = nextLevelID ? catalog.islandContaining(nextLevelID) : undefined;
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
    const fresh = island.id === newlyUnlocked;
    const isNext = unlocked && island.id === current?.id;
    return button(`island-card${unlocked ? "" : ".locked"}${fresh ? ".just-unlocked" : ""}${isNext ? ".current" : ""}`,
      [isNext && h("span.play-here", { "aria-hidden": "true" }, "Play here!"), picked, h("span.island-name", {}, island.name), detail],
      () => model.go({ name: "island", id: island.id }), { disabled: !unlocked });
  });
  const chip = (key: string, text: string) => h("span.count-chip", {}, picture(key), text);
  // The player's own island, with their decorations, pets and trophy cabinet. It sits in the middle
  // of the map with the six islands ringed around it, so it is easy to find without knowing about the Home button.
  const homeLandmark = button("home-landmark", [art("island_home", "home-landmark-art"), h("span.home-landmark-name", {}, "Rainbow Island")],
    () => model.go({ name: "home" }), { "aria-label": "Rainbow Island, your own island to decorate" });
  const element: HTMLElement = h("section.screen.map", { style: backdrop("bg_map") },
    h("header.bar.map-bar", {},
      roundButton("home", "Title screen", () => model.go({ name: "title" })),
      chip(profile?.avatar ?? "🙂", profile?.nickname ?? ""),
      h("span.grow"),
      chip("⭐️", String(profile ? totalStars(profile) : 0)),
      chip("💎", `${profile?.crystals.length ?? 0}/6`),
      trophiesButton(model),
      photoButton(model, (): HTMLElement => element),
      button("gold", [picture("🎒"), "Treasures"], () => model.go({ name: "collection" })),
      button("cream", [picture("🏝️"), "Home"], () => model.go({ name: "home" })),
    ),
    unlockedName && h("p.map-note.unlocked", {}, picture("✨"), `New island to explore: ${unlockedName}!`),
    h("div.islands", {}, ...cards, homeLandmark),
    h("div.map-foot", {},
      model.breakSuggested
        ? h("p.map-note.break", {}, picture("🌙"), "Great playing today! This is a good moment for a break.")
        : h("p.map-note", {}, current && profile && isIslandUnlocked(current, profile) ? `Tap ${current.name} to play!` : "Tap an island to explore"),
    ),
  );
  return { element, destroy: animateLagoon(element, "bg_map") };
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
  return { element, destroy: animateLagoon(element, theme.background) };
}
