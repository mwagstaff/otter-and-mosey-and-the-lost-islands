import Foundation

/// Generates Year 3 maths questions that always have exactly one right answer.
public enum MathsGenerator {
    public static let defaultTables = [2, 3, 4, 5, 8, 10]

    public static func make<R: RandomNumberGenerator>(
        skill: Skill, level: Int, tables: [Int] = defaultTables,
        format: AnswerFormat = .choice, using rng: inout R
    ) -> Question {
        let level = min(max(level, 1), 5)
        let tables = tables.isEmpty ? defaultTables : tables
        let draft: Draft
        switch skill {
        case .addition: draft = addition(level, &rng)
        case .subtraction: draft = subtraction(level, &rng)
        case .multiplication: draft = multiplication(level, tables, &rng)
        case .division: draft = division(level, tables, &rng)
        case .fractions: draft = fractions(level, &rng)
        case .placeValue: draft = placeValue(level, &rng)
        case .sequences: draft = sequences(level, &rng)
        case .wordProblems: draft = wordProblem(level, tables, &rng)
        default: draft = addition(level, &rng)
        }
        return draft.question(skill: skill, level: level, format: format, using: &rng)
    }

    /// Rebuilds a specific times-table or division fact from its spaced-repetition key.
    public static func make<R: RandomNumberGenerator>(
        factKey key: String, level: Int, format: AnswerFormat = .choice, using rng: inout R
    ) -> Question? {
        let parts = key.split(separator: ":")
        guard parts.count == 2 else { return nil }
        let numbers = parts[1].split(separator: "x").compactMap { Int($0) }
        guard numbers.count == 2, numbers[0] > 0, numbers[1] > 0 else { return nil }
        let (a, b) = (numbers[0], numbers[1])
        switch parts[0] {
        case "mul":
            return timesFact(a, b).question(skill: .multiplication, level: level, format: format, using: &rng)
        case "div":
            return divisionFact(table: a, quotient: b).question(skill: .division, level: level, format: format, using: &rng)
        default:
            return nil
        }
    }

    // MARK: - Draft

    struct Draft {
        var key: String?
        var prompt: String
        var answer: Int
        var near: [Int]
        var hint: String
        var spoken: String?
        var audio: String?

        func question<R: RandomNumberGenerator>(
            skill: Skill, level: Int, format: AnswerFormat, using rng: inout R
        ) -> Question {
            let options = MathsGenerator.choices(answer: answer, near: near, using: &rng)
            return Question(
                key: key ?? "\(skill.rawValue):L\(level)", skill: skill, format: format, prompt: prompt,
                answer: String(answer), choices: options.map(String.init), hint: hint,
                spoken: spoken ?? MathsGenerator.speakable(prompt), level: level,
                audioKey: audio ?? "skill_\(skill.rawValue)"
            )
        }
    }

    /// Three distinct, non-negative options containing the answer.
    static func choices<R: RandomNumberGenerator>(answer: Int, near: [Int], using rng: inout R) -> [Int] {
        var pool: [Int] = []
        for candidate in near.shuffled(using: &rng) where candidate >= 0 && candidate != answer && !pool.contains(candidate) {
            pool.append(candidate)
        }
        var offset = 1
        while pool.count < 2 {
            for candidate in [answer + offset, answer - offset] where candidate >= 0 && candidate != answer && !pool.contains(candidate) {
                pool.append(candidate)
            }
            offset += 1
        }
        return ([answer] + pool.prefix(2)).shuffled(using: &rng)
    }

    /// Wrong answers a child might plausibly reach: one or two out, or a place-value slip
    /// when the number is big enough for that to make sense.
    static func slips(around answer: Int) -> [Int] {
        var offsets = [1, -1, 2, -2]
        if answer >= 20 { offsets += [10, -10] }
        if answer >= 150 { offsets += [100, -100] }
        return offsets.map { answer + $0 }.filter { $0 >= 0 }
    }

