import { artURL } from "../assets";
import type { AppModel } from "../app/model";
import { catalog, type Profile } from "../core";
import { button, h, picture, roundButton } from "./dom";

// The group photo from the finale: everyone together on the beach. Once every crystal fragment
// is home it can be looked at again from the map, the trophy cabinet and Treasures.

/** The words under the photo. It is a photo for the player, who is not in the picture. */
export function photoCaption(name: string): string {
  return `A special photo for ${name}`;
}

export function hasGroupPhoto(profile: Profile | undefined): boolean {
  return profile !== undefined && profile.crystals.length === catalog.islands.length;
}

/** Shows the photo over `host`, with a way to watch the ending again. */
export function showGroupPhoto(model: AppModel, host: HTMLElement): void {
  const profile = model.profile;
  if (!profile) return;
  host.querySelector(".photo-viewer")?.remove();
  const close = () => {
    viewer.remove();
    document.removeEventListener("keydown", onKey);
  };
  const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") close(); };
  const viewer = h("div.photo-viewer", { role: "dialog", "aria-label": "Group photo", onClick: (event: Event) => { if (event.target === event.currentTarget) close(); } },
    h("div.photo-card", {},
      h("figure.photo-polaroid", {},
        h("img", { src: artURL("bg_ending"), alt: "Otter, Mosey and all six guardians celebrating on the beach", draggable: "false" }),
        h("figcaption", {}, photoCaption(profile.nickname))),
      h("div.photo-actions", {},
        roundButton("close", "Close", close),
        button("teal", [picture("🌈"), "Watch the ending"], () => { close(); model.go({ name: "ending" }); }),
      ),
    ),
  );
  document.addEventListener("keydown", onKey);
  host.append(viewer);
}

/** A button with a little copy of the photo on it, or nothing until the game is complete. */
export function photoButton(model: AppModel, host: () => HTMLElement, className = "cream"): HTMLElement | false {
  if (!hasGroupPhoto(model.profile)) return false;
  return button(`${className}.photo-button`, [h("img.photo-thumb", { src: artURL("bg_ending"), alt: "", draggable: "false" }), h("span.photo-word", {}, "Photo")],
    () => showGroupPhoto(model, host()), { "aria-label": "Group photo" });
}
