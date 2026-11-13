// Tolerant readers for save data: a missing or unreadable value becomes its default.
// This is what lets newer builds open older save files.

export type Raw = Record<string, unknown>;

export function asObject(value: unknown): Raw {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? (value as Raw) : {};
}

export function num(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

export function int(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) ? value : fallback;
}

export function bool(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function str(value: unknown, fallback: string): string {
  return typeof value === "string" ? value : fallback;
}

export function optionalStr(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

/** A list where every entry passes `check`; anything else gives the fallback. */
export function list<T>(value: unknown, check: (entry: unknown) => entry is T, fallback: T[]): T[] {
  return Array.isArray(value) && value.every(check) ? [...value] : fallback;
}

/** A dictionary whose values are each decoded with `read`. */
export function record<T>(value: unknown, read: (entry: unknown) => T): Record<string, T> {
  const result: Record<string, T> = {};
  for (const [key, entry] of Object.entries(asObject(value))) result[key] = read(entry);
  return result;
}

export const isString = (value: unknown): value is string => typeof value === "string";
export const isBoolean = (value: unknown): value is boolean => typeof value === "boolean";
export const isNumber = (value: unknown): value is number => typeof value === "number" && Number.isFinite(value);
export const isInteger = (value: unknown): value is number => typeof value === "number" && Number.isInteger(value);

/** An identifier in the same shape the iOS game writes. */
export function newID(): string {
  return crypto.randomUUID().toUpperCase();
}
