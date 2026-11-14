// Designs the two character voices with ElevenLabs Voice Design and saves previews to ./samples.
// ElevenLabs does not allow designing children's voices, so both are described as adult voice
// actors performing youthful cartoon characters (Otter by a woman, Mosey, a boy, by a man).
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
    description: "A young adult British voice actor performing a gentle boy mosasaur, a friendly cartoon sea dinosaur, for a family animated film. Warm, youthful and mid-low in pitch, a little deeper and rounder than a child, with a soft, slightly rumbly, dinosaur-like quality. Calm, steady, kind and reassuring, unhurried, with quiet wonder and a little playful humour. Clear southern English accent. Clean studio recording.",
    text: "Welcome to my favourite place. Maths, under the sea. Stay close, Otter, and follow me. Each right answer builds a rainbow plank, so there is no need to rush. Look, the flowers are waking up. We did it together, and that is the real magic.",
  },
  // The six guardians: funny, never frightening. Keys match the guardian "kind" in islands.py.
  tree: {
    name: "Old Grumblebark (Lost Islands)",
    description: "An elderly British man performing a grumpy but lovable talking oak tree in a family animated film. Deep, slow, creaky and gravelly, full of comic harrumphing and bluster, with obvious warmth underneath. Funny, never frightening. Clean studio recording.",
    text: "Harrumph! Who is making all that cheerful noise in my woods? My leaves have gone grey, and so has my mood. Stop it. I am not smiling. That is just how my bark sits. Oh no. I can feel a giggle coming. Ha ha ha! I have not laughed in a hundred years!",
  },
  octopus: {
    name: "Inky (Lost Islands)",
    description: "A middle-aged British woman performing a sweet, hopelessly muddled octopus in a family animated film. Fluttery, dithery and flustered, warm and a little posh, tripping over her own thoughts and counting on her arms. Comic and kind, never frightening. Clean studio recording.",
    text: "Oh dear, oh dear. Is that two visitors, or twelve? Eight arms, or is it nine? I have lost count of everything! Wait, that helps! But now my sums are all in a knot. Eight! I have eight arms! Thank you, clever friends! Here, I was sitting on this shiny thing.",
  },
  dragon: {
    name: "Sir Scorch (Lost Islands)",
    description: "A British man performing a silly, pompous little dragon knight in a family animated film. Grand, theatrical and self-important, with a plummy voice that keeps cracking into panicked yelps. A harmless buffoon, comic, never frightening. Clean studio recording.",
    text: "Halt! I am Sir Scorch, the fearsome... ouch. Warm. Behold my mighty fl... is something burning? It is my trousers! Again! Quick, distract me with times tables! Ahhh. Thank you. These were my best trousers. Take the fragment. It was making my pocket itchy.",
  },
  wizard: {
    name: "Nimbus (Lost Islands)",
    description: "A British voice actor performing a cheeky, mischievous little cloud wizard in a family animated film. Light, quick, impish and giggly, constantly delighted with his own tricks, sing-song and playful. Comic, never frightening. Clean studio recording.",
    text: "Ooh, visitors! Want to see a trick? Nope! It is a word muddle! Tee hee! I jumbled all the words in the sky! Hey! Stop fixing things! Take that word muddle! My best spell! Nobody can... oh. You can. All right, all right. You win. That was fun!",
  },
  marshmallow: {
    name: "Puff (Lost Islands)",
    description: "A British man performing a huge, soft, friendly marshmallow monster in a family animated film. Big, round, slow and pillowy, simple and sweet-natured, speaking about himself by name in short sentences, booming but gentle. Comic, never frightening. Clean studio recording.",
    text: "Puff is the biggest! Puff keeps all the sweets! Mine! All the sweets are mine! How many is that? Sharing? What is sharing? Show Puff! Half for you, half for me. Puff is getting it! Sharing makes the sweets taste better! Puff shares the shiny thing too.",
  },
  shadow: {
    name: "Umbra (Lost Islands)",
    description: "A British voice actor performing a small, shy, lonely shadow creature in a family animated film. Very soft, breathy, hesitant and quiet, sad but gentle and sweet, slowly warming with hope. Sympathetic, never frightening. Clean studio recording.",
    text: "Go away. Shadows do not have friends. You came all this way for a crystal? I did not mean to. I only wanted to hold something bright. Why are you being kind to me? It makes me feel warm. I would like that. Here. I kept it safe for you.",
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
