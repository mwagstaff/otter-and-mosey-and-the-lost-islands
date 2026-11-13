// The bundled content, read from the same JSON files the iOS game ships
// (Packages/LostIslandsCore/Sources/LostIslandsCore/Resources).
import dialogueJSON from "@content/dialogue.json";
import islandsJSON from "@content/islands.json";
import lookalikesJSON from "@content/lookalikes.json";
import narrationJSON from "@content/narration.json";
import sentencesJSON from "@content/sentences.json";
import wordsJSON from "@content/words.json";
import { Catalog, type RawCatalog, type VoicedLine } from "./catalog";
import { WordBank, type WordEntry } from "./wordbank";

export const catalog = new Catalog(islandsJSON as RawCatalog);

export const wordBank = new WordBank(wordsJSON as WordEntry[], sentencesJSON, lookalikesJSON);

/** Every narrator clip key and the words spoken in it. */
export const narration: Record<string, string> = narrationJSON;

/** Every voiced dialogue line, by clip key. */
export const voicedLines: Record<string, VoicedLine> = dialogueJSON;
