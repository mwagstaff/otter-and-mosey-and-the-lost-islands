import { artURL } from "../assets";

import { audio } from "../game/audio";

const random = (min: number, max: number) => min + Math.random() * (max - min);
function shuffleBag<T>(choices: readonly T[]) {
  let remaining: T[] = [], previous: T;
  return () => {
    if (!remaining.length) {
      remaining = [...choices];
      for (let i = remaining.length - 1; i > 0; --i) {
        const j = Math.floor(random(0, i + 1));
        [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
      }
      if (remaining.at(-1) === previous) remaining.reverse();
    }
    return previous = remaining.pop()!;
  };
}

const birds = [
  { art: "bird_macaw", width: 44, beat: 0.16, glide: 0.8, count: 4 },
  { art: "bird_tropicbird", width: 40, beat: 0.13, glide: 2.1, count: 3 },
  { art: "bird_bee_eater", width: 33, beat: 0.09, glide: 0.65, count: 6 },
];
const swimmers = ["lagoon_bottlenose", "lagoon_spotted_dolphin", "lagoon_snapper", "lagoon_flying_fish"];

/** Coordinates are top-left relative to the 900 x 600 lagoon painting. */
export function islandWildlife() {
  const nextBird = shuffleBag(birds), nextSwimmer = shuffleBag(swimmers);
  const images = new Map<string, HTMLImageElement>();
  const actors: ((ctx: CanvasRenderingContext2D, time: number) => boolean)[] = [];
  type Animal = { x: number; y: number; kind: "bird" | "swimmer"; greeted: boolean };
  const visible: Animal[] = [];
  const calls: { x: number; y: number; caption: string; start: number }[] = [];
  let birdAt = random(2, 6), swimAt = random(6, 14);
  function image(name: string) {
    let img = images.get(name);
    if (!img) {
      img = new Image();
      img.src = artURL(name);
      images.set(name, img);
    }
    return img;
  }
  function flock(start: number) {
    const bird = nextBird(), img = image(bird.art), dir = Math.random() < 0.5 ? 1 : -1;
    const altitude = random(115, 180), bank = random(-26, 26), phase = random(0, 6);
    const duration = random(8, 12), spacing = random(25, 39);
    const count = Math.floor(random(bird.art === "bird_bee_eater" ? 2 : 1, bird.count + 1));
    for (let i = 0; i < count; i++) {
      const offset = random(-6, 6) + i * 2, width = bird.width * random(0.85, 1.15);
      const delay = random(0, 0.9), beat = bird.beat * random(0.9, 1.1);
      const animal: Animal = { x: 0, y: 0, kind: "bird", greeted: false };
      actors.push((ctx, now) => {
        const age = now - start, u = age / duration;
        if (u > 1) return false;
        if (!img.naturalWidth) return true;
        const tile = img.naturalWidth / 3, height = width * img.naturalHeight / tile;
        const step = Math.floor(((age + delay) % (beat * 4 + bird.glide)) / beat);
        const frame = step === 0 ? 0 : step === 2 ? 2 : 1;
        ctx.save();
        animal.x = (dir > 0 ? -25 : 925) + dir * ((950 + count * spacing) * u - i * spacing);
        animal.y = altitude + offset + bank * u + 13 * Math.sin(u * 6 + phase + i * 0.28);
        visible.push(animal);
        ctx.translate(animal.x, animal.y);
        ctx.scale(dir, 1);
        ctx.drawImage(img, tile * frame, 0, tile, img.naturalHeight, -width / 2, -height / 2, width, height);
        ctx.restore();
        return true;
      });
    }
  }
  function breach(start: number) {
    const species = nextSwimmer(), img = image(species), large = swimmers.indexOf(species) < 2;
    const x = random(248, 622), y = random(367, 409), dir = Math.random() < 0.5 ? 1 : -1;
    const width = large ? random(38, 46) : random(25, 32), range = random(32, 57);
    const duration = large ? random(1.3, 1.65) : random(0.95, 1.24), height = large ? random(46, 62) : random(34, 45);
    const animal: Animal = { x, y, kind: "swimmer", greeted: false };
    const drops = Array.from({ length: large ? 10 : 6 }, () => ({ dx: random(-17, 17), rise: random(4, 13) }));
    actors.push((ctx, now) => {
      const u = (now - start) / duration, splash = now - start - duration * 0.87;
      if (splash > 0.8) return false;
      if (u < 1 && img.naturalWidth) {
        ctx.save();
        ctx.beginPath(); ctx.rect(x - 90, y - 100, 180, 100); ctx.clip();
        animal.x = x + dir * range * (1 - 2 * u);
        animal.y = y + 24 - height * 4 * u * (1 - u);
        if (animal.y <= y + 4) visible.push(animal);
        ctx.translate(animal.x, animal.y);
        ctx.rotate(dir * 0.8 * (1 - 2 * u)); ctx.scale(dir, 1);
        const h = width * img.naturalHeight / img.naturalWidth;
        ctx.drawImage(img, -width / 2, -h / 2, width, h);
        ctx.restore();
      }
      if (splash >= 0) {
        ctx.save(); ctx.translate(x - dir * range * 0.74, y);
        ctx.globalAlpha = 0.8 * (1 - splash / 0.8); ctx.strokeStyle = ctx.fillStyle = "white";
        ctx.beginPath(); ctx.ellipse(0, 0, 6 + 14 * splash, 1.4 + 3 * splash, 0, 0, 2 * Math.PI); ctx.stroke();
        const f = splash / 0.48;
        if (f < 1) for (const drop of drops) ctx.fillRect(drop.dx * f, -4 * drop.rise * f * (1 - f), 1.5, 2);
        ctx.restore();
      }
      return true;
    });
  }
  function tap(x: number, y: number, time: number) {
    let nearest: Animal | undefined, best = 31;
    for (const animal of visible) {
      const distance = Math.hypot(animal.x - x, animal.y - y);
      if (distance < best) { nearest = animal; best = distance; }
    }
    if (!nearest || nearest.greeted) return;
    nearest.greeted = true;
    const bird = nearest.kind === "bird";
    audio.play(bird ? "chirp" : "glub", 0.8);
    calls.push({x: nearest.x, y: nearest.y - 18, caption: bird ? "Squawk!" : "Glub glub!", start: time});
  }
  function draw(ctx: CanvasRenderingContext2D, time: number) {
    visible.length = 0;
    if (time >= birdAt) { flock(time); birdAt = time + random(18, 32); }
    if (time >= swimAt) { breach(time); swimAt = time + random(13, 27); }
    for (let i = actors.length - 1; i >= 0; i--) if (!actors[i](ctx, time)) actors.splice(i, 1);
    ctx.save();
    ctx.font = "bold 17px Nunito, sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "white";
    ctx.strokeStyle = "#25434a";
    ctx.lineWidth = 3;
    for (let i = calls.length - 1; i >= 0; --i) {
      const call = calls[i], age = time - call.start;
      if (age >= 1) { calls.splice(i, 1); continue; }
      ctx.globalAlpha = Math.min(1, (1 - age) * 4);
      const x = Math.max(55, Math.min(845, call.x)), y = call.y - 6 * age;
      ctx.strokeText(call.caption, x, y);
      ctx.fillText(call.caption, x, y);
    }
    ctx.restore();
  }
  return { draw, tap };
}
