import type { Skill } from "./skill";

export const allGameModes = ["wordBlaster", "mathsSplash", "bridgeBuilder", "eggRescue", "typingTurbo", "guardian"] as const;
export type GameMode = (typeof allGameModes)[number];

export const gameModeTitles: Record<GameMode, string> = {
  wordBlaster: "Word Blaster",
  mathsSplash: "Maths Splash",
  bridgeBuilder: "Rainbow Bridge",
  eggRescue: "Number Rescue",
  typingTurbo: "Typing Turbo",
  guardian: "Guardian",
};

export type Speaker = "otter" | "mosey" | "guardian" | "narrator";

/** One line of dialogue. Stored in JSON as `"o:Hello!"` (o, m, g or n). */
export interface DialogueLine {
  speaker: Speaker;
  text: string;
}

const prefixes: Record<Speaker, string> = { otter: "o", mosey: "m", guardian: "g", narrator: "n" };

export function parseDialogueLine(raw: string): DialogueLine {
  const colon = raw.indexOf(":");
  if (colon < 0) throw new Error(`Dialogue needs a speaker prefix: ${raw}`);
  const prefix = raw.slice(0, colon);
  const speaker: Speaker = prefix === "o" ? "otter" : prefix === "m" ? "mosey" : prefix === "g" ? "guardian" : "narrator";
  return { speaker, text: raw.slice(colon + 1) };
}

/**
 * The recorded clip for a line. Every speaker is voiced; story lines are read by the question
 * narrator. The key is a 32-bit FNV-1a hash of "speaker:text", matching tools/build_content.py.
 */
export function dialogueAudioKey(line: DialogueLine): string {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(`${prefixes[line.speaker]}:${line.text}`)) {
    hash = Math.imul(hash ^ byte, 0x01000193) >>> 0;
  }
  return "line_" + hash.toString(16).padStart(8, "0");
}

export interface LevelDef {
  id: string;
  title: string;
  mode: GameMode;
  skills: Skill[];
  /** How many questions the level asks. */
  count: number;
  intro: DialogueLine[];
  outro: DialogueLine[];
  /** Reward id granted the first time the level is cleared. */
  reward?: string;
  blurb: string;
}

export interface GuardianDef {
  name: string;
  kind: string;
  /** What the guardian says at the start of each phase. */
  phases: DialogueLine[];
  befriended: DialogueLine[];
}

export interface Island {
  id: string;
  name: string;
  tagline: string;
  focus: string;
  /** Hex colour of this island's crystal fragment, e.g. `#3FBF6B`. */
  colour: string;
  guardian: GuardianDef;
  levels: LevelDef[];
}

export type RewardKind = "pet" | "accessory" | "decoration";

export interface Reward {
  id: string;
  kind: RewardKind;
  name: string;
  emoji: string;
}

/** Every voiced dialogue line: clip key to speaker, scene and text. */
export interface VoicedLine {
  speaker: string;
  scene: string;
  text: string;
  /** Set to "befriended" for a guardian's lines after it has been won over. */
  mood?: string;
}

/** The shape of islands.json, where dialogue is still `"o:Hello!"` strings. */
export interface RawCatalog {
  islands: {
    id: string;
    name: string;
    tagline: string;
    focus: string;
    colour: string;
    guardian: { name: string; kind: string; phases: string[]; befriended: string[] };
    levels: {
      id: string;
      title: string;
      mode: string;
      skills: string[];
      count: number;
      intro: string[];
      outro: string[];
      reward?: string | null;
      blurb: string;
    }[];
  }[];
  rewards: { id: string; kind: string; name: string; emoji: string }[];
  intro: string[];
  introAfter: string[];
  askGrownUp: string[];
}

/** Decorations everyone starts with or earns from star totals. */
export const starDecorations: readonly { stars: number; reward: string }[] = [
  { stars: 0, reward: "deco-palm" },
  { stars: 6, reward: "deco-flowers" },
  { stars: 20, reward: "deco-castle" },
  { stars: 45, reward: "deco-tent" },
];

/** All bundled level definitions and story text. */
export class Catalog {
  readonly islands: Island[];
  readonly rewards: Reward[];
  readonly intro: DialogueLine[];
  readonly introAfter: DialogueLine[];
  /** Kind suggestions from Otter or Mosey to fetch a grown-up when a child keeps getting stuck. */
  readonly askGrownUp: DialogueLine[];

  constructor(raw: RawCatalog) {
    const lines = (list: string[]) => list.map(parseDialogueLine);
    this.islands = raw.islands.map((island) => ({
      ...island,
      guardian: { ...island.guardian, phases: lines(island.guardian.phases), befriended: lines(island.guardian.befriended) },
      levels: island.levels.map((level) => ({
        ...level,
        mode: level.mode as GameMode,
        skills: level.skills as Skill[],
        intro: lines(level.intro),
        outro: lines(level.outro),
        reward: level.reward ?? undefined,
      })),
    }));
    this.rewards = raw.rewards.map((reward) => ({ ...reward, kind: reward.kind as RewardKind }));
    this.intro = lines(raw.intro);
    this.introAfter = lines(raw.introAfter);
    this.askGrownUp = lines(raw.askGrownUp ?? []);
  }

  get allLevels(): LevelDef[] {
    return this.islands.flatMap((island) => island.levels);
  }

  level(id: string): LevelDef | undefined {
    return this.allLevels.find((level) => level.id === id);
  }

  island(id: string): Island | undefined {
    return this.islands.find((island) => island.id === id);
  }

  islandContaining(levelID: string): Island | undefined {
    return this.islands.find((island) => island.levels.some((level) => level.id === levelID));
  }

  reward(id: string): Reward | undefined {
    return this.rewards.find((reward) => reward.id === id);
  }

  /** The level that follows `levelID` on the same island, if any. */
  nextLevel(levelID: string): LevelDef | undefined {
    const island = this.islandContaining(levelID);
    const index = island?.levels.findIndex((level) => level.id === levelID) ?? -1;
    return index < 0 ? undefined : island!.levels[index + 1];
  }
}
