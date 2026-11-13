const MASK = (1n << 64n) - 1n;
const GOLDEN = 0x9e3779b97f4a7c15n;

/** Anything that can hand out random numbers. `next` returns a value in [0, 1). */
export interface Rng {
  next(): number;
}

/**
 * Deterministic generator (SplitMix64, the same mixing as the Swift game) so question
 * generation can be tested and replayed. The same seed always gives the same questions here,
 * though not the same ones as the iOS game, which draws its numbers from the stream differently.
 */
export class SeededGenerator implements Rng {
  private state: bigint;

  constructor(seed: number | bigint = randomSeed()) {
    this.state = (BigInt(seed) + GOLDEN) & MASK;
  }

  nextUInt64(): bigint {
    this.state = (this.state + GOLDEN) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  }

  next(): number {
    return Number(this.nextUInt64() >> 11n) / 2 ** 53;
  }
}

export function randomSeed(): bigint {
  return BigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER));
}

/** A whole number from `low` to `high`, both included. */
export function randomInt(rng: Rng, low: number, high: number): number {
  return low + Math.floor(rng.next() * (high - low + 1));
}

export function randomBool(rng: Rng): boolean {
  return rng.next() < 0.5;
}

export function pick<T>(rng: Rng, list: readonly T[]): T {
  if (list.length === 0) throw new Error("Cannot pick from an empty list");
  return list[randomInt(rng, 0, list.length - 1)]!;
}

/** A shuffled copy; the original is left alone. */
export function shuffled<T>(rng: Rng, list: readonly T[]): T[] {
  const copy = [...list];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const other = randomInt(rng, 0, index);
    [copy[index], copy[other]] = [copy[other]!, copy[index]!];
  }
  return copy;
}
