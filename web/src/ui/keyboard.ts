import type { KeyboardKind } from "../game/bridge";
import { capitalizesName } from "../core/keyboardCase";
import { h } from "./dom";

/** Shared keys for explorers and games; native buttons also support assistive activation. */
export function keyboardRows(kind: KeyboardKind, onKey: (key: string) => void, onDelete: () => void, uppercase = false): HTMLElement[] {
  const cap = (label: string, press: () => void, style = "", accessible = label) => {
    const key = h<"button">(`button.key${style}`, { type: "button", "aria-label": accessible, onClick: press }, label);
    // Preserve the name field's caret when tapping a key. Click still supports keyboard/AT activation.
    key.addEventListener("pointerdown", (event) => event.preventDefault());
    return key;
  };
  const letter = (character: string) => {
    const label = uppercase ? character.toUpperCase() : character.toLowerCase();
    const key = cap(label, () => onKey(key.textContent ?? label));
    if (/^\p{L}$/u.test(character)) key.dataset.letter = character;
    return key;
  };
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

/** Keep the same buttons (and keyboard focus) when their letter case changes. */
export function setKeyboardUppercase(root: HTMLElement, uppercase: boolean): void {
  for (const key of root.querySelectorAll<HTMLButtonElement>("[data-letter]")) {
    const letter = key.dataset.letter!;
    const label = uppercase ? letter.toUpperCase() : letter.toLowerCase();
    if (key.textContent === label) continue;
    key.textContent = label;
    key.setAttribute("aria-label", label);
  }
}

/** Physical input, deletion and moving the caret all update the visible name keys. */
export function bindNameKeyboard(input: HTMLInputElement, keyboard: HTMLElement): void {
  const refresh = () => setKeyboardUppercase(keyboard, capitalizesName(input.value.slice(0, input.selectionStart ?? input.value.length)));
  for (const event of ["input", "keyup", "click", "select", "selectionchange"]) input.addEventListener(event, refresh);
  refresh();
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
    text = capitalizesName(input.value.slice(0, start)) ? text.toUpperCase() : text.toLowerCase();
  }
  input.focus({ preventScroll: true });
  input.setRangeText(text, from, end, "end");
  input.setSelectionRange(from + text.length, from + text.length);
  input.dispatchEvent(new Event("input", { bubbles: true }));
}
