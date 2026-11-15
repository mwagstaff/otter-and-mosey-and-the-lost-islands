import LostIslandsCore
import SwiftUI

/// The grown-ups' area. Kept behind a gate and styled plainly so it reads as separate from play.
struct ParentAreaView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.97).ignoresSafeArea()
            if model.parentUnlocked {
                ParentDashboardView()
            } else {
                ParentGateView(onPass: { model.parentUnlocked = true }, onCancel: { model.leaveParentArea() })
            }
        }
    }
}

/// A sum most Year 3 children cannot yet do in their head, typed on a number pad.
struct ParentGateView: View {
    /// A line above the sum saying what the gate leads to, such as which player is being set up.
    var context: String?
    var onPass: () -> Void
    var onCancel: () -> Void
    @State private var a = Int.random(in: 13...19)
    @State private var b = Int.random(in: 6...9)
    @State private var entry = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 14) {
            if let context {
                Text(context)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(.white).stroke(Color(white: 0.85)))
            }
            Text("Grown-ups only").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("To continue, please answer:").font(.system(size: 18, design: .rounded)).foregroundStyle(.secondary)
            Text("\(a) × \(b) = \(entry.isEmpty ? "?" : entry)").font(.system(size: 38, weight: .heavy, design: .rounded)).monospacedDigit()
            if wrong { Text("That's not right. Here's a new one.").font(.system(size: 15, design: .rounded)).foregroundStyle(.red) }
            HStack(spacing: 8) {
                ForEach(Array("1234567890"), id: \.self) { digit in
                    Button(String(digit)) { if entry.count < 3 { entry.append(digit) } }
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white).shadow(radius: 1))
                }
                Button { if !entry.isEmpty { entry.removeLast() } } label: { Image(systemName: "delete.left") }
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            HStack(spacing: 16) {
                Button("Back", action: onCancel).buttonStyle(.bordered)
                Button("Continue") {
                    if Int(entry) == a * b {
                        onPass()
                    } else {
                        wrong = true
                        entry = ""
                        a = .random(in: 13...19)
                        b = .random(in: 6...9)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.isEmpty)
            }
            .controlSize(.large)
        }
        .padding(30)
    }
}

