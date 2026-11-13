import { makeQuestion, type Question } from "./question";
import { pick, randomInt, shuffled, type Rng } from "./rng";
import { spellingTopics, type InputProfile, type Skill } from "./skill";

/** One curated spelling word with a context sentence. */
export interface WordEntry {
  word: string;
  topic: Skill;
  level: number;
  /** A sentence with `___` where the word belongs. */
  sentence: string;
  /** For homophones: the sound-alike word it is confused with. */
  partner?: string;
}

export const wordKey = (entry: WordEntry) => `word:${entry.word}`;

export interface TypingSentence {
  level: number;
  text: string;
}

/** The bundled spelling and typing content, read from the same JSON as the iOS game. */
export class WordBank {
  private readonly byWord = new Map<string, WordEntry>();
  /** Real words outside the bank that sit one small change away from a bank word. */
  private readonly lookalikes: Set<string>;

  constructor(
    readonly words: readonly WordEntry[],
    readonly sentences: readonly TypingSentence[],
    lookalikes: Iterable<string> = [],
  ) {
    this.lookalikes = new Set(lookalikes);
    for (const entry of words) if (!this.byWord.has(entry.word)) this.byWord.set(entry.word, entry);
  }

  entry(word: string): WordEntry | undefined {
    return this.byWord.get(word.toLowerCase());
  }

  contains(word: string): boolean {
    return this.byWord.has(word.toLowerCase());
  }

  /** True for anything that spells a real word, whether or not it is in the bank. */
  isRealWord(word: string): boolean {
    return this.contains(word) || this.lookalikes.has(word.toLowerCase());
  }

  /** Words for the given topics at or just below the level, falling back gracefully so a pool is never empty. */
  pool(topics: readonly Skill[], level: number): readonly WordEntry[] {
    const inTopics = this.words.filter((entry) => topics.includes(entry.topic));
    const source = inTopics.length === 0 ? this.words : inTopics;
    for (const spread of [1, 2, 4]) {
      const matches = source.filter((entry) => entry.level <= level && entry.level >= level - spread);
      if (matches.length >= 6) return matches;
    }
    return source;
  }

  sentencePool(level: number): readonly TypingSentence[] {
    const matches = this.sentences.filter((sentence) => Math.abs(sentence.level - level) <= 1);
    return matches.length === 0 ? this.sentences : matches;
  }
}

// Turns word-bank entries into concrete challenges.

export type SpellingStyle =
  /** Type the missing letters (or the whole word at higher levels). */
  | "typed"
  /** Choose the letters or word that fits. */
  | "choice";

const clamp = (level: number) => Math.min(Math.max(level, 1), 5);

export function makeSpelling(entry: WordEntry, style: SpellingStyle, level: number, bank: WordBank, rng: Rng): Question {
  const pitch = clamp(level);
  const audioKey = `word_${entry.word}`;
  const filledSentence = entry.sentence.replaceAll("___", entry.word);

  if (entry.topic === "homophones" && entry.partner && style === "choice") {
    return makeQuestion({
      key: wordKey(entry), skill: "homophones", format: "choice", prompt: entry.sentence,
      answer: entry.word, choices: shuffled(rng, [entry.word, entry.partner]),
      hint: "Say the sentence aloud. Which spelling has the right meaning?",
      spoken: filledSentence, level: pitch, audioKey,
    });
  }

  const letters = [...entry.word];
  const spoken = `${entry.word}. ${filledSentence}`;

  if (style === "typed" && (pitch >= 4 || (pitch === 3 && letters.length <= 6))) {
    // Look, cover, write: the whole word, shown briefly first.
    return makeQuestion({
      key: wordKey(entry), skill: entry.topic, format: "typed", prompt: entry.sentence,
      answer: entry.word, masked: "_".repeat(letters.length), typingTarget: entry.word,
      hint: `It starts with “${letters[0]}” and has ${letters.length} letters.`,
      spoken, level: pitch, audioKey, flashThenHide: true,
    });
  }

  const hidden = hiddenPositions(letters.length, pitch, style, rng);
  const missing = hidden.map((index) => letters[index]).join("");
  const masked = letters.map((letter, index) => (hidden.includes(index) ? "_" : letter)).join("");

  if (style === "typed") {
    return makeQuestion({
      key: wordKey(entry), skill: entry.topic, format: "typed", prompt: entry.sentence,
      answer: entry.word, masked, typingTarget: missing,
      hint: `The word is “${entry.word}”. Say it slowly and listen for each sound.`,
      spoken, level: pitch, audioKey,
    });
  }
  return makeQuestion({
    key: wordKey(entry), skill: entry.topic, format: "choice", prompt: entry.sentence,
    answer: entry.word, choices: letterChoices(missing, letters, hidden, bank, rng), correctChoice: missing,
    masked, typingTarget: missing, hint: "Try each one in the gap. Which looks right?",
    spoken, level: pitch, audioKey,
  });
}

