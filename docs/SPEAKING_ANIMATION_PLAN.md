# Plan: showing who is speaking

A plan for making it obvious which character is talking during story dialogue: a mouth that opens
and closes with the voice, a small animated speech bubble over the speaker, and a little body
movement. Nothing here is built yet.

The aim is a visual helper, not lip-sync. A mouth that flaps roughly in time with the loudness of
the voice reads as "talking" to a child; matching mouth shapes to individual sounds is out of scope.

## Where things stand today

- Dialogue is a SwiftUI panel (`UI/Components/DialogueView.swift`) drawn over the SpriteKit scene.
  It shows a static portrait (`otter_idle`, `mosey_idle` or the guardian), a name pill and the text.
- The characters in the scene are `CharacterNode`s (`Game/Characters/CharacterNode.swift`). Each
  shows one painted pose at a time: idle, blink, cheer, think, oops, and run or swim. There is no
  separate mouth, and both idle poses have a closed smile.
- Voice clips are played by `Narrator` (`Audio/AudioManager.swift`) with a private
  `AVAudioPlayer`. Nothing outside it knows whether a clip is playing or how loud it is.
- Only nine Otter and Mosey lines have recordings so far. Guardian and "Story" lines have none, and
  a player can turn character voices off or mute the game.

So two things are missing: a signal that says "this character is speaking, this loudly, right now",
and a mouth-open picture to show.

## Recommended approach

Three layers that all read one shared signal. Each is useful alone, so they can ship in order.

| Layer | What the child sees | New art |
| --- | --- | --- |
| 1. Speaker cue | An animated speech-bubble badge over the speaker in the scene, and the dialogue portrait bouncing gently with the voice | None |
| 2. Mouth flap | The speaker's mouth opens and closes with the loudness of the voice, in the portrait and in the scene | One "talking" frame each for Otter and Mosey |
| 3. Word highlight (optional) | Each word in the bubble lights up as it is spoken | None |

### The shared signal

Add one small observable object, `SpeechStage`, that `Narrator` updates and everything else reads:

- `speaker`: Otter, Mosey, a guardian, or nobody
- `level`: loudness from 0 to 1, smoothed
- `mouthOpen`: true or false

**When a recording plays**, `Narrator` turns on `AVAudioPlayer` metering and samples it about 30
times a second (`updateMeters()` then `averagePower(forChannel:)`), converts decibels to 0–1, and
smooths it so the mouth opens quickly and closes a little more slowly.

**When there is no recording** (guardians, lines not yet recorded, voices switched off, or the game
muted), `Narrator` plays a made-up "chatter" pattern instead: a few open-close beats a second for a
time based on the length of the line, roughly 0.06 seconds per character, kept between 1 and 4
seconds. This matters: the cue must work for every line, not only the voiced ones, and must not
depend on hearing anything.

**Turning loudness into open or closed** needs a little care or the mouth flickers. Use two
thresholds (open above about 0.35, close below about 0.2) and hold each state for at least 70
milliseconds. Put this in `LostIslandsCore` as a small pure type (`MouthGate`), with the chatter
pattern beside it, so it is unit-tested and available to a future web or Android version.

### Layer 1: speaker cue

- **Badge in the scene.** `CharacterNode` gains `setSpeaking(_:)`. While speaking it shows a small
  cream speech bubble above its head with three dots that bounce in turn, scaled slightly by
  `level`. It pops in when the line starts and out when it ends.
- **Body language.** The speaker does a small squash-and-stretch with `level`; the listener stays
  still. No new poses.
- **Portrait.** The portrait in the dialogue panel scales a few percent with `level`, and the
  panel gets a small tail pointing at it.
- **Guardians** get the same badge and bounce using the chatter pattern, so all three kinds of
  speaker are treated alike. "Story" lines show no speaker.
- **Calmer motion setting:** keep the badge, drop the bouncing.

Scenes need to know who is speaking. `DialogueView` already knows the line's speaker, so it sets
`SpeechStage.speaker` when a line appears and clears it when the line ends. `GameScene`,
`IntroScene` and `GuardianScene` watch `SpeechStage` and call `setSpeaking` on the matching node.

### Layer 2: mouth flap

Two frames per character are enough: the existing idle pose (mouth closed) and one new "talking"
frame (mouth open). `mouthOpen` picks between them.

**Getting a talking frame that does not jitter.** Earlier attempts at a matching blink frame came
back as slightly different drawings, which would make the whole character twitch on every flap.
Avoid that by only ever using the mouth from the new image:

1. Generate an edit of the idle image with the existing art pipeline (`tools/generate_art.py`,
   `gpt-image-2.5-sunburst`, the idle image as the reference). Suggested prompts:
   - Otter: "Exactly the same image, unchanged in every detail, except that his mouth is open in a
     happy, mid-sentence talking shape, showing a little pink tongue. Do not move or redraw
     anything else."
   - Mosey: "Exactly the same image, unchanged in every detail, except that her mouth is slightly
     open in a gentle, mid-sentence talking shape, rounded, with no sharp teeth. Do not move or
     redraw anything else."
