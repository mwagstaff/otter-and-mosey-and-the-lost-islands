// @vitest-environment happy-dom
import { describe, expect, it, vi } from "vitest";
import { editName, keyboardRows } from "../src/ui/keyboard";

function nameField(value = "") {
  const input = document.createElement("input");
  input.maxLength = 12;
  input.value = value;
  input.setSelectionRange(value.length, value.length);
  return input;
}

describe("explorer name keyboard", () => {
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
