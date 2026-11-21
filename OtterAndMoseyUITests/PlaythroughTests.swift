import XCTest
import LostIslandsCore

nonisolated final class PlaythroughTests: XCTestCase {
    @MainActor func testGrownUpKeypadAcceptsTapsAcrossEachKey() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let grownUps = app.buttons["Grown-ups"]
        app.buttons["Tap to continue"].tap()
        XCTAssertTrue(grownUps.waitForExistence(timeout: 15))
        grownUps.tap()

        func showsAnswer(_ answer: String) -> Bool {
            app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " = " + answer))
                .firstMatch.waitForExistence(timeout: 3)
        }

        let edge = CGVector(dx: 0.12, dy: 0.15)
        app.buttons["1"].coordinate(withNormalizedOffset: edge).tap()
        XCTAssertTrue(showsAnswer("1"))
        app.buttons["0"].press(forDuration: 1)
        XCTAssertTrue(showsAnswer("10"))
        app.buttons["Delete"].coordinate(withNormalizedOffset: edge).tap()
        XCTAssertTrue(showsAnswer("1"))
    }

    @MainActor func testRainbowIslandRemembersCabinetAndPetPlacement() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-debugRoute", "home", "-debugUnlock"]
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let cabinet = app.buttons["Trophy cabinet"]
        XCTAssertTrue(cabinet.waitForExistence(timeout: 10))
        let start = cabinet.frame.midX
        let targetX: CGFloat = start > app.frame.midX ? 0.25 : 0.75
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: targetX, dy: 0.4))
        cabinet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.15, thenDragTo: target)
        XCTAssertEqual(cabinet.frame.midX, app.frame.width * targetX, accuracy: 10)

        let name = "Flicker the firefly"
        let pet = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertFalse(pet.exists)
        app.buttons["Add " + name].tap()
        XCTAssertTrue(pet.waitForExistence(timeout: 5))
        let petTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.34))
        pet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.15, thenDragTo: petTarget)
        app.terminate()
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(cabinet.waitForExistence(timeout: 10))
        XCTAssertEqual(cabinet.frame.midX, app.frame.width * targetX, accuracy: 10)
        XCTAssertEqual(pet.frame.midX, app.frame.width * 0.52, accuracy: 10)
        XCTAssertEqual(pet.frame.midY, app.frame.height * 0.34, accuracy: 10)
        pet.doubleTap()
        XCTAssertFalse(pet.exists)
        cabinet.tap()
        XCTAssertFalse(app.staticTexts["Rainbow Island"].exists)
    }

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