2. In `tools/import_art.py`, find the area around the muzzle where the two images differ, and paste
   only that area, with a soft edge, from the edited image onto the untouched idle image. Every
   pixel outside the mouth is then identical by construction.
3. Save the result as `otter_talk` and `mosey_talk`, the same size as the idle images.
4. Add a check to the import step that fails if anything outside the mouth area differs.

Two images at about $0.06 each; art spend so far is $3.27 of the $10–15 budget.

**If the generated mouth does not line up or looks wrong**, fall back to drawing it: a small dark
rounded shape with a pink tongue, placed at a fixed point on each character's muzzle and stretched
by `level`. It needs one anchor point per character and no generated art. It is less charming but
cannot misalign.

**In the app:**

- `CharacterNode` adds a `talk` pose and swaps idle ↔ talk on `mouthOpen`, without the usual
  pose-change pop. It only does this while resting in the idle pose; if the character is cheering
  or reacting, the mouth is left alone and the badge carries the cue.
- The dialogue portrait swaps `otter_idle` ↔ `otter_talk` the same way.
- Guardians keep their single image and rely on Layer 1.

### Layer 3 (optional): word highlight

ElevenLabs can return timings for each character and word of a clip. That would let the dialogue
text light up word by word as it is spoken, which is a real reading aid, and could tighten the
mouth timing.

- For clips already recorded: `client.forcedAlignment.create` takes the audio and its text and
  returns start and end times per word.
- For new recordings: `client.textToSpeech.convertWithTimestamps` returns the audio and timings in
  one call.

Timings would be saved as a small JSON file beside each clip. Both calls exist in the installed
SDK; their credit cost has not been checked. This is not needed for the mouth flap, so decide on it
separately.

## Order of work

| Step | Work | Files | Check |
| --- | --- | --- | --- |
| 1 | `MouthGate` and the chatter pattern | `LostIslandsCore` + tests | Tests: no flicker on noisy input; closes at silence; chatter lasts the expected time |
| 2 | `SpeechStage`; `Narrator` publishes level from metering or chatter | `Audio/AudioManager.swift` | Level rises and falls with a recorded clip; chatter runs when muted |
| 3 | Layer 1: badge, bounce, portrait, panel tail | `CharacterNode.swift`, `DialogueView.swift`, the three scene types | Play the opening story: the right character is marked on every line, voiced or not |
| 4 | Talking frames through the art pipeline, with the alignment check | `tools/art_manifest.json`, `tools/import_art.py` | Flip between idle and talk: only the mouth changes |
| 5 | Layer 2: mouth swap in scene and portrait | `CharacterNode.swift`, `DialogueView.swift`, `Art` test list | Mouth moves with the voice and rests closed between lines |
| 6 | Calmer-motion behaviour, iPhone and iPad pass | | Badge clear of the HUD and the dialogue panel on both |

Steps 1–3 are about half a day and need no art. Steps 4–5 are about another half day, mostly
getting the talking frames right. Layer 3 is separate.

## Things that could go wrong

- **The badge hides behind the dialogue panel.** On iPhone the panel covers the lower part of the
  screen, and characters stand low. The intro scene already lifts the characters when dialogue
  shows; level scenes may need the same, or the badge placed to the side of the head.
- **Mouth out of step with the sound.** Metering is live, so delay is small. If the flap looks
  late, open slightly earlier by lowering the open threshold instead of adding prediction.
- **Otter's lively voice makes the mouth chatter too fast.** The minimum hold time handles this;
  raise it for Otter if needed.
- **Characters mid-reaction.** A line can start while a character is still cheering. The rule above
  (only flap from idle) avoids pose clashes, at the cost of a still mouth for a moment.
- **Two things speaking at once.** A question's narration and a dialogue line never overlap today,
  because `Narrator` stops the previous clip. Keep it that way: one speaker at a time.

## Alternatives considered

- **Real lip-sync with mouth shapes per sound.** Needs six to ten matching mouth drawings per
  character and per-sound timing. Far more art and work than a speaker cue warrants.
- **Working out loudness in advance** and bundling it as data beside each clip. Removes the need
  for live metering and is what a web version would probably do, but adds a build step. Not worth
  it on iOS while live metering is one line; the `MouthGate` logic is the same either way.
- **Re-using the cheer pose as the open mouth.** It is a different drawing with arms raised, so the
  whole body would jump on every syllable.
- **A separate talking sprite sheet.** More frames, same alignment problem, no visible gain at
  this size.

## Decisions for you

1. Should guardians "talk" too, using the made-up chatter, or only Otter and Mosey?
2. Is the word-by-word highlight (Layer 3) wanted? It costs ElevenLabs credits and is the only
   part that does.
3. If the generated talking frame is not good enough, is the simple drawn mouth acceptable, or
   would you prefer the speaker cue alone?
