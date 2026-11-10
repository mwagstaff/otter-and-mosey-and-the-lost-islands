import LostIslandsCore
import SwiftUI

/// The grown-ups' area. Kept behind a gate and styled plainly so it reads as separate from play.
struct ParentAreaView: View {
    @Environment(AppModel.self) private var model
    @State private var unlocked = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.97).ignoresSafeArea()
            if unlocked {
                ParentDashboardView()
            } else {
                ParentGateView(onPass: { unlocked = true }, onCancel: { model.route = .title })
            }
        }
    }
}

/// A sum most Year 3 children cannot yet do in their head, typed on a number pad.
struct ParentGateView: View {
    var onPass: () -> Void
    var onCancel: () -> Void
    @State private var a = Int.random(in: 13...19)
    @State private var b = Int.random(in: 6...9)
    @State private var entry = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Grown-ups only").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("To continue, please answer:").font(.system(size: 18, design: .rounded)).foregroundStyle(.secondary)
            Text("\(a) × \(b) = \(entry.isEmpty ? "?" : entry)").font(.system(size: 38, weight: .heavy, design: .rounded)).monospacedDigit()
            if wrong { Text("That is not right. Here is a new one.").font(.system(size: 15, design: .rounded)).foregroundStyle(.red) }
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
    @State private var profileID: UUID?
    @State private var confirmReset = false

    private var profile: Profile? { model.save.profiles.first { $0.id == (profileID ?? model.save.activeProfileID) } }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    List {
                        if model.save.profiles.count > 1 {
                            Picker("Child", selection: Binding(get: { profile.id }, set: { profileID = $0 })) {
                                ForEach(model.save.profiles) { Text("\($0.avatar) \($0.nickname)").tag($0.id) }
                            }
                        }
                        overview(profile)
                        skills(profile)
                        practice(profile)
                        achievements(profile)
                        learning(profile)
                        Section("Sound and accessibility") {
                            SettingsControls(compact: true).listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                        Section {
                            Button("Reset \(profile.nickname)'s progress", role: .destructive) { confirmReset = true }
                        } footer: {
                            Text("Everything is stored on this device only. The game has no accounts, adverts or purchases and collects no personal information.")
                        }
                    }
                } else {
                    ContentUnavailableView("No players yet", systemImage: "person.crop.circle.badge.plus", description: Text("Create a player from the title screen to see their progress here."))
                }
            }
            .navigationTitle("Parent dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { model.route = .title } }
            }
            .confirmationDialog("Reset all progress for this child?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { if let profile { model.resetProgress(profile.id) } }
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "No data yet" }

    private func overview(_ profile: Profile) -> some View {
        Section("Overview") {
            LabeledContent("Total playtime", value: Duration.seconds(profile.playSeconds).formatted(.units(allowed: [.hours, .minutes], width: .wide)))
            LabeledContent("Stars and crystals", value: "\(profile.totalStars) stars, \(profile.crystals.count) of 6 crystals")
            LabeledContent("Spelling accuracy", value: percent(profile.learner.accuracy(for: .spelling)))
            LabeledContent("Maths accuracy", value: percent(profile.learner.accuracy(for: .maths)))
            LabeledContent("Typing accuracy", value: profile.learner.typing.keystrokes == 0 ? "No data yet" : percent(profile.learner.typing.accuracy))
            LabeledContent("Typing speed", value: profile.learner.typing.samples.isEmpty
                ? "Measured with a hardware keyboard"
                : "\(Int(profile.learner.typing.averageWordsPerMinute.rounded())) wpm average, best \(Int(profile.learner.typing.bestWordsPerMinute.rounded()))")
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
        Section("Recent achievements") {
            let recent = profile.achievements.sorted { $0.value > $1.value }.prefix(5)
            if recent.isEmpty { Text("None yet.").foregroundStyle(.secondary) }
            ForEach(Array(recent), id: \.key) { entry in
                if let achievement = Progression.achievements.first(where: { $0.id == entry.key }) {
                    LabeledContent("\(achievement.emoji) \(achievement.title)", value: entry.value.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
    }

    private func learning(_ profile: Profile) -> some View {
        let parent = Binding<ParentSettings>(get: { profile.parent }, set: { value in model.updateProfile(profile.id) { $0.parent = value } })
        return Section {
            Picker("Difficulty", selection: parent.difficulty) {
                ForEach(DifficultyMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            VStack(alignment: .leading) {
                Text("Times tables")
                HStack {
                    ForEach([2, 3, 4, 5, 8, 10], id: \.self) { table in
                        let on = profile.parent.tables.contains(table)
                        Button("\(table)×") {
                            var tables = profile.parent.tables
                            if on { tables.removeAll { $0 == table } } else { tables.append(table) }
                            if !tables.isEmpty { parent.wrappedValue.tables = tables.sorted() }
                        }
                        .buttonStyle(.bordered)
                        .tint(on ? .teal : .gray)
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Spelling topics")
                ForEach(Skill.spellingTopics, id: \.self) { topic in
                    Toggle(topic.title, isOn: Binding(get: { profile.parent.spellingTopics.contains(topic) }, set: { isOn in
                        var topics = profile.parent.spellingTopics
                        if isOn { topics.append(topic) } else { topics.removeAll { $0 == topic } }
                        if !topics.isEmpty { parent.wrappedValue.spellingTopics = topics }
                    }))
                }
            }
            Picker("Suggest a break after", selection: parent.sessionMinutes) {
                Text("Never").tag(0)
                ForEach([10, 15, 20, 30, 45], id: \.self) { Text("\($0) minutes").tag($0) }
            }
            Toggle("Timed bonus points", isOn: parent.timedChallenges)
        } header: {
            Text("Learning settings")
        } footer: {
            Text("Adaptive difficulty raises or lowers each skill separately based on recent answers. Timed bonus points only add extra score for quick answers; nothing ever runs out of time.")
        }
    }
}
