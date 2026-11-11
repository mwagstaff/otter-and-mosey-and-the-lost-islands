import Foundation
import Testing
@testable import LostIslandsCore

@Suite struct MathsGeneratorTests {
    /// Independently evaluates simple "a op b = ?" prompts.
    func evaluate(_ prompt: String) -> Int? {
        let parts = prompt.split(separator: " ").map(String.init)
        guard parts.count == 5, parts[3] == "=", parts[4] == "?", let a = Int(parts[0]), let b = Int(parts[2]) else { return nil }
        switch parts[1] {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b != 0 && a % b == 0 ? a / b : nil
        default: return nil
        }
    }

    @Test func everySkillAndLevelIsWellFormed() {
        var rng = SeededGenerator(seed: 42)
        for skill in Skill.mathsTopics {
            for level in 1...5 {
                for _ in 0..<300 {
                    let question = MathsGenerator.make(skill: skill, level: level, using: &rng)
                    let answer = Int(question.answer)
                    #expect(answer != nil && answer! >= 0, "\(question.prompt)")
                    #expect(question.choices.count == 3, "\(question.prompt)")
                    #expect(Set(question.choices).count == 3, "choices must differ: \(question.prompt) \(question.choices)")
                    #expect(question.choices.filter { question.isCorrect(choice: $0) }.count == 1)
                    #expect(question.choices.allSatisfy { (Int($0) ?? -1) >= 0 })
                    #expect(!question.hint.isEmpty)
                    if let expected = evaluate(question.prompt) {
                        #expect(expected == answer, "\(question.prompt) should be \(expected), got \(question.answer)")
                    }
                }
            }
        }
    }

    @Test func arithmeticPromptsAreIndependentlyCheckable() {
        var rng = SeededGenerator(seed: 7)
        var checked = 0
        for skill in [Skill.addition, .subtraction, .division] {
            for level in 1...5 {
                for _ in 0..<100 {
                    let question = MathsGenerator.make(skill: skill, level: level, using: &rng)
                    #expect(evaluate(question.prompt) == Int(question.answer), "\(question.prompt)")
                    checked += 1
                }
            }
        }
        #expect(checked == 1500)
    }

    @Test func multiplicationRespectsChosenTables() {
        var rng = SeededGenerator(seed: 3)
        for _ in 0..<300 {
            let question = MathsGenerator.make(skill: .multiplication, level: 4, tables: [8], using: &rng)
            #expect(question.key.hasPrefix("mul:8x"), "\(question.key)")
        }
    }

    @Test func missingFactorAnswersAreConsistent() {
        var rng = SeededGenerator(seed: 11)
        for _ in 0..<400 {
            let question = MathsGenerator.make(skill: .multiplication, level: 4, using: &rng)
            guard question.prompt.hasPrefix("?") else { continue }
            let parts = question.prompt.split(separator: " ").compactMap { Int($0) }
            #expect(parts.count == 2 && Int(question.answer)! * parts[0] == parts[1], "\(question.prompt)")
        }
    }

    @Test func fractionsOfAmountsAreWhole() {
        var rng = SeededGenerator(seed: 5)
        for level in 2...4 {
            for _ in 0..<200 {
                let question = MathsGenerator.make(skill: .fractions, level: level, using: &rng)
                // "n/d of w = ?"
                let numbers = question.prompt.replacingOccurrences(of: "/", with: " ").split(separator: " ").compactMap { Int($0) }
                #expect(numbers.count == 3)
                #expect(numbers[2] % numbers[1] == 0)
                #expect(numbers[2] / numbers[1] * numbers[0] == Int(question.answer))
            }
        }
    }

    @Test func factKeysRebuildTheSameFact() {
        var rng = SeededGenerator(seed: 1)
        let times = MathsGenerator.make(factKey: "mul:8x7", level: 3, using: &rng)
        #expect(times?.answer == "56")
        let divide = MathsGenerator.make(factKey: "div:4x9", level: 3, using: &rng)
        #expect(divide?.prompt == "36 ÷ 4 = ?" && divide?.answer == "9")
        #expect(MathsGenerator.make(factKey: "word:because", level: 3, using: &rng) == nil)
    }

    @Test func typedFormatUsesTheAnswerDigits() {
        var rng = SeededGenerator(seed: 9)
        let question = MathsGenerator.make(skill: .multiplication, level: 3, format: .typed, using: &rng)
        #expect(question.format == .typed && question.typingTarget == question.answer)
        #expect(question.isCorrect(typed: " \(question.answer) "))
    }
}

@Suite struct WordBankTests {
    let bank = WordBank.shared

