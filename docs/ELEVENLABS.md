# ElevenLabs audio: what was sent, and how to continue

Everything ElevenLabs has been asked to make for this game, with the exact inputs, so that you or
another agent can re-run, tweak or extend it. All of it happens at development time through the
scripts in `tools/sfx`. The app never calls ElevenLabs.

## Status

| Audio | State |
| --- | --- |
| Sound effects (21) | Done and bundled. |
| Question narrator, "Alice" (486 clips) | Done and bundled. |
| Otter and Mosey voices | **Proof of concept only**: the 9 lines of the opening story. The other 124 lines are not recorded. |
| Guardian and "Story" lines | Not voiced. |

## Setup

- SDK: `@elevenlabs/elevenlabs-js`, installed in `tools/sfx` (`cd tools/sfx && npm install`).
- Key: `ELEVENLABS_API_KEY` in the git-ignored `.env.local` at the repository root. Create it with
  `npx -y @elevenlabs/cli@latest onboard init`. The npm scripts load it with `node --env-file`.
  Never paste the key into chat, code or this document.
- Account: Starter plan, 40,000 credits a month.
- All settings live in `tools/sfx/narration.config.json` and `tools/sfx/sounds.json`.

## 1. Otter and Mosey voices

### Why they are not children's voices

The first request asked Voice Design for a young girl's voice for each character. ElevenLabs
refused both with `403 blocked_generation` ("this prompt potentially doesn't follow our safety
guidelines"): it does not generate children's voices. These were the rejected descriptions:

- Otter: "A young British girl of about eight with a bright, bubbly, high-pitched child's voice.
  Excitable and giggly, bursting with energy, mischief and imagination, speaking quickly and
  playfully with lots of enthusiasm. Clean studio recording."
- Mosey: "A young British girl of about nine with a soft, calm, warm child's voice. Gentle, steady,
  kind and reassuring, thoughtful and unhurried, with quiet youthful wonder and a little playful
  humour. Clean studio recording."

The voices in use are therefore adult voice actresses performing youthful cartoon characters,
which is how most animation is voiced. Do not try to reword the request to obtain a child's voice.

### Voice Design requests that were accepted

Endpoint: `client.textToVoice.design({ voiceDescription, text })` (default model, no other
parameters). Script: `tools/sfx/design-voices.mjs`.

**Otter**

- `voiceDescription`: "An adult British voice actress in her twenties performing a cute cartoon
  animal for a family animated film. Bright, bubbly, light and high in pitch, excitable and giggly,
  bursting with energy, mischief and imagination, speaking quickly and playfully. Clean studio
  recording."
- `text` (the preview script): "Mosey! Mosey, look! Word bubbles are stuck in the trees! Popping
  things is my favourite subject. I crossed a rainbow, and now my feet feel all fizzy. Again! Again!
  Can we do it again? Six islands, six fragments, and one snack break. Let's go!"

**Mosey**

- `voiceDescription`: "An adult British voice actress in her twenties performing a gentle cartoon
  sea creature for a family animated film. Soft, light and youthful, calm, steady, kind and
  reassuring, unhurried, with quiet wonder and a little playful humour. Clean studio recording."
- `text`: "Welcome to my favourite place. Maths, under the sea. Stay close, Otter, and follow me.
  Each right answer builds a rainbow plank, so there is no need to rush. Look, the flowers are
  waking up. We did it together, and that is the real magic."

### Previews and which were kept

Each request returned three previews, saved in `docs/voice-poc/design_<character>_<n>.mp3`. They
were chosen without listening, using a rough pitch measurement (median pitch, and the range
between the 10th and 90th percentile). Treat the choice as provisional.

| Preview | Median pitch | Pitch range | Kept |
| --- | --- | --- | --- |
| Otter 1 | 400 Hz | 281 Hz | **Yes** |
| Otter 2 | 457 Hz | 312 Hz | |
| Otter 3 | 314 Hz | 314 Hz | |
| Mosey 1 | 286 Hz | 118 Hz | **Yes** |
| Mosey 2 | 258 Hz | 71 Hz | |
| Mosey 3 | 235 Hz | 113 Hz | |

Kept previews were saved to the account with `client.textToVoice.create({ voiceName,
voiceDescription, generatedVoiceId })`:

| Character | Voice name in the account | Voice ID |
| --- | --- | --- |
| Otter | Otter (Lost Islands) | `sYN0fMdsZGmW5GjQDfRo` |
| Mosey | Mosey (Lost Islands) | `K0lydB7PoIvM0LcxjPER` |

Preview IDs expire, so previews 2 and 3 can no longer be saved as they are. To get a different
voice, run the design step again (new previews each time), listen, then keep one:

```bash
cd tools/sfx
node --env-file=../../.env.local design-voices.mjs otter
node --env-file=../../.env.local design-voices.mjs --keep otter 2
```

`--keep` writes the new voice ID into `narration.config.json`. Edit the descriptions at the top of
`design-voices.mjs` to steer the result.

### Text-to-speech request for each line

Endpoint: `client.textToSpeech.convert(voiceId, {...})`.

| Parameter | Otter | Mosey |
| --- | --- | --- |
| `modelId` | `eleven_v4` | `eleven_v4` |
| `outputFormat` | `mp3_44100_64` | `mp3_44100_64` |
| `languageCode` | `en` | `en` |
| `voiceSettings.stability` | 0.35 | 0.6 |
| `voiceSettings.similarityBoost` | 0.8 | 0.8 |
| Delivery tag put before the line | `[excited] ` | `[gently] ` |

Eleven v4 takes only those two voice settings (no style or speed) and uses audio tags in square
brackets for delivery. Lower stability gives more expressive, less predictable reads.

### The nine proof-of-concept lines

Exactly the text sent, in story order. Files for listening are in `docs/voice-poc`; the copies the
game plays are `OtterAndMosey/Resources/Speech/say_<key>.mp3`.

| # | File | Key | Text sent |
| --- | --- | --- | --- |
| 1 | `01_otter.mp3` | `line_4b3595f3` | [excited] Mosey! I spelled 'breakfast' in the sand. Now I am hungry. |
| 2 | `02_mosey.mp3` | `line_346f97c9` | [gently] You are always hungry. That is three breakfasts today. |
| 3 | `03_otter.mp3` | `line_6370a177` | [excited] Three is a very good number. |
| 4 | `04_mosey.mp3` | `line_4b10a9e0` | [gently] Otter… the colours are fading! |
| 5 | `05_otter.mp3` | `line_0db2687c` | [excited] The flowers have gone grey. We have to fix this! |
| 6 | `06_mosey.mp3` | `line_441c4686` | [gently] Look, a word bubble by that flower. Try the missing letter! |
| 7 | `07_otter.mp3` | `line_044ac971` | [excited] It bloomed! The colour came back! |
| 8 | `08_mosey.mp3` | `line_47a1f912` | [gently] So our answers bring the world back to life. |
| 9 | `09_otter.mp3` | `line_f8eb8524` | [excited] Six islands. Six fragments. One snack break. Let us go! |

Things worth listening for: whether the single tag suits every line (line 4 is worried, not
gentle; line 5 is alarmed, not excited), and whether "Let us go!" should be written "Let's go!".

### Continuing

The full script is `Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/dialogue.json`
(133 lines, about 4,700 characters before tags), built from `tools/content/islands.py` by
`python3 tools/build_content.py`. Each entry has a `speaker`, a `scene` (`intro` or a level id such
as `woods-1`) and the `text`.

```bash
cd tools/sfx
npm run narrate -- --dialogue woods-1 --count   # list a scene's lines, spend nothing
npm run narrate -- --dialogue woods-1           # record one scene
npm run narrate -- --dialogue all               # record everything still missing
npm run narrate -- --dialogue intro --force     # re-record a scene after changing settings
```

How the pieces fit:

- A clip's key is a 32-bit FNV-1a hash of `"o:<text>"` or `"m:<text>"`. `tools/build_content.py`
  and `DialogueLine.audioKey` (Swift) compute it the same way; a core test checks they agree.
  Changing a line's wording changes its key, so that line needs recording again.
- The game plays `say_<key>.mp3` when a line appears, if the "Otter and Mosey voices" setting is
  on. Lines with no recording are silent, so partial recording is safe.
- To change the delivery of individual lines, the tag is currently one per character
  (`deliveryTag` in `narration.config.json`). Per-line tags would need a small change: add an
  optional tag to the lines in `islands.py`, carry it into `dialogue.json`, and use it in
  `narrate.mjs` in place of the character's default.
- Guardians and "Story" lines are not in `dialogue.json`. Voicing them means adding their speakers
  in `build_content.py` and `DialogueLine.audioKey`, plus a voice for each in the config.

## 2. Question narrator

Voice: Alice, a premade ElevenLabs voice (`Xb7hH8MSUJpSbSDYk0k2`, British, "Clear, Engaging
Educator"). George and Lily were sampled as alternatives; samples are made with
`npm run narrate -- --samples`.

Request per clip: `client.textToSpeech.convert(voiceId, { text, modelId: "eleven_v4",
outputFormat: "mp3_44100_64", languageCode: "en", voiceSettings: { stability: 0.55,
similarityBoost: 0.75 } })`. No delivery tags.

The 486 lines sent are in
`Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/narration.json` (key to exact text),
generated by `tools/build_content.py`:

- `word_<word>`: the word, then its sentence, for example "Because. I wear a coat because it is cold."
- `mul_<table>x<n>`: "7 times 8."
- `mulq_<table>x<n>`: "What times 8 makes 56?"
- `div_<table>x<n>`: "56 divided by 8."
- `skill_<topic>`: one instruction per maths topic, for example "Add the two numbers together."

```bash
cd tools/sfx
npm run narrate -- --count   # what is missing
npm run narrate              # record anything missing
```

## 3. Sound effects

Request per effect: `client.textToSoundEffects.convert({ text, modelId: "eleven_text_to_sound_v3",
durationSeconds, promptInfluence: 0.6 })`. The prompt (`text`), length (`seconds`) and playback
level (`gain`, in dB, applied locally) for all 21 effects are in `tools/sfx/sounds.json`. The
script then trims silence, sets the level and encodes each as AAC with macOS `afconvert`.

```bash
cd tools/sfx
npm run generate -- --force pop   # regenerate one effect after editing its prompt
```
