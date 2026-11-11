// Composes the game's background music with ElevenLabs Music and installs it as seamless loops.
//
//   cd tools/sfx && npm install
//   npm run music                 # compose anything missing
//   npm run music -- music_bay    # only these
//   npm run music -- --force      # compose everything again (uses credits; see docs/ELEVENLABS.md)
//   npm run music -- --install    # rebuild the loops from ./raw without composing anything
//
// The prompts and lengths are in music.json. The API key is read from ELEVENLABS_API_KEY, loaded
// by `npm run` from the git-ignored .env.local. Decoding and AAC encoding use macOS `afconvert`.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const rawDir = join(here, "raw");
const bundleDir = join(here, "../../OtterAndMosey/Resources/Audio");
const config = JSON.parse(readFileSync(join(here, "music.json"), "utf8"));

const args = process.argv.slice(2);
const flags = new Set(args.filter((arg) => arg.startsWith("--")));
const wanted = args.filter((arg) => !arg.startsWith("--"));

const client = new ElevenLabsClient();
mkdirSync(rawDir, { recursive: true });

async function compose(name, track) {
  const audio = await client.music.compose({
    prompt: `${track.prompt} ${config.style}`,
    musicLengthMs: track.seconds * 1000,
    modelId: config.modelId,
    forceInstrumental: true,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(join(rawDir, `${name}.mp3`), Buffer.concat(chunks));
}

// Turns a composed piece into a loop: trims silence, then blends the last few seconds into the
// first few, so the end of the file runs straight into its start.
function install(name) {
  const rate = 44100;
  const wav = join(tmpdir(), `lost-islands-${name}.wav`);
  execFileSync("afconvert", ["-f", "WAVE", "-d", `LEI16@${rate}`, "-c", "2", join(rawDir, `${name}.mp3`), wav]);
  const file = readFileSync(wav);
  const dataAt = file.indexOf("data") + 8;
  const samples = new Int16Array(file.buffer.slice(file.byteOffset + dataAt, file.byteOffset + dataAt + Math.floor((file.length - dataAt) / 4) * 4));
  const frames = samples.length / 2;

  let peak = 1;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const quiet = peak * 0.02;
  const loud = (frame) => Math.abs(samples[frame * 2]) > quiet || Math.abs(samples[frame * 2 + 1]) > quiet;
  let start = 0;
  let end = frames - 1;
  while (start < end && !loud(start)) start++;
  while (end > start && !loud(end)) end--;
  // Pieces usually end on a fading last note; drop it so the loop does not dip in level.
  end = Math.max(start + rate * 10, end - Math.round(rate * config.dropTailSeconds));

  const fade = Math.round(rate * config.crossfadeSeconds);
  const length = end - start - fade;
  // Level every track to the same average loudness, so no island is louder than another.
  let energy = 0;
  for (let index = (start + fade) * 2; index < end * 2; index++) energy += samples[index] * samples[index];
  const average = Math.sqrt(energy / ((end - start - fade) * 2));
  const gain = Math.min((0.95 * 32767) / peak, (config.loudness * 32767) / average);
  const out = new Int16Array(length * 2);
  for (let frame = 0; frame < length; frame++) {
    // The loop starts `fade` into the piece. Its last `fade` frames blend the piece's ending
    // with the piece's opening, which leads into where the loop starts.
    const intoEnd = frame - (length - fade);
    for (let channel = 0; channel < 2; channel++) {
      let value = samples[(start + fade + frame) * 2 + channel];
      if (intoEnd >= 0) {
        const mix = intoEnd / fade;
        value = value * Math.cos(mix * Math.PI / 2) + samples[(start + intoEnd) * 2 + channel] * Math.sin(mix * Math.PI / 2);
      }
      out[frame * 2 + channel] = Math.max(-32767, Math.min(32767, Math.round(value * gain)));
    }
  }

  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + out.byteLength, 4); header.write("WAVEfmt ", 8);
  header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
  header.writeUInt32LE(rate, 24); header.writeUInt32LE(rate * 4, 28); header.writeUInt16LE(4, 32);
  header.writeUInt16LE(16, 34); header.write("data", 36); header.writeUInt32LE(out.byteLength, 40);
  writeFileSync(wav, Buffer.concat([header, Buffer.from(out.buffer)]));
  execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", String(config.bitrate), wav, join(bundleDir, `${name}.m4a`)]);
  rmSync(wav);
  return (length / rate).toFixed(1);
}

for (const [name, track] of Object.entries(config.tracks)) {
  if (wanted.length && !wanted.includes(name)) continue;
  const raw = join(rawDir, `${name}.mp3`);
  try {
    if (!flags.has("--install") && (flags.has("--force") || !existsSync(raw))) {
      console.log(`composing ${name} (${track.seconds}s)`);
      await compose(name, track);
    }
    if (existsSync(raw)) console.log(`${name}: ${install(name)}s loop`);
  } catch (error) {
    console.error(`FAILED ${name}: ${error?.statusCode ?? ""} ${String(error?.message ?? error).slice(0, 300)}`);
  }
}
const usage = await client.user.subscription.get();
console.log(`credits used: ${usage.characterCount} of ${usage.characterLimit}`);