struct ParentDashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false
    @State private var keepRewards = true
    @State private var confirmDelete = false

    private var profile: Profile? {
        model.save.profiles.first { $0.id == model.dashboardProfileID }
            ?? model.save.profiles.first { $0.id == model.save.activeProfileID }
            ?? model.save.profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    List {
                        if model.save.profiles.count > 1 {
                            Picker("Child", selection: Binding(get: { profile.id }, set: { model.dashboardProfileID = $0 })) {
                                ForEach(model.save.profiles) { Text("\($0.avatar) \($0.nickname)").tag($0.id) }
                            }
                        }
                        learning(profile)
                        overview(profile)
                        skills(profile)
                        practice(profile)
                        achievements(profile)
                        playtest(profile)
                        ending(profile)
                        Section("Sound and accessibility") {
                            SettingsControls(compact: true).listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                        Section {
                            Toggle("Keep trophies and treasures", isOn: $keepRewards)
                            Button("Restart \(profile.nickname)'s adventure", role: .destructive) { confirmReset = true }
                            Button("Delete \(profile.nickname)", role: .destructive) { confirmDelete = true }
                        } header: {
                            Text("Player")
                        } footer: {
                            Text("Restarting returns to the opening story and clears levels, stars, crystals, playtime and learning history. Keep trophies and treasures to save achievements, accessories and home decorations. The player and settings are always kept. Deleting removes the player completely. Everything is stored on this device only. The game has no accounts, adverts or purchases and collects no personal information.")
                        }
                    }
                } else {
                    List {
                        ContentUnavailableView("No players yet", systemImage: "person.crop.circle.badge.plus", description: Text("Create a player from the title screen to see their progress here."))
                        playtest(nil)
                        Section("Sound and accessibility") {
                            SettingsControls(compact: true)
                        }
                    }
                }
            }
            .navigationTitle("Parent dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { model.leaveParentArea() } }
            }
            .confirmationDialog("Restart \(profile?.nickname ?? "this child")'s adventure?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Restart adventure", role: .destructive) { if let profile { model.resetProgress(profile.id, keepRewards: keepRewards) } }
                Button("Keep progress", role: .cancel) {}
            } message: {
                Text("The story, levels, stars, crystals, playtime and learning history will start again. " + (keepRewards
                    ? "Trophies, achievements, treasures, accessories and home decorations will be kept. "
                    : "Trophies, achievements, treasures, accessories and home decorations will also be cleared. ")
                     + "The player and settings will be kept. This can't be undone.")
            }
            .alert("Delete \(profile?.nickname ?? "this player")?", isPresented: $confirmDelete, presenting: profile) { doomed in
                Button("Delete", role: .destructive) {
                    model.deleteProfile(doomed.id)
                    model.dashboardProfileID = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: { doomed in
                Text("\(doomed.nickname) and all their progress will be removed from this device. This can't be undone.")
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "No data yet" }

    /// "1 hour, 5 minutes", "12 minutes" or "0 minutes".
    private func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        func plural(_ count: Int, _ unit: String) -> String { "\(count) \(unit)\(count == 1 ? "" : "s")" }
        return hours > 0 ? "\(plural(hours, "hour")), \(plural(minutes % 60, "minute"))" : plural(minutes, "minute")
    }

    private func speed(average: Double, best: Double) -> String {
        "\(Int(average.rounded())) wpm average, best \(Int(best.rounded()))"
    }

    private func overview(_ profile: Profile) -> some View {
        let typing = profile.learner.typing
        return Section {
            LabeledContent("Playtime today", value: duration(profile.playSeconds(overLast: 1)))
            LabeledContent("Playtime, last 7 days", value: duration(profile.playSeconds(overLast: 7)))
            LabeledContent("Total playtime", value: duration(profile.playSeconds))
            LabeledContent("Stars and crystals", value: "\(profile.totalStars) stars, \(profile.crystals.count) of 6 crystals")
            LabeledContent("Spelling accuracy", value: percent(profile.learner.accuracy(for: .spelling)))
            LabeledContent("Maths accuracy", value: percent(profile.learner.accuracy(for: .maths)))
            LabeledContent("Typing accuracy", value: profile.learner.typing.keystrokes == 0 ? "No data yet" : percent(profile.learner.typing.accuracy))
            if typing.samples.isEmpty, typing.touchSamples.isEmpty {
                LabeledContent("Typing speed", value: "No data yet")
            }
            if !typing.samples.isEmpty {
                LabeledContent("Typing speed, keyboard", value: speed(average: typing.averageWordsPerMinute, best: typing.bestWordsPerMinute))
            }
            if !typing.touchSamples.isEmpty {
                LabeledContent("Typing speed, on-screen keys", value: speed(average: typing.averageTouchWordsPerMinute, best: typing.bestTouchWordsPerMinute))
            }
        } header: {
            Text("Overview")
        } footer: {
            Text("Typing speed is measured in Typing Turbo levels. Tapping on-screen keys is naturally slower than typing on a keyboard, so the two are shown separately.")
        }
    }

    private func skills(_ profile: Profile) -> some View {
        Section("Skills practised") {
            if profile.learner.practisedSkills.isEmpty { Text("Nothing practised yet.").foregroundStyle(.secondary) }
            ForEach(profile.learner.practisedSkills, id: \.self) { skill in
                let stats = profile.learner.stats(for: skill)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skill.title).font(.headline)
                        Spacer()
                        Text("Level \(profile.learner.level(for: skill)) of 5 · \(stats.correct)/\(stats.attempts) right first time")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: stats.accuracy).tint(stats.accuracy >= 0.8 ? .green : stats.accuracy >= 0.6 ? .orange : .red)
                    Text("Average answer time \(stats.averageSeconds.formatted(.number.precision(.fractionLength(1)))) s").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func practice(_ profile: Profile) -> some View {
        Section("Areas needing practice") {
            let weak = profile.learner.skillsNeedingPractice
            let tricky = profile.learner.troublesomeItems.prefix(12)
            if weak.isEmpty, tricky.isEmpty { Text("Nothing stands out yet. The game brings back anything missed automatically.").foregroundStyle(.secondary) }
            ForEach(weak, id: \.self) { Label($0.title, systemImage: "arrow.up.right.circle") }
            if !tricky.isEmpty {
                Text("Being revisited: " + tricky.map { describe($0.key) }.joined(separator: ", ")).font(.subheadline)
            }
        }
    }

    private func describe(_ key: String) -> String {
        let parts = key.split(separator: ":")
        guard parts.count == 2 else { return key }
        let numbers = parts[1].split(separator: "x")
        switch parts[0] {
        case "mul" where numbers.count == 2: return "\(numbers[1]) × \(numbers[0])"
        case "div" where numbers.count == 2: return "\((Int(numbers[0]) ?? 0) * (Int(numbers[1]) ?? 0)) ÷ \(numbers[0])"
        default: return String(parts[1])
        }
    }

    private func achievements(_ profile: Profile) -> some View {
        Section("Recent trophies") {
            let count = Trophies.count(in: profile, catalog: model.catalog)
            LabeledContent("Trophy cabinet", value: "\(count.won) of \(count.total)")
            let recent = profile.achievements.sorted { $0.value > $1.value }.compactMap { entry in
                Trophies.trophy(entry.key, catalog: model.catalog).map { ($0, entry.value) }
            }.prefix(5)
            if recent.isEmpty { Text("None yet.").foregroundStyle(.secondary) }
            ForEach(Array(recent), id: \.0.id) { trophy, date in
                LabeledContent(trophy.levelID.flatMap { model.catalog.level($0) }.map { "\(trophy.title): \($0.title)" } ?? trophy.title,
                               value: date.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    /// Any level, locked or not, for a grown-up to try. Nothing played here is saved.
    private func playtest(_ profile: Profile?) -> some View {
        Section {
            ForEach(model.catalog.islands) { island in
                DisclosureGroup(island.name) {
                    ForEach(island.levels) { level in
                        Button { model.startPlaytest(levelID: level.id, as: profile?.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.title).foregroundStyle(.primary)
                                    Text("\(level.mode.title) · \(level.count) questions · " + level.skills.map(\.title).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let profile, profile.stars(for: level.id) > 0 {
                                    Text(String(repeating: "★", count: profile.stars(for: level.id))).foregroundStyle(.orange)
                                }
                                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.teal)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play-test \(level.title)")
                    }
                }
            }
        } header: {
            Text("Play-test a level")
        } footer: {
            Text((profile.map { "Opens any level, even a locked one, with \($0.nickname)'s learning settings and current skill levels, so you see the questions they would get. " }
                  ?? "Opens any level, even a locked one, as a new player would see it. ")
                 + "Nothing is saved: no stars, treasures, playtime or learning progress.")
        }
    }

    /// Replays the finale for this child, for anyone who missed a bit of it.
    private func ending(_ profile: Profile) -> some View {
        Section {
            Button { model.watchEnding(for: profile.id) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch the ending").foregroundStyle(.primary)
                        Text("Nothing is saved or changed.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Watch the ending with \(profile.nickname)")
        } header: {
            Text("The ending")
        } footer: {
            Text(profile.crystals.count == model.catalog.islands.count
                 ? "Plays the end-of-game celebration again, with \(profile.nickname)'s name and totals. Watch it as often as you like."
                 : "\(profile.nickname) hasn't found all six crystal pieces yet, so this will show how the story ends before they get there.")
        }
    }

    private func learning(_ profile: Profile) -> some View {
        Section {
            MathsSettingsRows(profile: profile)
            VStack(alignment: .leading) {
                Text("Spelling topics")
                SpellingTopicRows(profile: profile)
            }
            PlaySettingsRows(profile: profile)
        } header: {
            Text("Learning settings")
        } footer: {
            Text(learningHelp)
        }
    }
}

let learningHelp = "Adaptive difficulty raises or lowers each skill separately based on recent answers. Switching a times table off also leaves it out as the other number, so with 8× off there's no 8 × 3 either. \"Multiply and divide by\" picks the other number: switch off × 11 and × 12 to keep things gentler. \"Fractions\" picks which fractions come up, from halves to tenths. Timed bonus points only add extra score for quick answers; nothing ever runs out of time."

/// Saves a change to one player's learning settings straight away.
private func parentBinding(_ profile: Profile, _ model: AppModel) -> Binding<ParentSettings> {
    Binding(get: { profile.parent }, set: { value in model.updateProfile(profile.id) { $0.parent = value } })
}

/// The list with `value` switched on or off, kept sorted. At least one value always stays on.
private func toggled(_ value: Int, in values: [Int]) -> [Int] {
    let next = values.contains(value) ? values.filter { $0 != value } : (values + [value]).sorted()
    return next.isEmpty ? values : next
}

/// Difficulty, times tables, multipliers and fractions, as rows of a list section.
struct MathsSettingsRows: View {
    @Environment(AppModel.self) private var model
    let profile: Profile

    private func fractionName(_ denominator: Int) -> String {
        SettingsNames.fraction(denominator)
    }

    var body: some View {
        let parent = parentBinding(profile, model)
        Picker("Difficulty", selection: parent.difficulty) {
            ForEach(DifficultyMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        VStack(alignment: .leading) {
            Text("Times tables")
            HStack {
                ForEach(MathsGenerator.defaultTables, id: \.self) { table in
                    let on = profile.parent.tables.contains(table)
                    Button("\(table)×") {
                        var tables = profile.parent.tables
                        if on { tables.removeAll { $0 == table } } else { tables.append(table) }
                        if !tables.isEmpty { parent.wrappedValue.tables = tables.sorted() }
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .teal : .gray)
                    .accessibilityValue(on ? "On" : "Off")
                }
            }
        }
        VStack(alignment: .leading) {
            Text("Multiply and divide by")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), alignment: .leading)], alignment: .leading) {
                ForEach(MathsGenerator.defaultMultipliers, id: \.self) { value in
                    // A switched-off table is never used as the other number either, so its button is off too.
                    let blocked = MathsGenerator.defaultTables.contains(value) && !profile.parent.tables.contains(value)
                    let on = profile.parent.multipliers.contains(value) && !blocked
                    Button("× \(value)") {
                        parent.wrappedValue.multipliers = toggled(value, in: profile.parent.multipliers)
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .teal : .gray)
                    .disabled(blocked)
                    .accessibilityValue(on ? "On" : "Off")
                }
            }
        }
        VStack(alignment: .leading) {
            Text("Fractions")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), alignment: .leading)], alignment: .leading) {
                ForEach(MathsGenerator.defaultDenominators, id: \.self) { denominator in
                    let on = profile.parent.denominators.contains(denominator)
                    Button("1/\(denominator)") {
                        parent.wrappedValue.denominators = toggled(denominator, in: profile.parent.denominators)
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .teal : .gray)
                    .accessibilityLabel(fractionName(denominator))
                    .accessibilityValue(on ? "On" : "Off")
                }
            }
        }
    }
}

/// A switch for each spelling topic. At least one always stays on.
struct SpellingTopicRows: View {
    @Environment(AppModel.self) private var model
    let profile: Profile

    var body: some View {
        let parent = parentBinding(profile, model)
        ForEach(Skill.spellingTopics, id: \.self) { topic in
            Toggle(topic.title, isOn: Binding(get: { profile.parent.spellingTopics.contains(topic) }, set: { isOn in
                var topics = profile.parent.spellingTopics
                if isOn { topics.append(topic) } else { topics.removeAll { $0 == topic } }
                if !topics.isEmpty { parent.wrappedValue.spellingTopics = topics }
            }))
        }
    }
}

/// Break reminders and timed bonus points.
struct PlaySettingsRows: View {
    @Environment(AppModel.self) private var model
    let profile: Profile

    var body: some View {
        let parent = parentBinding(profile, model)
        Picker("Suggest a break after", selection: parent.sessionMinutes) {
            Text("Never").tag(0)
            ForEach([10, 15, 20, 30, 45], id: \.self) { Text("\($0) minutes").tag($0) }
        }
        Toggle("Timed bonus points", isOn: parent.timedChallenges)
    }
}

enum SettingsNames {
    static func fraction(_ denominator: Int) -> String {
        ["halves", "thirds", "quarters", "fifths", "sixths", "sevenths", "eighths", "ninths", "tenths"][denominator - 2]
    }
}
