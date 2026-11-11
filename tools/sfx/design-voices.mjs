// Designs the two character voices with ElevenLabs Voice Design and saves previews to ./samples.
// ElevenLabs does not allow designing children's voices, so both are described as adult voice
// actresses performing youthful cartoon characters.
//
//   node --env-file=../../.env.local design-voices.mjs                 # make previews for both characters
//   node --env-file=../../.env.local design-voices.mjs --keep otter 2  # save preview 2 as Otter's voice
//
// Keeping a preview creates the voice in the ElevenLabs account and writes its id into
// narration.config.json. Preview ids only last a short while, so keep one soon after designing.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const samples = join(here, "samples");
const configPath = join(here, "narration.config.json");
const previewsPath = join(samples, "design.json");
const client = new ElevenLabsClient();

const characters = {
  otter: {
    name: "Otter (Lost Islands)",
    description: "An adult British voice actress in her twenties performing a cute cartoon animal for a family animated film. Bright, bubbly, light and high in pitch, excitable and giggly, bursting with energy, mischief and imagination, speaking quickly and playfully. Clean studio recording.",
    text: "Mosey! Mosey, look! Word bubbles are stuck in the trees! Popping things is my favourite subject. I crossed a rainbow, and now my feet feel all fizzy. Again! Again! Can we do it again? Six islands, six fragments, and one snack break. Let's go!",
  },
  mosey: {
    name: "Mosey (Lost Islands)",
    description: "An adult British voice actress in her twenties performing a gentle cartoon sea creature for a family animated film. Soft, light and youthful, calm, steady, kind and reassuring, unhurried, with quiet wonder and a little playful humour. Clean studio recording.",
    text: "Welcome to my favourite place. Maths, under the sea. Stay close, Otter, and follow me. Each right answer builds a rainbow plank, so there is no need to rush. Look, the flowers are waking up. We did it together, and that is the real magic.",
  },
};

// Median pitch and how much it moves, from a simple autocorrelation. A rough, objective
// guide to which preview sounds youngest and liveliest; it does not replace listening.
function pitch(file) {
  const wav = join(tmpdir(), `pitch-${process.pid}.wav`);
  execFileSync("afconvert", ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", file, wav]);
  const data = readFileSync(wav);
  rmSync(wav);
  const at = data.indexOf("data") + 8;
  const s = new Int16Array(data.buffer, data.byteOffset + at, Math.floor((data.length - at) / 2));
  const found = [];
  for (let start = 0; start + 640 < s.length; start += 320) {
    let energy = 0;
    for (let i = 0; i < 640; i++) energy += s[start + i] * s[start + i];
    if (Math.sqrt(energy / 640) < 600) continue;
    let best = 0, bestLag = 0;
    for (let lag = 26; lag <= 133; lag++) { // 120 Hz to 600 Hz
      let sum = 0, a = 0, b = 0;
      for (let i = 0; i < 640 - lag; i++) { sum += s[start + i] * s[start + i + lag]; a += s[start + i] ** 2; b += s[start + i + lag] ** 2; }
      const r = sum / Math.sqrt(a * b + 1);
      if (r > best) { best = r; bestLag = lag; }
    }
    if (best > 0.6) found.push(16000 / bestLag);
  }
  found.sort((x, y) => x - y);
  const at10 = found[Math.floor(found.length * 0.1)], median = found[Math.floor(found.length / 2)], at90 = found[Math.floor(found.length * 0.9)];
  return { median: Math.round(median), spread: Math.round(at90 - at10) };
}

const args = process.argv.slice(2);
mkdirSync(samples, { recursive: true });

if (args[0] === "--keep") {
  const [, who, number] = args;
  const previews = JSON.parse(readFileSync(previewsPath, "utf8"));
  const voice = await client.textToVoice.create({
    voiceName: characters[who].name,
    voiceDescription: characters[who].description,
    generatedVoiceId: previews[who][Number(number) - 1].id,
  });
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  config.characters ??= {};
  config.characters[who] = { ...(config.characters[who] ?? {}), voiceId: voice.voiceId, voiceName: characters[who].name };
  writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n");
  console.log(`kept preview ${number} as ${who}`);
} else {
  const previews = existsSync(previewsPath) ? JSON.parse(readFileSync(previewsPath, "utf8")) : {};
  for (const [who, spec] of Object.entries(characters)) {
    if (args.length && !args.includes(who)) continue;
    try {
      const result = await client.textToVoice.design({ voiceDescription: spec.description, text: spec.text });
      previews[who] = result.previews.map((preview, index) => {
        const file = join(samples, `design_${who}_${index + 1}.mp3`);
        writeFileSync(file, Buffer.from(preview.audioBase64, "base64"));
        const measured = pitch(file);
        console.log(`${who} preview ${index + 1}: median pitch ${measured.median} Hz, range ${measured.spread} Hz, ${preview.durationSecs.toFixed(1)} s`);
        return { id: preview.generatedVoiceId, ...measured };
      });
    } catch (error) {
      console.error(`FAILED ${who}: ${error?.statusCode ?? ""} ${String(error?.message ?? error).slice(0, 300)}`);
    }
  }
  writeFileSync(previewsPath, JSON.stringify(previews, null, 2) + "\n");
}
