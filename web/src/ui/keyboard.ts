import type { KeyboardKind } from "../game/bridge";
import { h } from "./dom";

/** Shared keys for explorers and games; native buttons also support assistive activation. */
export function keyboardRows(kind: KeyboardKind, onKey: (key: string) => void, onDelete: () => void): HTMLElement[] {
  const cap = (label: string, press: () => void, style = "", accessible = label) => {
    const key = h<"button">(`button.key${style}`, { type: "button", "aria-label": accessible, onClick: press }, label);
    // Preserve the name field's caret when tapping a key. Click still supports keyboard/AT activation.
    key.addEventListener("pointerdown", (event) => event.preventDefault());
    return key;
  };
  const letter = (character: string) => cap(character, () => onKey(character));
  const row = (...keys: HTMLElement[]) => h("div.key-row", {}, ...keys);
  const erase = () => cap("⌫", onDelete, ".coral", "Delete");
  if (kind.kind === "tray") return [row(...kind.letters.map(letter))];
  if (kind.kind === "numbers") return [row(...[..."1234567890"].map(letter), erase())];
  if (kind.kind !== "qwerty") return [];
  const rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map((letters) => row(...[...letters].map(letter)));
  if (kind.space) rows[2]!.append(cap("Space", () => onKey(" "), ".gold.wide"));
  rows[2]!.append(erase());
  return rows;
}

/** Edit at the current caret/selection, just as a physical keyboard does. */
export function editName(input: HTMLInputElement, key: string): void {
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  let from = start;
  let text = key;
  if (key === "Backspace") {
    text = "";
    if (start === end) from = start - ([...input.value.slice(0, start)].at(-1)?.length ?? 0);
  } else {
    if (input.maxLength >= 0 && input.value.length - (end - start) + text.length > input.maxLength) return;
    if (start === 0 || input.value[start - 1] === " ") text = text.toLocaleUpperCase();
  }
  input.focus({ preventScroll: true });
  input.setRangeText(text, from, end, "end");
  input.setSelectionRange(from + text.length, from + text.length);
  input.dispatchEvent(new Event("input", { bubbles: true }));
}
