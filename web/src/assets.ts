import manifest from "./generated/assets.json";

// Where the pictures, sounds and voice clips copied from the iOS project live.
// The manifest is written by scripts/sync-assets.mjs.

const art: Record<string, string> = manifest.art;
const audio: Record<string, string> = manifest.audio;
const speech = new Set(manifest.speech);
const base = `${import.meta.env.BASE_URL}assets/`;

export function hasArt(name: string): boolean {
  return name in art;
}

export function artURL(name: string): string {
  const path = art[name];
  if (path === undefined) throw new Error(`No picture called ${name}`);
  return base + path;
}

/** A sound effect or music loop, e.g. `pop` or `music_title`. */
export function audioURL(name: string): string {
  const path = audio[name];
  if (path === undefined) throw new Error(`No sound called ${name}`);
  return base + path;
}

/** The recording for a narrator or dialogue clip key, if there is one. */
export function speechURL(key: string | undefined): string | undefined {
  return key !== undefined && speech.has(key) ? `${base}speech/say_${key}.mp3` : undefined;
}
