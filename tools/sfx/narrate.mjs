// Records the narrator's lines with ElevenLabs text-to-speech and bundles them with the app.
//
//   cd tools/sfx && npm install
//   npm run narrate                       # record anything missing
//   npm run narrate -- word_because       # only these keys
//   npm run narrate -- --force            # record everything again (uses about 13,000 credits)
//   npm run narrate -- --samples          # short samples of each candidate voice, into ./samples
//   npm run narrate -- --count            # show what would be recorded, spend nothing
//
// The script (what is said) comes from narration.json, which tools/build_content.py writes.
// The voice and model are set in narration.config.json. The API key is read from
// ELEVENLABS_API_KEY, loaded by `npm run` from the git-ignored .env.local.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(here, "narration.config.json"), "utf8"));
const script = JSON.parse(readFileSync(
  join(here, "../../Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/narration.json"), "utf8"));
const speechDir = join(here, "../../OtterAndMosey/Resources/Speech");
const args = process.argv.slice(2);
const flags = new Set(args.filter((arg) => arg.startsWith("--")));
const wanted = args.filter((arg) => !arg.startsWith("--"));

const client = new ElevenLabsClient();

async function record(voiceId, text, file) {
  const audio = await client.textToSpeech.convert(voiceId, {
    text,
    modelId: config.modelId,
    outputFormat: config.outputFormat,
    languageCode: "en",
    voiceSettings: config.voiceSettings,
  });
  const chunks = [];
  for await (const chunk of audio) chunks.push(Buffer.from(chunk));
  writeFileSync(file, Buffer.concat(chunks));
}

// A few requests at a time, with one retry, so a rate limit or blip does not stop the run.
async function runAll(jobs, width = 3) {
  let failed = 0;
  let done = 0;
  const queue = [...jobs];
  await Promise.all(Array.from({ length: width }, async () => {
    for (let job = queue.shift(); job; job = queue.shift()) {
      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          await record(job.voiceId, job.text, job.file);
          done++;
          if (done % 25 === 0) console.log(`${done}/${jobs.length}`);
          break;
        } catch (error) {
          if (attempt === 2) {
            failed++;
            console.error(`FAILED ${job.key}: ${error?.statusCode ?? ""} ${String(error?.message ?? error).slice(0, 160)}`);
          } else {
            await new Promise((resolve) => setTimeout(resolve, 2500));
          }
        }
      }
    }
  }));
  return { done, failed };
}

if (flags.has("--samples")) {
  const samples = join(here, "samples");
  mkdirSync(samples, { recursive: true });
  const jobs = [];
  for (const [name, voiceId] of Object.entries(config.candidates)) {
    for (const key of config.sampleKeys) {
      jobs.push({ key: `${name}:${key}`, voiceId, text: script[key], file: join(samples, `${name}_${key}.mp3`) });
    }
  }
  console.log(await runAll(jobs), "samples in", samples);
} else {
  mkdirSync(speechDir, { recursive: true });
  const jobs = Object.entries(script)
    .filter(([key]) => !wanted.length || wanted.includes(key))
    .map(([key, text]) => ({ key, text, voiceId: config.voiceId, file: join(speechDir, `say_${key}.mp3`) }))
    .filter((job) => flags.has("--force") || !existsSync(job.file));
  const characters = jobs.reduce((sum, job) => sum + job.text.length, 0);
  console.log(`${jobs.length} lines to record with ${config.voiceName} (${characters} characters)`);
  if (!flags.has("--count") && jobs.length) console.log(await runAll(jobs));
}
