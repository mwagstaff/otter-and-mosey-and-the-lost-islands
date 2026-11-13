import { asObject, bool, int, isString, list, newID, num, optionalStr, record, str } from "./decode";
import { LearnerModel } from "./learner";
import { readParentSettings, type ParentSettings } from "./session";

// Save files use the same versioned JSON shape as the iOS game.

export interface LevelRecord {
  stars: number;
  bestScore: number;
  plays: number;
}

export function newLevelRecord(): LevelRecord {
  return { stars: 0, bestScore: 0, plays: 0 };
}

export interface PlacedDecoration {
  id: string;
  reward: string;
  /** Position on the home island as fractions of its width and height. */
  x: number;
  y: number;
}

export function placeDecoration(reward: string, x: number, y: number): PlacedDecoration {
  return { id: newID(), reward, x, y };
}

/** One child's local profile. Holds a nickname and progress only: no personal details. */
export interface Profile {
  id: string;
  nickname: string;
  avatar: string;
  /** "otter" or "mosey": who leads on screen. */
  favourite: string;
  levels: Record<string, LevelRecord>;
  /** Island ids whose crystal fragment has been recovered. */
  crystals: string[];
  rewards: string[];
  equippedAccessory?: string;
  /** Achievement id to when it was earned (an ISO 8601 time without fractions of a second). */
  achievements: Record<string, string>;
  learner: LearnerModel;
  parent: ParentSettings;
  playSeconds: number;
  seenIntro: boolean;
  decorations: PlacedDecoration[];
  lastLevelID?: string;
  bestCombo: number;
  friendshipPowers: number;
}

export function newProfile(nickname: string, avatar = "🦦", favourite = "otter"): Profile {
  return readProfile({ nickname, avatar, favourite });
}

function readProfile(value: unknown): Profile {
  const raw = asObject(value);
  return {
    id: str(raw.id, "") || newID(),
    nickname: str(raw.nickname, "Explorer"),
    avatar: str(raw.avatar, "🦦"),
    favourite: str(raw.favourite, "otter"),
    levels: record(raw.levels, (entry) => {
      const level = asObject(entry);
      return { stars: int(level.stars, 0), bestScore: int(level.bestScore, 0), plays: int(level.plays, 0) };
    }),
    crystals: list(raw.crystals, isString, []),
    rewards: list(raw.rewards, isString, []),
    equippedAccessory: optionalStr(raw.equippedAccessory),
    achievements: Object.fromEntries(Object.entries(asObject(raw.achievements)).filter(([, when]) => isString(when))) as Record<string, string>,
    learner: LearnerModel.fromJSON(raw.learner),
    parent: readParentSettings(raw.parent),
    playSeconds: num(raw.playSeconds, 0),
    seenIntro: bool(raw.seenIntro, false),
    decorations: (Array.isArray(raw.decorations) ? raw.decorations : []).flatMap((entry) => {
      const placed = asObject(entry);
      if (!isString(placed.reward)) return [];
      return [{ id: str(placed.id, "") || newID(), reward: placed.reward, x: num(placed.x, 0.5), y: num(placed.y, 0.5) }];
    }),
    lastLevelID: optionalStr(raw.lastLevelID),
    bestCombo: int(raw.bestCombo, 0),
    friendshipPowers: int(raw.friendshipPowers, 0),
  };
}

export function totalStars(profile: Profile): number {
  return Object.values(profile.levels).reduce((sum, level) => sum + level.stars, 0);
}

export function starsFor(profile: Profile, levelID: string): number {
  return profile.levels[levelID]?.stars ?? 0;
}

export function hasReward(profile: Profile, reward: string): boolean {
  return profile.rewards.includes(reward);
}

/** The time now, in the form the iOS game reads and writes. */
export function timestamp(date: Date = new Date()): string {
  return date.toISOString().replace(/\.\d+Z$/, "Z");
}

