import { Container, Sprite, type Texture } from "pixi.js";
import { everyFrame, run } from "./actions";

/**
 * Settings for a particle emitter, named and measured like SpriteKit's SKEmitterNode so the
 * iOS game's effects carry over: angles in radians with up as a quarter turn, speeds in
 * points a second, and a negative `yAcceleration` pulling particles down.
 */
export interface EmitterOptions {
  texture: Texture;
  /** Particles a second. */
  birthRate: number;
  /** Stop after this many particles. Leave out to keep going. */
  total?: number;
  lifetime: number;
  lifetimeRange?: number;
  /** Width and height of the area particles appear in, centred on the emitter. */
  positionRange?: { x: number; y: number };
  angle?: number;
  angleRange?: number;
  speed?: number;
  speedRange?: number;
  yAcceleration?: number;
  scale?: number;
  scaleRange?: number;
  scaleSpeed?: number;
  alpha?: number;
  alphaSpeed?: number;
  /** Opacity over a particle's life, as [time from 0 to 1, opacity] steps. Replaces `alpha`. */
  alphaSteps?: [number, number][];
  rotationRange?: number;
  rotationSpeed?: number;
  /** One colour, or several to share out between particles. */
  colours?: string[];
  additive?: boolean;
  /**
   * Put particles in this container instead of inside the emitter, so they stay where they were
   * born when the emitter moves (a trail). The emitter must sit directly inside it.
   */
  leaveIn?: Container;
}

interface Particle {
  sprite: Sprite;
  age: number;
  life: number;
  vx: number;
  vy: number;
  scale: number;
  alpha: number;
}

const spread = (range = 0) => (Math.random() - 0.5) * range;

export class Emitter extends Container {
  birthRate: number;
  positionRange: { x: number; y: number };
  private readonly particles: Particle[] = [];
  private owed = 0;
  private made = 0;

  constructor(private readonly options: EmitterOptions) {
    super();
    this.birthRate = options.birthRate;
    this.positionRange = options.positionRange ?? { x: 0, y: 0 };
    run(this, everyFrame((dt) => this.advance(dt)));
  }

  /** True once a limited emitter has sent out everything and it has all faded. */
  get isSpent(): boolean {
    return this.options.total !== undefined && this.made >= this.options.total && this.particles.length === 0;
  }

  override destroy(options?: Parameters<Container["destroy"]>[0]): void {
    // Particles left in another container would otherwise be stranded there.
    if (this.options.leaveIn) for (const particle of this.particles) particle.sprite.destroy();
    super.destroy(options);
  }

  private advance(dt: number): void {
    const options = this.options;
    this.owed += this.birthRate * dt;
    while (this.owed >= 1) {
      this.owed -= 1;
      if (options.total !== undefined && this.made >= options.total) {
        this.owed = 0;
        break;
      }
      this.spawn();
    }
    for (let index = this.particles.length - 1; index >= 0; index -= 1) {
      const particle = this.particles[index]!;
      particle.age += dt;
      if (particle.age >= particle.life) {
        particle.sprite.destroy();
        this.particles.splice(index, 1);
        continue;
      }
      particle.vy -= (options.yAcceleration ?? 0) * dt;
      particle.scale = Math.max(0, particle.scale + (options.scaleSpeed ?? 0) * dt);
      particle.alpha += (options.alphaSpeed ?? 0) * dt;
      const sprite = particle.sprite;
      sprite.x += particle.vx * dt;
      sprite.y += particle.vy * dt;
      sprite.rotation += (options.rotationSpeed ?? 0) * dt;
      sprite.scale.set(particle.scale);
      sprite.alpha = Math.min(Math.max(options.alphaSteps ? stepped(options.alphaSteps, particle.age / particle.life) : particle.alpha, 0), 1);
    }
  }

  private spawn(): void {
    const options = this.options;
    this.made += 1;
    const sprite = new Sprite(options.texture);
    sprite.anchor.set(0.5);
    sprite.position.set(spread(this.positionRange.x), spread(this.positionRange.y));
    if (options.leaveIn) {
      sprite.x += this.x;
      sprite.y += this.y;
      sprite.zIndex = this.zIndex;
    }
    sprite.rotation = spread(options.rotationRange);
    if (options.colours?.length) sprite.tint = options.colours[this.made % options.colours.length]!;
    if (options.additive) sprite.blendMode = "add";
    const angle = (options.angle ?? 0) + spread(options.angleRange);
    const speed = (options.speed ?? 0) + spread(options.speedRange);
    const particle: Particle = {
      sprite,
      age: 0,
      life: Math.max(0.05, options.lifetime + spread(options.lifetimeRange)),
      vx: Math.cos(angle) * speed,
      vy: -Math.sin(angle) * speed,
      scale: Math.max(0.01, (options.scale ?? 1) + spread(options.scaleRange)),
      alpha: options.alpha ?? 1,
    };
    sprite.scale.set(particle.scale);
    sprite.alpha = options.alphaSteps ? stepped(options.alphaSteps, 0) : particle.alpha;
    this.particles.push(particle);
    (options.leaveIn ?? this).addChild(sprite);
  }
}

function stepped(steps: [number, number][], time: number): number {
  for (let index = 1; index < steps.length; index += 1) {
    const [end, to] = steps[index]!;
    const [start, from] = steps[index - 1]!;
    if (time <= end) return from + ((to - from) * (time - start)) / Math.max(end - start, 0.0001);
  }
  return steps.at(-1)?.[1] ?? 1;
}
