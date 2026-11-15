// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest";
import { bindNameKeyboard, editName, keyboardRows, setKeyboardUppercase } from "../src/ui/keyboard";
import { capitalizesName, capitalizesTarget } from "../src/core/keyboardCase";

function nameField(value = "") {
  const input = document.createElement("input");
  input.maxLength = 12;
  input.value = value;
  input.setSelectionRange(value.length, value.length);
  return input;
}

describe("explorer name keyboard", () => {
  it("updates labels and inserted letters after typing, spaces, hyphens, deletion and caret changes", () => {
    const input = nameField();
    const keyboard = document.createElement("div");
    keyboard.append(...keyboardRows({ kind: "qwerty", space: true }, key => editName(input, key), () => editName(input, "Backspace")));
    document.body.append(input, keyboard);
    bindNameKeyboard(input, keyboard);
    const n = keyboard.querySelector<HTMLButtonElement>('[data-letter="n"]')!;
    expect(n.textContent).toBe("N");
    n.click();
    expect(input.value).toBe("N");
    expect(n.textContent).toBe("n");
    editName(input, "-");
    expect(n.textContent).toBe("N");
    n.click();
    expect(input.value).toBe("N-N");
    editName(input, "Backspace");
    expect(n.textContent).toBe("N");
    input.value = "Nova ";
    input.setSelectionRange(5, 5);
    input.dispatchEvent(new Event("input"));
    expect(n.getAttribute("aria-label")).toBe("N");
    input.setSelectionRange(2, 4);
    input.dispatchEvent(new Event("select"));
    expect(n.textContent).toBe("n");
    n.click();
    expect(input.value).toBe("Non ");
    input.setSelectionRange(0, input.value.length);
    editName(input, "Backspace");
    expect(n.textContent).toBe("N");
    expect(document.activeElement).toBe(input);
    input.remove();
    keyboard.remove();
  });

  it("switches letter trays in place, retaining focus and emitting the displayed case", () => {
    const onKey = vi.fn();
    const keyboard = document.createElement("div");
    keyboard.append(...keyboardRows({ kind: "tray", letters: ["a", "b"] }, onKey, () => {}, true));
    document.body.append(keyboard);
    const a = keyboard.querySelector<HTMLButtonElement>('[data-letter="a"]')!;
    a.focus();
    a.click();
    setKeyboardUppercase(keyboard, false);
    expect(document.activeElement).toBe(a);
    expect(a.getAttribute("aria-label")).toBe("a");
    a.click();
    expect(onKey.mock.calls).toEqual([["A"], ["a"]]);
    keyboard.remove();
  });
  it("mixes physical text with on-screen insertion, selection replacement and deletion", () => {
    const input = nameField("Nova");
    input.setSelectionRange(1, 3);
    editName(input, "i");
    expect(input.value).toBe("Nia");
    editName(input, "Backspace");
    expect(input.value).toBe("Na");
    expect(input.selectionStart).toBe(1);
  });
  it("respects the length limit but permits replacement at the limit", () => {
    const input = nameField("abcdefghijkl");
    editName(input, "x");
    expect(input.value).toBe("abcdefghijkl");
    input.setSelectionRange(0, 2);
    editName(input, "n");
    expect(input.value).toBe("Ncdefghijkl");
  });
  it("emits input for validation and safely deletes at the beginning or after emoji", () => {
    const input = nameField("A🦦");
    const changed = vi.fn();
    input.addEventListener("input", changed);
    editName(input, "Backspace");
    expect(input.value).toBe("A");
    input.setSelectionRange(0, 0);
    editName(input, "Backspace");
    expect(input.value).toBe("A");
    expect(changed).toHaveBeenCalledTimes(2);
  });
  it("supports click and assistive activation without duplicate pointer input", () => {
    const onKey = vi.fn();
    const onDelete = vi.fn();
    const root = document.createElement("div");
    root.append(...keyboardRows({ kind: "qwerty", space: true }, onKey, onDelete));
    const key = root.querySelector<HTMLButtonElement>('button[aria-label="q"]')!;
    key.dispatchEvent(new PointerEvent("pointerdown", { cancelable: true }));
    expect(onKey).not.toHaveBeenCalled();
    key.click();
    root.querySelector<HTMLButtonElement>('button[aria-label="Space"]')!.click();
    root.querySelector<HTMLButtonElement>('button[aria-label="Delete"]')!.click();
    expect(onKey.mock.calls).toEqual([["q"], [" "]]);
    expect(onDelete).toHaveBeenCalledOnce();
  });
});

describe("shared capitalization rules", () => {
  it("capitalizes name starts, spaces and hyphens without capitalizing every letter", () => {
    for (const prefix of ["", "Nova ", "Anne-", " "]) expect(capitalizesName(prefix)).toBe(true);
    for (const prefix of ["N", "Nova", "Anne-M", "O’"]) expect(capitalizesName(prefix)).toBe(false);
  });
  it("follows sentence starts and proper names throughout an exercise", () => {
    const target = "Hi Nova. I am Otter";
    expect([...target].flatMap((_, index) => capitalizesTarget(target, index) ? [index] : [])).toEqual([0, 3, 9, 14]);
    expect(capitalizesTarget(target, -1)).toBe(false);
    expect(capitalizesTarget(target, target.length)).toBe(false);
  });
  it("keeps lowercase spelling, missing letters and numeric answers unchanged", () => {
    for (const target of ["sun", "u", "42", " ", ""]) expect(capitalizesTarget(target, 0)).toBe(false);
    expect(capitalizesTarget("Élan", 0)).toBe(true);
    expect(capitalizesTarget("Élan", 1)).toBe(false);
    const keyboard = document.createElement("div");
    keyboard.append(...keyboardRows({ kind: "numbers" }, () => {}, () => {}, true));
    expect(keyboard.textContent).toBe("1234567890⌫");
  });
});
