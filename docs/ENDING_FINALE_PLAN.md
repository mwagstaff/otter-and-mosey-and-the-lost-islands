# Finale proposal: "Thank you, explorer!"

Replaces the single card in `endingScreen` (`web/src/ui/menus.ts`) and its Swift twin with a
short, voiced celebration (about 60–75 seconds, every beat tap-to-skip). Mock-up:
`web/mockups/finale.html` (run the web dev server, open `/mockups/finale.html`).

## Beats

| # | Beat | What happens | Why it lands |
|---|------|--------------|--------------|
| 1 | **The crystal comes home** | Night sky. The six fragments fly in from the edges, each glowing in its island colour, circle once and snap together. White flash, rainbow rays. | The thing they've been collecting all game finally pays off on screen. |
| 2 | **Colour returns** | A rainbow iris opens from the crystal onto the title beach, fading from grey to full colour. "Every island is full of colour again." | Echoes the map's grey-to-colour restoration the player has watched all game. |
| 3 | **Friends arrive** | Each guardian enters in character (Grumblebark grows up, Inky splashes up, Sir Scorch swoops in, Nimbus floats down, Puff bounces, Umbra sparkles into being) and says a personal thank-you that calls back to their story. | Everyone the player has befriended, together for the first time. |
| 4 | **Otter and Mosey's thank you** | They run and swim in, thank the player by name, then "Three cheers for our champion!" while a banner with their name drops in. Everyone jumps on each "Hooray!" with a confetti burst. | The big emotional peak; the player's name is on screen in big letters while everyone cheers. |
| 5 | **Your adventure** | Counting-up tally: questions answered, stars, trophies, treasures, best streak. Then the **Rainbow Crystal Champion** medal stamps down with their name. | Concrete proof of their hard work, which parents love to see too. |
| 6 | **Group photo** | "Everyone squeeze in! Say cheese!" 3-2-1, camera flash, and the `bg_ending` painting drops in as a polaroid captioned "{name}, Otter, Mosey and friends". | A keepsake. The photo is saved to Treasures so they can look at it again. |
| 7 | **The adventure goes on** | Otter: "Every island's open now, so you can play any level again, whenever you like!" Mosey: "And there are still trophies hiding out there…" Card shows what's left to find, with **Back to the map** and **See my trophies**. | Turns the ending into a reason to keep playing. |

## Script (UK English, voiced like the rest)

- **Grumblebark:** "You gave me back my laugh! Ha ha! I'm saving my very best story just for you."
- **Inky:** "Eight arms, and I'd use every single one to give you a hug!"
- **Sir Scorch:** "Trousers dry, pocket not itchy. You're a proper hero!"
- **Nimbus:** "Best playmate the sky's ever had. Come back and play any time!"
- **Puff:** "Puff saved you the biggest marshmallow. Fair shares!"
- **Umbra:** "You helped me find the light. I'll never forget that."
- **Otter:** "We couldn't have done any of this without you!"
- **Mosey:** "All those spellings and all those sums, and you never gave up!"
- **Otter:** "Three cheers for our champion! Hip hip…" **Everyone:** "Hooray!" ×3
- **Mosey:** "Everyone squeeze in for a photo! Say cheese!"
- **Otter:** "Every island's open now, so you can play any level again, whenever you like!"
- **Mosey:** "And there are still trophies hiding out there, and stars to win, and pets to find!"

**Player names:** every spoken line is generic, so all of them can be recorded once
like the rest of the game. The name only ever appears as on-screen text, never in a
speech bubble: the banner during the cheers ("★ {name} ★"), the tally title
("{name}'s adventure"), the trophy ("Awarded to {name}") and the photo caption
("{name}, Otter, Mosey and friends"). "Hip hip… Hooray!" needs a group recording
(all voices layered).

## Building it

- **New screen** `finaleScreen` (web) / `FinaleView` (Swift) driven by a small beat timeline;
  any tap skips to the end of the current beat, and a **Skip** button jumps to beat 7.
- **Shared content**: add a `finale` block to `islands.json` (guardian thank-yous keyed by
  island, Otter/Mosey lines) so `tools/build_content.py` generates the voice clips as usual.
- **Stats** come from the profile (answers, stars, trophies earned/total, rewards owned,
  best combo). "Still to find" counts trophies not yet earned, levels under 3 stars and
  rewards not yet owned. If everything is found, the last card says so and celebrates instead.
- **New trophy** "Rainbow Crystal Champion" (`trophy_champion.png` already exists) awarded at
  beat 5; **Group photo** added to Treasures; **Watch the ending again** button in the
  trophy cabinet once it's been seen.
- **Map after the finale**: a small "Champion" ribbon on the map bar and the "Play here!"
  marker points to the island with the most left to find.
- **Audio**: existing `victory`, `unlock` and crystal sounds, plus a whoosh for shards, a
  camera shutter and a crowd "hooray".
- **Accessibility**: respects reduced motion (cross-fades instead of flying/flash), captions
  for every voiced line, no strobing (the camera flash is a single soft fade).