    @Test func bankIsSubstantialAndClean() {
        #expect(bank.words.count >= 250)
        #expect(Set(bank.words.map(\.word)).count == bank.words.count, "words must be unique")
        for entry in bank.words {
            #expect(entry.word.allSatisfy { $0.isLetter && $0.isLowercase }, "\(entry.word)")
            #expect(entry.sentence.components(separatedBy: "___").count == 2, "\(entry.word)")
            #expect((1...5).contains(entry.level))
            #expect(entry.topic.subject == .spelling)
            #expect(!entry.sentence.lowercased().contains(" \(entry.word) "), "sentence gives away \(entry.word)")
        }
        for topic in Skill.spellingTopics {
            #expect(bank.words.filter { $0.topic == topic }.count >= 20, "\(topic)")
        }
    }

    @Test func ukSpellingsArePresent() {
        #expect(bank.contains("favourite"))
        #expect(!bank.contains("favorite"))
        let text = bank.words.map(\.sentence).joined(separator: " ") + bank.sentences.map(\.text).joined(separator: " ")
        #expect(text.contains("colour") && !text.contains("color "))
    }

    @Test func homophonesHavePartnersAndDifferentSpellings() {
        for entry in bank.words where entry.topic == .homophones {
            #expect(entry.partner != nil && entry.partner != entry.word, "\(entry.word)")
        }
    }

    @Test func typedChallengesRebuildTheWord() {
        var rng = SeededGenerator(seed: 21)
        for entry in bank.words {
            for level in 1...5 {
                let question = SpellingGenerator.make(entry: entry, style: .typed, level: level, using: &rng)
                #expect(question.format == .typed)
                var missing = Array(question.typingTarget)
                let rebuilt = String((question.masked ?? "").map { $0 == "_" ? missing.removeFirst() : $0 })
                #expect(rebuilt == entry.word, "\(entry.word) L\(level): \(question.masked ?? "") + \(question.typingTarget)")
                #expect(missing.isEmpty)
                #expect(question.isCorrect(typed: question.typingTarget.uppercased()))
            }
        }
    }

    @Test func choiceChallengesHaveExactlyOneRealWord() {
        var rng = SeededGenerator(seed: 22)
        for entry in bank.words {
            for level in 1...4 {
                let question = SpellingGenerator.make(entry: entry, style: .choice, level: level, using: &rng)
                #expect(question.choices.count >= 2 && Set(question.choices).count == question.choices.count, "\(entry.word)")
                #expect(question.choices.filter { question.isCorrect(choice: $0) }.count == 1, "\(entry.word)")
                guard let masked = question.masked else { continue }
                let real = question.choices.filter { choice in
                    var letters = Array(choice)
                    let filled = String(masked.map { $0 == "_" ? letters.removeFirst() : $0 })
                    return bank.isRealWord(filled)
                }
                #expect(real == [question.correctChoice], "\(entry.word): \(question.choices)")
            }
        }
    }

    @Test func wrongChoicesNeverSpellAnotherRealWord() {
        #expect(bank.isRealWord("sum") && bank.isRealWord("sin"), "common lookalikes are known")
        var rng = SeededGenerator(seed: 77)
        let sun = bank.entry(for: "sun")!
        for _ in 0..<200 {
            let question = SpellingGenerator.make(entry: sun, style: .choice, level: 1, using: &rng)
            #expect(question.choices.count == 3)
            for choice in question.choices where choice != question.correctChoice {
                var letters = Array(choice)
                let filled = String((question.masked ?? "").map { $0 == "_" ? letters.removeFirst() : $0 })
                #expect(!bank.isRealWord(filled), "\(filled) is a real word")
            }
        }
    }

    @Test func everySpokenQuestionHasANarrationLine() {
        let narration = WordBank.narration
        #expect(narration.count > 480)
        var rng = SeededGenerator(seed: 12)
        for entry in bank.words {
            for style in [SpellingGenerator.Style.typed, .choice] {
                let question = SpellingGenerator.make(entry: entry, style: style, level: 3, using: &rng)
                #expect(question.audioKey == "word_\(entry.word)")
                #expect(narration[question.audioKey ?? ""]?.lowercased().contains(entry.word) == true, "\(entry.word)")
            }
        }
        var specific = 0
        for skill in Skill.mathsTopics {
            for level in 1...5 {
                for _ in 0..<200 {
                    let question = MathsGenerator.make(skill: skill, level: level, using: &rng)
                    let key = question.audioKey ?? "none"
                    #expect(narration[key] != nil, "no narration for \(key): \(question.prompt)")
                    if !key.hasPrefix("skill_") { specific += 1 }
                }
            }
        }
        #expect(specific > 1000, "times-table and division facts get their own recordings")
        #expect(narration["mul_8x7"] == "7 times 8." && narration["div_4x9"] == "36 divided by 4.")
        #expect(SpellingGenerator.typing(level: 2, profile: .hardware, using: &rng).audioKey == nil)
    }