/** Preferences shared by every profile on this device. */
export interface AppSettings {
  musicVolume: number;
  effectsVolume: number;
  muted: boolean;
  haptics: boolean;
  reducedMotion: boolean;
  highContrast: boolean;
  easyReadFont: boolean;
  spokenInstructions: boolean;
  /** Let the device's built-in voice read questions that have no narrator recording. */
  deviceVoice: boolean;
  /** Play the characters' recorded voices during story dialogue. */
  characterVoices: boolean;
}

export function newAppSettings(): AppSettings {
  return readAppSettings({});
}

function readAppSettings(value: unknown): AppSettings {
  const raw = asObject(value);
  return {
    musicVolume: num(raw.musicVolume, 0.5),
    effectsVolume: num(raw.effectsVolume, 0.8),
    muted: bool(raw.muted, false),
    haptics: bool(raw.haptics, true),
    reducedMotion: bool(raw.reducedMotion, false),
    highContrast: bool(raw.highContrast, false),
    easyReadFont: bool(raw.easyReadFont, false),
    spokenInstructions: bool(raw.spokenInstructions, true),
    deviceVoice: bool(raw.deviceVoice, false),
    characterVoices: bool(raw.characterVoices, true),
  };
}

/**
 * The whole save file. `version` is bumped whenever the shape changes in a way that
 * tolerant reading cannot absorb; `loadSave` upgrades older files.
 */
export interface SaveFile {
  version: number;
  profiles: Profile[];
  activeProfileID?: string;
  settings: AppSettings;
}

export const currentSaveVersion = 2;

export function newSaveFile(): SaveFile {
  return { version: currentSaveVersion, profiles: [], settings: newAppSettings() };
}

export function activeProfile(file: SaveFile): Profile | undefined {
  return file.profiles.find((profile) => profile.id === file.activeProfileID);
}

/** Thrown when a file was written by a newer version of the game than this one understands. */
export class SaveFromTheFutureError extends Error {
  constructor(readonly version: number) {
    super(`Save file version ${version} is newer than this game understands`);
  }
}

/** Reads any supported save version and upgrades it to the current shape. Throws if it cannot. */
export function loadSave(text: string): SaveFile {
  const parsed: unknown = JSON.parse(text);
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error("Save file is not an object");
  const raw = asObject(parsed);
  const version = int(raw.version, 1);
  if (version > currentSaveVersion) throw new SaveFromTheFutureError(version);
  const file: SaveFile = {
    version: currentSaveVersion,
    profiles: (Array.isArray(raw.profiles) ? raw.profiles : []).map(readProfile),
    activeProfileID: optionalStr(raw.activeProfileID),
    settings: readAppSettings(raw.settings),
  };
  // v1 allowed a save with profiles but no active one; v2 always has an active profile.
  if (version < 2 && !activeProfile(file)) file.activeProfileID = file.profiles[0]?.id;
  return file;
}

export function encodeSave(file: SaveFile): string {
  return JSON.stringify(file);
}

/** Where saves are kept: `localStorage` in the browser. */
export interface KeyValueStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

/**
 * Reads and writes the save. The previous good save is kept as a backup, so a damaged
 * or half-written one cannot destroy progress.
 */
export class SaveStore {
  constructor(
    private readonly storage: KeyValueStorage,
    readonly key = "lost-islands.save",
  ) {}

  get backupKey(): string {
    return this.key + ".backup";
  }

  private read(key: string): SaveFile | undefined {
    try {
      const text = this.storage.getItem(key);
      return text === null ? undefined : loadSave(text);
    } catch {
      return undefined;
    }
  }

  /** Loads the save, falling back to the backup, then to a fresh file. Never throws: a child should always be able to play. */
  load(): SaveFile {
    return this.read(this.key) ?? this.read(this.backupKey) ?? newSaveFile();
  }

  /** Throws if the browser refuses the write (storage full or blocked). */
  save(file: SaveFile): void {
    const existing = this.storage.getItem(this.key);
    if (existing !== null && this.read(this.key)) {
      try {
        this.storage.setItem(this.backupKey, existing);
      } catch {
        // A missing backup must not stop the real save.
      }
    }
    this.storage.setItem(this.key, encodeSave(file));
  }
}
