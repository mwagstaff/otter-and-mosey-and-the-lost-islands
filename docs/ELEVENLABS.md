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

### The voice

The narrator is **Alice**, one of ElevenLabs' premade voices. Unlike Otter and Mosey, no voice was
designed: there is no description or prompt behind her, only a voice ID.

| | |
| --- | --- |
| Voice ID | `Xb7hH8MSUJpSbSDYk0k2` |
| Name in ElevenLabs | Alice - Clear, Engaging Educator |
| Labels | British, female, middle-aged, "professional", use case "informative / educational" |
| Category | premade (available on every plan) |

She was chosen from the account's 21 premade voices by filtering to British accents, which left
four: Alice, George ("Warm, Captivating Storyteller", male), Lily ("Velvety Actress", female) and
Daniel ("Steady Broadcaster", male). Alice's "educator" label fitted a question reader best. The
choice was then confirmed by ear.

### The request for each clip

Endpoint: `client.textToSpeech.convert(voiceId, {...})`. Script: `tools/sfx/narrate.mjs`.

| Parameter | Value | Note |
| --- | --- | --- |
| `voiceId` | `Xb7hH8MSUJpSbSDYk0k2` | `voiceId` in `narration.config.json` |
| `text` | the line, exactly as in `narration.json` | No delivery tags and no extra instructions |
| `modelId` | `eleven_v4` | |
| `outputFormat` | `mp3_44100_64` | Played by the app as it is; no processing afterwards |
| `languageCode` | `en` | |
| `voiceSettings.stability` | 0.55 | Middle of the range: steady, but not flat |
| `voiceSettings.similarityBoost` | 0.75 | |

Eleven v4 accepts only those two voice settings. Nothing else shapes the delivery: the only
"direction" Alice gets is the punctuation and wording of each line.

### What she is asked to say

486 lines, 13,217 characters in total. The complete list, key to exact text, is
`Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/narration.json`. It is generated by
`tools/build_content.py` from these patterns:

| Key | Count | Text sent | Example |
| --- | --- | --- | --- |
| `word_<word>` | 262 | The word with a capital letter and a full stop, then its sentence with the word filled in | `word_because`: "Because. I wear a coat because it is cold." |
| `mul_<table>x<n>` | 72 | "`n` times `table`." | `mul_8x7`: "7 times 8." |
| `mulq_<table>x<n>` | 72 | "What times `table` makes `product`?" | `mulq_8x7`: "What times 8 makes 56?" |
| `div_<table>x<n>` | 72 | "`product` divided by `table`." | `div_8x7`: "56 divided by 8." |
| `skill_<topic>` | 8 | A fixed instruction per maths topic (below) | |

Tables are 2, 3, 4, 5, 8 and 10, each with 1 to 12. Numbers are sent as digits and read naturally.

The word-then-sentence pattern is deliberate: the child hears the word alone first, then in
context. For homophones the sentence is what tells them which spelling is meant
(`word_hear`: "Hear. I can hear the waves.").

The eight topic instructions, used when a question's exact numbers have no recording:

| Key | Text sent |
| --- | --- |
| `skill_addition` | Add the two numbers together. |
| `skill_subtraction` | Take the second number away from the first. |
| `skill_multiplication` | Multiply the two numbers. |
| `skill_division` | Share the first number equally. |
| `skill_fractions` | Work out the fraction. |
| `skill_placeValue` | Think about the hundreds, tens and ones. |
| `skill_sequences` | Which number is missing from the pattern? |
| `skill_wordProblems` | Read the number story, then work out the answer. |

### Which clip plays for which question

Each question carries an `audioKey` set by the generators in `LostIslandsCore`:

- Spelling questions of every kind use `word_<word>`.
- A plain times-table question uses `mul_`, a missing-factor question uses `mulq_`, and a
  division fact uses `div_`.
- Every other maths question uses its topic's `skill_` line. That includes word problems, sums
  with arbitrary numbers, fractions, place value and multiples of ten such as 30 × 4.
- Typing Turbo text is never read aloud.

A core test checks that every key the generators can produce has a line in `narration.json`, and
an app test checks that every line has a bundled recording.

### Changing or extending it

```bash
cd tools/sfx
npm run narrate -- --count          # what is missing, spends nothing
npm run narrate                     # record anything missing
npm run narrate -- word_because     # record named keys only
npm run narrate -- --samples        # the same four lines in each candidate voice, into ./samples
npm run narrate -- --force          # record everything again
```

- **Different voice**: set `voiceId` and `voiceName` in `narration.config.json`, then
  `npm run narrate -- --force`. That re-records all 486 lines (13,217 characters).
  The candidates and the four lines used for samples are in the same file (`candidates`,
  `sampleKeys`).
- **Different delivery**: change `voiceSettings` in the config. Lower stability is more
  expressive. To direct a line, put an audio tag such as `[warmly]` at the start of its text;
  there is no tag support in the narrator path yet, so that means adding one in
  `build_content.py` where the lines are built.
- **Different wording**: edit the patterns in the narration block of `tools/build_content.py`,
  or a word's sentence in `tools/content/words.txt`, then run `python3 tools/build_content.py`.
  Changed lines keep their key, so re-record them by name or delete their `say_<key>.mp3` first.
- **New words**: add them to `words.txt`, rebuild content, then `npm run narrate` records only
  the new ones.
- **More maths read word for word**: add a new key pattern in `build_content.py` and set the
  matching `audioKey` in `MathsGenerator.swift`. Only finite sets can be recorded; anything with
  free-ranging numbers cannot.

## 3. Sound effects

Request per effect: `client.textToSoundEffects.convert({ text, modelId: "eleven_text_to_sound_v3",
durationSeconds, promptInfluence: 0.6 })`. The prompt (`text`), length (`seconds`) and playback
level (`gain`, in dB, applied locally) for all 21 effects are in `tools/sfx/sounds.json`. The
script then trims silence, sets the level and encodes each as AAC with macOS `afconvert`.

```bash
cd tools/sfx
npm run generate -- --force pop   # regenerate one effect after editing its prompt
```