    @Test func typingContentAdaptsToInputMethod() {
        var rng = SeededGenerator(seed: 8)
        for _ in 0..<50 {
            let phone = SpellingGenerator.typing(level: 2, profile: .compactTouch, using: &rng)
            #expect(!phone.answer.contains(" "), "phones get single words at low levels")
            let keyboard = SpellingGenerator.typing(level: 2, profile: .hardware, using: &rng)
            #expect(keyboard.answer.contains(" "), "hardware keyboards get sentences")
        }
        #expect(bank.sentences.allSatisfy { $0.text.allSatisfy { $0 == " " || ($0.isLetter && $0.isLowercase) } })
    }
}

@Suite struct LearnerTests {
    @Test func ratingRisesWithSuccessAndEasesWithMistakes() {
        var learner = LearnerModel()
        #expect(learner.level(for: .addition) == 1)
        for _ in 0..<12 { learner.record(key: "addition:L1", skill: .addition, correct: true, seconds: 3, usedHint: false) }
        let raised = learner.level(for: .addition)
        #expect(raised >= 3)
        for _ in 0..<6 { learner.record(key: "addition:L3", skill: .addition, correct: false, seconds: 10, usedHint: false) }
        #expect(learner.level(for: .addition) < raised)
        for _ in 0..<100 { learner.record(key: "x", skill: .addition, correct: false, seconds: 1, usedHint: false) }
        #expect(learner.stats(for: .addition).rating == 1.0)
        for _ in 0..<100 { learner.record(key: "x", skill: .addition, correct: true, seconds: 1, usedHint: false) }
        #expect(learner.stats(for: .addition).rating == 5.0)
    }

    @Test func hintsCountAsLearningNotMastery() {
        var hinted = LearnerModel(), clean = LearnerModel()
        for _ in 0..<5 {
            hinted.record(key: "k", skill: .division, correct: true, seconds: 3, usedHint: true)
            clean.record(key: "k", skill: .division, correct: true, seconds: 3, usedHint: false)
        }
        #expect(hinted.stats(for: .division).rating < clean.stats(for: .division).rating)
    }

    @Test func difficultyModesClampTheLevel() {
        var learner = LearnerModel()
        for _ in 0..<60 { learner.record(key: "k", skill: .fractions, correct: true, seconds: 2, usedHint: false) }
        #expect(learner.level(for: .fractions, mode: .adaptive) == 5)
        #expect(learner.level(for: .fractions, mode: .gentle) == 2)
        #expect(learner.level(for: .fractions, mode: .steady) == 4)
        #expect(LearnerModel().level(for: .fractions, mode: .stretch) == 3)
    }

    @Test func troublesomeItemsComeBackAfterAGap() {
        var learner = LearnerModel()
        learner.record(key: "mul:8x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false)
        #expect(learner.dueKeys(for: [.multiplication]).isEmpty, "not due straight away")
        for _ in 0..<3 { learner.record(key: "addition:L1", skill: .addition, correct: true, seconds: 2, usedHint: false) }
        #expect(learner.dueKeys(for: [.multiplication]) == ["mul:8x7"])
        #expect(learner.dueKeys(for: [.addition]).isEmpty)
    }

    @Test func itemsAreRetiredOnceSecure() {
        var learner = LearnerModel()
        learner.record(key: "word:because", skill: .exceptionWords, correct: false, seconds: 9, usedHint: false)
        for _ in 0..<LearnerModel.intervals.count {
            learner.record(key: "word:because", skill: .exceptionWords, correct: true, seconds: 4, usedHint: false)
        }
        #expect(learner.items["word:because"] == nil)
    }

    @Test func gapsGrowAfterEachSuccess() {
        var learner = LearnerModel()
        learner.record(key: "word:friend", skill: .exceptionWords, correct: false, seconds: 9, usedHint: false)
        let first = learner.items["word:friend"]!.dueAt - learner.answerCount
        learner.record(key: "word:friend", skill: .exceptionWords, correct: true, seconds: 4, usedHint: false)
        let second = learner.items["word:friend"]!.dueAt - learner.answerCount
        #expect(second > first)
    }

    @Test func dashboardSummaries() {
        var learner = LearnerModel()
        #expect(learner.accuracy(for: .maths) == nil)
        for index in 0..<10 { learner.record(key: "k", skill: .subtraction, correct: index < 3, seconds: 5, usedHint: false) }
        #expect(learner.accuracy(for: .maths) == 0.3)
        #expect(learner.skillsNeedingPractice == [.subtraction])
        #expect(learner.practisedSkills == [.subtraction])
    }

    @Test func typingMeterMeasuresSpeedAndAccuracy() {
        var meter = TypingMeter()
        let start = Date(timeIntervalSince1970: 0)
        for index in 0..<50 { meter.record(correct: index % 10 != 0, at: start.addingTimeInterval(Double(index) * 0.6)) }
        #expect(meter.accuracy == 0.9)
        // 45 correct characters = 9 words in 29.4 seconds.
        #expect(abs((meter.wordsPerMinute ?? 0) - 9 / (29.4 / 60)) < 0.01)
        #expect(TypingMeter().wordsPerMinute == nil)
    }
}
