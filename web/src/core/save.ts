import { asObject, bool, int, isInteger, isString, list, newID, num, optionalStr, record, str } from "./decode";
import { LearnerModel } from "./learner";
import { readParentSettings, type ParentSettings } from "./session";

// Save files use the same versioned JSON shape as the iOS game.

export interface LevelRecord {
  stars: number;
  bestScore: number;
  plays: number;
  /** Finished at least once with every answer right first time. */
  flawless: boolean;
}

export function newLevelRecord(): LevelRecord {
  return { stars: 0, bestScore: 0, plays: 0, flawless: false };
}

/** Lifetime counts kept for the trophy cabinet that the rest of the save does not already hold. */
export interface PlayerStats {
  /** Pearls scooped in Maths Splash. */
  pearls: number;
  /** Different calendar days on which a level was finished. */
  playDays: number;
  lastPlayDay?: string;
  /** Weekdays (1 = Sunday … 7 = Saturday, as on iOS) on which a level has been finished at a weekend. */
  weekendDays: number[];
  /** Accessory ids the player has tried on. */
  hatsWorn: string[];
  /** Levels finished in a row while wearing a hat. */
  hatStreak: number;
  /** Right-first-time answers per times table, keyed by the table ("3"). */
  tableFirstTry: Record<string, number>;
  /** The day trophies were last won, and the islands they were won on that day. */
  trophyDay?: string;
  trophyDayIslands: string[];
}

function readPlayerStats(value: unknown): PlayerStats {
  const raw = asObject(value);
  return {
    pearls: int(raw.pearls, 0),
    playDays: int(raw.playDays, 0),
    lastPlayDay: optionalStr(raw.lastPlayDay),
    weekendDays: list(raw.weekendDays, isInteger, []),
    hatsWorn: list(raw.hatsWorn, isString, []),
    hatStreak: int(raw.hatStreak, 0),
    tableFirstTry: record(raw.tableFirstTry, (entry) => int(entry, 0)),
    trophyDay: optionalStr(raw.trophyDay),
    trophyDayIslands: list(raw.trophyDayIslands, isString, []),
  };
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
  levels: Record<string, LevelRecord>;
  /** Island ids whose crystal fragment has been recovered. */
  crystals: string[];
  rewards: string[];
  equippedAccessory?: string;
  /** Trophy id to when it went into the cabinet (an ISO 8601 time without fractions of a second). */
  achievements: Record<string, string>;
  /** Trophies won but not yet handed out, because a level hands out only a couple at a time. */
  pendingTrophies: string[];
  /** Set once older stickers have been moved into the trophy cabinet. */
  trophiesReady: boolean;
  /** How many trophies the player had when they last opened the cabinet, for the "New!" tag. */
  trophiesSeen: number;
  stats: PlayerStats;
  learner: LearnerModel;
  parent: ParentSettings;
  playSeconds: number;
  /** Seconds played per local calendar day, keyed `yyyy-MM-dd`. Only recent days are kept. */
  dailyPlaySeconds: Record<string, number>;
  seenIntro: boolean;
  decorations: PlacedDecoration[];
  lastLevelID?: string;
  bestCombo: number;
  friendshipPowers: number;
}

export function newProfile(nickname: string, avatar = "🦦"): Profile {
  return readProfile({ nickname, avatar });
}

function readProfile(value: unknown): Profile {
  const raw = asObject(value);
  return {
    id: str(raw.id, "") || newID(),
    nickname: str(raw.nickname, "Explorer"),
    avatar: str(raw.avatar, "🦦"),
    levels: record(raw.levels, (entry) => {
      const level = asObject(entry);
      return { stars: int(level.stars, 0), bestScore: int(level.bestScore, 0), plays: int(level.plays, 0), flawless: bool(level.flawless, false) };
    }),
    crystals: list(raw.crystals, isString, []),
    rewards: list(raw.rewards, isString, []),
    equippedAccessory: optionalStr(raw.equippedAccessory),
    achievements: Object.fromEntries(Object.entries(asObject(raw.achievements)).filter(([, when]) => isString(when))) as Record<string, string>,
    pendingTrophies: list(raw.pendingTrophies, isString, []),
    trophiesReady: bool(raw.trophiesReady, false),
    trophiesSeen: int(raw.trophiesSeen, 0),
    stats: readPlayerStats(raw.stats),
    learner: LearnerModel.fromJSON(raw.learner),
    parent: readParentSettings(raw.parent),
    playSeconds: num(raw.playSeconds, 0),
    dailyPlaySeconds: record(raw.dailyPlaySeconds, (entry) => num(entry, 0)),
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

/** An independent copy of a profile, for play that must not change the saved one. */
export function cloneProfile(profile: Profile): Profile {
  return readProfile(JSON.parse(JSON.stringify(profile)));
}

/** How many days of daily playtime are kept. */
export const playHistoryDays = 35;

/** `yyyy-MM-dd` for the local calendar day containing `date`. */
export function dayKey(date: Date): string {
  const pad = (value: number, length = 2) => String(value).padStart(length, "0");
  return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function daysBefore(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() - days, 12);
}

/** Adds playtime to the running total and to the day it was played. */
export function addPlaytime(profile: Profile, seconds: number, date: Date = new Date()): void {
  profile.playSeconds += seconds;
  const today = dayKey(date);
  profile.dailyPlaySeconds[today] = (profile.dailyPlaySeconds[today] ?? 0) + seconds;
  const keys = Object.keys(profile.dailyPlaySeconds);
  if (keys.length <= playHistoryDays) return;
  // Keys sort as dates, so anything before the cutoff key is older.
  const oldest = dayKey(daysBefore(date, playHistoryDays - 1));
  for (const key of keys) if (key < oldest) delete profile.dailyPlaySeconds[key];
}

/** Seconds played over the `days` calendar days ending with the day containing `date`. One day means just that day. */
export function playSecondsOver(profile: Profile, days: number, date: Date = new Date()): number {
  let total = 0;
  for (let offset = 0; offset < days; offset += 1) total += profile.dailyPlaySeconds[dayKey(daysBefore(date, offset))] ?? 0;
  return total;
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

/** Puts on an accessory, or takes it off with undefined, remembering every hat ever tried. */
export function wear(profile: Profile, accessory: string | undefined): void {
  profile.equippedAccessory = accessory;
  if (accessory !== undefined && !profile.stats.hatsWorn.includes(accessory)) profile.stats.hatsWorn.push(accessory);
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
