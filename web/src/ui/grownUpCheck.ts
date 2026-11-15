import { artURL } from "../assets";
import type { AppModel } from "../app/model";
import { settingsSummary } from "../core";
import { audio } from "../game/audio";
import { art, button, h, picture, symbol } from "./dom";
import type { Screen } from "./menus";

/**
 * Shown to a new player after they pick their name, before the opening story: a nudge to let a
 * grown-up check the learning settings. It never blocks play, as "Start adventure" always works.
 */
export function grownUpCheckScreen(model: AppModel): Screen {
  const profile = model.profile!;
  const checked = profile.grownUpChecked;
  if (checked) window.setTimeout(() => audio.play("unlock"), 300);
  const settings = h("dl.check-settings", {}, ...settingsSummary(profile.parent).flatMap((line) => [
    h("dt", {}, line.label),
    h(`dd${checked && line.changed ? ".changed" : ""}`, {}, line.value),
  ]));
  const grownUps = button(checked ? "cream.small" : "gold", [symbol("gear"), "Grown-ups"], () => model.openQuickSetup(),
    { "aria-label": "Grown-ups: check the settings" });
  const start = button("teal.big", ["Start adventure", symbol("play")], () => model.startAdventure());
  const element = h("section.screen.check", { style: `background-image: url("${artURL("bg_title")}")` },
    h("div.veil.soft"),
    art(checked ? "otter_cheer" : "otter_idle", "hero otter"),
    art(checked ? "mosey_cheer" : "mosey_idle", "hero mosey"),
    h("div.check-card.panel", { role: "group", "aria-labelledby": "check-title" },
      h("div.check-head", {},
        h("span.check-avatar", {}, picture(profile.avatar, "avatar")),
        h("h1", { id: "check-title" }, checked ? `All set, ${profile.nickname}!` : `Nice to meet you, ${profile.nickname}!`),
      ),
      h("p.check-lede", {}, checked
        ? "Thanks, grown-up! Time to find the lost crystal fragments."
        : "Before we set sail, ask a grown-up to check the game is just right for you."),
      h("div.check-summary", {},
        h("div.check-summary-title", {}, h("span", {}, "The game is set to"),
          checked && h("span.checked-badge", {}, symbol("tick"), "Checked by a grown-up")),
        settings,
      ),
      h("div.check-actions", {}, grownUps, start),
      !checked && h("p.check-note", {}, "Grown-ups can change these any time from the title screen."),
    ),
  );
  return { element };
}
