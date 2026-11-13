import { Text } from "pixi.js";
import { options } from "../game/options";

/** The game typeface: the system's rounded face where there is one, otherwise the bundled Nunito. */
export const gameFont = 'ui-rounded, "SF Pro Rounded", "Nunito Variable", "Arial Rounded MT Bold", system-ui, sans-serif';
/** Verdana's open letter shapes and wide spacing are a common recommendation for dyslexic readers. */
export const easyReadFont = "Verdana, Geneva, sans-serif";

/** Scene text in the game typeface. Change `text` or `colour` at any time. */
export class GameLabel extends Text {
  private widest?: number;

  constructor(text: string, size: number, colour = "#ffffff", settings: { tracking?: number; maxWidth?: number; fitWidth?: number } = {}) {
    const easy = options.settings.easyReadFont;
    super({
      text,
      style: {
        fontFamily: easy ? easyReadFont : gameFont,
        fontSize: easy ? size * 0.92 : size,
        fontWeight: easy ? "700" : "800",
        fill: colour,
        letterSpacing: settings.tracking ?? (easy ? 1.6 : 0.3),
        align: "center",
        wordWrap: settings.maxWidth !== undefined,
        wordWrapWidth: settings.maxWidth,
      },
    });
    this.anchor.set(0.5);
    this.fitWidth = settings.fitWidth;
  }

  set colour(colour: string) {
    this.style.fill = colour;
  }

  /** When set, the label shrinks so its text never spills past this width. */
  set fitWidth(width: number | undefined) {
    this.widest = width;
    this.refit();
  }

  set string(text: string) {
    if (text === this.text) return;
    this.text = text;
    this.refit();
  }

  private refit(): void {
    if (this.widest === undefined) return;
    this.scale.set(1);
    const width = this.width;
    this.scale.set(width > this.widest && width > 0 ? this.widest / width : 1);
  }
}
