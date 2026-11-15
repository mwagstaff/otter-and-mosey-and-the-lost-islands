/** The case shown by custom letter keys, matching the native game's rules. */
export function capitalizesName(prefix: string): boolean {
  return prefix.length === 0 || /[\s-]$/u.test(prefix);
}

/** Follow the target rather than capitalizing lowercase spelling/missing-letter answers. */
export function capitalizesTarget(text: string, index: number): boolean {
  const letter = [...text][index];
  return letter !== undefined && letter !== letter.toLowerCase() && letter === letter.toUpperCase();
}
