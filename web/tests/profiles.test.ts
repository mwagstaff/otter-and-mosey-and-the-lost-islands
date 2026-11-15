// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from "vitest";
vi.mock("../src/game/audio", () => ({ audio: { apply: vi.fn(), play: vi.fn(), playMusic: vi.fn() }, narrator: { stop: vi.fn() } }));
import { AppModel } from "../src/app/model";
import { profilesScreen } from "../src/ui/menus";

afterEach(() => document.body.replaceChildren());

function setup(existingPlayer = false) {
  const model = new AppModel({ getItem: () => null, setItem: () => {} });
  if (existingPlayer) model.createProfile("Pip", "🦦");
  const screen = profilesScreen(model).element;
  document.body.append(screen);
  const click = (text: string) => {
    const button = [...screen.querySelectorAll("button")].find(b => b.textContent === text);
    expect(button, `button ${text}`).toBeDefined();
    button!.click();
  };
  const input = () => screen.querySelector<HTMLInputElement>(".nickname")!;
  return { model, screen, click, input };
}

describe("new explorer steps", () => {
  it("chooses a character before showing the name or keyboard, preserving the draft when going back", () => {
    const { model, screen, click, input } = setup();
    expect(screen.querySelectorAll(".avatar-choice")).toHaveLength(17);
    expect(input()).toBeNull();
    expect(screen.querySelector(".name-keyboard")).toBeNull();
    screen.querySelector<HTMLButtonElement>('[aria-label="Picture 3"]')!.click();
    expect(model.save.profiles).toHaveLength(0);
    click("Next");
    expect(screen.querySelector(".avatar-grid")).toBeNull();
    expect(document.activeElement).toBe(input());
    input().value = "No";
    input().dispatchEvent(new Event("input"));
    screen.querySelector<HTMLButtonElement>('.name-keyboard [aria-label="v"]')!.click();
    screen.querySelector<HTMLButtonElement>('.name-keyboard [aria-label="a"]')!.click();
    click("Back");
    expect(screen.querySelector('[aria-label="Picture 3"]')!.getAttribute("aria-pressed")).toBe("true");
    expect(screen.querySelector(".name-keyboard")).toBeNull();
    screen.querySelector<HTMLButtonElement>('[aria-label="Picture 4"]')!.click();
    click("Next");
    expect(input().value).toBe("Nova");
    input().dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    expect(model.save.profiles).toHaveLength(1);
    expect(model.profile).toMatchObject({ nickname: "Nova", avatar: "🦖" });
  });

  it("keeps empty and whitespace-only names on the name step with friendly validation", () => {
    const { model, screen, click, input } = setup();
    click("Next");
    input().value = "   ";
    input().dispatchEvent(new Event("input"));
    click("Let's go!");
    expect(model.save.profiles).toHaveLength(0);
    expect(input().getAttribute("aria-invalid")).toBe("true");
    expect(screen.querySelector(".name-hint")!.textContent).toContain("What shall we call you?");
    screen.querySelector<HTMLButtonElement>('.name-keyboard [aria-label="B"]')!.click();
    expect(input().hasAttribute("aria-invalid")).toBe(false);
    screen.querySelector<HTMLButtonElement>('header [aria-label="Back"]')!.click();
    expect(screen.querySelector(".avatar-grid")).not.toBeNull();
  });

  it("cancels an additional player without saving and starts a fresh character step next time", () => {
    const { model, screen, click, input } = setup(true);
    click("New player");
    click("Next");
    input().value = "Draft";
    input().dispatchEvent(new Event("input"));
    click("Back");
    click("Cancel");
    expect(screen.querySelector("h1")!.textContent).toBe("Who's playing?");
    expect(model.save.profiles).toHaveLength(1);
    click("New player");
    expect(input()).toBeNull();
    click("Next");
    expect(input().value).toBe("");
  });
});
