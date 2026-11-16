import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
const islands = JSON.parse(readFileSync(new URL("../../Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/islands.json", import.meta.url), "utf8"));
const selected = ["woods-1", "bay-1", "woods-2", "dragon-1", "woods-3", "woods-5"];
const levels = process.env.PLAYTEST_FULL ? (islands as any).islands.flatMap((i: any) => i.levels.map((l: any) => l.id)) : selected;
const scenarios = [...levels.map((level: string) => ({ level, recovery: false })), { level: "woods-1", recovery: true }];
for (const { level, recovery } of scenarios) test(`complete ${level}${recovery ? " after mistake and hint" : ""} through browser input`, async ({ page }, info) => {
  const errors: string[] = [];
  page.on("pageerror", e => errors.push(e.message));
  await page.goto(`./?level=${level}&short`);
  await expect(page.locator("canvas")).toBeVisible();
  const state = () => page.evaluate(() => (window as any).__playtest?.());
  let typed = -1;
  let recovered = false;
  await expect(async () => {
    const skip = page.getByRole("button", { name: "Skip", exact: false });
    if (await skip.isVisible()) { await skip.click(); return expect(false).toBe(true); }
    const s = await state();
    expect(s).toBeTruthy();
    if (s.result) return;
    const tap = async (p: any) => {
      if (info.project.use.hasTouch) await page.touchscreen.tap(p.x, p.y);
      else await page.mouse.click(p.x, p.y);
    };
    if (s.power) await tap(s.power);
    else if (s.crystal) await tap(s.crystal);
    else if (s.question && s.ready) {
      if (s.question.format === "typed" && typed !== s.completed) {
        if (recovery && !recovered) {
          await page.keyboard.type(s.question.typingTarget[0].toLowerCase() === "a" ? "b" : "a");
          await page.getByRole("button", { name: "Hint", exact: true }).click();
          recovered = true;
        }
        if (info.project.use.hasTouch) {
          for (const letter of s.question.typingTarget) {
            const label = letter === " " ? "Space" : letter;
            await page.getByRole("button", { name: new RegExp(`^${label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i") }).tap();
          }
        } else await page.keyboard.type(s.question.typingTarget, { delay: 90 });
        typed = s.completed;
      } else if (s.question.format === "choice") {
        const index = s.question.choices.indexOf(s.question.correctChoice);
        const target = s.targets[index];
        if (target) {
          if (s.slot && !info.project.use.hasTouch) {
            await page.mouse.move(target.x, target.y); await page.mouse.down();
            await page.mouse.move(s.slot.x, s.slot.y, { steps: 12 }); await page.mouse.up();
          } else await tap(target);
        }
      }
    }
    expect((await state())?.result).toBeTruthy();
  }).toPass({ timeout: 150_000, intervals: [500] });
  const final = await state();
  expect(final.completed).toBe(final.total);
  expect(final.result.stars).toBe(recovery ? 2 : 3);
  expect(errors).toEqual([]);
  await info.attach("result", { body: JSON.stringify(final), contentType: "application/json" });
});