    static func speakable(_ prompt: String) -> String {
        prompt
            .replacingOccurrences(of: "×", with: " times ")
            .replacingOccurrences(of: "÷", with: " divided by ")
            .replacingOccurrences(of: "−", with: " take away ")
            .replacingOccurrences(of: "+", with: " plus ")
            .replacingOccurrences(of: "= ?", with: "")
            .replacingOccurrences(of: "?", with: " what ")
    }

    // MARK: - Number operations

    static func addition<R: RandomNumberGenerator>(_ level: Int, _ rng: inout R) -> Draft {
        let a: Int, b: Int
        switch level {
        case 1: a = .random(in: 2...10, using: &rng); b = .random(in: 2...9, using: &rng)
        case 2: a = .random(in: 11...60, using: &rng); b = .random(in: 2...9, using: &rng)
        case 3: a = .random(in: 12...55, using: &rng); b = .random(in: 11...44, using: &rng)
        case 4:
            a = .random(in: 110...780, using: &rng)
            b = [.random(in: 2...9, using: &rng), .random(in: 1...9, using: &rng) * 10, .random(in: 1...2, using: &rng) * 100]
                .randomElement(using: &rng)!
        default: a = .random(in: 120...560, using: &rng); b = .random(in: 25...380, using: &rng)
        }
        let answer = a + b
        return Draft(
            prompt: "\(a) + \(b) = ?", answer: answer,
            near: slips(around: answer),
            hint: level <= 2 ? "Start at \(max(a, b)) and count on \(min(a, b))." : "Add the tens first, then the ones."
        )
    }

    static func subtraction<R: RandomNumberGenerator>(_ level: Int, _ rng: inout R) -> Draft {
        let a: Int, b: Int
        switch level {
        case 1: a = .random(in: 6...20, using: &rng); b = .random(in: 1...min(9, a - 1), using: &rng)
        case 2: a = .random(in: 21...80, using: &rng); b = .random(in: 2...9, using: &rng)
        case 3: a = .random(in: 40...99, using: &rng); b = .random(in: 11...(a - 8), using: &rng)
        case 4:
            a = .random(in: 230...900, using: &rng)
            b = [.random(in: 2...9, using: &rng), .random(in: 1...9, using: &rng) * 10, .random(in: 1...2, using: &rng) * 100]
                .randomElement(using: &rng)!
        default: a = .random(in: 300...900, using: &rng); b = .random(in: 25...(a - 100), using: &rng)
        }
        let answer = a - b
        return Draft(
            prompt: "\(a) − \(b) = ?", answer: answer,
            near: slips(around: answer) + [a + b],
            hint: level <= 2 ? "Start at \(a) and count back \(b)." : "Take away the tens first, then the ones."
        )
    }

    static func timesFact(_ table: Int, _ other: Int) -> Draft {
        let answer = table * other
        let steps = (1...3).map { String(table * $0) }.joined(separator: ", ")
        return Draft(
            key: "mul:\(table)x\(other)",
            prompt: "\(other) × \(table) = ?", answer: answer,
            near: [answer + table, answer - table, answer + other, answer - other, answer + 1, answer - 1, answer + 10].filter { $0 > 0 },
            hint: "Count in \(table)s, \(other) times: \(steps), …",
            audio: recordedFact("mul", table, other)
        )
    }

    static func divisionFact(table: Int, quotient: Int) -> Draft {
        let dividend = table * quotient
        return Draft(
            key: "div:\(table)x\(quotient)",
            prompt: "\(dividend) ÷ \(table) = ?", answer: quotient,
            near: [quotient + 1, quotient - 1, quotient + 2, quotient - 2, table, quotient * 2].filter { $0 > 0 },
            hint: "How many \(table)s make \(dividend)? Count in \(table)s.",
            audio: recordedFact("div", table, quotient)
        )
    }

    /// The narrator clip for a times-table fact, when that fact is one of the recorded ones.
    static func recordedFact(_ kind: String, _ table: Int, _ other: Int) -> String? {
        defaultTables.contains(table) && (1...12).contains(other) ? "\(kind)_\(table)x\(other)" : nil
    }

