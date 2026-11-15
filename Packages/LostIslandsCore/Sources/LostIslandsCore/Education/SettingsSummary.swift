import Foundation

/// One line of the grown-ups' settings in plain words, for the check before a new player's first adventure.
public struct SettingsLine: Equatable, Sendable {
    public let label: String
    public let value: String
    /// True when it differs from what a new player starts with.
    public let changed: Bool
}

extension ParentSettings {
    /// The numbers times-table and division questions can actually use, once switched-off tables are left out.
    public var usableMultipliers: [Int] {
        let limits = MathsGenerator.Limits(tables: tables, multipliers: multipliers)
        return MathsGenerator.defaultMultipliers.filter { limits.allows(multiplier: $0) }
    }

    /// The learning settings in plain words, in the order the quick setup shows them. "×" and its
    /// number are joined by a non-breaking space so a narrow screen never splits them.
    public var summary: [SettingsLine] {
        let fresh = ParentSettings()
        let tables = MathsGenerator.defaultTables.filter(self.tables.contains)
        let multipliers = usableMultipliers
        let denominators = MathsGenerator.defaultDenominators.filter(self.denominators.contains)
        let topics = Skill.spellingTopics.filter(spellingTopics.contains)
        let fractionName = { (denominator: Int) in SettingsWording.fractionNames[denominator] ?? "1/\(denominator)" }
        return [
            SettingsLine(label: "Difficulty",
                         value: difficulty.title.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression),
                         changed: difficulty != fresh.difficulty),
            SettingsLine(label: "Times tables",
                         value: SettingsWording.listed(tables.map(String.init)),
                         changed: Set(tables) != Set(fresh.tables)),
            SettingsLine(label: "Multiply and divide by",
                         value: SettingsWording.describe(multipliers, of: MathsGenerator.defaultMultipliers,
                                                         name: { "×\u{00A0}\($0)" }, everything: "Everything from ×\u{00A0}1 to ×\u{00A0}12",
                                                         range: { "×\u{00A0}\($0) to ×\u{00A0}\($1)" }),
                         changed: multipliers.count != MathsGenerator.defaultMultipliers.count),
            SettingsLine(label: "Fractions",
                         value: SettingsWording.describe(denominators, of: MathsGenerator.defaultDenominators,
                                                         name: fractionName, everything: "Halves to tenths",
                                                         range: { "\(fractionName($0)) to \(fractionName($1))" }),
                         changed: denominators.count != MathsGenerator.defaultDenominators.count),
            SettingsLine(label: "Spelling",
                         value: SettingsWording.describe(topics, of: Skill.spellingTopics, name: { $0.title.lowercased() },
                                                         everything: "All \(Skill.spellingTopics.count) topics"),
                         changed: topics.count != Skill.spellingTopics.count),
        ]
    }
}

enum SettingsWording {
    static let fractionNames = [2: "halves", 3: "thirds", 4: "quarters", 5: "fifths", 6: "sixths",
                                7: "sevenths", 8: "eighths", 9: "ninths", 10: "tenths"]

    /// "a", "a and b", "a, b and c".
    static func listed(_ items: [String], last: String = "and") -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " \(last) " + items[items.count - 1]
    }

    static func capitalised(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    /// The chosen items in as few words as possible: everything, "Only …", a range, a range or
    /// "All but" with one or two gaps, or else a plain list.
    static func describe<T: Equatable>(_ chosen: [T], of all: [T], name: (T) -> String, everything: String,
                                       range: ((T, T) -> String)? = nil) -> String {
        let picked = all.filter(chosen.contains)
        guard picked.count != all.count else { return everything }
        guard let first = picked.first, let last = picked.last else { return "None" }
        if picked.count == 1 { return "Only \(name(first))" }
        let span: [T]
        if range != nil, let start = all.firstIndex(of: first), let end = all.firstIndex(of: last) {
            span = Array(all[start...end])
        } else {
            span = all
        }
        let missing = span.filter { !picked.contains($0) }
        if let range, missing.isEmpty { return capitalised(range(first, last)) }
        if missing.count <= 2 {
            let gaps = missing.map(name)
            if span.count == all.count { return "All but \(listed(gaps))" }
            if let range { return capitalised("\(range(first, last)), but not \(listed(gaps, last: "or"))") }
        }
        return capitalised(listed(picked.map(name)))
    }
}
