# ElevenLabs audio: what was sent, and how to continue

Everything ElevenLabs has been asked to make for this game, with the exact inputs, so that you or
another agent can re-run, tweak or extend it. All of it happens at development time through the
scripts in `tools/sfx`. The app never calls ElevenLabs.

## Status

| Audio | State |
| --- | --- |
| Sound effects (21) | Done and bundled. |
| Question narrator, "Alice" (486 clips) | Done and bundled. |
| Otter and Mosey voices | Done and bundled: all 133 lines. The 9 opening-story lines were recorded first as a proof of concept. |
| Guardian voices | Done and bundled: all 41 lines, six designed voices. |
| Music (7 loops) | Done and bundled: one for the menus, one per island. See section 4. |
| "Story" lines (4 clips) | Done and bundled, read by Alice with her question settings and no tag. Copies in `docs/voice-poc/story/`. |

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
between the 10th and 90th percentile). The nine proof-of-concept lines were then approved by ear
before the rest were recorded.

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

All of Otter's and Mosey's 133 lines are recorded with the settings above. The commands below are for re-recording
after a change, or for new lines.

The full script is `Packages/LostIslandsCore/Sources/LostIslandsCore/Resources/dialogue.json`
(178 lines, about 6,800 characters before tags: 133 for Otter and Mosey, 41 for guardians, 4 story lines), built from `tools/content/islands.py` by
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
- "Story" lines are in `dialogue.json` with the speaker `narrator`. `narrate.mjs` records them
  with the question narrator's voice and settings (section 2) and no delivery tag. In the app they
  play like any other line but show no speech badge, since nobody on screen is talking.

## 1b. Guardian voices

Six more designed voices, one per guardian, made the same way as Otter's and Mosey's
(`client.textToVoice.design`, then `client.textToVoice.create`). All 41 guardian lines are
recorded. Each guardian is described as an adult performer playing a funny, harmless cartoon
character.

### Voice Design requests

**Old Grumblebark** (`tree`)

- `voiceDescription`: "An elderly British man performing a grumpy but lovable talking oak tree in a family animated film. Deep, slow, creaky and gravelly, full of comic harrumphing and bluster, with obvious warmth underneath. Funny, never frightening. Clean studio recording."
- `text`: "Harrumph! Who is making all that cheerful noise in my woods? My leaves have gone grey, and so has my mood. Stop it. I am not smiling. That is just how my bark sits. Oh no. I can feel a giggle coming. Ha ha ha! I have not laughed in a hundred years!"

**Inky** (`octopus`)

- `voiceDescription`: "A middle-aged British woman performing a sweet, hopelessly muddled octopus in a family animated film. Fluttery, dithery and flustered, warm and a little posh, tripping over her own thoughts and counting on her arms. Comic and kind, never frightening. Clean studio recording."
- `text`: "Oh dear, oh dear. Is that two visitors, or twelve? Eight arms, or is it nine? I have lost count of everything! Wait, that helps! But now my sums are all in a knot. Eight! I have eight arms! Thank you, clever friends! Here, I was sitting on this shiny thing."

**Sir Scorch** (`dragon`)

- `voiceDescription`: "A British man performing a silly, pompous little dragon knight in a family animated film. Grand, theatrical and self-important, with a plummy voice that keeps cracking into panicked yelps. A harmless buffoon, comic, never frightening. Clean studio recording."
- `text`: "Halt! I am Sir Scorch, the fearsome... ouch. Warm. Behold my mighty fl... is something burning? It is my trousers! Again! Quick, distract me with times tables! Ahhh. Thank you. These were my best trousers. Take the fragment. It was making my pocket itchy."

**Nimbus** (`wizard`)

- `voiceDescription`: "A British voice actor performing a cheeky, mischievous little cloud wizard in a family animated film. Light, quick, impish and giggly, constantly delighted with his own tricks, sing-song and playful. Comic, never frightening. Clean studio recording."
- `text`: "Ooh, visitors! Want to see a trick? Nope! It is a word muddle! Tee hee! I jumbled all the words in the sky! Hey! Stop fixing things! Take that word muddle! My best spell! Nobody can... oh. You can. All right, all right. You win. That was fun!"

**Puff** (`marshmallow`)

