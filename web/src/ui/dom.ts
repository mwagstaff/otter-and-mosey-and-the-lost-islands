import { artURL } from "../assets";
import { iconName } from "../engine/art";
import { audio } from "../game/audio";

type Child = Node | string | false | null | undefined;
type Props = Record<string, string | number | boolean | undefined | ((event: Event) => void)>;

/**
 * Makes an element. `tag` may carry classes ("div.panel.big"); props starting with "on" are
 * listeners, the rest are attributes.
 */
export function h<K extends keyof HTMLElementTagNameMap>(tag: `${K}${string}`, props: Props = {}, ...children: Child[]): HTMLElementTagNameMap[K] {
  const [name, ...classes] = tag.split(".");
  const element = document.createElement(name as K);
  if (classes.length > 0) element.className = classes.join(" ");
  for (const [key, value] of Object.entries(props)) {
    if (typeof value === "function") element.addEventListener(key.slice(2).toLowerCase(), value);
    else if (value !== undefined && value !== false) element.setAttribute(key, value === true ? "" : String(value));
  }
  element.append(...children.filter((child): child is Node | string => child !== false && child !== null && child !== undefined));
  return element;
}

const shapes: Record<string, string> = {
  play: '<path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z"/>',
  pause: '<rect x="5" y="4" width="5" height="16" rx="1.5"/><rect x="14" y="4" width="5" height="16" rx="1.5"/>',
  speaker: '<path d="M3 9.5v5a1 1 0 0 0 1 1h3l4.3 3.6a1 1 0 0 0 1.7-.8V5.7a1 1 0 0 0-1.7-.8L7 8.5H4a1 1 0 0 0-1 1z"/><path d="M16 8.5a5 5 0 0 1 0 7M18.6 5.8a9 9 0 0 1 0 12.4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  bulb: '<path d="M12 2.5a7 7 0 0 0-4 12.7V17a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1v-1.8a7 7 0 0 0-4-12.7z"/><rect x="9" y="19.5" width="6" height="2.5" rx="1.25"/>',
  again: '<path d="M12 5V2.2a.6.6 0 0 0-1-.45L6.6 5.6a.6.6 0 0 0 0 .9L11 10.3a.6.6 0 0 0 1-.45V7.2a5.4 5.4 0 1 1-5.3 6.5 1.1 1.1 0 0 0-2.2.4A7.6 7.6 0 1 0 12 5z"/>',
  back: '<path d="M14.7 4.3a1.2 1.2 0 0 1 0 1.7L8.7 12l6 6a1.2 1.2 0 0 1-1.7 1.7l-6.9-6.9a1.2 1.2 0 0 1 0-1.7L13 4.3a1.2 1.2 0 0 1 1.7 0z"/>',
  skip: '<path d="M4 5.5v13a1 1 0 0 0 1.6.8l9-6.5a1 1 0 0 0 0-1.6l-9-6.5A1 1 0 0 0 4 5.5z"/><rect x="17" y="4.5" width="3.5" height="15" rx="1.5"/>',
  gear: '<path fill-rule="evenodd" d="M10.3 2.6a1 1 0 0 1 1-.8h1.4a1 1 0 0 1 1 .8l.3 1.7 1.3.6 1.5-1a1 1 0 0 1 1.3.2l1 1a1 1 0 0 1 .1 1.3l-1 1.5.6 1.3 1.7.3a1 1 0 0 1 .8 1v1.4a1 1 0 0 1-.8 1l-1.7.3-.6 1.3 1 1.5a1 1 0 0 1-.1 1.3l-1 1a1 1 0 0 1-1.3.1l-1.5-1-1.3.6-.3 1.7a1 1 0 0 1-1 .8h-1.4a1 1 0 0 1-1-.8l-.3-1.7-1.3-.6-1.5 1a1 1 0 0 1-1.3-.1l-1-1a1 1 0 0 1-.1-1.3l1-1.5-.6-1.3-1.7-.3a1 1 0 0 1-.8-1v-1.4a1 1 0 0 1 .8-1l1.7-.3.6-1.3-1-1.5a1 1 0 0 1 .1-1.3l1-1a1 1 0 0 1 1.3-.1l1.5 1 1.3-.6zM12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z"/>',
  close: '<path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>',
  plus: '<path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>',
  home: '<path d="M11.3 3.3a1 1 0 0 1 1.4 0l8 7.6a1 1 0 0 1-.7 1.7H19v6.9a1 1 0 0 1-1 1h-3.5v-5.5h-5V20.5H6a1 1 0 0 1-1-1v-6.9H4a1 1 0 0 1-.7-1.7z"/>',
  keyboard: '<path d="M4 6h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2zm1.5 3v2h2V9zm3.5 0v2h2V9zm3.5 0v2h2V9zm3.5 0v2h2V9zM7 13.5v2h10v-2z" fill-rule="evenodd"/>',
};

/** A small drawn symbol that takes the colour and size of the text around it. */
export function symbol(name: keyof typeof shapes): HTMLElement {
  const span = h("span.symbol", { "aria-hidden": "true" });
  span.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor">${shapes[name]}</svg>`;
  return span;
}

/** The game's painted picture for an emoji or picture name, falling back to the emoji itself. */
export function picture(key: string, className = "glyph"): HTMLElement {
  const name = iconName(key);
  if (name) return h(`img.${className}`, { src: artURL(name), alt: "", draggable: "false" });
  return h(`span.${className}`, { "aria-hidden": "true" }, key);
}

export function art(name: string, className: string): HTMLImageElement {
  return h(`img.${className}`, { src: artURL(name), alt: "", draggable: "false" }) as HTMLImageElement;
}

/** A chunky button. Plays the tap sound before doing its job. */
export function button(className: string, label: Child[], action: () => void, props: Props = {}): HTMLButtonElement {
  return h(`button.button.${className}`, { type: "button", ...props, onClick: () => { audio.play("tap", 0.7); action(); } }, ...label) as HTMLButtonElement;
}

/** A round button holding just a symbol. */
export function roundButton(name: keyof typeof shapes, label: string, action: () => void, className = ""): HTMLButtonElement {
  return button(`round${className ? "." + className : ""}`, [symbol(name)], action, { "aria-label": label, title: label });
}
