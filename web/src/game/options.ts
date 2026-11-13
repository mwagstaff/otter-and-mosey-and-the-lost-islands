import { newAppSettings, type AppSettings } from "../core";

const calmer = typeof matchMedia === "function" ? matchMedia("(prefers-reduced-motion: reduce)") : undefined;

/** The settings every scene and sound reads. The app model keeps `settings` up to date. */
export const options = {
  settings: newAppSettings() as AppSettings,

  /** Fewer, calmer effects: chosen in the game's settings or asked for by the device. */
  get reducedMotion(): boolean {
    return this.settings.reducedMotion || (calmer?.matches ?? false);
  },
};