    static func tables(for level: Int, from enabled: [Int]) -> [Int] {
        let wanted: [Int]
        switch level {
        case 1: wanted = [2, 5, 10]
        case 2: wanted = [2, 5, 10, 3]
        case 3: wanted = [3, 4, 8]
        default: wanted = enabled
        }
        let usable = wanted.filter(enabled.contains)
        return usable.isEmpty ? enabled : usable
    }

    static func multiplication<R: RandomNumberGenerator>(_ level: Int, _ tables: [Int], _ rng: inout R) -> Draft {
        let table = MathsGenerator.tables(for: level, from: tables).randomElement(using: &rng)!
        if level == 5, Bool.random(using: &rng) {
            // Year 3 extension: a multiple of ten times a single digit.
            let tens = Int.random(in: 2...8, using: &rng) * 10
            let answer = tens * table
            return Draft(
                prompt: "\(tens) × \(table) = ?", answer: answer,
                near: [answer + 10, answer - 10, answer / 10, answer + table * 10, answer - table].filter { $0 > 0 },
                hint: "Work out \(tens / 10) × \(table) first, then make it ten times bigger."
            )
        }
        let other = Int.random(in: (level == 1 ? 1...6 : 2...12), using: &rng)
        if level >= 4, Bool.random(using: &rng) {
            let product = table * other
            return Draft(
                key: "mul:\(table)x\(other)",
                prompt: "? × \(table) = \(product)", answer: other,
                near: [other + 1, other - 1, other + 2, other - 2, table].filter { $0 > 0 },
                hint: "Count in \(table)s until you reach \(product). How many jumps?",
                spoken: "What times \(table) equals \(product)?",
                audio: recordedFact("mulq", table, other)
            )
        }
        return timesFact(table, other)
    }

    static func division<R: RandomNumberGenerator>(_ level: Int, _ tables: [Int], _ rng: inout R) -> Draft {
        let table = MathsGenerator.tables(for: level, from: tables).randomElement(using: &rng)!
        let quotient = Int.random(in: (level == 1 ? 1...6 : 2...12), using: &rng)
        return divisionFact(table: table, quotient: quotient)
    }

    // MARK: - Fractions, place value, sequences

    static func fractions<R: RandomNumberGenerator>(_ level: Int, _ rng: inout R) -> Draft {
        switch level {
        case 1:
            let half = Int.random(in: 2...10, using: &rng)
            return Draft(prompt: "Half of \(half * 2) = ?", answer: half, near: [half + 1, half - 1, half * 2, half + 2],
                         hint: "Split \(half * 2) into 2 equal groups.")
        case 2, 3:
            let denominator = (level == 2 ? [3, 4] : [3, 4, 5, 8, 10]).randomElement(using: &rng)!
            let part = Int.random(in: 2...(level == 2 ? 6 : 9), using: &rng)
            let whole = denominator * part
            return Draft(prompt: "1/\(denominator) of \(whole) = ?", answer: part,
                         near: [part + 1, part - 1, denominator, part * 2, whole - denominator].filter { $0 > 0 },
                         hint: "Share \(whole) into \(denominator) equal groups.",
                         spoken: "What is one \(ordinal(denominator)) of \(whole)?")
        case 4:
            let denominator = [3, 4, 5].randomElement(using: &rng)!
            let numerator = Int.random(in: 2...(denominator - 1), using: &rng)
            let part = Int.random(in: 2...6, using: &rng)
            let whole = denominator * part
            return Draft(prompt: "\(numerator)/\(denominator) of \(whole) = ?", answer: numerator * part,
                         near: [part, whole - part, numerator * part + part, numerator * part - 1, numerator * part + 1].filter { $0 > 0 },
                         hint: "Find 1/\(denominator) of \(whole) first, then multiply by \(numerator).",
                         spoken: "What is \(numerator) \(ordinal(denominator))s of \(whole)?")
        default:
            let denominator = [5, 6, 7, 8, 9, 10].randomElement(using: &rng)!
            let a = Int.random(in: 1...(denominator - 3), using: &rng)
            let b = Int.random(in: 1...(denominator - a - 1), using: &rng)
            return Draft(prompt: "\(a)/\(denominator) + \(b)/\(denominator) = ?/\(denominator)", answer: a + b,
                         near: [a + b + 1, a + b - 1, denominator, a * b, a + b + 2].filter { $0 > 0 },
                         hint: "The bottom number stays the same. Just add the top numbers.",
                         spoken: "\(a) \(ordinal(denominator))s plus \(b) \(ordinal(denominator))s. How many \(ordinal(denominator))s?")
        }
    }

