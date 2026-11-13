/**
 * Turns a stream of loudness readings into "mouth open" or "mouth closed" without flicker.
 * Two thresholds stop it chattering around one level, and a minimum hold keeps each state
 * on screen long enough to read as a mouth movement.
 */
export class MouthGate {
  isOpen = false;
  private lastChange = -Infinity;

  constructor(
    public openAbove = 0.35,
    public closeBelow = 0.2,
    public minimumHold = 0.07,
  ) {}

  /** Feeds one loudness reading (0–1) taken at `time` seconds and returns the mouth state. */
  update(level: number, time: number): boolean {
    if (time - this.lastChange < this.minimumHold) return this.isOpen;
    const wanted = this.isOpen ? level > this.closeBelow : level > this.openAbove;
    if (wanted !== this.isOpen) {
      this.isOpen = wanted;
      this.lastChange = time;
    }
    return this.isOpen;
  }
}

/**
 * A made-up talking rhythm for lines that have no recording (or when sound is off),
 * so the speaker is still shown moving their mouth.
 */
export const Chatter = {
  /** How long a silent line "talks" for, from its length. */
  duration(textLength: number): number {
    return Math.min(Math.max(textLength * 0.06, 1.0), 4.0);
  },

  /**
   * Loudness (0–1) at `time` seconds into a line lasting `duration` seconds:
   * about four and a half syllables a second, with a slower swell so it is not mechanical.
   */
  level(time: number, duration: number): number {
    if (time < 0 || time >= duration) return 0;
    const syllable = Math.abs(Math.sin(Math.PI * 4.5 * time));
    const swell = 0.7 + 0.3 * Math.sin(2.3 * time + 0.6);
    const fadeOut = Math.min(1, (duration - time) / 0.15);
    return syllable * swell * fadeOut;
  },
};
