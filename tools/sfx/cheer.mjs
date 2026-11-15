// Records the whole cast shouting "Hooray!" (Otter, Mosey and the six guardians, each in their
// own voice) and mixes the takes into one group cheer, played three times in the finale.
//
//   cd tools/sfx && npm run cheer            # record any missing takes, then mix
//   npm run cheer -- --force                 # record every take again
//
// Takes are kept in ./raw/cheer; the mix goes to OtterAndMosey/Resources/Audio/cheer.m4a, which
// web/scripts/sync-assets.mjs copies to the web game like every other sound effect.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(here, "narration.config.json"), "utf8"));
const takes = join(here, "raw", "cheer");
const output = join(here, "../../OtterAndMosey/Resources/Audio/cheer.m4a");
const force = process.argv.includes("--force");
mkdirSync(takes, { recursive: true });

const client = new ElevenLabsClient();
const text = "[cheering loudly] Hooray!";
const files = [];
for (const [name, character] of Object.entries(config.characters)) {
  const file = join(takes, `${name}.mp3`);
  files.push(file);
  if (existsSync(file) && !force) continue;
  const audio = await client.textToSpeech.convert(character.voiceId, {
    text, modelId: config.modelId, outputFormat: config.outputFormat, languageCode: "en", voiceSettings: character.voiceSettings,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(file, Buffer.concat(chunks));
  console.log("recorded", name);
}

// Each voice starts a few milliseconds apart, as a real crowd would. macOS's afconvert decodes
// the takes and encodes the result (mono AAC, 44.1 kHz, like the other sound effects); the
// mixing itself is plain arithmetic here, so no other audio tools are needed.
const rate = 44100;
const delays = [0, 40, 15, 70, 30, 55, 10, 85];
const work = join(takes, "work");
mkdirSync(work, { recursive: true });

function decode(file) {
  const wav = join(work, `${file.split("/").pop()}.wav`);
  execFileSync("afconvert", ["-f", "WAVE", "-d", `LEI16@${rate}`, "-c", "1", file, wav]);
  const data = readFileSync(wav);
  let offset = 12;
  while (data.toString("ascii", offset, offset + 4) !== "data") offset += 8 + data.readUInt32LE(offset + 4);
  const length = data.readUInt32LE(offset + 4) / 2;
  const samples = new Float32Array(length);
  for (let index = 0; index < length; index++) samples[index] = data.readInt16LE(offset + 8 + index * 2) / 32768;
  // Drop the quiet lead-in so every voice shouts at once.
  const start = samples.findIndex((value) => Math.abs(value) > 0.03);
  return samples.subarray(Math.max(0, start));
}

const length = Math.round(rate * 1.8);
const mix = new Float32Array(length);
files.forEach((file, index) => {
  const voice = decode(file);
  const delay = Math.round((delays[index % delays.length] / 1000) * rate);
  for (let at = 0; at < voice.length && at + delay < length; at++) mix[at + delay] += voice[at];
});
// Level to just under full scale, then fade the last 0.4 seconds.
const peak = mix.reduce((most, value) => Math.max(most, Math.abs(value)), 0) || 1;
const fade = Math.round(rate * 0.4);
const pcm = Buffer.alloc(44 + length * 2);
pcm.write("RIFF", 0); pcm.writeUInt32LE(36 + length * 2, 4); pcm.write("WAVE", 8);
pcm.write("fmt ", 12); pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22);
pcm.writeUInt32LE(rate, 24); pcm.writeUInt32LE(rate * 2, 28); pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34);
pcm.write("data", 36); pcm.writeUInt32LE(length * 2, 40);
for (let at = 0; at < length; at++) {
  const gain = at > length - fade ? (length - at) / fade : 1;
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, (mix[at] / peak) * 0.85 * gain)) * 32767), 44 + at * 2);
}
const mixed = join(work, "cheer.wav");
writeFileSync(mixed, pcm);
execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "96000", mixed, output]);
console.log("mixed", files.length, "takes into", output);
