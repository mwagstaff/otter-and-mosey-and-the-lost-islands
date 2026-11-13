# Otter & Mosey: The Lost Islands

A native iOS and iPadOS adventure game for UK Year 3 children (ages 8–9) that teaches spelling,
typing and maths. Otter (a mischievous brown otter) and Mosey (a friendly blue mosasaur) travel
across six islands recovering the fragments of the Great Rainbow Crystal. Every right answer
brings colour back to the world.

Landscape only. iOS / iPadOS 26 or later. Fully offline: no accounts, adverts, purchases or
network calls.

## What is in the game

- **Six islands, 30 levels**: Whispering Woods, Bubble Bay, Dragonfire Mountain, Cloud Castle,
  Candy Kingdom and Starlight Island. Each has four levels and a guardian encounter.
- **Six game modes**
  - *Word Blaster*: type the missing letters to pop word bubbles (look-cover-write at higher levels).
  - *Maths Splash*: Mosey swims through the tunnel with the right answer; drag to scoop pearls.
  - *Rainbow Bridge*: drag the right answer into the gap to build a bridge plank by plank.
  - *Number Rescue*: type the answer on a number pad to hatch eggs and open chests and jars.
  - *Typing Turbo*: every correct key speeds the ride. Stars come from accuracy, never speed.
  - *Guardian encounters*: right answers charge Friendship Power for a joint special move.
- **Learning engine**: Year 3 maths generators (addition, subtraction, 2/3/4/5/8/10 times tables,
  division, fractions, place value, sequences, word problems), a curated bank of 262 UK-spelling
  words with context sentences, per-skill adaptive difficulty and spaced repetition of missed
  words and number facts.
- **Progression**: three-star ratings, crystals, pets, hats, stickers (achievements), a home
  island to decorate, and multiple local player profiles.
- **Parent area** behind a gate: playtime, accuracy per subject and skill, items being revisited,
  difficulty, times tables, spelling topics, break reminders and accessibility.
- **Accessibility**: calmer motion, high contrast, easy-read text, spoken questions, hints,
  volume controls, no mandatory timers. Questions are read by a recorded narrator.

## Build and run

Requirements: macOS with Xcode 26 or later. No third-party dependencies.

```bash
open OtterAndMosey.xcodeproj
```

Choose the `OtterAndMosey` scheme and an iPhone or iPad simulator, then Run. From the command line:

```bash
xcodebuild -project OtterAndMosey.xcodeproj -scheme OtterAndMosey -destination 'platform=iOS Simulator,name=iPad (A16)' build
```

If several simulators share a name, pass `id=<UDID>` from `xcrun simctl list devices` instead.
Bundle ID: `otter-and-mosey-and-the-lost-islands.dev.skynolimit`.

## Tests

```bash
cd Packages/LostIslandsCore && swift test
```

45 tests cover question correctness, the word bank, adaptive difficulty, spaced repetition,
sessions, progression and save files. They run on macOS in under a second.

```bash
xcodebuild -project OtterAndMosey.xcodeproj -scheme OtterAndMosey -destination 'platform=iOS Simulator,id=<UDID>' test
```

5 app tests check that all art and audio is bundled, that progress survives a relaunch and that
every game mode builds a scene and asks a question.

## Project layout

| Path | What it holds |
| --- | --- |
| `Packages/LostIslandsCore` | Platform-neutral logic (Foundation only): questions, generators, learner model, sessions, progression, save data, and the JSON content. |
| `OtterAndMosey/App` | App entry, navigation and the app model. |
| `OtterAndMosey/Game` | SpriteKit: scenes, characters, effects, art loading. |
| `OtterAndMosey/UI` | SwiftUI: menus, HUD, keyboards, dialogue, parent dashboard. |
| `OtterAndMosey/Audio` | Audio, narration and haptics. |
| `OtterAndMosey/Assets.xcassets`, `OtterAndMosey/Resources/Audio` | Bundled art and sound. |
| `tools/` | Development-time content, art and audio pipelines. |

### Porting to web and Android

`LostIslandsCore` has no UIKit, SwiftUI or SpriteKit imports. The level catalogue, dialogue,
word bank and typing sentences are plain JSON in
`Packages/LostIslandsCore/Sources/LostIslandsCore/Resources`, so another client can read the same
files. The rules that would need re-implementing (generators, adaptive level, spaced repetition,
star thresholds, unlocks) are small, pure and covered by the tests, which double as a spec.
Save files are versioned JSON.

## Web version (in progress)

`web/` holds a browser version built with TypeScript, Vite and PixiJS. It reuses this project's
art, audio and content rather than keeping its own copies:

- `web/scripts/sync-assets.mjs` copies the pictures from `Assets.xcassets` and the sound and
  voice clips from `OtterAndMosey/Resources` into `web/public/assets` (git-ignored) and writes a
  manifest. It runs automatically before `npm run dev` and `npm run build`.
- The content JSON is imported straight from `Packages/LostIslandsCore/.../Resources`.
- `web/src/core` is a TypeScript port of `LostIslandsCore`, and `web/tests` is a port of its
  tests. A rule changed in Swift needs the same change there. Save files have the same shape.

```bash
cd web && npm install
npm run dev     # http://localhost:5173
npm test        # the ported core tests
npm run build   # type-check, then build into web/dist
```

