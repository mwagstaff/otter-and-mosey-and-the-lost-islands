#!/usr/bin/env python3
"""Builds the JSON question banks bundled with LostIslandsCore from the plain-text sources.

Run from the repository root:  python3 tools/build_content.py
The JSON files are the cross-platform source of truth for web and Android ports.
"""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
out = root / "Packages/LostIslandsCore/Sources/LostIslandsCore/Resources"
topics = {"st": "starterWords", "ex": "exceptionWords", "pre": "prefixes", "suf": "suffixes", "hom": "homophones"}

words, seen, problems = [], set(), []
for n, line in enumerate((root / "tools/content/words.txt").read_text().splitlines(), 1):
    if not line.strip() or line.startswith("#"):
        continue
    parts = line.split("|")
    word, topic, level, sentence = parts[0], topics[parts[1]], int(parts[2]), parts[3]
    partner = parts[4] if len(parts) > 4 else None
    if not re.fullmatch(r"[a-z]+", word): problems.append(f"line {n}: '{word}' must be lowercase letters")
    if word in seen: problems.append(f"line {n}: duplicate '{word}'")
    if sentence.count("___") != 1: problems.append(f"line {n}: sentence needs exactly one ___")
    if not 1 <= level <= 5: problems.append(f"line {n}: level out of range")
    seen.add(word)
    entry = {"word": word, "topic": topic, "level": level, "sentence": sentence}
    if partner: entry["partner"] = partner
    words.append(entry)

sentences = []
for n, line in enumerate((root / "tools/content/sentences.txt").read_text().splitlines(), 1):
    if not line.strip() or line.startswith("#"):
        continue
    level, text = line.split("|")
    if not re.fullmatch(r"[a-z ]+", text): problems.append(f"sentence {n}: letters and spaces only")
    sentences.append({"level": int(level), "text": text})

if problems:
    sys.exit("\n".join(problems))
out.mkdir(parents=True, exist_ok=True)
# Real words that differ from a bank word only in one short run of letters. A missing-letters
# question must never offer a wrong choice that happens to spell one of these ("su_" + m = "sum").
lookalikes = set()
dictionary = pathlib.Path("/usr/share/dict/words")
if dictionary.exists():
    by_length = {}
    for candidate in dictionary.read_text().split():
        if candidate.islower() and candidate.isalpha():
            by_length.setdefault(len(candidate), []).append(candidate)
    bank = {w["word"] for w in words}
    for entry in words:
        word = entry["word"]
        for candidate in by_length.get(len(word), []):
            if candidate == word or candidate in bank:
                continue
            diff = [i for i in range(len(word)) if word[i] != candidate[i]]
            if diff and diff[-1] - diff[0] < 3:
                lookalikes.add(candidate)
    (out / "lookalikes.json").write_text(json.dumps(sorted(lookalikes)) + "\n")
else:
    print("warning: /usr/share/dict/words not found; keeping the existing lookalikes.json")
# The narrator's script: clip key -> exactly what is said. tools/sfx/narrate.mjs records these,
# and the app plays the clip whose key matches a question's `audioKey`.
narration = {}
for entry in words:
    spoken = entry["sentence"].replace("___", entry["word"])
    narration[f"word_{entry['word']}"] = f"{entry['word'].capitalize()}. {spoken}"
for table in (2, 3, 4, 5, 8, 10):
    for other in range(1, 13):
        narration[f"mul_{table}x{other}"] = f"{other} times {table}."
        narration[f"mulq_{table}x{other}"] = f"What times {table} makes {table * other}?"
        narration[f"div_{table}x{other}"] = f"{table * other} divided by {table}."
narration.update({
    "skill_addition": "Add the two numbers together.",
    "skill_subtraction": "Take the second number away from the first.",
    "skill_multiplication": "Multiply the two numbers.",
    "skill_division": "Share the first number equally.",
    "skill_fractions": "Work out the fraction.",
    "skill_placeValue": "Think about the hundreds, tens and ones.",
    "skill_sequences": "Which number is missing from the pattern?",
    "skill_wordProblems": "Read the number story, then work out the answer.",
})
(out / "narration.json").write_text(json.dumps(narration, indent=0, ensure_ascii=False) + "\n")
(out / "words.json").write_text(json.dumps(words, indent=1, ensure_ascii=False) + "\n")
(out / "sentences.json").write_text(json.dumps(sentences, indent=1) + "\n")
sys.path.insert(0, str(root / "tools/content"))
import islands as source
level_ids = [l["id"] for i in source.ISLANDS for l in i["levels"]]
reward_ids = {r[0] for r in source.REWARDS}
for island in source.ISLANDS:
    for l in island["levels"]:
        if l["reward"] and l["reward"] not in reward_ids: sys.exit(f"unknown reward {l['reward']}")
if len(set(level_ids)) != len(level_ids): sys.exit("duplicate level ids")
# Dialogue that is voiced (Otter, Mosey, the guardians and the story narrator): clip key -> who
# says it, where, and the words.
# The key is a hash of "speaker:text", computed the same way by DialogueLine.audioKey in Swift.
def line_key(line):
    value = 0x811C9DC5
    for byte in line.encode("utf-8"):
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"line_{value:08x}"

dialogue = {}
def collect(scene, lines, guardian=None, mood=None):
    for line in lines:
        speaker, text = line.split(":", 1)
        if speaker == "g" and guardian:
            # Guardians are recorded under their kind (tree, octopus, ...), one voice each.
            entry = {"speaker": guardian, "scene": scene, "text": text}
        elif speaker in ("o", "m"):
            entry = {"speaker": "otter" if speaker == "o" else "mosey", "scene": scene, "text": text}
        else:
            # Story lines, read by the question narrator.
            entry = {"speaker": "narrator", "scene": scene, "text": text}
        if mood:
            entry["mood"] = mood
        dialogue.setdefault(line_key(line), entry)
collect("intro", source.INTRO + source.INTRO_AFTER)
collect("help", source.ASK_GROWN_UP)
for island in source.ISLANDS:
    kind = island["guardian"]["kind"]
    for l in island["levels"]:
        collect(l["id"], l["intro"] + l["outro"], guardian=kind)
    boss = island["levels"][-1]["id"]
    collect(boss, island["guardian"]["phases"], guardian=kind)
    # Once won over, the guardian sounds different: these lines get the "befriended" delivery.
    collect(boss, island["guardian"]["befriended"], guardian=kind, mood="befriended")
(out / "dialogue.json").write_text(json.dumps(dialogue, indent=0, ensure_ascii=False) + "\n")
catalogue = {
    "islands": source.ISLANDS,
    "rewards": [{"id": r[0], "kind": r[1], "name": r[2], "emoji": r[3]} for r in source.REWARDS],
    "intro": source.INTRO, "introAfter": source.INTRO_AFTER, "askGrownUp": source.ASK_GROWN_UP,
}
(out / "islands.json").write_text(json.dumps(catalogue, indent=1, ensure_ascii=False) + "\n")
print(f"{len(words)} words, {len(sentences)} sentences, {len(level_ids)} levels, {len(dialogue)} voiced dialogue lines ({sum(len(d['text']) for d in dialogue.values())} characters), {len(lookalikes)} lookalikes, {len(narration)} narration lines ({sum(len(t) for t in narration.values())} characters)")
