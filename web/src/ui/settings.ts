import type { AppModel } from "../app/model";
import type { AppSettings } from "../core";
import { audio } from "../game/audio";
import { h, roundButton } from "./dom";

type Switch = { [Key in keyof AppSettings]: AppSettings[Key] extends boolean ? Key : never }[keyof AppSettings];

/** The sound and accessibility controls. Changes take effect, and are saved, straight away. */
export function settingsControls(model: AppModel): HTMLElement {
  const slider = (title: string, key: "musicVolume" | "effectsVolume") => {
    const input = h<"input">("input", { type: "range", min: 0, max: 1, step: 0.05, value: model.settings[key], "aria-label": title });
    input.addEventListener("input", () => model.updateSettings({ [key]: Number(input.value) }));
    // A sound to judge the new level by.
    input.addEventListener("change", () => audio.play("correct"));
    return h("label.slider", {}, h("span", {}, title), input);
  };
  const toggle = (title: string, key: Switch) => {
    const input = h<"input">("input", { type: "checkbox", role: "switch", checked: model.settings[key] });
    input.addEventListener("change", () => {
      model.updateSettings({ [key]: input.checked });
      audio.play("tap", 0.7);
    });
    return h("label.toggle", {}, h("span", {}, title), input);
  };
  const voices = typeof speechSynthesis !== "undefined";
  return h("div.settings-controls", {},
    slider("Music", "musicVolume"),
    slider("Sounds", "effectsVolume"),
    h("div.toggles", {},
      toggle("Mute everything", "muted"),
      toggle("Read questions aloud", "spokenInstructions"),
      toggle("Character voices", "characterVoices"),
      voices && toggle("Read every sum word for word", "deviceVoice"),
      toggle("Calmer motion", "reducedMotion"),
      toggle("High contrast", "highContrast"),
      toggle("Easy-read text", "easyReadFont"),
    ),
  );
}

/** Shows the settings over whatever is on screen. Escape, the cross or a tap outside closes it. */
export function openSettings(model: AppModel): void {
  const host = document.querySelector<HTMLElement>("#app")!;
  const close = () => {
    window.removeEventListener("keydown", onKey, true);
    shade.remove();
  };
  const onKey = (event: KeyboardEvent) => {
    if (event.key !== "Escape") return;
    // Keep Escape from also un-pausing the level underneath.
    event.stopPropagation();
    close();
  };
  const panel = h("div.settings.panel", { role: "dialog", "aria-label": "Settings" },
    h("header", {}, h("h2", {}, "Settings"), roundButton("close", "Close", close)),
    settingsControls(model),
  );
  const shade = h("div.shade.top", { onClick: (event) => { if (event.target === shade) close(); } }, panel);
  window.addEventListener("keydown", onKey, true);
  host.append(shade);
}
