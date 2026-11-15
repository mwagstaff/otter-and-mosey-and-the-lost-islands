import {
  activeProfile, addPlaytime, applyResult, catalog, cloneProfile, newProfile, nextLevelFor, prepareTrophies, SaveStore, starsFor, trophyCount,
  type AppSettings, type GameMode, type Island, type KeyValueStorage, type LearnerModel, type LevelResult, type Profile,
  type RewardSummary, type SaveFile,
} from "../core";
import { audio, narrator } from "../game/audio";
import { options } from "../game/options";
import { islandTheme } from "../game/theme";

export type Route =
  | { name: "title" }
  | { name: "profiles" }
  | { name: "check" }
  | { name: "intro" }
  | { name: "map" }
  | { name: "island"; id: string }
  | { name: "play"; level: string }
  | { name: "collection" }
  | { name: "trophies" }
  | { name: "home" }
  /** The grown-ups' area: the full dashboard, or with `setup` just the new player's quick setup. */
  | { name: "parent"; setup?: boolean }
  /** The finale. From the grown-ups' area it plays for `profileID` and leads back there. */
  | { name: "ending"; fromGrownUps?: boolean; profileID?: string };

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
  /**
   * Set while a grown-up is play-testing a level from the parent dashboard. It holds a copy of
   * the chosen child's profile (or a fresh one), and nothing played with it is saved.
   */
  playtest: { profile: Profile } | undefined;
  /** Stays true while a grown-up moves between the dashboard and play-testing, so the gate is not asked again. */
  parentUnlocked = false;
  /** The child last chosen in the parent dashboard. */
  dashboardProfileID: string | undefined;
  /** An island just unlocked by "Next adventure", which the map shows off on arrival. */
  unlockedIsland: string | undefined;
  /** Where the trophy cabinet's back button goes. */
  trophiesReturn: Route = { name: "map" };

  constructor(storage: KeyValueStorage = browserStorage()) {
    this.store = new SaveStore(storage);
    this.save = this.store.load();
    // Moves stickers from before the trophy cabinet into it, for every player.
    if (this.save.profiles.some((profile) => !profile.trophiesReady)) {
      for (const profile of this.save.profiles) prepareTrophies(profile);
      this.persist();
    }
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

  // Trophies

  openTrophies(): void {
    if (this.current.name !== "trophies") this.trophiesReturn = this.current;
    this.go({ name: "trophies" });
  }

  /** Trophies won since the player last opened the cabinet. */
  get hasNewTrophies(): boolean {
    const profile = this.profile;
    return !!profile && trophyCount(profile).won > profile.trophiesSeen;
  }

  markTrophiesSeen(): void {
    const profile = this.profile;
    if (!profile) return;
    const won = trophyCount(profile).won;
    if (profile.trophiesSeen === won) return;
    profile.trophiesSeen = won;
    this.persist();
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

  createProfile(nickname: string, avatar: string): Profile {
    const profile = newProfile([...nickname.trim()].slice(0, 12).join("") || "Explorer", avatar);
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
  resetProgress(id: string, keepRewards = false): void {
    const index = this.save.profiles.findIndex((profile) => profile.id === id);
    const old = this.save.profiles[index];
    if (!old) return;
    const fresh = newProfile(old.nickname, old.avatar);
    fresh.id = old.id;
    fresh.parent = old.parent;
    fresh.rewards = ["deco-palm"];
    if (keepRewards) {
      const kept = cloneProfile(old);
      fresh.rewards = kept.rewards;
      fresh.equippedAccessory = kept.equippedAccessory;
      fresh.decorations = kept.decorations;
      fresh.achievements = kept.achievements;
      fresh.pendingTrophies = kept.pendingTrophies;
      fresh.trophiesReady = kept.trophiesReady;
      fresh.trophiesSeen = kept.trophiesSeen;
    }
    this.save.profiles[index] = fresh;
    if (this.save.activeProfileID === id) {
      this.sessionSeconds = 0;
      this.unlockedIsland = undefined;
    }
    this.persist();
  }

  /** Counts time spent playing. It is written with the next real save, or when the page is hidden. */
  addPlaytime(seconds: number): void {
    const profile = this.profile;
    if (!profile || this.playtest || this.current.name === "title" || this.current.name === "parent" || this.current.name === "profiles") return;
    if (this.current.name === "ending" && this.current.fromGrownUps) return;
    this.sessionSeconds += seconds;
    addPlaytime(profile, seconds);
  }

  // Play-testing

  /** The profile a level is played with: the play-test copy, or the active player. */
  get playingProfile(): Profile | undefined {
    return this.playtest?.profile ?? this.profile;
  }

  /** Opens any level, locked or not, for a grown-up to try. Nothing it does is saved. */
  startPlaytest(levelID: string, profileID: string | undefined): void {
    if (!catalog.level(levelID)) return;
    const chosen = this.save.profiles.find((profile) => profile.id === profileID);
    const tester = chosen ? cloneProfile(chosen) : newProfile("Tester");
    tester.seenIntro = true;
    this.playtest = { profile: tester };
    this.go({ name: "play", level: levelID });
  }

  /** Plays the finale from the grown-ups' area for the chosen child, any number of times. */
  watchEnding(profileID: string | undefined): void {
    this.go({ name: "ending", fromGrownUps: true, profileID });
  }

  endPlaytest(): void {
    this.playtest = undefined;
    this.go({ name: "parent" });
  }

  leaveParentArea(): void {
    this.parentUnlocked = false;
    this.dashboardProfileID = undefined;
    this.go({ name: "title" });
  }

  /** True once the grown-ups' suggested play time has passed. */
  get breakSuggested(): boolean {
    const minutes = this.profile?.parent.sessionMinutes ?? 0;
    return minutes > 0 && this.sessionSeconds >= minutes * 60;
  }

  // Navigation

  /** Where Play leads: choosing a player, then the grown-up check and the opening story, then the map. */
  play(): void {
    const profile = this.profile;
    if (!profile) this.go({ name: "profiles" });
    else this.go({ name: profile.seenIntro ? "map" : "check" });
  }

  /** From the grown-up check to its quick setup, behind the grown-ups' gate. */
  openQuickSetup(): void {
    this.go({ name: "parent", setup: true });
  }

  /** Back to the grown-up check from the quick setup or its gate, marking it checked if `done`. */
  leaveQuickSetup(done: boolean): void {
    const profile = this.profile;
    if (done && profile && !profile.grownUpChecked) {
      profile.grownUpChecked = true;
      this.persist();
    }
    this.go({ name: "check" });
  }

  /** Leaves the grown-up check for the opening story. */
  startAdventure(): void {
    this.parentUnlocked = false;
    this.go({ name: "intro" });
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
    const profile = this.profile ?? this.createProfile("Tester", "🦦");
    profile.seenIntro = true;
    this.go({ name: "play", level });
  }

  // Progress

  /** Saves learning progress part-way through a level, so nothing is lost if the page is closed. */
  updateLearner(learner: LearnerModel): void {
    const profile = this.profile;
    if (!profile || this.playtest) return;
    profile.learner = learner.clone();
    this.persist();
  }

  complete(levelID: string, result: LevelResult, learner: LearnerModel, friendshipUses: number): RewardSummary | undefined {
    // A play-test shows what the child would earn, but keeps none of it.
    if (this.playtest) return applyResult(result, levelID, learner, cloneProfile(this.playtest.profile), { usedFriendshipPower: friendshipUses });
    const profile = this.profile;
    if (!profile) return undefined;
    const summary = applyResult(result, levelID, learner, profile, { usedFriendshipPower: friendshipUses });
    this.persist();
    return summary;
  }

  /** How much of an island's colour has returned: the share of its levels that are cleared. */
  restoration(island: Island): number {
    const profile = this.playingProfile;
    if (!profile) return 0;
    if (profile.crystals.includes(island.id)) return 1;
    return island.levels.filter((level) => starsFor(profile, level.id) > 0).length / island.levels.length;
  }
}
