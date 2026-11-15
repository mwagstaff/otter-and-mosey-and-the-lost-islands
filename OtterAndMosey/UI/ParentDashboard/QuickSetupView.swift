import LostIslandsCore
import SwiftUI

/// The grown-ups' area cut down to one new player's learning settings, reached from the grown-up
/// check. Behind the same gate as the dashboard, and it hands straight back to the child.
struct QuickSetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.97).ignoresSafeArea()
            if let profile = model.profile {
                if model.parentUnlocked {
                    form(profile)
                } else {
                    ParentGateView(context: "Setting up the game for \(profile.nickname)",
                                   onPass: { model.parentUnlocked = true },
                                   onCancel: { model.leaveQuickSetup(done: false) })
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func form(_ profile: Profile) -> some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Glyph(profile.avatar, size: 26)
                            Text(profile.nickname).fontWeight(.semibold)
                        }
                        .padding(.vertical, 4).padding(.leading, 6).padding(.trailing, 12)
                        .background(Capsule().fill(Color(white: 0.96)))
                        Text("Check these suit \(profile.nickname), then hand the game back. You can change them later in the parent dashboard.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section("Maths") { MathsSettingsRows(profile: profile) }
                Section("Spelling") { SpellingTopicRows(profile: profile) }
                Section {
                    PlaySettingsRows(profile: profile)
                } header: {
                    Text("Play")
                } footer: {
                    Text(learningHelp + " Progress reports, sound and accessibility settings are in the parent dashboard, from the title screen.")
                }
            }
            .navigationTitle("Quick setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Back") { model.leaveQuickSetup(done: false) } }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button { model.leaveQuickSetup(done: true) } label: {
                        Label("Hand back to \(profile.nickname)", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }
}

/// Puts a label's icon after its title, as an arrow on a "go on" button reads.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon
        }
    }
}
