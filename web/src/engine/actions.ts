import type { Container } from "pixi.js";

// Small, composable animations in the style of SpriteKit's SKAction: build one with the
// functions below, then `run` it on a node. `tick` advances everything that is running.

export type Ease = (t: number) => number;
export const linear: Ease = (t) => t;
export const easeIn: Ease = (t) => t * t;
export const easeOut: Ease = (t) => 1 - (1 - t) * (1 - t);
export const easeInOut: Ease = (t) => t * t * (3 - 2 * t);

/** Returns the time left over once finished, or -1 while still running. */
interface Runner {
  step(dt: number): number;
}

export type Action = (target: Container) => Runner;

/** An action that takes time. `setup` runs when it starts and returns how to apply progress. */
function interval(duration: number, ease: Ease, setup: (target: Container) => (progress: number, change: number) => void): Action {
  return (target) => {
    let apply: ((progress: number, change: number) => void) | undefined;
    let elapsed = 0;
    let last = 0;
    return {
      step(dt) {
        apply ??= setup(target);
        elapsed += dt;
        const t = duration <= 0 ? 1 : Math.min(elapsed / duration, 1);
        const progress = ease(t);
        apply(progress, progress - last);
        last = progress;
        return t >= 1 ? Math.max(elapsed - duration, 0) : -1;
      },
    };
  };
}

const instant = (body: (target: Container) => void): Action => (target) => ({
  step(dt) {
    body(target);
    return dt;
  },
});

export function moveBy(dx: number, dy: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => (_, change) => {
    target.x += dx * change;
    target.y += dy * change;
  });
}

export function moveTo(x: number, y: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => {
    const fromX = target.x, fromY = target.y;
    return (progress) => target.position.set(fromX + (x - fromX) * progress, fromY + (y - fromY) * progress);
  });
}

export function scaleToXY(x: number, y: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => {
    const fromX = target.scale.x, fromY = target.scale.y;
    return (progress) => target.scale.set(fromX + (x - fromX) * progress, fromY + (y - fromY) * progress);
  });
}

export const scaleTo = (scale: number, duration: number, ease: Ease = linear) => scaleToXY(scale, scale, duration, ease);

export function fadeTo(alpha: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => {
    const from = target.alpha;
    return (progress) => { target.alpha = from + (alpha - from) * progress; };
  });
}

export const fadeOut = (duration: number) => fadeTo(0, duration);
export const fadeIn = (duration: number) => fadeTo(1, duration);

export function rotateTo(angle: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => {
    const from = target.rotation;
    return (progress) => { target.rotation = from + (angle - from) * progress; };
  });
}

export function rotateBy(angle: number, duration: number, ease: Ease = linear): Action {
  return interval(duration, ease, (target) => (_, change) => { target.rotation += angle * change; });
}

/** Waits for `duration` seconds, give or take half of `range`. */
export function wait(duration: number, range = 0): Action {
  return (target) => interval(Math.max(0, duration + (Math.random() - 0.5) * range), linear, () => () => {})(target);
}

export const call = (body: () => void): Action => instant(body);

/** Takes the node off the screen for good. */
export const remove = (): Action => instant((target) => target.destroy({ children: true }));

/** Calls `body` every frame with the seconds since the last one, for as long as the node lives. */
export const everyFrame = (body: (dt: number) => void): Action => () => ({
  step(dt) {
    body(dt);
    return -1;
  },
});

export function sequence(...actions: Action[]): Action {
  return (target) => {
    let index = 0;
    let current = actions[0]?.(target);
    return {
      step(dt) {
        let time = dt;
        while (current) {
          const left = current.step(time);
          if (left < 0 || target.destroyed) return target.destroyed ? 0 : -1;
          index += 1;
          current = actions[index]?.(target);
          time = left;
        }
        return time;
      },
    };
  };
}

export function group(...actions: Action[]): Action {
  return (target) => {
    const runners: (Runner | undefined)[] = actions.map((action) => action(target));
    return {
      step(dt) {
        let left = dt;
        let running = false;
        runners.forEach((runner, index) => {
          if (!runner) return;
          const result = runner.step(dt);
          if (result < 0) running = true;
          else {
            runners[index] = undefined;
            left = Math.min(left, result);
          }
        });
        return running ? -1 : left;
      },
    };
  };
}

/** Runs an action a set number of times, one after another. */
export function repeat(action: Action, count: number): Action {
  return sequence(...Array.from({ length: count }, () => action));
}

export function repeatForever(action: Action): Action {
  return (target) => {
    let current = action(target);
    return {
      step(dt) {
        let time = dt;
        // A few rounds at most per frame, so an action with no length cannot spin for ever.
        for (let round = 0; round < 4; round += 1) {
          const left = current.step(time);
          if (left < 0) break;
          current = action(target);
          time = left;
          if (time <= 0) break;
        }
        return -1;
      },
    };
  };
}

/** A quick left-right shake that says "not quite" without being harsh. */
export function wobble(distance = 8): Action {
  return sequence(moveBy(-distance, 0, 0.05), moveBy(distance * 2, 0, 0.09), moveBy(-distance * 2, 0, 0.09), moveBy(distance, 0, 0.05));
}

export function pop(scale = 1): Action {
  return sequence(scaleTo(scale * 1.18, 0.12), scaleTo(scale, 0.1));
}

// Running actions

const running = new Map<Container, Map<string, Runner>>();
let unnamed = 0;

/** Starts an action on a node. Giving it a key replaces any action already running under that key. */
export function run(target: Container, action: Action, key?: string): void {
  let actions = running.get(target);
  if (!actions) running.set(target, (actions = new Map()));
  actions.set(key ?? `#${(unnamed += 1)}`, action(target));
}

export function stop(target: Container, key: string): void {
  running.get(target)?.delete(key);
}

export function stopAll(target: Container): void {
  running.delete(target);
}

export function isRunning(target: Container, key: string): boolean {
  return running.get(target)?.has(key) ?? false;
}

/** Advances every running action by `dt` seconds. */
export function tick(dt: number): void {
  for (const [target, actions] of [...running]) {
    if (target.destroyed) {
      running.delete(target);
      continue;
    }
    for (const [key, runner] of [...actions]) {
      if (actions.get(key) !== runner) continue;
      const left = runner.step(dt);
      if (target.destroyed) break;
      if (left >= 0 && actions.get(key) === runner) actions.delete(key);
    }
    if (target.destroyed || actions.size === 0) {
      if (running.get(target) === actions) running.delete(target);
    }
  }
}

/** Forgets everything, when a scene is thrown away. */
export function clearActions(): void {
  running.clear();
}
