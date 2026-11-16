import XCTest
import LostIslandsCore

nonisolated final class PlaythroughTests: XCTestCase {
    @MainActor func testSixModesThroughControls() throws {
        try play(["woods-1", "bay-1", "woods-2", "dragon-1", "woods-3", "woods-5"])
    }
    @MainActor func testAllLevelsThroughControls() throws {
        try play(Catalog.shared.allLevels.map(\.id))
    }
    @MainActor private func play(_ levels: [String]) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        for level in levels {
            let app = XCUIApplication()
            app.launchArguments = ["-debugLevel", level, "-debugShort", "-debugAutomation"]
            app.launch()
            defer { app.terminate() }
            let state = app.otherElements["playtest-state"]
            XCTAssertTrue(state.waitForExistence(timeout: 20))
            let deadline = Date().addingTimeInterval(120)
            var typed = -1
            var finished = false
            while Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                let skip = app.buttons["Skip"]
                if skip.exists && skip.isHittable { skip.tap(); continue }
                guard let raw = state.value as? String, let data = raw.data(using: .utf8),
                      let s = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if s["finished"] as? Bool == true { XCTAssertEqual(s["stars"] as? Int, 3, level); finished = true; break }
                func tap(_ p: [String: Double]) {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: p["x"] ?? 0, dy: p["y"] ?? 0)).tap()
                }
                if let p = s["powerButton"] as? [String: Double] { tap(p) }
                else if let p = s["crystal"] as? [String: Double] { tap(p) }
                else if s["ready"] as? Bool == true {
                    let choices = s["choices"] as? [String] ?? []
                    if !choices.isEmpty, let answer = s["choice"] as? String, let index = choices.firstIndex(of: answer),
                       let targets = s["targets"] as? [[String: Double]], targets.indices.contains(index) { tap(targets[index]) }
                    else if let target = s["typed"] as? String, !target.isEmpty, let count = s["completed"] as? Int, typed != count {
                        for letter in target {
                            let label = letter == " " ? "Space" : String(letter)
                            let key = app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
                            XCTAssertTrue(key.exists || key.waitForExistence(timeout: 5), "Missing key \(label) in \(level)")
                            key.tap()
                        }
                        typed = count
                    }
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = level; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(finished, "Level did not reach results: \(level)")
        }
    }
}
