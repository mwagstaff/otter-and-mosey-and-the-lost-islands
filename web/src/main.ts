import "@fontsource-variable/nunito";
import { Application } from "pixi.js";
import { AppModel, playableModes } from "./app/model";
import { catalog } from "./core";
import { h } from "./ui/dom";
import { gameView } from "./ui/gameView";
import { collectionScreen, homeScreen } from "./ui/collection";
import { introView } from "./ui/introView";
import { dedicationScreen, endingScreen, islandScreen, mapScreen, profilesScreen, titleScreen, type Screen } from "./ui/menus";
import { parentScreen } from "./ui/parent";
import "./ui/style.css";

const stage = document.querySelector<HTMLDivElement>("#stage")!;
const page = document.querySelector<HTMLElement>("#app")!;

async function boot(): Promise<void> {
  const model = new AppModel();

  // The level scenes are drawn on this canvas; menus are ordinary page elements over it.
  const app = new Application();
  stage.hidden = false;
  await app.init({ resizeTo: stage, background: "#0e3b43", antialias: true, autoDensity: true, resolution: Math.min(window.devicePixelRatio, 2) });
  stage.append(app.canvas);
  stage.hidden = true;
  app.ticker.stop();
  // Scene text is drawn onto the canvas, so the typeface has to be ready first.
  await document.fonts.load('800 20px "Nunito Variable"').catch(() => undefined);

  let current: Screen | undefined;
  const show = (screen: Screen, playing = false) => {
    current?.destroy?.();
    current = screen;
    stage.hidden = !playing;
    if (playing) {
      app.resize();
      app.ticker.start();
    } else {
      app.ticker.stop();
    }
    page.replaceChildren(screen.element);
  };

  model.onRoute(() => {
    const route = model.route;
    const island = route.name === "island" ? catalog.island(route.id) : undefined;
    const level = route.name === "play" ? catalog.level(route.level) : undefined;
    const home = level && catalog.islandContaining(level.id);
    if (route.name === "title") show(titleScreen(model));
    else if (route.name === "profiles") show(profilesScreen(model));
    else if (route.name === "intro" && model.profile) show(introView(model, app), true);
    else if (route.name === "ending") show(endingScreen(model));
    else if (route.name === "parent") show(parentScreen(model));
    else if (route.name === "collection" && model.profile) show(collectionScreen(model));
    else if (route.name === "home" && model.profile) show(homeScreen(model));
    else if (island) show(islandScreen(model, island));
    else if (level && home && model.profile && playableModes.has(level.mode)) show(gameView(model, app, level, home), true);
    else show(mapScreen(model));
  });

  // Playtime is counted in ten-second steps while the game is on screen.
  window.setInterval(() => { if (!document.hidden) model.addPlaytime(10); }, 10_000);
  document.addEventListener("visibilitychange", () => { if (document.hidden && model.profile) model.persist(); });

  // `?level=woods-1` opens a level directly and `?short` limits levels to three questions, for testing.
  const wanted = new URLSearchParams(location.search).get("level");
  if (wanted && catalog.level(wanted)) {
    model.openForTesting(wanted);
  } else {
    show(dedicationScreen(() => model.go({ name: "title" })));
  }
}

boot().catch((error: unknown) => {
  console.error(error);
  page.replaceChildren(h("section.screen.dedication", {}, h("div.dedication-body", {}, h("p", {}, "Sorry, the game could not start in this browser."))));
});