Every screen of the iOS game now has a web counterpart: the dedication and title screens, players
(nickname, picture and favourite), the opening story with its one-question tutorial, the map and
island screens, all six game modes (story dialogue with voices, HUD, hints, on-screen or real
keyboard, touch and mouse, pause, results), treasures, the home island, settings, the grown-ups'
area behind its gate (progress, learning settings, reset) and the ending. Progress, settings and
playtime are saved in the browser. The menu screens are web layouts in the game's style rather
than copies of the iOS ones, and there is no vibration.

`web/src/engine` holds the small SpriteKit-style pieces the scenes are built on (actions,
particles, procedural art); `web/src/game` holds the scenes and audio; `web/src/ui` holds the
page screens. Adding `?level=woods-1` to the address opens a level directly, and `?short` limits
levels to three questions.

## Content pipeline

Edit `tools/content/words.txt`, `sentences.txt` or `islands.py`, then:

```bash
python3 tools/build_content.py
```

This validates the content and regenerates the JSON, including `lookalikes.json`, the list of
real words used to stop a wrong spelling choice from accidentally forming another word.

## Art pipeline (development only)

All art was generated with the OpenAI Images API (`gpt-image-2.5-flare` and
`gpt-image-2.5-sunburst`) from the prompts in `tools/art_manifest.json`. The two heroes were
drawn from photos of the family's plush toys; every later pose uses those references.

```bash
python3 tools/generate_art.py          # generate anything missing into tools/raw
python3 tools/import_art.py            # optimise and package into Assets.xcassets
```

`generate_art.py` reads `OPENAI_API_KEY_CHATGPT_GRAPHICS` from the environment, passes it to curl
on stdin, tracks spend in `tools/.art-ledger.json` and stops at `ART_BUDGET_USD` (default 13).
`import_art.py` needs ImageMagick and pngquant (`brew install imagemagick pngquant`). The key is
never used at runtime and nothing in the app talks to the network. `tools/raw` and
`tools/reference` are git-ignored.

## Audio

**Sound effects** are generated with ElevenLabs (model `eleven_text_to_sound_v3`) from the
prompts in `tools/sfx/sounds.json`:

```bash
cd tools/sfx && npm install
npm run generate              # anything missing
npm run generate -- pop star  # just these
npm run generate -- --force   # everything again
```

The script reads `ELEVENLABS_API_KEY` from the git-ignored `.env.local` at the repository root
(create it with `npx -y @elevenlabs/cli@latest onboard init`), trims and levels each clip, and
encodes it into `OtterAndMosey/Resources/Audio` with macOS `afconvert`. Edit a prompt, its
`seconds` or its `gain` (dB) in `sounds.json` and regenerate that sound to change it.
Nothing in the app calls ElevenLabs.

**Narration** is pre-recorded with ElevenLabs text-to-speech, so questions are read by the same
friendly voice on every device, offline. `tools/build_content.py` writes the script to
`narration.json` (clip key to spoken text) and `tools/sfx/narrate.mjs` records it:

```bash
cd tools/sfx
npm run narrate -- --count    # what is missing, without spending credits
npm run narrate               # record anything missing
npm run narrate -- --samples  # short samples of each candidate voice, into tools/sfx/samples
npm run narrate -- --force    # record everything again (about 13,000 characters)
```

The voice and model are set in `tools/sfx/narration.config.json`. What is recorded:

- every spelling word followed by its sentence (262 clips)
- every 2, 3, 4, 5, 8 and 10 times-table fact as a product, a missing factor and a division (216 clips)
- one short instruction per maths topic, used when a question's exact numbers have no recording
  (for example "Add the two numbers together.")

While a character speaks, a speech badge appears over them and their mouth moves with the
voice (or with a made-up rhythm when a line has no recording); see
[docs/SPEAKING_ANIMATION_PLAN.md](docs/SPEAKING_ANIMATION_PLAN.md).

Otter, Mosey and the six guardians have their own designed voices and all 174 of their lines
are recorded, and the four "Story" lines are read by the question narrator; see [docs/ELEVENLABS.md](docs/ELEVENLABS.md) for every prompt and setting sent
to ElevenLabs and how to continue. Questions with no exact recording, such as word problems, get
the topic instruction; a grown-up can also turn on "Device voice for other sums" in Settings to
have the built-in iOS voice read those word for word.

**Music** is seven loops, one for the menus and one per island, composed with ElevenLabs Music
by `npm run music` in `tools/sfx` (prompts in `tools/sfx/music.json`) and turned into seamless
loops by the same script. To swap one, replace its `music_*.m4a` with a file of the same name.
`python3 tools/synth_audio.py --music --effects` writes simple synthesised stand-ins instead,
which overwrites the ElevenLabs files.

## Debug launch arguments (Debug builds only)

| Argument | Effect |
| --- | --- |
| `-debugLevel bay-1` | Open a level directly. |
| `-debugRoute map` | Open a screen: `map`, `collection`, `home`, `parent`, `ending`, `intro`, `island:woods`. |
| `-debugUnlock` | Treat every level as cleared for this launch. |
| `-debugShort` | Limit levels to three questions. |

## Known limitations

- The four music loops are synthesised placeholders.
- Characters are animated by swapping painted poses and moving them in code. There are no
  frame-by-frame sprite sheets.
- Word problems and sums with arbitrary numbers are not narrated word for word: they get a short
  recorded instruction for their topic, or the device voice if that option is turned on.
- Typing speed is only recorded when a hardware keyboard is attached. The hardware keyboard path
  has not been exercised in the simulator.
- Easy-read text uses Verdana with wider spacing rather than a dedicated dyslexia typeface.
- Pets, hats and home decorations use emoji artwork.
- Held in portrait, iPadOS letterboxes the landscape game instead of rotating it.