- `voiceDescription`: "A British man performing a huge, soft, friendly marshmallow monster in a family animated film. Big, round, slow and pillowy, simple and sweet-natured, speaking about himself by name in short sentences, booming but gentle. Comic, never frightening. Clean studio recording."
- `text`: "Puff is the biggest! Puff keeps all the sweets! Mine! All the sweets are mine! How many is that? Sharing? What is sharing? Show Puff! Half for you, half for me. Puff is getting it! Sharing makes the sweets taste better! Puff shares the shiny thing too."

**Umbra** (`shadow`)

- `voiceDescription`: "A British voice actor performing a small, shy, lonely shadow creature in a family animated film. Very soft, breathy, hesitant and quiet, sad but gentle and sweet, slowly warming with hope. Sympathetic, never frightening. Clean studio recording."
- `text`: "Go away. Shadows do not have friends. You came all this way for a crystal? I did not mean to. I only wanted to hold something bright. Why are you being kind to me? It makes me feel warm. I would like that. Here. I kept it safe for you."

### Voices kept and how their lines are sent

| Guardian | Key | Voice ID | Preview kept | Tag before it is won over | Tag once befriended | Stability |
| --- | --- | --- | --- | --- | --- | --- |
| Old Grumblebark | `tree` | `DJO7Y2M4iHF0NW2Ct2hR` | 3 of 3 | `[grumpy]` | `[laughing warmly]` | 0.45 |
| Inky | `octopus` | `7Y4hG5Z0d1hT7SGlsdND` | 2 of 3 | `[flustered]` | `[delighted]` | 0.4 |
| Sir Scorch | `dragon` | `BwY7haYnrb0GMFyLs0BE` | 3 of 3 | `[pompous]` | `[relieved]` | 0.4 |
| Nimbus | `wizard` | `TDf5YPBJ2QCSoaRCudlR` | 3 of 3 | `[mischievous]` | `[cheerful]` | 0.35 |
| Puff | `marshmallow` | `32MUcGWPdUZx2kPgRYP7` | 3 of 3 | `[booming]` | `[happy]` | 0.5 |
| Umbra | `shadow` | `5UOpXM9aihJ3gGnRwbAw` | 3 of 3 | `[sad, quietly]` | `[hopeful, softly]` | 0.55 |

All use `eleven_v4`, `mp3_44100_64`, `languageCode: "en"` and `similarityBoost` 0.8, as for Otter
and Mosey. A guardian's "befriended" lines (those spoken after the third Friendship Power) are
marked `"mood": "befriended"` in `dialogue.json` and get the second tag; every other line gets the
first.

The exact text sent for each line is listed by `npm run narrate -- --dialogue <level> --count`
after deleting or forcing, or can be read from `dialogue.json` plus the tags above.

### How the previews were chosen

Again without listening, from the pitch measurement (median pitch / range, in Hz, previews 1 to 3):

| Guardian | Preview 1 · 2 · 3 |
| --- | --- |
| Old Grumblebark | 302 / 124 · 267 / 143 · 222 / 165 |
| Inky | 444 / 339 · 286 / 164 · 271 / 143 |
| Sir Scorch | 302 / 113 · 302 / 159 · 314 / 202 |
| Nimbus | 500 / 302 · 356 / 224 · 356 / 295 |
| Puff | 333 / 118 · 364 / 186 · 198 / 72 |
| Umbra | 348 / 235 · 390 / 276 · 281 / 107 |

The measurement only looks between 120 and 600 Hz, so deep male voices read about an octave too
high; only the comparison within a row means anything. The lowest or steadiest preview was kept
for the tree, Puff and Umbra, a livelier one for Sir Scorch and Nimbus, and the middle one for
Inky because the first was very high. These are the least certain choices in this document:
listen to the previews in `docs/voice-poc/guardians/design_<key>_<n>.mp3` and to the two sample
lines per guardian beside them (`line_<key>_...mp3`).

Things worth listening for: Nimbus's "Nobody ever plays with me up here." is sent with
`[cheerful]` but is a wistful line; and whether Sir Scorch's panic and Puff's size come through.

To replace a guardian's voice, run the design step for that key, keep a preview, then re-record
its level:

```bash
cd tools/sfx
node --env-file=../../.env.local design-voices.mjs dragon
node --env-file=../../.env.local design-voices.mjs --keep dragon 1
npm run narrate -- --dialogue dragon-5 --force
```

Note that `--force` on a guardian's level also re-records Otter's and Mosey's lines in it.

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

## 4. Music

