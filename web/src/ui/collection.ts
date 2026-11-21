import { animateLagoon } from "./lagoon";
import { artURL } from "../assets";
import { hasGroupPhoto, showGroupPhoto } from "./photo";
import type { AppModel } from "../app/model";
import { catalog, hasReward, placeDecoration, wear as putOn, type PlacedDecoration, type Reward, type RewardKind } from "../core";
import { iconName } from "../engine/art";
import { audio } from "../game/audio";
import { button, h, picture, roundButton } from "./dom";
import type { Screen } from "./menus";

const backdrop = (name: string) => `background-image: url("${artURL(name)}")`;
const rewardArt = (reward: Reward) => iconName(`reward_${reward.id}`) ?? reward.emoji;

/** Everything the player has collected: crystals, pets and hats. Trophies have their own cabinet. */
export function collectionScreen(model: AppModel): Screen {
  const profile = model.profile!;
  const tabs = [["💎", "Crystals"], ["🐾", "Pets"], ["🎩", "Hats"]] as const;
  let tab = 0;
  const grid = h("div.tiles");

  const tile = (icon: HTMLElement, title: string, subtitle: string, earned: boolean, highlight = false) => {
    icon.classList.add("tile-art");
    if (!earned) icon.classList.add("missing");
    return h(`div.tile${earned ? "" : ".unearned"}${highlight ? ".worn" : ""}`, {}, icon, h("strong", {}, title), h("span", {}, subtitle));
  };

  const rewards = (kind: RewardKind) => catalog.rewards.filter((reward) => reward.kind === kind).map((reward) => {
    const owned = hasReward(profile, reward.id);
    const worn = profile.equippedAccessory === reward.id;
    const wearable = owned && kind === "accessory";
    const subtitle = !owned ? "Keep exploring to find it" : kind !== "accessory" ? "Your friend" : worn ? "Both wearing it! Tap to take off" : "Tap for both to wear";
    const made = tile(picture(rewardArt(reward), "glyph"), owned ? reward.name : "???", subtitle, owned, worn);
    if (!wearable) return made;
    const wear = button("tile-button", [made], () => {
      putOn(profile, worn ? undefined : reward.id);
      model.persist();
      render();
    }, { "aria-pressed": String(worn) });
    return wear;
  });

  function render(): void {
    tabButtons.forEach((each, index) => each.classList.toggle("chosen", index === tab));
    if (tab === 0) {
      grid.replaceChildren(...catalog.islands.map((island) => {
        const found = profile.crystals.includes(island.id);
        const shard = h("span.shard", {},
          h("img", { src: artURL("crystal_shard"), alt: "", draggable: "false" }),
          h("span.shard-tint", { style: `background: ${island.colour}; -webkit-mask-image: url("${artURL("crystal_shard")}"); mask-image: url("${artURL("crystal_shard")}")` }),
        );
        return tile(shard, island.name, found ? "Fragment found!" : "Still lost…", found);
      }));
      // The group photo from the finale, once every fragment is home.
      if (hasGroupPhoto(profile)) {
        const photo = h("span.photo-tile", {}, h("img", { src: artURL("bg_ending"), alt: "", draggable: "false" }));
        grid.append(button("tile-button", [tile(photo, "Group photo", "Tap to look at it", true)], () => showGroupPhoto(model, element)));
      }
    } else if (tab === 1) grid.replaceChildren(...rewards("pet"));
    else grid.replaceChildren(...rewards("accessory"));
  }

  const tabButtons = tabs.map(([emoji, title], index) => button("cream.tab", [picture(emoji), title], () => {
    tab = index;
    render();
  }));
  const element = h("section.screen.collection", { style: backdrop("bg_title") },
    h("div.veil.soft"),
    h("header.bar", {}, roundButton("back", "Back to map", () => model.go({ name: "map" })), h("div.tabs", {}, ...tabButtons), h("span.spacer")),
    h("div.collection-panel.panel", {}, grid),
  );
  render();
  return { element };
}

