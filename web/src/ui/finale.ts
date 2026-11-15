import { artURL } from "../assets";
import type { AppModel } from "../app/model";
import { catalog, hasReward, newProfile, placeBubble, totalStars, trophyCount, type DialogueLine, type Profile, type Rect } from "../core";
import { audio, narrator } from "../game/audio";
import { options } from "../game/options";
import { button, h, picture } from "./dom";
import type { Screen } from "./menus";
import { photoCaption } from "./photo";

// The end-of-game celebration: the crystal comes home, every guardian says thank you, three
// cheers, the player's adventure in numbers, a group photo, and a nudge to keep exploring.
// Nothing spoken uses the player's name (the lines are recorded once); it only appears as text.

interface CastMember {
  art: string;
  talkArt?: string;
  name: string;
  /** Centre, bottom and height, as percentages of the stage. */
  x: number;
  bottom: number;
  height: number;
  enter: "grow" | "splash" | "swoop" | "float" | "bounce" | "sparkle" | "run" | "swim";
  layer: number;
  line?: DialogueLine;
}

/** Where each guardian stands, and how it arrives, keyed by island. */
const guardianPlaces: Record<string, Omit<CastMember, "art" | "name" | "line">> = {
  woods: { x: 12, bottom: 16, height: 56, enter: "grow", layer: 1 },
  bay: { x: 24, bottom: 4, height: 30, enter: "splash", layer: 4 },
  dragon: { x: 75, bottom: 9, height: 42, enter: "swoop", layer: 3 },
  cloud: { x: 84, bottom: 60, height: 26, enter: "float", layer: 2 },
  candy: { x: 89, bottom: 2, height: 32, enter: "bounce", layer: 5 },
  star: { x: 34, bottom: 3, height: 20, enter: "sparkle", layer: 6 },
};

/** What is still out there to find, for the last card. */
export function stillToFind(profile: Profile): { trophies: number; stars: number; pets: number } {
  const count = trophyCount(profile);
  return {
    trophies: count.total - count.won,
    stars: catalog.allLevels.length * 3 - totalStars(profile),
    pets: catalog.rewards.filter((reward) => reward.kind === "pet" && !hasReward(profile, reward.id)).length,
  };
}

class Cancelled extends Error {}

