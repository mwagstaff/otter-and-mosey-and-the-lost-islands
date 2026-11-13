import { Assets, CanvasSource, ColorMatrixFilter, Sprite, Texture } from "pixi.js";
import { artURL, hasArt } from "../assets";

// Loads the painted artwork as textures, and draws the small procedural pieces
// (bubbles, panels, glows) that do not need painted art. Everything is cached.

export const palette = {
  ink: "#0E3B43", cream: "#FFF6E0", gold: "#FFC83D", coral: "#FF6B5E", teal: "#17B8A6", sky: "#3DB8FF", pink: "#FF7EB6",
};

export const rainbow = ["#FF5B5B", "#FF9F40", "#FFD93D", "#55D66B", "#3DB8FF", "#8E6BFF"];

function channels(hex: string): [number, number, number] {
  const value = parseInt(hex.replace("#", ""), 16);
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

/** A colour part of the way from one to another. */
export function mix(from: string, to: string, amount: number): string {
  const a = channels(from), b = channels(to);
  return "#" + a.map((channel, index) => Math.round(channel + (b[index]! - channel) * amount).toString(16).padStart(2, "0")).join("");
}

function alpha(hex: string, opacity: number): string {
  const [r, g, b] = channels(hex);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}

const textures = new Map<string, Texture>();

/** Fetches painted pictures so `texture` can hand them out straight away. Unknown names are skipped. */
export async function loadArt(names: Iterable<string>): Promise<void> {
  const wanted = [...new Set(names)].filter((name) => hasArt(name) && !textures.has(name));
  const loaded = await Promise.all(wanted.map((name) => Assets.load<Texture>(artURL(name))));
  wanted.forEach((name, index) => textures.set(name, loaded[index]!));
}

/** A painted picture that has already been loaded with `loadArt`. */
export function texture(name: string): Texture {
  const found = textures.get(name);
  if (!found) console.warn(`Picture ${name} was not loaded before use`);
  return found ?? Texture.EMPTY;
}

/**
 * The painted picture that stands in for an emoji, if the game has one. `key` is an emoji
 * ("⭐️" looks for `icon_2b50`) or already a picture name (`reward_hat-crown`).
 */
export function iconName(key: string): string | undefined {
  if (hasArt(key)) return key;
  const scalars = [...key].map((character) => character.codePointAt(0)!).filter((point) => point !== 0xfe0f);
  const name = "icon_" + scalars.map((point) => point.toString(16)).join("-");
  return hasArt(name) ? name : undefined;
}

/** A picture for an emoji or picture name, no bigger than `size` either way: painted art where it exists. */
export function iconSprite(key: string, size: number): Sprite {
  const name = iconName(key);
  const sprite = new Sprite(name ? texture(name) : emojiTexture(key));
  sprite.anchor.set(0.5);
  const longest = Math.max(sprite.texture.width, sprite.texture.height) || 1;
  sprite.scale.set(size / longest);
  return sprite;
}

// Procedural pieces

type Draw = (context: CanvasRenderingContext2D, width: number, height: number) => void;

function drawn(key: string, width: number, height: number, draw: Draw, resolution = 2): Texture {
  const cached = textures.get(key);
  if (cached) return cached;
  const canvas = document.createElement("canvas");
  canvas.width = Math.ceil(width * resolution);
  canvas.height = Math.ceil(height * resolution);
  const context = canvas.getContext("2d")!;
  context.scale(resolution, resolution);
  draw(context, width, height);
  const made = new Texture({ source: new CanvasSource({ resource: canvas, resolution }) });
  textures.set(key, made);
  return made;
}

function emojiTexture(emoji: string): Texture {
  return drawn(`emoji:${emoji}`, 96, 96, (context, width, height) => {
    context.font = `${width * 0.78}px system-ui, "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(emoji, width / 2, height * 0.54);
  });
}

/** A soft round glow, used for particles. */
export function glow(): Texture {
  return drawn("glow", 48, 48, (context) => {
    const gradient = context.createRadialGradient(24, 24, 0, 24, 24, 24);
    gradient.addColorStop(0.1, "rgba(255, 255, 255, 1)");
    gradient.addColorStop(1, "rgba(255, 255, 255, 0)");
    context.fillStyle = gradient;
    context.fillRect(0, 0, 48, 48);
  });
}

/** A small four-pointed sparkle. */
export function sparkle(): Texture {
  return drawn("sparkle", 40, 40, (context) => {
    context.beginPath();
    for (let index = 0; index < 8; index += 1) {
      const angle = (index * Math.PI) / 4;
      const radius = index % 2 === 0 ? 19 : 5;
      context.lineTo(20 + Math.cos(angle) * radius, 20 + Math.sin(angle) * radius);
    }
    context.closePath();
    context.fillStyle = "#fff";
    context.fill();
  });
}

export function confettiPiece(): Texture {
  return drawn("confetti", 14, 9, (context, width, height) => {
    context.fillStyle = "#fff";
    context.beginPath();
    context.roundRect(0, 0, width, height, 2);
    context.fill();
  });
}

/** A glassy bubble with a rim and a highlight. */
export function bubble(tint = "#BFF3FF"): Texture {
  return drawn(`bubble:${tint}`, 256, 256, (context) => {
    const gradient = context.createRadialGradient(128, 128, 0, 128, 128, 124);
    gradient.addColorStop(0.35, alpha(tint, 0.2));
    gradient.addColorStop(1, alpha(tint, 0.55));
    context.beginPath();
    context.ellipse(128, 128, 120, 120, 0, 0, Math.PI * 2);
    context.fillStyle = gradient;
    context.fill();
    context.strokeStyle = "rgba(255, 255, 255, 0.9)";
    context.lineWidth = 6;
    context.stroke();
    context.fillStyle = "rgba(255, 255, 255, 0.85)";
    context.beginPath();
    context.ellipse(82, 70, 26, 11, -0.6, 0, Math.PI * 2);
    context.fill();
    context.beginPath();
    context.ellipse(176, 184, 8, 8, 0, 0, Math.PI * 2);
    context.fill();
  });
}

/** A chunky rounded panel with an outline and a darker bottom edge, for signs, tiles and buttons. */
export function panel(width: number, height: number, fill: string, stroke = palette.ink, radius = 18, lineWidth = 4): Texture {
  const key = `panel:${Math.round(width)}x${Math.round(height)}:${fill}:${stroke}:${Math.round(radius)}:${lineWidth}`;
  return drawn(key, width, height, (context) => {
    const outline = () => {
      context.beginPath();
      context.roundRect(lineWidth / 2, lineWidth / 2, width - lineWidth, height - lineWidth, radius);
    };
    outline();
    context.fillStyle = fill;
    context.fill();
    context.save();
    context.clip();
    context.fillStyle = "rgba(0, 0, 0, 0.14)";
    context.fillRect(0, height * 0.82, width, height * 0.18);
    context.fillStyle = "rgba(255, 255, 255, 0.22)";
    context.fillRect(0, 0, width, height * 0.16);
    context.restore();
    outline();
    context.strokeStyle = stroke;
    context.lineWidth = lineWidth;
    context.stroke();
  });
}

export function circle(diameter: number, fill: string, stroke = "#fff", lineWidth = 5): Texture {
  return drawn(`circle:${diameter}:${fill}:${stroke}:${lineWidth}`, diameter, diameter, (context) => {
    const radius = diameter / 2 - lineWidth / 2;
    context.beginPath();
    context.arc(diameter / 2, diameter / 2, radius, 0, Math.PI * 2);
    context.fillStyle = fill;
    context.fill();
    context.strokeStyle = stroke;
    context.lineWidth = lineWidth;
    context.stroke();
  });
}

/** A rounded plank striped with the six rainbow colours. */
export function rainbowPlank(width: number, height: number): Texture {
  return drawn(`plank:${width}x${height}`, width, height, (context) => {
    context.beginPath();
    context.roundRect(1, 1, width - 2, height - 2, Math.min(12, height / 3));
    context.clip();
    const stripe = height / rainbow.length;
    rainbow.forEach((colour, index) => {
      context.fillStyle = colour;
      context.fillRect(0, index * stripe, width, stripe + 1);
    });
    context.fillStyle = "rgba(255, 255, 255, 0.25)";
    context.fillRect(0, 0, width, height * 0.18);
  });
}

/** A full rainbow arc, for bridge and island finales. Twice as wide as it is tall. */
export function rainbowArc(width = 600): Texture {
  return drawn(`arc:${width}`, width, width / 2, (context) => {
    const band = width * 0.035;
    rainbow.forEach((colour, index) => {
      context.strokeStyle = alpha(colour, 0.92);
      context.lineWidth = band + 0.5;
      context.beginPath();
      context.arc(width / 2, width / 2, width / 2 - band * (index + 0.5), Math.PI, Math.PI * 2);
      context.stroke();
    });
  });
}

/**
 * Rotates a sprite's colours round the colour wheel, so one painting can appear in several
 * colours. `turn` is a fraction of a full turn (0 = unchanged).
 */
export function tintByTurn(sprite: Sprite, turn: number): void {
  if (turn === 0) return;
  const filter = new ColorMatrixFilter();
  filter.hue(turn * 360, false);
  sprite.filters = [filter];
}

/** A small speech bubble with a tail, shown over whoever is talking. */
export function speechBubble(): Texture {
  return drawn("speechBubble", 132, 110, (context, width) => {
    const outline = () => {
      context.beginPath();
      context.roundRect(5, 5, width - 10, 78, 34);
      context.moveTo(40, 78);
      context.lineTo(34, 104);
      context.lineTo(66, 80);
      context.closePath();
    };
    context.lineJoin = "round";
    outline();
    context.strokeStyle = palette.ink;
    context.lineWidth = 9;
    context.stroke();
    outline();
    context.fillStyle = "#FFFDF3";
    context.fill();
  });
}