/** The home island, which the player decorates with things earned on the adventure. */
export function homeScreen(model: AppModel): Screen {
  const profile = model.profile!;
  const owned = (kind: RewardKind) => catalog.rewards.filter((reward) => reward.kind === kind && hasReward(profile, reward.id));
  const field = h("div.home-field");
  const scenery = h("div.home-scenery", { style: `${backdrop("bg_title")}; filter: saturate(${0.35 + (0.65 * profile.crystals.length) / 6})` });

  const clamp = (value: number, low: number, high: number) => Math.min(Math.max(value, low), high);

  function place(placed: PlacedDecoration): HTMLElement | undefined {
    const reward = catalog.reward(placed.reward);
    if (!reward) return undefined;
    const item = picture(rewardArt(reward), "home-item decoration");
    item.setAttribute("role", "img");
    item.setAttribute("aria-label", reward.name);
    const position = () => {
      item.style.left = `${placed.x * 100}%`;
      item.style.top = `${placed.y * 100}%`;
    };
    position();
    // pointerdown cancels the browser's own click and dblclick (so dragging never scrolls the
    // page), so a double tap is spotted here instead: two quick taps that barely move.
    let downAt = { x: 0, y: 0 };
    let lastTap = -Infinity;
    item.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      downAt = { x: event.clientX, y: event.clientY };
      item.setPointerCapture(event.pointerId);
      item.classList.add("dragging");
    });
    item.addEventListener("pointermove", (event) => {
      if (!item.hasPointerCapture(event.pointerId)) return;
      const box = field.getBoundingClientRect();
      placed.x = clamp((event.clientX - box.left) / box.width, 0.04, 0.96);
      placed.y = clamp((event.clientY - box.top) / box.height, 0.18, 0.82);
      position();
    });
    const drop = () => {
      item.classList.remove("dragging");
      model.persist();
    };
    const putAway = () => {
      profile.decorations = profile.decorations.filter((each) => each.id !== placed.id);
      model.persist();
      item.remove();
    };
    item.addEventListener("pointerup", (event) => {
      drop();
      if (Math.hypot(event.clientX - downAt.x, event.clientY - downAt.y) > 6) return;
      const now = performance.now();
      if (now - lastTap < 450) putAway();
      lastTap = now;
    });
    item.addEventListener("pointercancel", drop);
    return item;
  }

  function add(reward: Reward): void {
    if (profile.decorations.length >= 24) return;
    const placed = placeDecoration(reward.id, 0.25 + Math.random() * 0.5, 0.4 + Math.random() * 0.25);
    profile.decorations.push(placed);
    model.persist();
    const item = place(placed);
    if (item) field.append(item);
    audio.play("pop", 0.6);
  }

  for (const placed of profile.decorations) {
    const item = place(placed);
    if (item) field.append(item);
  }

  // The trophy cabinet stands on the island too.
  const cabinet = button("home-cabinet", [h("img", { src: artURL("trophy_cabinet"), alt: "", draggable: "false" }), h("span.panel", {}, "Trophies")],
    () => model.openTrophies(), { "aria-label": "Trophy cabinet" });
  function positionCabinet(x: number, y: number): void {
    cabinet.style.left = `${x * 100}%`;
    cabinet.style.top = `${y * 100}%`;
  }
  let start: { x: number; y: number; pointer: number } | undefined;
  let moved = false;
  positionCabinet(profile.cabinetPosition.x, profile.cabinetPosition.y);
  cabinet.addEventListener("pointerdown", (event) => {
    if (start || event.button !== 0) return;
    start = { x: event.clientX, y: event.clientY, pointer: event.pointerId };
    moved = false;
    cabinet.setPointerCapture(event.pointerId);
  });
  function dragCabinet(event: PointerEvent, save: boolean): void {
    if (!start || start.pointer !== event.pointerId) return;
    const dx = event.clientX - start.x, dy = event.clientY - start.y;
    moved ||= Math.hypot(dx, dy) >= 6;
    if (!moved) return;
    const { width, height } = field.getBoundingClientRect();
    const x = clamp(profile.cabinetPosition.x + dx / width, 0.1, 0.9);
    const y = clamp(profile.cabinetPosition.y + dy / height, 0.3, 0.68);
    positionCabinet(x, y);
    if (save) {
      profile.cabinetPosition = { x, y };
      model.persist();
    }
  }
  cabinet.addEventListener("pointermove", (event) => dragCabinet(event, false));
  cabinet.addEventListener("pointerup", (event) => {
    if (start?.pointer !== event.pointerId) return;
    dragCabinet(event, true);
    start = undefined;
  });
  cabinet.addEventListener("lostpointercapture", (event) => {
    if (start?.pointer !== event.pointerId) return;
    start = undefined;
    positionCabinet(profile.cabinetPosition.x, profile.cabinetPosition.y);
  });
  cabinet.addEventListener("click", (event) => {
    if (moved && event.detail > 0) event.stopImmediatePropagation();
  }, true);
  const element = h("section.screen.home", {},
    scenery,
    field,
    cabinet,
    h("header.bar", {}, roundButton("back", "Back to map", () => model.go({ name: "map" })), h("h1.home-title.panel", {}, "Rainbow Island"), h("span.spacer")),
    h("div.home-tray.panel", {},
      h("span", {}, "Tap to add. Drag to move. Double-tap to put away."),
      h("div.home-choices", {}, ...[...owned("decoration"), ...owned("pet")].map((reward) => button("avatar-choice", [picture(rewardArt(reward), "avatar")], () => add(reward), { "aria-label": `Add ${reward.name}` }))),
    ),
  );
  return { element, destroy: animateLagoon(scenery, "bg_title", element) };
}
