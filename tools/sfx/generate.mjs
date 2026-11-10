// Generates the game's sound effects with ElevenLabs and installs them into the app bundle.
//
//   cd tools/sfx && npm install
//   npm run generate              # make anything missing
//   npm run generate -- pop star  # only these
//   npm run generate -- --force   # regenerate everything
//
// The API key is read from ELEVENLABS_API_KEY, which `npm run generate` loads from the
// git-ignored .env.local at the repository root. It is never written to code or output.
// Trimming and levelling happen here; decoding and AAC encoding use macOS `afconvert`.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const rawDir = join(here, "raw");
const bundleDir = join(here, "../../OtterAndMosey/Resources/Audio");
const sounds = JSON.parse(readFileSync(join(here, "sounds.json"), "utf8"));

const args = process.argv.slice(2);
const force = args.includes("--force");
const wanted = args.filter((arg) => !arg.startsWith("--"));

const client = new ElevenLabsClient();
mkdirSync(rawDir, { recursive: true });

async function generate(name, spec) {
  const audio = await client.textToSoundEffects.convert({
    text: spec.text,
    modelId: "eleven_text_to_sound_v3",
    durationSeconds: spec.seconds,
    promptInfluence: 0.6,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(join(rawDir, `${name}.mp3`), Buffer.concat(chunks));
}

// Trim silence from both ends, set a consistent level, add tiny fades so nothing clicks,
// and encode as mono AAC for the app. Uses macOS afconvert for decoding and encoding.
function install(name, spec) {
  const wav = join(tmpdir(), `lost-islands-${name}.wav`);
  execFileSync("afconvert", ["-f", "WAVE", "-d", "LEI16@44100", "-c", "1", join(rawDir, `${name}.mp3`), wav]);
  const file = readFileSync(wav);
  const dataAt = file.indexOf("data") + 8;
  const samples = new Int16Array(file.buffer, file.byteOffset + dataAt, Math.floor((file.length - dataAt) / 2));

  let peak = 1;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const quiet = peak * 0.012; // about -38 dB below the peak counts as silence
  let start = 0;
  let end = samples.length - 1;
  while (start < end && Math.abs(samples[start]) < quiet) start++;
  while (end > start && Math.abs(samples[end]) < quiet) end--;
  start = Math.max(0, start - 220); // keep 5 ms of lead-in
  end = Math.min(samples.length - 1, end + 2200); // and 50 ms of tail

  const length = end - start + 1;
  const level = (32767 * 10 ** ((spec.gain - 1) / 20)) / peak;
  const fadeIn = 110;
  const fadeOut = Math.min(2200, Math.floor(length / 4));
  const out = Buffer.alloc(44 + length * 2);
  out.write("RIFF", 0); out.writeUInt32LE(36 + length * 2, 4); out.write("WAVEfmt ", 8);
  out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(1, 22);
  out.writeUInt32LE(44100, 24); out.writeUInt32LE(88200, 28); out.writeUInt16LE(2, 32); out.writeUInt16LE(16, 34);
  out.write("data", 36); out.writeUInt32LE(length * 2, 40);
  for (let i = 0; i < length; i++) {
    const fade = Math.min(1, i / fadeIn, (length - 1 - i) / fadeOut);
    out.writeInt16LE(Math.round(Math.max(-32767, Math.min(32767, samples[start + i] * level * fade))), 44 + i * 2);
  }
  writeFileSync(wav, out);
  execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "96000", wav, join(bundleDir, `${name}.m4a`)]);
  rmSync(wav);
  return (length / 44100).toFixed(2);
}

for (const [name, spec] of Object.entries(sounds)) {
  if (wanted.length && !wanted.includes(name)) continue;
  try {
    if (force || !existsSync(join(rawDir, `${name}.mp3`))) {
      await generate(name, spec);
      console.log(`generated ${name}`);
    }
    console.log(`installed ${name} (${install(name, spec)} s)`);
  } catch (error) {
    // Report the failure without echoing request details.
    console.error(`FAILED ${name}: ${error?.statusCode ?? ""} ${error?.message ?? error}`.slice(0, 300));
  }
}
console.log("done");
