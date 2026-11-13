import type { DialogueLine } from "../core";
import { audio, narrator } from "../game/audio";
import { button, h, symbol } from "./dom";

export interface DialogueOptions {
  /** The name shown when the island's guardian speaks. */
  guardianName?: string;
  /** Set when a level's HUD is on screen, so Skip sits under it instead of over its buttons. */
  belowHUD?: boolean;
  /** Whether to play the characters' recorded voices. */
  voiced: boolean;
  /** Called as each line appears, with its position. */
  onLine?: (index: number) => void;
  done: () => void;
}

/** Room to leave at the bottom of a scene so its ground shows above the speech panel. */
export const dialogueHeight = (compact: boolean) => (compact ? 124 : 190);

/**
 * Speech panels for story moments, shown in `overlay`. Tap anywhere (or press Enter) to move
 * on; Skip jumps to the end.
 */
export function showDialogue(overlay: HTMLElement, lines: DialogueLine[], options: DialogueOptions): void {
  let index = 0;
  const who = h("span.speaker");
  const words = h("p.line");
  const names = { otter: "Otter", mosey: "Mosey", guardian: options.guardianName ?? "Guardian", narrator: "Story" };
  const show = () => {
    const line = lines[index]!;
    who.textContent = names[line.speaker];
    who.dataset.speaker = line.speaker;
    words.textContent = line.text;
    options.onLine?.(index);
    audio.play("nav", 0.6);
    // The mouth and speech badge move for every speaker, recorded or not.
    narrator.speakLine(line, options.voiced);
  };
  const end = () => {
    narrator.stop();
    overlay.replaceChildren();
    delete overlay.dataset.kind;
    options.done();
  };
  const advance = () => {
    index += 1;
    if (index < lines.length) show();
    else end();
  };
  if (lines.length === 0) return end();
  const panel = h("button.dialogue.panel", { type: "button" }, who, words, h("span.continue", {}, "Tap to continue", symbol("play")));
  const skip = button(`cream.skip${options.belowHUD ? ".below-hud" : ""}`, ["Skip", symbol("skip")], end);
  skip.addEventListener("click", (event) => event.stopPropagation());
  overlay.dataset.kind = "dialogue";
  overlay.replaceChildren(h("div.dialogue-layer", { onClick: advance }, skip, panel));
  panel.focus();
  show();
}