    static func ordinal(_ denominator: Int) -> String {
        switch denominator {
        case 2: "half"
        case 3: "third"
        case 4: "quarter"
        case 5: "fifth"
        case 6: "sixth"
        case 7: "seventh"
        case 8: "eighth"
        case 9: "ninth"
        default: "tenth"
        }
    }

    static func placeValue<R: RandomNumberGenerator>(_ level: Int, _ rng: inout R) -> Draft {
        switch level {
        case 1:
            let n = Int.random(in: 12...85, using: &rng)
            let more = Bool.random(using: &rng)
            let answer = more ? n + 10 : n - 10
            return Draft(prompt: "10 \(more ? "more" : "less") than \(n) = ?", answer: answer,
                         near: [n + 1, n - 1, more ? n - 10 : n + 10, answer + 10],
                         hint: "Only the tens digit changes.")
        case 2:
            let n = Int.random(in: 120...850, using: &rng)
            let more = Bool.random(using: &rng)
            let answer = more ? n + 100 : n - 100
            return Draft(prompt: "100 \(more ? "more" : "less") than \(n) = ?", answer: answer,
                         near: [more ? n + 10 : n - 10, more ? n - 100 : n + 100, answer + 10, answer - 10],
                         hint: "Only the hundreds digit changes.")
        case 3:
            let digits = Array([1, 2, 3, 4, 5, 6, 7, 8, 9].shuffled(using: &rng).prefix(3))
            let n = digits[0] * 100 + digits[1] * 10 + digits[2]
            let index = Int.random(in: 0...2, using: &rng)
            let scale = [100, 10, 1][index]
            let digit = digits[index]
            return Draft(prompt: "In \(n), the \(digit) is worth ?", answer: digit * scale,
                         near: [digit, digit * 10, digit * 100],
                         hint: "Is the \(digit) in the hundreds, tens or ones place?",
                         spoken: "In the number \(n), what is the \(digit) worth?")
        case 4:
            let h = Int.random(in: 1...9, using: &rng), t = Int.random(in: 1...9, using: &rng), o = Int.random(in: 1...9, using: &rng)
            let answer = h * 100 + t * 10 + o
            return Draft(prompt: "\(h * 100) + \(t * 10) + \(o) = ?", answer: answer,
                         near: [h * 100 + o * 10 + t, t * 100 + h * 10 + o, h * 100 + t + o, answer + 10].filter { $0 != answer },
                         hint: "Put the hundreds, tens and ones side by side.")
        default:
            let digits = Array([1, 2, 3, 4, 5, 6, 7, 8, 9].shuffled(using: &rng).prefix(3))
            let answer = digits[0] * 100 + digits[1] * 10 + digits[2]
            return Draft(prompt: "\(digits[1]) tens, \(digits[2]) ones and \(digits[0]) hundreds = ?", answer: answer,
                         near: [digits[1] * 100 + digits[2] * 10 + digits[0], digits[2] * 100 + digits[1] * 10 + digits[0],
                                digits[0] * 100 + digits[2] * 10 + digits[1]],
                         hint: "Hundreds come first, then tens, then ones.")
        }
    }

