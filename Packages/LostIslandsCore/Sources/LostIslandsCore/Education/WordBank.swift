import Foundation

/// One curated spelling word with a context sentence.
public struct WordEntry: Codable, Equatable, Sendable {
    public let word: String
    public let topic: Skill
    public let level: Int
    /// A sentence with `___` where the word belongs.
    public let sentence: String
    /// For homophones: the sound-alike word it is confused with.
    public let partner: String?

    public var key: String { "word:\(word)" }
}

public struct TypingSentence: Codable, Equatable, Sendable {
    public let level: Int
    public let text: String
}

/// The bundled spelling and typing content. Loaded once from JSON so the same
/// files can feed other platforms.
public struct WordBank: Sendable {
    public let words: [WordEntry]
    public let sentences: [TypingSentence]
    private let byWord: [String: WordEntry]
    /// Real words outside the bank that sit one small change away from a bank word.
    private let lookalikes: Set<String>

    public init(words: [WordEntry], sentences: [TypingSentence], lookalikes: Set<String> = []) {
        self.words = words
        self.sentences = sentences
        self.lookalikes = lookalikes
        byWord = Dictionary(words.map { ($0.word, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static let shared: WordBank = {
        do {
            return try WordBank.loadBundled()
        } catch {
            assertionFailure("Bundled word bank failed to load: \(error)")
            return WordBank(words: [WordEntry(word: "sun", topic: .starterWords, level: 1, sentence: "The ___ is hot.", partner: nil)],
                            sentences: [TypingSentence(level: 1, text: "otter can swim")])
        }
    }()

    public static func loadBundled() throws -> WordBank {
        let decoder = JSONDecoder()
        guard let wordsURL = Bundle.module.url(forResource: "words", withExtension: "json"),
              let sentencesURL = Bundle.module.url(forResource: "sentences", withExtension: "json")
        else { throw CocoaError(.fileNoSuchFile) }
        var lookalikes: Set<String> = []
        if let url = Bundle.module.url(forResource: "lookalikes", withExtension: "json") {
            lookalikes = Set(try decoder.decode([String].self, from: Data(contentsOf: url)))
        }
        return WordBank(
            words: try decoder.decode([WordEntry].self, from: Data(contentsOf: wordsURL)),
            sentences: try decoder.decode([TypingSentence].self, from: Data(contentsOf: sentencesURL)),
            lookalikes: lookalikes
        )
    }

    public func entry(for word: String) -> WordEntry? { byWord[word.lowercased()] }

    public func contains(_ word: String) -> Bool { byWord[word.lowercased()] != nil }

    /// True for anything that spells a real word, whether or not it is in the bank.
    public func isRealWord(_ word: String) -> Bool { contains(word) || lookalikes.contains(word.lowercased()) }

    /// Words for the given topics at or just below the level, falling back gracefully so a pool is never empty.
    public func pool(topics: [Skill], level: Int) -> [WordEntry] {
        let inTopics = words.filter { topics.contains($0.topic) }
        let source = inTopics.isEmpty ? words : inTopics
        for spread in [1, 2, 4] {
            let matches = source.filter { $0.level <= level && $0.level >= level - spread }
            if matches.count >= 6 { return matches }
        }
        return source
    }

    /// Every narrator clip key and the words spoken in it.
    public static let narration: [String: String] = {
        guard let url = Bundle.module.url(forResource: "narration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lines = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return lines
    }()

    public func sentencePool(level: Int) -> [TypingSentence] {
        let matches = sentences.filter { abs($0.level - level) <= 1 }
        return matches.isEmpty ? sentences : matches
    }
}

/// Turns word-bank entries into concrete challenges.
public enum SpellingGenerator {
    public enum Style: Sendable {
        /// Type the missing letters (or the whole word at higher levels).
        case typed
        /// Choose the letters or word that fits.
        case choice
    }

    public static func make<R: RandomNumberGenerator>(
        entry: WordEntry, style: Style, level: Int, bank: WordBank = .shared, using rng: inout R
    ) -> Question {
        let level = min(max(level, 1), 5)
        if entry.topic == .homophones, let partner = entry.partner, style == .choice {
            return Question(
                key: entry.key, skill: .homophones, format: .choice, prompt: entry.sentence,
                answer: entry.word, choices: [entry.word, partner].shuffled(using: &rng), masked: nil,
                hint: "Say the sentence aloud. Which spelling has the right meaning?",
                spoken: entry.sentence.replacingOccurrences(of: "___", with: entry.word), level: level,
                audioKey: "word_\(entry.word)"
            )
        }

        let letters = Array(entry.word)
        let spokenSentence = entry.sentence.replacingOccurrences(of: "___", with: entry.word)

        if style == .typed, level >= 4 || (level == 3 && letters.count <= 6) {
            // Look, cover, write: the whole word, shown briefly first.
            return Question(
                key: entry.key, skill: entry.topic, format: .typed, prompt: entry.sentence,
                answer: entry.word, masked: String(repeating: "_", count: letters.count),
                typingTarget: entry.word, hint: "It starts with “\(letters[0])” and has \(letters.count) letters.",
                spoken: "\(entry.word). \(spokenSentence)", level: level, audioKey: "word_\(entry.word)", flashThenHide: true
            )
        }

        let hidden = hiddenPositions(count: letters.count, level: level, style: style, using: &rng)
        var maskedLetters = letters
        for index in hidden { maskedLetters[index] = "_" }
        let missing = String(hidden.map { letters[$0] })
        let masked = String(maskedLetters)

        switch style {
        case .typed:
            return Question(
                key: entry.key, skill: entry.topic, format: .typed, prompt: entry.sentence,
                answer: entry.word, masked: masked, typingTarget: missing,
                hint: "The word is “\(entry.word)”. Say it slowly and listen for each sound.",
                spoken: "\(entry.word). \(spokenSentence)", level: level, audioKey: "word_\(entry.word)"
            )
        case .choice:
            let options = letterChoices(for: missing, in: letters, hidden: hidden, bank: bank, using: &rng)
            return Question(
                key: entry.key, skill: entry.topic, format: .choice, prompt: entry.sentence,
                answer: entry.word, choices: options, correctChoice: missing, masked: masked,
                typingTarget: missing, hint: "Try each one in the gap. Which looks right?",
                spoken: "\(entry.word). \(spokenSentence)", level: level, audioKey: "word_\(entry.word)"
            )
        }
    }

    /// A contiguous run of hidden letters, sized to the level. Never hides the first letter of short easy words.
    static func hiddenPositions<R: RandomNumberGenerator>(
        count: Int, level: Int, style: Style, using rng: inout R
    ) -> [Int] {
        guard count > 1 else { return [0] }
        var size: Int
        switch level {
        case 1: size = 1
        case 2: size = 2
        case 3: size = 3
        default: size = max(3, count / 2)
        }
        if style == .choice { size = min(size, 3) }
        size = min(size, count - 1)
        let earliest = level <= 2 ? 1 : 0
        let latestStart = max(earliest, count - size)
        let start = Int.random(in: earliest...latestStart, using: &rng)
        return Array(start..<min(start + size, count))
    }

    /// The right letters plus two wrong fills that do not make a real bank word.
    static func letterChoices<R: RandomNumberGenerator>(
        for missing: String, in letters: [Character], hidden: [Int], bank: WordBank, using rng: inout R
    ) -> [String] {
        let vowels: [Character] = ["a", "e", "i", "o", "u"]
        let consonants: [Character] = ["b", "c", "d", "g", "k", "l", "m", "n", "p", "r", "s", "t"]
        var options: [String] = []

        func consider(_ candidate: String) {
            guard candidate != missing, !options.contains(candidate), candidate.count == missing.count else { return }
            var filled = letters
            for (offset, index) in hidden.enumerated() { filled[index] = Array(candidate)[offset] }
            if !bank.isRealWord(String(filled)) { options.append(candidate) }
        }

        let original = Array(missing)
        if original.count > 1 {
            consider(String(original.reversed()))
            var swapped = original
            swapped.swapAt(0, 1)
            consider(String(swapped))
        }
        var attempts = 0
        while options.count < 2, attempts < 60 {
            attempts += 1
            var changed = original
            let index = Int.random(in: 0..<changed.count, using: &rng)
            let pool = vowels.contains(changed[index]) ? vowels : consonants
            changed[index] = pool.randomElement(using: &rng)!
            consider(String(changed))
        }
        // Short words can run out of same-kind swaps that are not real words; widen the net.
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        attempts = 0
        while options.count < 2, attempts < 200 {
            attempts += 1
            var changed = original
            changed[Int.random(in: 0..<changed.count, using: &rng)] = alphabet.randomElement(using: &rng)!
            consider(String(changed))
        }
        return ([missing] + options.prefix(2)).shuffled(using: &rng)
    }

    /// A copy-typing challenge for Typing Turbo: the text stays visible.
    public static func typing<R: RandomNumberGenerator>(
        level: Int, profile: InputProfile, bank: WordBank = .shared, avoiding used: Set<String> = [], using rng: inout R
    ) -> Question {
        let level = min(max(level, 1), 5)
        let wantsSentence: Bool
        switch profile {
        case .compactTouch: wantsSentence = level >= 4
        case .fullTouch: wantsSentence = level >= 2
        case .hardware: wantsSentence = true
        }
        if wantsSentence {
            let sentenceLevel = profile == .compactTouch ? max(1, level - 2) : level
            let pool = bank.sentencePool(level: sentenceLevel)
            let fresh = pool.filter { !used.contains($0.text) }
            let pick = (fresh.isEmpty ? pool : fresh).randomElement(using: &rng)!
            return Question(key: "typing:L\(level)", skill: .typing, format: .typed, prompt: pick.text, answer: pick.text,
                            hint: "Find each letter one at a time. There is no rush.", spoken: pick.text, level: level)
        }
        let pool = bank.pool(topics: Skill.spellingTopics, level: min(level + 1, 3))
        let fresh = pool.filter { !used.contains($0.word) }
        let pick = (fresh.isEmpty ? pool : fresh).randomElement(using: &rng)!
        return Question(key: "typing:L\(level)", skill: .typing, format: .typed, prompt: pick.word, answer: pick.word,
                        hint: "Find each letter one at a time. There is no rush.", spoken: pick.word, level: level)
    }
}
