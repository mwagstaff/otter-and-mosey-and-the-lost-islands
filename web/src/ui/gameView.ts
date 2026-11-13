import type { Application } from "pixi.js";
import { playableModes, type AppModel } from "../app/model";
import {
  catalog, ChallengeSession, isLevelUnlocked, subjectOf, type DialogueLine, type GameMode, type InputProfile, type Island,
  type LevelDef, type LevelResult, type RewardSummary,
} from "../core";
import { tick } from "../engine/actions";
import { iconName, rainbow } from "../engine/art";
import { audio } from "../game/audio";
import { GameBridge, type KeyboardKind } from "../game/bridge";
import { BridgeBuilderScene } from "../game/bridgeBuilder";
import { EggRescueScene } from "../game/eggRescue";
import type { GameScene, Insets, SceneOptions } from "../game/gameScene";
import { GuardianScene } from "../game/guardian";
import { MathsSplashScene } from "../game/mathsSplash";
import { TypingTurboScene } from "../game/typingTurbo";
import { WordBlasterScene } from "../game/wordBlaster";
import { dialogueHeight, showDialogue as sharedDialogue } from "./dialogue";
import { button, h, picture, roundButton, symbol } from "./dom";
import { openSettings } from "./settings";
import { starRow, type Screen } from "./menus";

type Stage = "loading" | "intro" | "playing" | "outro" | "results";

const coarse = matchMedia("(pointer: coarse)");

/** Whether the child is on a touch screen (show the game's own keys) or has a real keyboard. */
function inputProfile(compact: boolean): InputProfile {
  if (!coarse.matches) return "hardware";
  return compact ? "compactTouch" : "fullTouch";
}

/** Heights the on-screen keys need, so scenes can keep gameplay clear of them. */
const keyHeights = (compact: boolean) => ({ tray: compact ? 76 : 104, qwerty: compact ? 146 : 226, numbers: compact ? 76 : 104 });

const scenes: Record<GameMode, new (session: ChallengeSession, bridge: GameBridge, options: SceneOptions) => GameScene> = {
  wordBlaster: WordBlasterScene,
  mathsSplash: MathsSplashScene,
  bridgeBuilder: BridgeBuilderScene,
  eggRescue: EggRescueScene,
  typingTurbo: TypingTurboScene,
  guardian: GuardianScene,
};