Seven instrumental loops, composed with ElevenLabs Music and bundled as
`OtterAndMosey/Resources/Audio/music_*.m4a`. The menus use `music_title`; each island's track is
named in `IslandTheme.island(_:)` in `OtterAndMosey/Game/Systems/Theme.swift`.

```bash
cd tools/sfx
npm run music                 # compose anything missing from ./raw, then build the loops
npm run music -- music_bay    # only this track
npm run music -- --force      # compose again (uses credits)
npm run music -- --install    # rebuild the loops from ./raw, composing nothing
```

### What is sent

`client.music.compose` once per track, with:

| Parameter | Value |
| --- | --- |
| `modelId` | `music_v2_5` |
| `musicLengthMs` | 60000 |
| `forceInstrumental` | `true` |
| `prompt` | the track's prompt followed by the shared style text, both in `tools/sfx/music.json` |

Shared style text, added to every prompt:

> Instrumental background music for a gentle children's learning game, ages 7 to 8. Warm, friendly
> and unhurried, with a clear hummable melody. Steady tempo and even loudness from the first second
> to the last: no intro build-up, no breakdown, no big finish, no fade-out, so it can repeat as a
> loop. No vocals, no spoken words, no sound effects.

| Track | Used for | Prompt |
| --- | --- | --- |
| `music_title` | Menus, map, story | Bright, welcoming adventure theme for a storybook world of rainbow islands. Ukulele, glockenspiel, pizzicato strings, soft hand percussion and a playful recorder melody. Sunny, hopeful, about 104 bpm, C major. |
| `music_woods` | Whispering Woods | Cosy enchanted forest tune. Fingerpicked acoustic guitar, wooden marimba, soft clarinet melody, light shaker. Curious and calm, like tiptoeing among friendly talking trees, about 92 bpm, G major. |
| `music_bay` | Bubble Bay | Dreamy underwater lagoon tune. Harp arpeggios, vibraphone, warm soft synth pad, gentle bubbling plucked bass, a floating flute melody. Weightless and soothing, about 84 bpm, F major. |
| `music_dragon` | Dragonfire Mountain | Plucky, friendly volcano adventure tune. Bouncy bassoon and tuba, pizzicato strings, hand drums and a brave little trumpet melody. Determined but never scary, about 108 bpm, A minor with a cheerful lift. |
| `music_cloud` | Cloud Castle | Light, airy castle-in-the-sky tune. Celesta, music box, soft flutes and high gentle strings with a skipping waltz feel. Floating and a little mischievous, about 96 bpm in three-four time, D major. |
| `music_candy` | Candy Kingdom | Sweet, bouncy sweet-shop tune. Toy piano, xylophone, kazoo-like soft synth lead, plucked upright bass and finger snaps. Giggly and light on its feet, about 112 bpm, B flat major. |
| `music_star` | Starlight Island | Quiet, wondering night-sky tune. Soft felt piano, glassy bells, warm cello and a slow twinkling arpeggio. Tender and hopeful, a little lonely at first and comforting by the end of each phrase, about 76 bpm, E flat major. |

Each track was composed once and kept; nothing was auditioned. Composing is not repeatable: the
same prompt gives a different piece each time.

### How a piece becomes a loop

The composed MP3s (stereo, 48 kHz) are kept in the git-ignored `tools/sfx/raw/`. `music.mjs` then:

1. trims silence from both ends and drops the last 2.5 seconds, where pieces tend to die away;
2. blends the final 3 seconds into the first 3 seconds, so the end of the file runs into its start;
3. sets every track to the same average loudness (0.14 of full scale);
4. encodes stereo AAC at 96 kbit/s with `afconvert`. Each loop is about 54 seconds and 0.7 MB.

The numbers are in `music.json` (`dropTailSeconds`, `crossfadeSeconds`, `loudness`, `bitrate`).

### Cost

The seven tracks used 5,250 credits in total (750 for each 60-second piece), read from the
account's balance before and after. The balance updates a few minutes late, so do not rely on it
straight after a run. Rebuilding loops with `--install` costs nothing.

### Known limits

- The blend hides the join in level but not in harmony: if a piece ends on a different chord from
  the one it starts on, the join can still be heard as a soft change.
- The Starlight Island track winds down towards its end, so its last few seconds are quieter.
- The app plays loops with `AVAudioPlayer`, and AAC files carry a few milliseconds of padding, so a
  very short gap at the loop point is possible.
