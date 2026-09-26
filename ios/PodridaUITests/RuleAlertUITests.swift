import XCTest

/// Drives the ledger when a turn's calls add up to the turn number: the alert blocks everything until
/// one of the calls is changed.
@MainActor
final class RuleAlertUITests: XCTestCase {
    /// Four players on turn 3, whose calls (1, 0, 2, 0) add up to 3.
    private static let brokenGame = #"""
    {"playerNames":["Marta","Jordi","Laia","Pau"],
     "hands":[[0,1,1,0],[0,1,0,0],[1,0,2,0],[null,null,null,null]],
     "won":[[0,0,0,1],[0,2,0,0],[null,null,null,null],[null,null,null,null]]}
    """#

    /// Turn 1, which deals one hand: both players called 1, and the first one won it.
    private static let oneHandWon = #"""
    {"playerNames":["Ada","Bo"],"hands":[[1,1],[null,null]],"won":[[1,null],[null,null]]}
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

    /// The rule alert, a custom view found by its accessibility identifier rather than a system alert.
    private var overlay: XCUIElement { app.descendants(matching: .any)["blockingAlert"] }

    /// A piece of text inside the alert, found the same way the ledger's own custom cells are.
    private func overlayText(_ label: String) -> XCUIElement { app.descendants(matching: .any)[label] }

    func testTheAlertBlocksTheLedgerUntilACallIsChanged() {
        launch(with: Self.brokenGame)
        XCTAssertTrue(overlayText("Total hands called can’t equal 3").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["New Game"].isEnabled)
        XCTAssertFalse(app.buttons["+ Add turn"].isEnabled)

        // Leaving the calls without fixing them brings the alert straight back.
        app.buttons["Change a Call"].tap()
        let pau = app.textFields["Pau, turn 3, hands called"]
        XCTAssertTrue(pau.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["Pau, turn 3, hands won"].exists)
        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))

        // Changing a call lifts the lock. The alert selects the call, so typing replaces it.
        app.buttons["Change a Call"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("1")
        XCTAssertEqual(pau.value as? String, "1")
        XCTAssertFalse(overlay.waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Pau, turn 3, hands won"].exists)
        app.toolbars.buttons["Done"].tap()
        XCTAssertFalse(overlay.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Game"].isEnabled)
    }

    func testMoreHandsWonThanTheTurnDealsMustBeFixed() {
        launch(with: Self.oneHandWon)
        let boWon = app.textFields["Bo, turn 1, hands won"]
        XCTAssertTrue(boWon.waitForExistence(timeout: 5))
        boWon.tap()
        app.typeText("1")

        // The alert comes up after a pause in typing, while the field it's about is still focused.
        // A system alert would take the keyboard down here; the custom one must not.
        XCTAssertTrue(overlayText("Too many hands won").waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.exists, "keyboard should stay up while the alert is showing")
        XCTAssertFalse(app.buttons["New Game"].isEnabled)
        XCTAssertFalse(app.textFields["Bo, turn 1, hands called"].exists)

        // The alert sends the keyboard back to Bo's result, selected, so typing replaces it.
        app.buttons["Fix Hands Won"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("0")
        XCTAssertEqual(boWon.value as? String, "0")
        XCTAssertFalse(overlay.waitForExistence(timeout: 2))
        app.toolbars.buttons["Done"].tap()
        XCTAssertFalse(overlay.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Game"].isEnabled)
        // Turn 1 is complete, so turn 2 opens.
        XCTAssertTrue(app.textFields["Ada, turn 2, hands called"].exists)
    }

    func testCallingMoreHandsThanTheTurnDealsMustBeFixed() {
        launch(with: #"{"playerNames":["Ada","Bo"],"hands":[[null,null],[null,null]],"won":[[null,null],[null,null]]}"#)
        let adaCall = app.textFields["Ada, turn 1, hands called"]
        XCTAssertTrue(adaCall.waitForExistence(timeout: 5))
        adaCall.tap()
        app.typeText("2")

        // Same pause-triggered case as above: the keyboard must stay up under the alert.
        XCTAssertTrue(overlayText("Can’t call more than 1").waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.exists, "keyboard should stay up while the alert is showing")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Ada’s call")).firstMatch.exists)
        XCTAssertFalse(app.textFields["Ada, turn 1, hands won"].exists)

        app.buttons["Change a Call"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("1")
        XCTAssertEqual(adaCall.value as? String, "1")
        XCTAssertFalse(overlay.waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Ada, turn 1, hands won"].exists)
    }
}