/** Hosts one level: the scene with the HUD, keys, dialogue and results over it. */
export function gameView(model: AppModel, app: Application, level: LevelDef, island: Island): Screen {
  const profile = model.profile!;
  const compact = () => window.innerHeight < 520;
  const input = inputProfile(compact());
  const hardware = input === "hardware";
  const bridge = new GameBridge();
  let stage: Stage = "loading";
  let paused = false;
  let summary: RewardSummary | undefined;
  let destroyed = false;

  const base = model.restoration(island);
  const hat = profile.equippedAccessory === undefined ? undefined : catalog.reward(profile.equippedAccessory);
  const sceneOptions: SceneOptions = {
    favourite: profile.favourite === "mosey" ? "mosey" : "otter",
    accessory: hat && (iconName(`reward_${hat.id}`) ?? hat.emoji),
    island,
    inputProfile: input,
    startRestoration: base * 0.75,
    endRestoration: level.mode === "guardian" ? 1 : Math.min(1, base * 0.75 + 0.5),
  };
  const short = new URLSearchParams(location.search).has("short");
  const session = new ChallengeSession({
    level, learner: profile.learner, settings: profile.parent, inputProfile: input, questionLimit: short ? 3 : undefined,
  });
  bridge.onLearnerChanged = (learner) => model.updateLearner(learner);
  const scene = new scenes[level.mode](session, bridge, sceneOptions);

  // The page over the scene

  const progressText = h("span.progress-count");
  const progressFill = h("span.progress-fill", { style: `background: linear-gradient(90deg, ${rainbow.join(", ")})` });
  const caption = h("p.caption");
  const combo = h("span.combo");
  const listen = roundButton("speaker", "Hear it again", () => bridge.onRepeatSpeech?.());
  const hud = h("header.hud", {},
    roundButton("pause", "Pause", () => setPaused(true)),
    h("div.progress.panel", {}, progressText, h("span.progress-track", {}, progressFill)),
    caption,
    combo,
    listen,
    roundButton("bulb", "Hint", () => bridge.onHint?.(), "gold"),
  );
  const hint = h("p.hint.panel");
  const toast = h("p.toast");
  const meterFill = h("span.meter-fill");
  const meter = h("div.meter.panel", { role: "img" }, picture("💞", "glyph"), h("span.meter-track", {}, meterFill));
  const extras = h("div.hud-extras", {}, hint, h("div.hud-row", {}, meter, toast));
  const keys = h("div.keys");
  const overlay = h("div.overlay");
  const element = h("section.screen.game", {}, hud, extras, keys, overlay);

  let toastShown = 0;
  let toastTimer = 0;
  let keysShown = "";

  function render(): void {
    if (destroyed) return;
    const playing = stage === "playing" || stage === "outro";
    hud.hidden = !playing;
    extras.hidden = !playing;
    progressText.textContent = `${bridge.completed}/${bridge.total}`;
    progressFill.style.width = `${Math.max(10, (100 * bridge.completed) / Math.max(bridge.total, 1))}%`;
    caption.textContent = bridge.caption;
    caption.classList.toggle("long", bridge.caption.length > 40);
    combo.hidden = bridge.combo < 2;
    combo.replaceChildren(`×${bridge.multiplier}`, picture("🔥", "glyph"), String(bridge.combo));
    listen.disabled = !bridge.canSpeak;
    hint.hidden = bridge.hintText === undefined;
    hint.replaceChildren(symbol("bulb"), bridge.hintText ?? "");
    meter.hidden = bridge.friendship === undefined;
    meterFill.style.width = `${Math.max(6, 100 * (bridge.friendship ?? 0))}%`;
    meter.setAttribute("aria-label", `Friendship Power ${Math.round(100 * (bridge.friendship ?? 0))} percent`);
    if (bridge.toastID !== toastShown) {
      toastShown = bridge.toastID;
      toast.textContent = bridge.toast;
      toast.classList.remove("show");
      void toast.offsetWidth;
      toast.classList.add("show");
      window.clearTimeout(toastTimer);
      toastTimer = window.setTimeout(() => toast.classList.remove("show"), 1300);
    }
    renderKeys();
    if (bridge.result && stage === "playing") finish(bridge.result);
    if (bridge.dialogue.length > 0 && overlay.dataset.kind !== "dialogue") {
      showDialogue(bridge.dialogue, true, () => bridge.finishDialogue());
    }
    applyInsets();
  }

  function renderKeys(): void {
    const kind: KeyboardKind = stage === "playing" && bridge.dialogue.length === 0 ? bridge.keyboard : { kind: "none" };
    const signature = hardware ? `hardware:${kind.kind}` : JSON.stringify(kind);
    if (signature === keysShown) return;
    keysShown = signature;
    keys.className = `keys ${kind.kind}`;
    keys.hidden = kind.kind === "none";
    if (hardware) {
      keys.className = "keys pill";
      keys.replaceChildren(h("p.keyboard-note", {}, symbol("keyboard"), "Type on your keyboard"));
      return;
    }
    const cap = (label: string, press: () => void, className = "") => {
      const key = h(`button.key${className}`, { type: "button", "aria-label": label === "␣" ? "space" : label === "⌫" ? "delete" : label }, label);
      // Act on press, not release, and keep the page from selecting or scrolling.
      key.addEventListener("pointerdown", (event) => { event.preventDefault(); press(); });
      return key;
    };
    const letter = (character: string) => cap(character, () => bridge.onKey?.(character));
    const row = (...children: HTMLElement[]) => h("div.key-row", {}, ...children);
    if (kind.kind === "tray") keys.replaceChildren(row(...kind.letters.map(letter)));
    else if (kind.kind === "numbers") keys.replaceChildren(row(...[..."1234567890"].map(letter), cap("⌫", () => bridge.onBackspace?.(), ".coral")));
    else if (kind.kind === "qwerty") {
      const rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map((letters) => row(...[...letters].map(letter)));
      if (kind.space) rows[2]!.append(cap("␣", () => bridge.onKey?.(" "), ".gold.wide"));
      keys.replaceChildren(...rows);
    } else keys.replaceChildren();
  }

  // Layout

  function reservedKeys(): number {
    const mode = level.mode;
    // Guardians only need keys when they ask spelling questions.
    const typesWords = level.skills.some((skill) => subjectOf(skill) === "spelling");
    if (mode === "mathsSplash" || mode === "bridgeBuilder" || (mode === "guardian" && !typesWords)) return 0;
    if (hardware) return 40;
    const heights = keyHeights(compact());
    if (mode === "typingTurbo") return heights.qwerty + 14;
    if (mode === "eggRescue") return heights.numbers + 14;
    return (compact() ? heights.tray : heights.qwerty) + 14;
  }

  function insets(): Insets {
    const talking = stage === "intro" || stage === "outro" || bridge.dialogue.length > 0 || stage === "loading";
    const bottom = talking ? dialogueHeight(compact()) : stage === "results" ? 0 : reservedKeys();
    return { top: (compact() ? 64 : 92) + 6, left: 8, right: 8, bottom };
  }

  function applyInsets(): void {
    if (destroyed || stage === "loading") return;
    element.classList.toggle("compact", compact());
    scene.resize(app.screen.width, app.screen.height, insets());
  }

  // Dialogue

  function showDialogue(lines: DialogueLine[], belowHUD: boolean, done: () => void): void {
    sharedDialogue(overlay, lines, { guardianName: island.guardian.name, belowHUD, voiced: model.settings.characterVoices, done });
  }

  // Finishing

  function finish(result: LevelResult): void {
    summary = model.complete(level.id, result, session.learner, bridge.friendshipUses);
    stage = "outro";
    render();
    showDialogue(level.outro, true, () => {
      stage = "results";
      render();
      showResults(result);
    });
  }

  function replay(): void {
    // Rebuild this screen from scratch with fresh questions.
    model.go({ name: "play", level: level.id });
  }

  function showResults(result: LevelResult): void {
    const earned = summary;
    const next = catalog.nextLevel(level.id);
    const canGoOn = next && playableModes.has(next.mode) && isLevelUnlocked(next.id, model.profile!);
    const headline = earned?.crystalIsland ? "Crystal fragment found!" : result.stars === 3 ? "Superstar!" : result.stars === 2 ? "Great work!" : "You did it!";
    const stat = (title: string, value: string) => h("div.stat", {}, h("strong", {}, value), h("span", {}, title));
    const stars = starRow(0, "stars big");
    const chip = (key: string, name: string) => h("span.chip", {}, picture(key), name);
    const chips = [
      ...(earned?.crystalIsland ? [chip("💎", `${earned.crystalIsland.name} crystal`)] : []),
      ...(earned?.reward ? [chip(iconName(`reward_${earned.reward.id}`) ?? earned.reward.emoji, earned.reward.name)] : []),
      ...(earned?.decorations ?? []).map((item) => chip(iconName(`reward_${item.id}`) ?? item.emoji, item.name)),
      ...(earned?.achievements ?? []).map((item) => chip(iconName(`badge_${item.id}`) ?? item.emoji, item.title)),
    ];
    overlay.dataset.kind = "results";
    overlay.replaceChildren(h("div.shade", {}, h("div.results.panel", { role: "dialog", "aria-label": "Level complete" },
      h("h2", {}, headline),
      stars,
      h("div.stats", {},
        stat("Score", String(result.score)),
        stat(level.mode === "typingTurbo" ? "Accuracy" : "First try", `${Math.round(result.accuracy * 100)}%`),
        result.bestCombo >= 2 && stat("Best streak", String(result.bestCombo)),
        result.wordsPerMinute !== undefined && stat("Speed", `${Math.round(result.wordsPerMinute)} wpm`),
      ),
      chips.length > 0 && h("div.chips", {}, ...chips),
      model.saveFailed && h("p.warning", {}, "This browser would not save your progress."),
      h("div.actions", {},
        button("cream", [picture("🏝️"), "Island"], () => model.go({ name: "island", id: island.id })),
        button("cream", [symbol("again"), "Again"], replay),
        earned?.gameComplete && button("teal.big", [picture("🌈"), "The ending!"], () => model.go({ name: "ending" })),
        !earned?.gameComplete && canGoOn && button("teal.big", ["Next", symbol("play")], () => model.go({ name: "play", level: next.id })),
        !earned?.gameComplete && !canGoOn && earned?.crystalIsland && button("teal.big", [picture("🗺️"), "Map"], () => model.go({ name: "map" })),
      ),
    )));
    for (let star = 1; star <= Math.max(result.stars, 1); star += 1) {
      window.setTimeout(() => {
        if (destroyed) return;
        stars.children[star - 1]?.classList.remove("unearned");
        stars.children[star - 1]?.classList.add("pop");
        audio.play("star");
        if (star === result.stars && (earned?.crystalIsland || earned?.reward)) audio.play("unlock");
      }, 400 * star);
    }
  }

  // Pausing

  function setPaused(value: boolean): void {
    if (stage !== "playing" || bridge.dialogue.length > 0) return;
    paused = value;
    if (!value) {
      overlay.replaceChildren();
      delete overlay.dataset.kind;
      return;
    }
    overlay.dataset.kind = "pause";
    overlay.replaceChildren(h("div.shade", {}, h("div.pause.panel", { role: "dialog", "aria-label": "Paused" },
      h("h2", {}, "Paused"),
      h("p", {}, level.title),
      button("teal.big", [symbol("play"), "Keep playing"], () => setPaused(false)),
      h("div.actions", {},
        button("cream", [symbol("again"), "Start again"], replay),
        button("cream", [symbol("gear"), "Sound"], () => openSettings(model)),
        button("coral", [picture("🏝️"), "Leave"], () => model.go({ name: "island", id: island.id })),
      ),
    )));
  }

  // Keyboard

  function onKeyDown(event: KeyboardEvent): void {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.key === "Escape" && stage === "playing") {
      setPaused(!paused);
      return;
    }
    if (paused || stage !== "playing" || bridge.dialogue.length > 0) return;
    if (event.target instanceof HTMLButtonElement && (event.key === " " || event.key === "Enter")) {
      // Space would press whichever button was last clicked; it belongs to the game here.
      event.target.blur();
    }
    if (event.key === "Backspace") {
      event.preventDefault();
      bridge.onBackspace?.();
    } else if (/^[\p{L}\p{N} ]$/u.test(event.key)) {
      event.preventDefault();
      bridge.onKey?.(event.key);
    }
  }

  // Touch and mouse on the scene itself

  const canvas = app.canvas;
  const place = (event: PointerEvent) => {
    const box = canvas.getBoundingClientRect();
    return [event.clientX - box.left, event.clientY - box.top] as const;
  };
  let pressed: number | undefined;
  const live = () => !paused && !destroyed && (stage === "playing" || stage === "outro") && bridge.dialogue.length === 0;
  const onPointerDown = (event: PointerEvent) => {
    if (!live() || pressed !== undefined) return;
    pressed = event.pointerId;
    canvas.setPointerCapture(event.pointerId);
    scene.pointerDown(...place(event));
  };
  const onPointerMove = (event: PointerEvent) => {
    if (event.pointerId === pressed && live()) scene.pointerMove(...place(event));
  };
  const onPointerUp = (event: PointerEvent) => {
    if (event.pointerId !== pressed) return;
    pressed = undefined;
    if (event.type === "pointercancel" || !live()) scene.pointerCancel();
    else scene.pointerUp(...place(event));
  };
  canvas.addEventListener("pointerdown", onPointerDown);
  canvas.addEventListener("pointermove", onPointerMove);
  canvas.addEventListener("pointerup", onPointerUp);
  canvas.addEventListener("pointercancel", onPointerUp);

  // Start-up

  const frame = () => {
    if (!paused) tick(Math.min(app.ticker.deltaMS / 1000, 0.1));
  };
  const onResize = () => applyInsets();

  bridge.onChange(render);
  window.addEventListener("keydown", onKeyDown);
  overlay.replaceChildren(h("p.loading", {}, "Getting ready…"));
  render();

  void scene.load().then(() => {
    if (destroyed) return;
    app.stage.addChild(scene.root);
    app.ticker.add(frame);
    app.renderer.on("resize", onResize);
    stage = "intro";
    applyInsets();
    showDialogue(level.intro, false, () => {
      stage = "playing";
      // Make room for the keys before the first question is laid out.
      render();
      scene.begin();
    });
  }).catch((error: unknown) => {
    console.error(error);
    overlay.replaceChildren(h("div.shade", {}, h("div.pause.panel", {},
      h("h2", {}, "Sorry, this level could not load"),
      button("cream", [picture("🏝️"), "Back to the island"], () => model.go({ name: "island", id: island.id })),
    )));
  });

  return {
    element,
    destroy() {
      destroyed = true;
      window.clearTimeout(toastTimer);
      window.removeEventListener("keydown", onKeyDown);
      app.ticker.remove(frame);
      app.renderer.off("resize", onResize);
      canvas.removeEventListener("pointerdown", onPointerDown);
      canvas.removeEventListener("pointermove", onPointerMove);
      canvas.removeEventListener("pointerup", onPointerUp);
      canvas.removeEventListener("pointercancel", onPointerUp);
      scene.destroy();
    },
  };
}