export function finaleScreen(model: AppModel, from: { fromGrownUps?: boolean; profileID?: string } = {}): Screen {
  // From the grown-ups' area it plays for the child chosen there; otherwise for the active player.
  const profile = (from.fromGrownUps ? model.save.profiles.find((each) => each.id === from.profileID) : undefined)
    ?? model.profile ?? newProfile("Explorer");
  const name = profile.nickname || "Explorer";
  const voiced = model.settings.characterVoices;
  const script = catalog.finale;
  const url = (art: string) => artURL(art);

  // ---------- the stage ----------
  const stage = h("div.f-stage", { "aria-live": "polite" });
  const layer = (className: string) => h(`div.f-layer.${className}`);
  const night = layer("f-night");
  night.append(layer("f-stars"));
  const beach = layer("f-beach");
  beach.style.backgroundImage = `url("${url("bg_title")}")`;
  const rays = h("div.f-rays");
  const shardBox = h("div");
  const crystal = h("img.f-crystal", { src: url("crystal_whole"), alt: "" });
  const flash = layer("f-flash");
  const castBox = h("div");
  const canvas = h("canvas.f-confetti") as HTMLCanvasElement;
  const dim = layer("f-dim");
  const caption = h("p.f-caption");
  const hooray = h("p.f-hooray", { "aria-hidden": "true" }, "Hooray!");
  const sash = h("p.f-sash", {}, `★ ${name} ★`);
  const bubble = h("div.f-bubble");

  const guardians = catalog.islands.map((island) => ({ id: island.id, place: guardianPlaces[island.id], island }))
    .filter((each) => each.place !== undefined);
  const cast: Record<string, CastMember> = {
    otter: { art: "otter_cheer", talkArt: "otter_talk", name: "Otter", x: 45, bottom: 3, height: 36, enter: "run", layer: 7 },
    mosey: { art: "mosey_cheer", talkArt: "mosey_talk", name: "Mosey", x: 60, bottom: 1, height: 34, enter: "swim", layer: 7 },
  };
  for (const { id, place, island } of guardians) {
    cast[id] = { ...place!, art: `guardian_${island.guardian.kind}_happy`, name: island.guardian.name, line: script.guardians[id] };
  }
  const people: Record<string, HTMLElement> = {};
  for (const [id, member] of Object.entries(cast)) {
    const figure = h(`div.f-char.f-enter-${member.enter}`, {
      style: `left:${member.x}%;bottom:${member.bottom}%;height:${member.height}%;z-index:${member.layer}`,
    }, h("img", { src: url(member.art), alt: "" }));
    castBox.append(figure);
    people[id] = figure;
  }
  castBox.append(bubble);

  // ---------- the panels ----------
  const learner = profile.learner;
  const trophies = trophyCount(profile);
  const tally: [string, number, string][] = [
    ["✨", learner.answerCount, "questions answered"],
    ["⭐️", totalStars(profile), "stars won"],
    ["🏅", trophies.won, "trophies"],
    ["🎒", catalog.rewards.filter((reward) => hasReward(profile, reward.id)).length, "treasures"],
    ["🔥", profile.bestCombo, "best streak"],
  ];
  const tiles = tally.map(([icon, value, label]) => h("div.f-tile", { "data-to": String(value) }, picture(icon, "f-tile-art"), h("strong", {}, "0"), h("span", {}, label)));
  const stats = h("div.f-panel.f-stats", {}, h("h2", {}, `${name}'s adventure`), h("div.f-tally", {}, ...tiles));
  const medal = h("div.f-medal", {},
    h("img", { src: url("trophy_champion"), alt: "" }),
    h("div.f-ribbon", {}, "Rainbow Crystal Champion"),
    h("div.f-who", {}, `Awarded to ${name}`),
  );
  const countdown = h("p.f-countdown", { "aria-hidden": "true" });
  const polaroid = h("figure.f-polaroid", {}, h("img", { src: url("bg_ending"), alt: "Everyone together on the beach" }), h("figcaption", {}, photoCaption(name)));
  const saved = h("p.f-saved", {}, picture("🎒"), "Photo saved to Treasures");

  const left = stillToFind(profile);
  const pills = [
    left.trophies > 0 && h("span.f-pill", {}, picture("🏅"), left.trophies === 1 ? "1 trophy to find" : `${left.trophies} trophies to find`),
    left.stars > 0 && h("span.f-pill", {}, picture("⭐️"), left.stars === 1 ? "1 more star to win" : `${left.stars} more stars to win`),
    left.pets > 0 && h("span.f-pill", {}, picture("🐾"), left.pets === 1 ? "1 pet waiting" : `${left.pets} pets waiting`),
  ].filter((pill): pill is HTMLElement => pill !== false);
  const everything = pills.length === 0;
  const next = h("div.f-panel.f-next", {},
    h("h2", {}, everything ? "You found everything!" : "The adventure goes on!"),
    h("p", {}, everything
      ? "Every trophy, every star and every pet. You're a true Lost Islands legend! Play any level again, just for fun."
      : "Every island is open. Play any level again to find what's still hiding."),
    pills.length > 0 && h("div.f-pills", {}, ...pills),
    from.fromGrownUps
      ? h("div.f-buttons", {},
        button("teal.big", ["Back to grown-ups"], () => model.go({ name: "parent" })),
        button("gold.big", [picture("🌈"), "Watch again"], () => model.watchEnding(from.profileID)),
      )
      : h("div.f-buttons", {},
        button("teal.big", [picture("🗺️"), "Back to the map"], () => model.go({ name: "map" })),
        button("gold.big", [picture("trophy_champion"), "See my trophies"], () => model.openTrophies()),
      ),
  );
  const skip = button("cream.f-skip", ["Skip"], () => play(beats.length - 1));
  const hint = h("p.f-hint", {}, "Tap to speed up");

  stage.append(night, beach, rays, shardBox, crystal, flash, castBox, canvas, dim, caption, sash, hooray, stats, medal, countdown, polaroid, saved, next, skip, hint);
  const element = h("section.screen.finale", {}, stage);

  // The stage fills the screen, so the beach picture is cropped differently on each shape of
  // screen. Work out where its castle crystal lands, for the flying crystal and the colour reveal.
  function placeHome(): void {
    const width = stage.clientWidth;
    const height = stage.clientHeight;
    if (!width || !height) return;
    const scale = Math.max(width / 1536, height / 1024);
    const left = (width - 1536 * scale) / 2;
    const top = (height - 1024 * scale) / 2;
    const at = (x: number, y: number) => [((left + x * 1536 * scale) / width) * 100, ((top + y * 1024 * scale) / height) * 100];
    const [hx, hy] = at(0.653, 0.106);
    const [rx, ry] = at(0.65, 0.14);
    stage.style.setProperty("--hx", `${hx}%`);
    stage.style.setProperty("--hy", `${hy}%`);
    stage.style.setProperty("--rx", `${rx}%`);
    stage.style.setProperty("--ry", `${ry}%`);
    stage.style.setProperty("--hw", `${0.055 * 1536 * scale}px`);
  }
  const resizing = new ResizeObserver(placeHome);
  resizing.observe(stage);

  // ---------- timing ----------
  let run = 0;
  let alive = true;
  let hurry: (() => void) | undefined;
  let tapped = false;

  function wait(ms: number, token: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const done = () => {
        window.clearTimeout(timer);
        if (hurry === done) hurry = undefined;
        if (alive && token === run) resolve();
        else reject(new Cancelled());
      };
      const timer = window.setTimeout(done, options.reducedMotion ? Math.min(ms, 600) : ms);
      hurry = done;
    });
  }
  stage.addEventListener("click", (event) => {
    if ((event.target as HTMLElement).closest("button")) return;
    tapped = true;
    hurry?.();
  });

  /** Says a line in a speech bubble over its speaker, waiting for the recording (or a tap). */
  async function say(id: string, line: DialogueLine, token: number, least?: number): Promise<void> {
    const member = cast[id]!;
    const figure = people[id]!;
    const image = figure.querySelector("img")!;
    Object.values(people).forEach((each) => each.classList.toggle("talking", each === figure));
    if (member.talkArt) image.src = url(member.talkArt);
    bubble.replaceChildren(h("b", {}, member.name), line.text);
    // Never over the speaker: measure the bubble, then find room beside their picture.
    const area = { width: stage.clientWidth, height: stage.clientHeight };
    const pictureHeight = (member.height / 100) * area.height;
    const ratio = image.naturalWidth && image.naturalHeight ? image.naturalWidth / image.naturalHeight : 1;
    const speaker: Rect = {
      x: (member.x / 100) * area.width - (pictureHeight * ratio) / 2, y: (1 - (member.bottom + member.height) / 100) * area.height,
      width: pictureHeight * ratio, height: pictureHeight,
    };
    const box = stage.getBoundingClientRect();
    const avoid = [skip, sash].filter((each) => !each.hidden && getComputedStyle(each).opacity !== "0").map((each) => {
      const rect = each.getBoundingClientRect();
      return { x: rect.left - box.left, y: rect.top - box.top, width: rect.width, height: rect.height };
    });
    const spot = placeBubble(area, speaker, { width: bubble.offsetWidth, height: bubble.offsetHeight }, { margin: area.width * 0.012, gap: area.height * 0.025, avoid });
    bubble.classList.remove("tail-down", "tail-up", "tail-left", "tail-right");
    bubble.classList.add(`tail-${spot.tail}`);
    bubble.style.left = `${spot.x}px`;
    bubble.style.top = `${spot.y}px`;
    bubble.style.setProperty("--tail", `${spot.tailAt}px`);
    restart(bubble, "on");
    tapped = false;
    narrator.speakLine(line, voiced);
    try {
      await wait(least ?? 900 + line.text.length * 40, token);
      while (!tapped && narrator.speaking) await wait(120, token);
      await wait(250, token);
    } finally {
      narrator.stop();
      figure.classList.remove("talking");
      if (member.talkArt) image.src = url(member.art);
    }
  }
  /** A story line: read by the narrator, shown as a caption. */
  function show(line: DialogueLine | undefined): void {
    if (!line) return;
    caption.textContent = line.text;
    restart(caption, "on");
    narrator.speakLine(line, voiced);
  }
  async function tell(line: DialogueLine | undefined, token: number, least = 2400): Promise<void> {
    if (!line) return;
    show(line);
    tapped = false;
    await wait(least, token);
    while (!tapped && narrator.speaking) await wait(120, token);
  }
  const hush = () => bubble.classList.remove("on");
  const enter = (id: string) => people[id]?.classList.add("in");
  function restart(target: HTMLElement, className: string): void {
    target.classList.remove(className);
    void target.offsetWidth;
    target.classList.add(className);
  }
  function jumpAll(): void {
    Object.values(people).forEach((figure, index) => {
      figure.classList.remove("jump", "instant");
      figure.style.animationDelay = "";
      void figure.offsetWidth;
      figure.style.animationDelay = `${index * 40}ms`;
      figure.classList.add("jump");
    });
  }

  // ---------- confetti ----------
  const context = canvas.getContext("2d");
  const colours = [...catalog.islands.map((island) => island.colour), "#FFC83D", "#FFFFFF"];
  let bits: { x: number; y: number; vx: number; vy: number; r: number; vr: number; w: number; c: string; life: number }[] = [];
  let frame = 0;
  function confetti(count = 140, x = 0.5, y = 0.35): void {
    if (options.reducedMotion) count = Math.round(count / 3);
    const box = stage.getBoundingClientRect();
    const ratio = window.devicePixelRatio || 1;
    canvas.width = box.width * ratio;
    canvas.height = box.height * ratio;
    for (let index = 0; index < count; index += 1) {
      const angle = Math.random() * Math.PI * 2;
      const speed = (4 + Math.random() * 9) * ratio;
      bits.push({
        x: x * canvas.width, y: y * canvas.height, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 6 * ratio,
        r: Math.random() * 6, vr: Math.random() * 0.3 - 0.15, w: (6 + Math.random() * 6) * ratio, c: colours[index % colours.length]!, life: 1,
      });
    }
  }
  function tick(): void {
    if (!alive || !context) return;
    const ratio = window.devicePixelRatio || 1;
    context.clearRect(0, 0, canvas.width, canvas.height);
    bits = bits.filter((bit) => bit.y < canvas.height + 40 && bit.life > 0);
    for (const bit of bits) {
      bit.vy += 0.25 * ratio;
      bit.vx *= 0.985;
      bit.x += bit.vx;
      bit.y += bit.vy;
      bit.r += bit.vr;
      bit.life -= 0.004;
      context.save();
      context.translate(bit.x, bit.y);
      context.rotate(bit.r);
      context.globalAlpha = Math.min(1, bit.life * 2);
      context.fillStyle = bit.c;
      context.fillRect(-bit.w / 2, -bit.w / 4, bit.w, bit.w / 2);
      context.restore();
    }
    frame = requestAnimationFrame(tick);
  }
  frame = requestAnimationFrame(tick);

  // ---------- jumping straight to a beat ----------
  function reset(beat: number): void {
    hush();
    narrator.stop();
    caption.classList.remove("on");
    bits = [];
    shardBox.replaceChildren();
    [dim, stats, next, saved, sash, polaroid].forEach((each) => each.classList.remove("on"));
    medal.className = "f-medal";
    tiles.forEach((tile) => { tile.classList.remove("on"); tile.querySelector("strong")!.textContent = "0"; });
    const after = (index: number) => beat > index;
    night.classList.toggle("gone", after(1));
    beach.classList.toggle("open", after(1));
    crystal.classList.toggle("on", after(0));
    rays.classList.toggle("on", after(0));
    crystal.classList.toggle("home", after(1));
    rays.classList.toggle("home", after(1));
    Object.values(people).forEach((figure) => figure.classList.remove("in", "jump", "talking", "dim", "instant"));
    if (after(2)) guardians.forEach(({ id }) => people[id]!.classList.add("in", "instant"));
    if (after(3)) ["otter", "mosey"].forEach((id) => people[id]!.classList.add("in", "instant"));
  }

  // ---------- the beats ----------
  const beats: ((token: number) => Promise<void>)[] = [
    // The crystal comes home.
    async (token) => {
      show(script.opening[0]);
      await wait(1200, token);
      const starts = [[-10, 10], [110, 5], [-10, 70], [110, 75], [30, 115], [70, -15]] as const;
      const shards = catalog.islands.map((island, index) => {
        const shard = h("img.f-shard", { src: url("crystal_shard"), alt: "" });
        shard.style.filter = `drop-shadow(0 0 1.2cqw ${island.colour}) drop-shadow(0 0 2.4cqw ${island.colour})`;
        shardBox.append(shard);
        const [sx, sy] = starts[index % starts.length]!;
        const angle = (index / catalog.islands.length) * Math.PI * 2;
        shard.animate([
          { left: `${sx}cqw`, top: `${sy}cqh`, opacity: 0, rotate: "-160deg" },
          { left: `${50 + Math.cos(angle) * 14}cqw`, top: `${36 + Math.sin(angle) * 18}cqh`, opacity: 1, rotate: "0deg", offset: 0.55 },
          { left: `${50 + Math.cos(angle + 2) * 8}cqw`, top: `${36 + Math.sin(angle + 2) * 10}cqh`, opacity: 1, rotate: "220deg", offset: 0.85 },
          { left: "50cqw", top: "36cqh", opacity: 0, rotate: "360deg", scale: 0.4 },
        ], { duration: options.reducedMotion ? 600 : 3000, delay: index * 120, easing: "cubic-bezier(.45,0,.4,1)", fill: "forwards" });
        return shard;
      });
      audio.play("whoosh");
      await wait(3600, token);
      restart(flash, "go");
      shards.forEach((shard) => shard.remove());
      crystal.classList.add("on");
      rays.classList.add("on");
      audio.play("crystal");
      confetti(90, 0.5, 0.3);
      await tell(script.opening[1], token, 2600);
    },
    // Colour returns.
    async (token) => {
      caption.classList.remove("on");
      night.classList.add("gone");
      beach.classList.add("open");
      crystal.classList.add("home");
      rays.classList.add("home");
      audio.play("unlock");
      await wait(1600, token);
      await tell(script.opening[2], token, 2600);
      caption.classList.remove("on");
    },
    // Each guardian arrives and says thank you.
    async (token) => {
      for (const { id } of guardians) {
        enter(id);
        audio.play("pop", 0.8);
        if (cast[id]!.enter === "splash" || cast[id]!.enter === "sparkle") confetti(30, cast[id]!.x / 100, 0.8);
        await wait(700, token);
        const line = cast[id]!.line;
        if (line) await say(id, line, token);
        hush();
        await wait(250, token);
      }
    },
    // Otter and Mosey's thank you, then three cheers.
    async (token) => {
      enter("otter");
      await wait(500, token);
      enter("mosey");
      await wait(1000, token);
      const [first, second, cheers] = script.thanks;
      if (first) await say("otter", first, token);
      if (second) await say("mosey", second, token);
      sash.classList.add("on");
      if (cheers) await say("otter", cheers, token, 1800);
      hush();
      for (let index = 0; index < 3; index += 1) {
        restart(hooray, "go");
        jumpAll();
        // The whole cast shouts, recorded together as one sound.
        audio.play("cheer");
        if (index === 2) audio.play("victory", 0.5);
        confetti(120, 0.2 + index * 0.3, 0.4);
        await wait(1150, token);
      }
      await wait(600, token);
      sash.classList.remove("on");
    },
    // The adventure in numbers, then the champion's trophy.
    async (token) => {
      dim.classList.add("on");
      stats.classList.add("on");
      await wait(600, token);
      for (const tile of tiles) {
        tile.classList.add("on");
        audio.play("pop", 0.6);
        const number = tile.querySelector("strong")!;
        const target = Number(tile.dataset.to);
        const began = performance.now();
        const count = (now: number) => {
          const progress = Math.min(1, (now - began) / 900);
          number.textContent = Math.round(target * (1 - (1 - progress) ** 3)).toLocaleString("en-GB");
          if (progress < 1 && run === token && alive) requestAnimationFrame(count);
        };
        requestAnimationFrame(count);
        window.setTimeout(() => { if (run === token) number.textContent = target.toLocaleString("en-GB"); }, 1000);
        await wait(450, token);
      }
      await wait(2000, token);
      stats.classList.remove("on");
      restart(medal, "go");
      audio.play("levelComplete");
      confetti(160, 0.5, 0.45);
      await wait(3400, token);
      medal.classList.add("out");
      dim.classList.remove("on");
      await wait(500, token);
    },
    // Group photo.
    async (token) => {
      const [cheese] = script.photo;
      if (cheese) await say("mosey", cheese, token, 2200);
      hush();
      // Otter counts down; the big numbers match the recording.
      for (const [index, number] of ["3", "2", "1"].entries()) {
        countdown.textContent = number;
        restart(countdown, "go");
        const spoken = script.countdown[index];
        if (spoken) narrator.speakLine(spoken, voiced);
        else audio.play("tap");
        await wait(900, token);
      }
      narrator.stop();
      restart(flash, "go");
      audio.play("portal");
      dim.classList.add("on");
      polaroid.classList.add("on");
      await wait(1200, token);
      saved.classList.add("on");
      await wait(3200, token);
      polaroid.classList.remove("on");
      saved.classList.remove("on");
      dim.classList.remove("on");
      await wait(600, token);
    },
    // The adventure goes on.
    async (token) => {
      const [otter, mosey] = script.after;
      if (otter) await say("otter", otter, token);
      if (mosey) await say("mosey", mosey, token);
      hush();
      Object.values(people).forEach((figure) => figure.classList.add("dim"));
      next.classList.add("on");
      skip.hidden = true;
      hint.hidden = true;
      next.querySelector("button")?.focus();
    },
  ];

  async function play(from: number): Promise<void> {
    run += 1;
    const token = run;
    hurry?.();
    reset(from);
    skip.hidden = false;
    hint.hidden = false;
    for (let index = from; index < beats.length; index += 1) {
      try {
        await beats[index]!(token);
      } catch (error) {
        if (error instanceof Cancelled) return;
        throw error;
      }
      if (token !== run || !alive) return;
    }
  }

  audio.playMusic("music_title");
  window.setTimeout(() => void play(0), 300);

  return {
    element,
    destroy() {
      alive = false;
      run += 1;
      hurry?.();
      cancelAnimationFrame(frame);
      resizing.disconnect();
      narrator.stop();
    },
  };
}
