export type Ambient = "fireflies" | "bubbles" | "embers" | "sparkles" | "sprinkles" | "stars";

/** The look of one island: which art to use and how its ambient effects behave. */
export interface IslandTheme {
  id: string;
  collectible: string;
  collectInstruction: string;
  gateDecoration: string;
  snack: string;
  snackName: string;
  tint: string;
  ambient: Ambient;
  /** Little things that pop up as the island recovers. */
  blooms: string[];
  /** Art for the "type the answer to open it" mode: what is locked, and who comes out. */
  container: string;
  friends: string[];
  music: string;
  /** True when the heroes swim or float through this island's travel levels. */
  underwater: boolean;
  background: string;
  foreground: string;
  guardian: string;
  guardianHappy: string;
  islandArt: string;
}

const fish = ["friend_fish", "friend_fish_b", "friend_fish_c", "friend_fish_d"];

const looks: Record<string, Pick<IslandTheme, "tint" | "ambient" | "blooms" | "container" | "friends" | "underwater"> & { guardian: string }> = {
  woods: { tint: "#3FBF6B", ambient: "fireflies", blooms: ["🌸", "🌼", "🌷", "🍄", "🦋"], container: "chest", friends: fish, underwater: false, guardian: "tree" },
  bay: { tint: "#29B6E8", ambient: "bubbles", blooms: ["🐠", "🐚", "🪸", "⭐️", "🐟"], container: "chest", friends: fish, underwater: true, guardian: "octopus" },
  dragon: { tint: "#F2683C", ambient: "embers", blooms: ["🔥", "💎", "🌋", "✨", "🌺"], container: "egg", friends: ["babydragon", "babydragon_b", "babydragon_c"], underwater: false, guardian: "dragon" },
  cloud: { tint: "#8FA8FF", ambient: "sparkles", blooms: ["🌈", "☁️", "🕊️", "🌼", "🎈"], container: "chest", friends: fish, underwater: false, guardian: "wizard" },
  candy: { tint: "#FF7EB6", ambient: "sprinkles", blooms: ["🍭", "🍬", "🧁", "🍓", "🍩"], container: "jar", friends: ["friend_gummy", "friend_gummy_b", "friend_gummy_c"], underwater: false, guardian: "marshmallow" },
  star: { tint: "#9B6BFF", ambient: "stars", blooms: ["⭐️", "🌟", "🪐", "💫", "☄️"], container: "chest", friends: fish, underwater: false, guardian: "shadow" },
};

export function islandTheme(island: string): IslandTheme {
  const id = island in looks ? island : "star";
  const look = looks[id]!;
  return {
    ...look,
    ...activities[id]!,
    id,
    music: `music_${id}`,
    background: `bg_${id}`,
    foreground: `fg_${id}`,
    guardian: `guardian_${look.guardian}`,
    guardianHappy: `guardian_${look.guardian}_happy`,
    islandArt: `island_${id}`,
  };
}

const activities: Record<string, Pick<IslandTheme, "collectible" | "collectInstruction" | "gateDecoration" | "snack" | "snackName">> = {
  woods: { collectible: "🍓", collectInstruction: "Tap berries to eat them, or drag to collect!", gateDecoration: "🌸", snack: "🍓", snackName: "berries" },
  bay: { collectible: "pearl", collectInstruction: "Tap pearls to pop them, or drag to collect!", gateDecoration: "🐚", snack: "fish_biscuits", snackName: "fish biscuits" },
  dragon: { collectible: "💎", collectInstruction: "Tap gems to pop them, or drag to collect!", gateDecoration: "💎", snack: "cookie", snackName: "warm cookies" },
  cloud: { collectible: "☁️", collectInstruction: "Tap clouds to pop them, or drag to collect!", gateDecoration: "🌈", snack: "🧁", snackName: "cloud cakes" },
  candy: { collectible: "🍬", collectInstruction: "Tap candies to eat them, or drag to collect!", gateDecoration: "🍬", snack: "🍬", snackName: "candies" },
  star: { collectible: "⭐️", collectInstruction: "Tap stars to pop them, or drag to collect!", gateDecoration: "⭐️", snack: "star_cookie", snackName: "star cookies" },
};
