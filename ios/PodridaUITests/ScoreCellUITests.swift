import XCTest

/// The ledger's Score cells show each turn's own points, so a column adds up to the Total row.
@MainActor
final class ScoreCellUITests: XCTestCase {
    /// Two turns played, the third about to be called. Ada scores +8 then −8; Bo −8 then +11.
    private static let twoTurnsPlayed = #"""
    {"playerNames":["Ada","Bo"],
     "hands":[[1,1],[1,2],[null,null]],
     "won":[[1,0],[0,2],[null,null]]}
    """#

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(with game: String) {
        app = XCUIApplication()
        // Launch arguments land in UserDefaults' argument domain, which the app reads before its own saves.
        let hex = Data(game.utf8).map { String(format: "%02x", $0) }.joined()
        app.launchArguments = ["-hasSeenOnboarding", "YES", "-game", "<\(hex)>"]
        app.launch()
    }

    private func value(of label: String) -> String? {
        let element = app.descendants(matching: .any)[label]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(label) not found")
        return element.value as? String
    }

    func testScoreCellsShowEachTurnsPointsAndAddUpToTheTotal() {
        launch(with: Self.twoTurnsPlayed)

        XCTAssertEqual(value(of: "Ada, turn 1, score"), "8")
        XCTAssertEqual(value(of: "Ada, turn 2, score"), "-8")
        XCTAssertEqual(value(of: "Bo, turn 1, score"), "-8")
        XCTAssertEqual(value(of: "Bo, turn 2, score"), "11")
        XCTAssertEqual(value(of: "Ada, turn 3, score"), "Not scored yet")

        XCTAssertEqual(value(of: "Ada total"), "0, lowest score")
        XCTAssertEqual(value(of: "Bo total"), "3, high score")
    }
}
