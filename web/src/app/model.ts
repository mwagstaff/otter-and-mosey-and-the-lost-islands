import {
  activeProfile, applyResult, catalog, newProfile, nextLevelFor, SaveStore, starsFor,
  type AppSettings, type GameMode, type Island, type KeyValueStorage, type LearnerModel, type LevelResult, type Profile,
  type RewardSummary, type SaveFile,
} from "../core";
import { audio, narrator } from "../game/audio";
import { options } from "../game/options";
import { islandTheme } from "../game/theme";

export type Route =
  | { name: "title" }
  | { name: "profiles" }
  | { name: "intro" }
  | { name: "map" }
  | { name: "island"; id: string }
  | { name: "play"; level: string }
  | { name: "collection" }
  | { name: "home" }
  | { name: "parent" }
  | { name: "ending" };

/** The game modes built for the web. A level in any other mode is shown as coming soon. */
export const playableModes: ReadonlySet<GameMode> = new Set<GameMode>(["wordBlaster", "mathsSplash", "bridgeBuilder", "eggRescue", "typingTurbo", "guardian"]);

/** Somewhere to keep the save when the browser will not allow `localStorage` (some private windows). */
class MemoryStorage implements KeyValueStorage {
  private readonly items = new Map<string, string>();
  getItem(key: string): string | null { return this.items.get(key) ?? null; }
  setItem(key: string, value: string): void { this.items.set(key, value); }
}

function browserStorage(): KeyValueStorage {
  try {
    localStorage.setItem("lost-islands.check", "1");
    localStorage.removeItem("lost-islands.check");
    return localStorage;
  } catch {
    return new MemoryStorage();
  }
}

/** App-wide state: the save file, the active profile and where the player is. */
export class AppModel {
  readonly save: SaveFile;
  private readonly store: SaveStore;
  private current: Route = { name: "title" };
  private readonly listeners = new Set<() => void>();
  /** True when progress could not be written, so the page can say so. */
  saveFailed = false;
  /** Seconds played since the page was opened, for the optional break reminder. */
  sessionSeconds = 0;

  constructor(storage: KeyValueStorage = browserStorage()) {
    this.store = new SaveStore(storage);
    this.save = this.store.load();
    options.settings = this.save.settings;
    this.applySettings();
  }

  onRoute(listener: () => void): void {
    this.listeners.add(listener);
  }

  get route(): Route {
    return this.current;
  }

  go(route: Route): void {
    // Silence the screen being left before the next one speaks.
    narrator.stop();
    this.current = route;
    const island = route.name === "island" ? route.id : route.name === "play" ? catalog.islandContaining(route.level)?.id : undefined;
    audio.playMusic(island ? islandTheme(island).music : "music_title");
    for (const listener of this.listeners) listener();
  }

  persist(): void {
    try {
      this.store.save(this.save);
      this.saveFailed = false;
    } catch (error) {
      this.saveFailed = true;
      console.error("Could not save progress", error);
    }
  }

  // Settings

  get settings(): AppSettings {
    return this.save.settings;
  }

  /** Changes some settings, puts them into effect and saves them. */
  updateSettings(changes: Partial<AppSettings>): void {
    Object.assign(this.save.settings, changes);
    this.applySettings();
    this.persist();
  }

  private applySettings(): void {
    audio.apply();
    if (typeof document === "undefined") return;
    document.body.classList.toggle("easy-read", this.settings.easyReadFont);
    document.body.classList.toggle("high-contrast", this.settings.highContrast);
    document.body.classList.toggle("calm", options.reducedMotion);
  }

  // Profiles

  get profile(): Profile | undefined {
    return activeProfile(this.save);
  }

  createProfile(nickname: string, avatar: string, favourite: string): Profile {
    const profile = newProfile([...nickname.trim()].slice(0, 12).join("") || "Explorer", avatar, favourite);
    profile.rewards = ["deco-palm"];
    this.save.profiles.push(profile);
    this.save.activeProfileID = profile.id;
    this.persist();
    return profile;
  }

  selectProfile(id: string): void {
    this.save.activeProfileID = id;
    this.persist();
  }

  deleteProfile(id: string): void {
    this.save.profiles = this.save.profiles.filter((profile) => profile.id !== id);
    if (this.save.activeProfileID === id) this.save.activeProfileID = this.save.profiles[0]?.id;
    this.persist();
  }

  /** Wipes one player's progress, keeping their name, picture and the grown-ups' choices. */
  resetProgress(id: string): void {
    const index = this.save.profiles.findIndex((profile) => profile.id === id);
    const old = this.save.profiles[index];
    if (!old) return;
    const fresh = newProfile(old.nickname, old.avatar, old.favourite);
    fresh.id = old.id;
    fresh.parent = old.parent;
    fresh.rewards = ["deco-palm"];
    this.save.profiles[index] = fresh;
    this.persist();
  }

  /** Counts time spent playing. It is written with the next real save, or when the page is hidden. */
  addPlaytime(seconds: number): void {
    const profile = this.profile;
    if (!profile || this.current.name === "title" || this.current.name === "parent" || this.current.name === "profiles") return;
    this.sessionSeconds += seconds;
    profile.playSeconds += seconds;
  }

  /** True once the grown-ups' suggested play time has passed. */
  get breakSuggested(): boolean {
    const minutes = this.profile?.parent.sessionMinutes ?? 0;
    return minutes > 0 && this.sessionSeconds >= minutes * 60;
  }

  // Navigation

  /** Where Play leads: choosing a player, then the opening story, then the map. */
  play(): void {
    const profile = this.profile;
    if (!profile) this.go({ name: "profiles" });
    else this.go({ name: profile.seenIntro ? "map" : "intro" });
  }

  /** Jumps straight to the island with the next unfinished level. */
  continueGame(): void {
    const profile = this.profile;
    if (!profile?.seenIntro) return this.play();
    const next = nextLevelFor(profile);
    const island = next && catalog.islandContaining(next.id);
    this.go(island ? { name: "island", id: island.id } : { name: "map" });
  }

  finishIntro(): void {
    const profile = this.profile;
    if (profile) {
      profile.seenIntro = true;
      this.persist();
    }
    this.go({ name: "map" });
  }

  /** Opens a level directly for testing, making a player first if there is none. */
  openForTesting(level: string): void {
    const profile = this.profile ?? this.createProfile("Tester", "🦦", "otter");
    profile.seenIntro = true;
    this.go({ name: "play", level });
  }

  // Progress

  /** Saves learning progress part-way through a level, so nothing is lost if the page is closed. */
  updateLearner(learner: LearnerModel): void {
    const profile = this.profile;
    if (!profile) return;
    profile.learner = learner.clone();
    this.persist();
  }

  complete(levelID: string, result: LevelResult, learner: LearnerModel, friendshipUses: number): RewardSummary | undefined {
    const profile = this.profile;
    if (!profile) return undefined;
    const summary = applyResult(result, levelID, learner, profile, { usedFriendshipPower: friendshipUses });
    this.persist();
    return summary;
  }

  /** How much of an island's colour has returned: the share of its levels that are cleared. */
  restoration(island: Island): number {
    const profile = this.profile;
    if (!profile) return 0;
    if (profile.crystals.includes(island.id)) return 1;
    return island.levels.filter((level) => starsFor(profile, level.id) > 0).length / island.levels.length;
  }
}