/** A contiguous run of hidden letters, sized to the level. Never hides the first letter of short easy words. */
function hiddenPositions(count: number, level: number, style: SpellingStyle, rng: Rng): number[] {
  if (count <= 1) return [0];
  let size = level <= 3 ? level : Math.max(3, Math.floor(count / 2));
  if (style === "choice") size = Math.min(size, 3);
  size = Math.min(size, count - 1);
  const earliest = level <= 2 ? 1 : 0;
  const start = randomInt(rng, earliest, Math.max(earliest, count - size));
  const positions: number[] = [];
  for (let index = start; index < Math.min(start + size, count); index += 1) positions.push(index);
  return positions;
}

const vowels = [..."aeiou"];
const consonants = [..."bcdgklmnprst"];
const alphabet = [..."abcdefghijklmnopqrstuvwxyz"];

/** The right letters plus two wrong fills that do not make a real word. */
function letterChoices(missing: string, letters: readonly string[], hidden: readonly number[], bank: WordBank, rng: Rng): string[] {
  const options: string[] = [];
  const original = [...missing];

  const consider = (candidate: string[]) => {
    const text = candidate.join("");
    if (text === missing || options.includes(text) || candidate.length !== original.length) return;
    const filled = [...letters];
    hidden.forEach((index, offset) => { filled[index] = candidate[offset]!; });
    if (!bank.isRealWord(filled.join(""))) options.push(text);
  };
  const changedAt = (index: number, letter: string) => original.map((old, at) => (at === index ? letter : old));

  if (original.length > 1) {
    consider([...original].reverse());
    consider([original[1]!, original[0]!, ...original.slice(2)]);
  }
  for (let attempts = 0; options.length < 2 && attempts < 60; attempts += 1) {
    const index = randomInt(rng, 0, original.length - 1);
    consider(changedAt(index, pick(rng, vowels.includes(original[index]!) ? vowels : consonants)));
  }
  // Short words can run out of same-kind swaps that are not real words; widen the net.
  for (let attempts = 0; options.length < 2 && attempts < 200; attempts += 1) {
    consider(changedAt(randomInt(rng, 0, original.length - 1), pick(rng, alphabet)));
  }
  return shuffled(rng, [missing, ...options.slice(0, 2)]);
}

/** A copy-typing challenge for Typing Turbo: the text stays visible. */
export function makeTyping(
  level: number, profile: InputProfile, bank: WordBank, rng: Rng, used: ReadonlySet<string> = new Set(),
): Question {
  const pitch = clamp(level);
  const wantsSentence = profile === "hardware" || pitch >= (profile === "compactTouch" ? 4 : 2);
  let text: string;
  if (wantsSentence) {
    const pool = bank.sentencePool(profile === "compactTouch" ? Math.max(1, pitch - 2) : pitch);
    const fresh = pool.filter((sentence) => !used.has(sentence.text));
    text = pick(rng, fresh.length === 0 ? pool : fresh).text;
  } else {
    const pool = bank.pool(spellingTopics, Math.min(pitch + 1, 3));
    const fresh = pool.filter((entry) => !used.has(entry.word));
    text = pick(rng, fresh.length === 0 ? pool : fresh).word;
  }
  return makeQuestion({
    key: `typing:L${pitch}`, skill: "typing", format: "typed", prompt: text, answer: text,
    hint: "Find each letter one at a time. There is no rush.", level: pitch,
  });
}
