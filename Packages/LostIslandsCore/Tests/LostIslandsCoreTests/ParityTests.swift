import Foundation
import Testing
@testable import LostIslandsCore

@Test func exportPlaytestContract() throws {
    guard let directory = ProcessInfo.processInfo.environment["PLAYTEST_OUTPUT"] else { return }
    let levels = Catalog.shared.allLevels.map { ["id": $0.id, "mode": $0.mode.rawValue, "count": String($0.count)] }
    let accuracies = [0.0, 0.5499, 0.55, 0.8499, 0.85, 1.0]
    let stars = accuracies.map { Progression.stars(forAccuracy: $0) }
    #expect(stars == [1, 1, 2, 2, 3, 3])
    var profile = Profile(nickname: "Parity", avatar: "🦦")
    var campaign: [[String: Any]] = []
    let now = Date(timeIntervalSince1970: 1794787200)
    for level in Catalog.shared.allLevels {
        #expect(Progression.isUnlocked(levelID: level.id, in: profile))
        let result = LevelResult(stars: 3, accuracy: 1, score: 900, bestCombo: level.count, correctFirstTry: level.count, total: level.count)
        let summary = Progression.apply(result, levelID: level.id, learner: profile.learner, to: &profile, now: now)
        campaign.append(["id": level.id, "next": Progression.nextLevel(for: profile)?.id ?? "", "rewards": profile.rewards.sorted(), "crystals": profile.crystals.sorted(), "trophies": summary.trophies.map(\.id), "waiting": profile.pendingTrophies, "complete": summary.gameComplete])
    }
    #expect(profile.crystals.count == 6)
    let trophies = Trophies.all().map { ["id": $0.id, "title": $0.title, "detail": $0.detail, "art": $0.art] }
    let data = try JSONSerialization.data(withJSONObject: ["levels": levels, "stars": stars, "campaign": campaign, "trophies": trophies], options: [.sortedKeys])
    try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("swift-contract.json"))
}
