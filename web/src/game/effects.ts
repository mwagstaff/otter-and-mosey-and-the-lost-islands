import { Container } from "pixi.js";
import { call, easeInOut, fadeOut, group, moveBy, remove, repeatForever, rotateTo, run, scaleTo, sequence, wait } from "../engine/actions";
import { bubble, confettiPiece, glow, iconSprite, rainbow, sparkle } from "../engine/art";
import { GameLabel } from "../engine/label";
import { Emitter, type EmitterOptions } from "../engine/particles";
import { options } from "./options";
import type { Ambient } from "./theme";

// Particle effects built in code so they can follow the reduced-motion setting.

const scaled = (count: number) => (options.reducedMotion ? Math.max(4, Math.floor(count / 4)) : count);

/** A one-shot burst of sparkles. Removes itself. */
export function burst(parent: Container, x: number, y: number, colour: string, count = 28, z = 60): void {
  const emitter = new Emitter({
    texture: sparkle(), total: scaled(count), birthRate: 600, lifetime: 0.7, lifetimeRange: 0.4,
    angleRange: Math.PI * 2, speed: 190, speedRange: 120, yAcceleration: -260,
    scale: 0.5, scaleRange: 0.35, scaleSpeed: -0.4, alphaSpeed: -1.1,
    rotationRange: Math.PI, rotationSpeed: 3, colours: [colour], additive: true,
  });
  emitter.position.set(x, y);
  emitter.zIndex = z;
  parent.addChild(emitter);
  run(emitter, sequence(wait(1.6), remove()));
}

/** A burst in every rainbow colour. */
export function rainbowBurst(parent: Container, x: number, y: number, count = 60): void {
  for (const colour of rainbow) burst(parent, x, y, colour, Math.floor(count / rainbow.length));
}

/** Confetti falling across the whole scene for a few seconds. */
export function confetti(parent: Container, width: number, height: number, duration = 3): void {
  if (options.reducedMotion) {
    rainbowBurst(parent, width / 2, height * 0.4);
    return;
  }
  for (const colour of rainbow) {
    const emitter = new Emitter({
      texture: confettiPiece(), birthRate: 14, lifetime: 4, positionRange: { x: width, y: 0 },
      angle: -Math.PI / 2, angleRange: 0.5, speed: 150, speedRange: 80, yAcceleration: -60,
      rotationRange: Math.PI * 2, rotationSpeed: 4, scale: 1, scaleRange: 0.5, colours: [colour],
    });
    emitter.position.set(width / 2, -10);
    emitter.zIndex = 90;
    parent.addChild(emitter);
    run(emitter, sequence(wait(duration), call(() => { emitter.birthRate = 0; }), wait(4.2), remove()));
  }
}

/** Slow drifting motes that make a scene feel alive. Set `birthRate` from how restored the island is. */
export function ambient(kind: Ambient, width: number, height: number): Emitter {
  const base: EmitterOptions = {
    texture: glow(), birthRate: 0.6, positionRange: { x: width, y: height }, lifetime: 5, lifetimeRange: 2,
    alphaSteps: [[0, 0], [0.2, 0.9], [0.7, 0.9], [1, 0]],
    scale: 0.22, scaleRange: 0.14, speed: 14, speedRange: 10, angleRange: Math.PI * 2, additive: true,
  };
  const up = { angle: Math.PI / 2 };
  const variants: Record<Ambient, Partial<EmitterOptions>> = {
    fireflies: { colours: ["#F6FF8A"] },
    bubbles: { texture: bubble(), additive: false, scale: 0.07, scaleRange: 0.05, ...up, angleRange: 0.3, speed: 34 },
    embers: { colours: ["#FF9A3D"], ...up, angleRange: 0.6, speed: 30, scale: 0.14 },
    sparkles: { texture: sparkle(), scale: 0.3 },
    sprinkles: { texture: confettiPiece(), colours: rainbow, additive: false, scale: 0.7, angle: -Math.PI / 2, speed: 26, rotationSpeed: 2 },
    stars: { texture: sparkle(), colours: ["#DCCBFF"], scale: 0.26 },
  };
  const emitter = new Emitter({ ...base, ...variants[kind] });
  emitter.position.set(width / 2, height / 2);
  emitter.zIndex = 4;
  return emitter;
}

/** A trailing stream behind something fast. Particles are left behind in `world`; set `birthRate` to switch it on. */
export function trail(world: Container, overrides: Partial<EmitterOptions> = {}): Emitter {
  return new Emitter({
    texture: glow(), birthRate: 0, lifetime: 0.6, angle: Math.PI, angleRange: 0.35, speed: 160, speedRange: 60,
    scale: 0.5, scaleSpeed: -0.6, alphaSpeed: -1.4, colours: rainbow, additive: true, leaveIn: world, ...overrides,
  });
}

/** A picture that pops up, drifts upward and fades, for big reactions. */
export function floatPicture(parent: Container, emoji: string, x: number, y: number, size: number): void {
  const holder = new Container();
  holder.addChild(iconSprite(emoji, size));
  holder.position.set(x, y);
  holder.zIndex = 80;
  holder.scale.set(0.3);
  parent.addChild(holder);
  run(holder, sequence(
    group(sequence(scaleTo(1.15, 0.2), scaleTo(1, 0.12)), moveBy(0, -54, 1.3), sequence(wait(0.9), fadeOut(0.4))),
    remove(),
  ));
}

/** Text that floats up and fades, for points and praise. */
export function floatText(parent: Container, text: string, x: number, y: number, colour = "#ffffff", size = 26): void {
  const label = new GameLabel(text, size, colour);
  label.style.stroke = { color: "#0E3B43", width: 4, join: "round" };
  label.position.set(x, y);
  label.zIndex = 80;
  label.scale.set(0.4);
  parent.addChild(label);
  run(label, sequence(group(scaleTo(1, 0.18), moveBy(0, -46, 0.9), sequence(wait(0.55), fadeOut(0.35))), remove()));
}

/** Something small popping up out of the ground with a bounce. */
export function bloom(parent: Container, emoji: string, x: number, y: number, size: number, z = 6): Container {
  const sprite = iconSprite(emoji, size);
  const full = sprite.scale.x;
  sprite.anchor.set(0.5, 0.9);
  sprite.position.set(x, y);
  sprite.zIndex = z;
  sprite.scale.set(0);
  parent.addChild(sprite);
  run(sprite, sequence(scaleTo(full * 1.25, 0.22), scaleTo(full, 0.14)));
  if (!options.reducedMotion) run(sprite, repeatForever(sequence(rotateTo(0.08, 1.4, easeInOut), rotateTo(-0.08, 1.4, easeInOut))));
  return sprite;
}
