import type { Application } from "pixi.js";
import type { AppModel } from "../app/model";
import { catalog } from "../core";
import { tick } from "../engine/actions";
import { narrator } from "../game/audio";
import { IntroScene } from "../game/introScene";
import { dialogueHeight, showDialogue } from "./dialogue";
import { button, h, symbol } from "./dom";
import type { Screen } from "./menus";

type Step = "loading" | "story" | "tutorial" | "after";

/** The opening story and the one-question tutorial. */
export function introView(model: AppModel, app: Application): Screen {
  const scene = new IntroScene();
  let step: Step = "loading";
  let destroyed = false;
  const compact = () => window.innerHeight < 520;
  const trayHeight = () => (compact() ? 76 : 104);

  const banner = h("p.tutorial-banner.panel", { hidden: true }, "Tap the missing letter to bring the flower back!");
  const skip = button("cream.skip.below-hud", ["Skip", symbol("skip")], () => model.finishIntro());
  skip.hidden = true;
  const keys = h("div.keys.tray", { hidden: true }, h("div.key-row", {}, ...IntroScene.tutorialLetters.map((letter) => {
    const key = h("button.key", { type: "button", "aria-label": letter }, letter);
    key.addEventListener("pointerdown", (event) => { event.preventDefault(); scene.handleKey(letter); });
    return key;
  })));
  const overlay = h("div.overlay");
  const element = h("section.screen.game", {}, banner, skip, keys, overlay);

  function layout(): void {
    if (destroyed || step === "loading") return;
    const bottom = step === "tutorial" ? trayHeight() + 14 : dialogueHeight(compact());
    scene.resize(app.screen.width, app.screen.height, { top: 0, left: 0, right: 0, bottom });
  }

  function startTutorial(): void {
    // Skipping the story still breaks the crystal, so the tutorial makes sense.
    scene.shatter();
    step = "tutorial";
    banner.hidden = false;
    skip.hidden = false;
    keys.hidden = false;
    layout();
    window.setTimeout(() => {
      if (destroyed || step !== "tutorial") return;
      scene.startTutorial();
      // The word is also said aloud, like every spelling question in the game.
      if (model.settings.spokenInstructions) narrator.say("word_sun", "Sun. The sun is hot and bright.");
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
