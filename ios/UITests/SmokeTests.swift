import XCTest

/// End-to-end smoke test against the live fakester.app server. CI runs it in the
/// iOS simulator (ios.yml with `fotos: true`): it plays one complete 5-song
/// game as a guest, the way a person would - tapping buttons, picking answers,
/// locking in - and attaches a screenshot at every step.
///
/// Elements are found by their visible English text, except the answer
/// buttons and the lock-in button, which carry accessibility identifiers
/// (`answer-<type>-<index>`, `lock-in`) because their text changes per round.
final class SmokeTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func waitFor(_ element: XCUIElement, _ seconds: TimeInterval, _ what: String) {
        if !element.waitForExistence(timeout: seconds) {
            shot("FAILED - " + what)
            XCTFail("Did not appear within \(Int(seconds)) s: " + what)
        }
    }

    func testFullGameAsGuest() throws {
        // 1. Login: play as a guest
        let createGame = app.buttons["Create Game"]
        let playNow = app.buttons["Play now"]
        if playNow.waitForExistence(timeout: 20) {
            shot("01 login")
            playNow.tap()
            let name = app.textFields.firstMatch
            waitFor(name, 5, "guest name field")
            name.tap()
            name.typeText("Smoke\(Int.random(in: 100...999))\n")
        }

        // 2. Home
        waitFor(createGame, 20, "home screen (Create Game)")
        shot("02 home")

        // 3. Create a private game: 5 songs, 20 s
        createGame.tap()
        let privateButton = app.buttons["Private"]
        waitFor(privateButton, 15, "create game screen")
        let five = app.buttons["5"].firstMatch
        if five.waitForExistence(timeout: 5) { five.tap() }
        let twenty = app.buttons["20s"].firstMatch
        if twenty.exists { twenty.tap() }
        // The first featured playlist is picked automatically once it has loaded.
        let deadline = Date().addingTimeInterval(15)
        while !privateButton.isEnabled && Date() < deadline { usleep(300_000) }
        if !privateButton.isEnabled { element(containing: "Featured").tap() }
        shot("03 create game")
        privateButton.tap()

        // 4. Lobby
        let start = app.buttons["Start Game"]
        waitFor(start, 30, "lobby (Start Game)")
        sleep(1)
        shot("04 lobby")
        start.tap()

        // 5. Five rounds: pick one answer per type, lock in, wait for the reveal
        for round in 1...5 {
            let firstTitle = app.buttons["answer-title-0"]
            waitFor(firstTitle, 90, "round \(round) answers")
            sleep(1)
            shot("05 round \(round)")
            firstTitle.tap()
            let artist = app.buttons["answer-artist-1"]
            if artist.exists { artist.tap() }
            let year = app.buttons["answer-year-2"]
            if year.exists { year.tap() }
            if round == 1 { shot("06 round 1 picked") }
            let lock = app.buttons["lock-in"]
            if lock.waitForExistence(timeout: 3) && lock.isEnabled {
                lock.tap()
                if round == 1 { sleep(1); shot("07 round 1 locked in") }
            }
            let results = element(containing: "Results")
            waitFor(results, 60, "reveal of round \(round)")
            sleep(1)
            shot("08 reveal \(round)")
        }

        // 6. Game over
        let mainMenu = app.buttons["Main menu"]
        waitFor(mainMenu, 60, "game over (Main menu)")
        sleep(2)
        shot("09 game over")
        mainMenu.tap()

        // 7. Leaderboard (public, works for guests)
        waitFor(createGame, 20, "home after the game")
        let board = app.buttons["Board"]
        waitFor(board, 5, "Board button")
        board.tap()
        waitFor(element(containing: "XP"), 20, "leaderboard rows")
        sleep(1)
        shot("10 leaderboard")
    }
}
