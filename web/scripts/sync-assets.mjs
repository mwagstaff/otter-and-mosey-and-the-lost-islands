// Copies the iOS game's art, sound and narration into web/public/assets and writes a manifest
// of what exists. The iOS project stays the single source: nothing here is edited by hand,
// and the copies are git-ignored. Runs before `npm run dev` and `npm run build`.
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const ios = join(web, "..", "OtterAndMosey");
const out = join(web, "public", "assets");

let copied = 0;
let removed = 0;

/** Copies `from` to `to` unless an identical-looking copy is already there. */
function copy(from, to) {
  const source = statSync(from);
  if (existsSync(to)) {
    const target = statSync(to);
    if (target.size === source.size && target.mtimeMs >= source.mtimeMs) return;
  }
  copyFileSync(from, to);
  copied += 1;
}

/** Deletes anything in `folder` that the iOS project no longer has. */
function prune(folder, keep) {
  for (const name of readdirSync(folder)) {
    if (!keep.has(name)) {
      rmSync(join(folder, name), { recursive: true });
      removed += 1;
    }
  }
}

function folder(name) {
  const path = join(out, name);
  mkdirSync(path, { recursive: true });
  return path;
}

// Art: one file per image set, named after the set.
const art = {};
const artOut = folder("art");
const catalogue = join(ios, "Assets.xcassets");
for (const set of readdirSync(catalogue).filter((name) => name.endsWith(".imageset")).sort()) {
  const contents = JSON.parse(readFileSync(join(catalogue, set, "Contents.json"), "utf8"));
  const file = contents.images?.find((image) => image.filename)?.filename;
  if (!file) continue;
  const name = set.replace(/\.imageset$/, "");
  const target = name + extname(file).toLowerCase();
  copy(join(catalogue, set, file), join(artOut, target));
  art[name] = `art/${target}`;
}
prune(artOut, new Set(Object.values(art).map((path) => path.slice(4))));

// Sound effects and music, keyed by file name without the extension.
const audio = {};
const audioOut = folder("audio");
const audioIn = join(ios, "Resources", "Audio");
for (const file of readdirSync(audioIn).filter((name) => /\.(m4a|mp3)$/.test(name)).sort()) {
  copy(join(audioIn, file), join(audioOut, file));
  audio[file.replace(/\.[^.]+$/, "")] = `audio/${file}`;
}
prune(audioOut, new Set(Object.values(audio).map((path) => path.slice(6))));

// Narration and dialogue: `say_<key>.mp3`. Only the keys go in the manifest.
const speech = [];
const speechOut = folder("speech");
const speechIn = join(ios, "Resources", "Speech");
const speechFiles = readdirSync(speechIn).filter((name) => /^say_.+\.mp3$/.test(name)).sort();
for (const file of speechFiles) {
  copy(join(speechIn, file), join(speechOut, file));
  speech.push(file.slice(4, -4));
}
prune(speechOut, new Set(speechFiles));

const generated = join(web, "src", "generated");
mkdirSync(generated, { recursive: true });
const manifest = JSON.stringify({ art, audio, speech }, null, 1) + "\n";
const manifestPath = join(generated, "assets.json");
if (!existsSync(manifestPath) || readFileSync(manifestPath, "utf8") !== manifest) writeFileSync(manifestPath, manifest);

console.log(
  `assets: ${Object.keys(art).length} pictures, ${Object.keys(audio).length} sounds, ${speech.length} voice clips` +
    ` (${copied} copied, ${removed} removed)`,
);
