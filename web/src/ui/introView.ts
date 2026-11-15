import type { Application } from "pixi.js";
import type { AppModel } from "../app/model";
import { catalog } from "../core";
import { tick } from "../engine/actions";
import { narrator } from "../game/audio";
import { IntroScene, practice } from "../game/introScene";
import { dialogueHeight, showDialogue } from "./dialogue";
import { button, h, symbol } from "./dom";
import type { Screen } from "./menus";
import { keyboardRows } from "./keyboard";

type Step = "loading" | "story" | "tutorial" | "after";

/** The opening story and the practice round that follows it. */
export function introView(model: AppModel, app: Application): Screen {
  const scene = new IntroScene();
  let step: Step = "loading";
  let destroyed = false;
  const compact = () => window.innerHeight < 520;
  const trayHeight = () => (compact() ? 76 : 104);

  const progress = h("span.tutorial-progress");
  const instruction = h("span.tutorial-instruction");
  const banner = h("p.tutorial-banner.panel", { hidden: true, "aria-live": "polite" }, progress, instruction);
  const skip = button("cream.skip.below-hud", ["Skip", symbol("skip")], () => model.finishIntro());
  skip.hidden = true;
  // Letter questions use the same accessible keys as levels; the sum gets answer buttons instead.
  const keys = h("div.keys.tray", { hidden: true });
  let question = 0;

  function showQuestion(index: number): void {
    question = index;
    const item = practice[index]!;
    progress.textContent = `Practice ${index + 1} of ${practice.length}`;
    instruction.textContent = item.instruction;
    banner.hidden = false;
    if (item.answer.kind === "letters") {
      keys.replaceChildren(...keyboardRows({ kind: "tray", letters: item.answer.tray }, (letter) => {
        if (step === "tutorial") scene.handleKey(letter);
      }, () => {}));
    } else {
      keys.replaceChildren(h("div.key-row", {}, ...item.answer.choices.map((choice) => {
        const key = h<"button">("button.key.choice", { type: "button", onClick: () => {
          // A wrong answer fades away, as the tunnels fizz shut in the maths levels.
          if (step === "tutorial" && !scene.choose(choice)) key.disabled = true;
        } }, choice);
        return key;
      })));
    }
    // The question is also said aloud, like every question in the game.
    if (model.settings.spokenInstructions) narrator.say(item.speechKey, item.speech);
  }

  scene.onQuestion = showQuestion;
  scene.onPeek = () => {
    if (practice[question]) instruction.textContent = "Here's a peek! Remember it, then try again.";
  };
  const overlay = h("div.overlay");
  const element = h("section.screen.game", {}, banner, skip, keys, overlay);

  function layout(): void {
    if (destroyed || step === "loading") return;
    const bottom = step === "tutorial" ? trayHeight() + 14 : dialogueHeight(compact());
    scene.resize(app.screen.width, app.screen.height, { top: 0, left: 0, right: 0, bottom });
  }

  function startTutorial(): void {
    // Skipping the story still breaks the crystal, so the practice makes sense.
    scene.shatter();
    step = "tutorial";
    skip.hidden = false;
    keys.hidden = false;
    layout();
    window.setTimeout(() => {
      if (destroyed || step !== "tutorial") return;
      scene.startTutorial();
    }, 900);
  }

  scene.onTutorialDone = () => {
    if (destroyed) return;
    narrator.stop();
    step = "after";
    banner.hidden = true;
    skip.hidden = true;
    keys.hidden = true;
    layout();
    showDialogue(overlay, catalog.introAfter, { voiced: model.settings.characterVoices, done: () => model.finishIntro() });
  };

  const onKeyDown = (event: KeyboardEvent) => {
    if (step !== "tutorial" || event.metaKey || event.ctrlKey || event.altKey || event.key.length !== 1) return;
    scene.handleKey(event.key);
  };
  const frame = () => tick(Math.min(app.ticker.deltaMS / 1000, 0.1));
  window.addEventListener("keydown", onKeyDown);
  overlay.replaceChildren(h("p.loading", {}, "Getting ready…"));

  void scene.load().then(() => {
    if (destroyed) return;
    app.stage.addChild(scene.root);
    app.ticker.add(frame);
    app.renderer.on("resize", layout);
    step = "story";
    layout();
    showDialogue(overlay, catalog.intro, {
      voiced: model.settings.characterVoices,
      // The story beats drive the scene: line 5 shakes the crystal, line 6 breaks it.
      onLine: (index) => {
        if (index === 4) scene.rumble();
        if (index === 5) scene.shatter();
      },
      done: startTutorial,
    });
  }).catch((error: unknown) => {
    console.error(error);
    model.finishIntro();
  });

  return {
    element,
    destroy() {
      destroyed = true;
      window.removeEventListener("keydown", onKeyDown);
      app.ticker.remove(frame);
      app.renderer.off("resize", layout);
      scene.destroy();
    },
  };
}