    static func sequences<R: RandomNumberGenerator>(_ level: Int, _ rng: inout R) -> Draft {
        let step: Int
        switch level {
        case 1: step = [2, 5, 10].randomElement(using: &rng)!
        case 2: step = [3, 4].randomElement(using: &rng)!
        case 3: step = [4, 8].randomElement(using: &rng)!
        case 4: step = [50, 100].randomElement(using: &rng)!
        default: step = [3, 4, 8, 50].randomElement(using: &rng)!
        }
        let start = step * Int.random(in: (level >= 4 ? 0...4 : 1...6), using: &rng)
        var terms = (0..<5).map { start + step * $0 }
        if level == 5, Bool.random(using: &rng) { terms.reverse() }
        let hole = level >= 5 ? Int.random(in: 2...3, using: &rng) : 4
        let answer = terms[hole]
        let shown = terms.enumerated().map { $0.offset == hole ? "?" : String($0.element) }.joined(separator: ", ")
        return Draft(prompt: shown, answer: answer,
                     near: [answer + step, answer - step, answer + 1, answer - 1, answer + 2, answer + 10].filter { $0 >= 0 },
                     hint: "The numbers \(terms[1] > terms[0] ? "go up" : "go down") by \(step) each time.",
                     spoken: "Which number is missing from the pattern?")
    }

    // MARK: - Word problems

    static func wordProblem<R: RandomNumberGenerator>(_ level: Int, _ tables: [Int], _ rng: inout R) -> Draft {
        let things = ["shells", "pearls", "berries", "acorns", "starfish", "pebbles"].randomElement(using: &rng)!
        switch Int.random(in: 0...(level >= 4 ? 4 : 3), using: &rng) {
        case 0:
            let a = Int.random(in: (level <= 2 ? 5...20 : 20...70), using: &rng)
            let b = Int.random(in: (level <= 2 ? 3...9 : 11...28), using: &rng)
            return Draft(prompt: "Otter has \(a) \(things). Mosey gives him \(b) more. How many now?", answer: a + b,
                         near: [a + b + 1, a + b - 1, a - b, a + b + 10, a + b - 10].filter { $0 > 0 },
                         hint: "More means add: \(a) + \(b).")
        case 1:
            let a = Int.random(in: (level <= 2 ? 10...20 : 30...90), using: &rng)
            let b = Int.random(in: (level <= 2 ? 2...8 : 11...25), using: &rng)
            return Draft(prompt: "Mosey has \(a) \(things). She gives \(b) away. How many are left?", answer: a - b,
                         near: [a - b + 1, a - b - 1, a + b, a - b + 10, a - b - 10].filter { $0 > 0 },
                         hint: "Giving away means subtract: \(a) − \(b).")
        case 2:
            let table = MathsGenerator.tables(for: max(level, 2), from: tables).randomElement(using: &rng)!
            let groups = Int.random(in: 2...(level <= 2 ? 5 : 9), using: &rng)
            return Draft(key: "mul:\(table)x\(groups)",
                         prompt: "\(groups) baby dragons eat \(table) \(things) each. How many altogether?", answer: groups * table,
                         near: [groups + table, groups * table + table, groups * table - table, groups * table + 1].filter { $0 > 0 },
                         hint: "\(groups) lots of \(table) is \(groups) × \(table).")
        case 3:
            let table = MathsGenerator.tables(for: max(level, 2), from: tables).randomElement(using: &rng)!
            let each = Int.random(in: 2...(level <= 2 ? 5 : 9), using: &rng)
            return Draft(key: "div:\(table)x\(each)",
                         prompt: "Otter shares \(table * each) \(things) equally between \(table) friends. How many each?", answer: each,
                         near: [each + 1, each - 1, table, each + 2, table * each - table].filter { $0 > 0 },
                         hint: "Sharing equally means divide: \(table * each) ÷ \(table).")
        default:
            let a = Int.random(in: 20...60, using: &rng), b = Int.random(in: 11...30, using: &rng), c = Int.random(in: 5...15, using: &rng)
            return Draft(prompt: "Otter has \(a) \(things). He finds \(b) more, then drops \(c). How many now?", answer: a + b - c,
                         near: [a + b, a + b + c, a - b + c, a + b - c + 10, a + b - c - 1].filter { $0 > 0 },
                         hint: "Two steps: first \(a) + \(b), then take away \(c).")
        }
    }
}
