import XCTest

// Drives the installed Ottsel app with real touches on its UIKit controls.
final class OttselTouchTests: XCTestCase {
  let app = XCUIApplication(bundleIdentifier: "com.ottsel.shell")
  let out = "/tmp/ottsel-uitest"
  // The app's runtime log, passed in by the runner (the test process can read the Simulator's files).
  let log = ProcessInfo.processInfo.environment["OTTSEL_LOG"] ?? ""

  func shot(_ name: String) {
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(out)-\(name).png"))
  }

  func logText() -> String { (try? String(contentsOfFile: log, encoding: .utf8)) ?? "" }

  // Press a control until the game logs the marker (the Simulator runs the game at a few fps).
  func press(_ label: String, until marker: String, timeout: Double = 60) -> Bool {
    let button = app.buttons[label]
    XCTAssertTrue(button.waitForExistence(timeout: 20), "no control labelled \(label)")
    let before = logText().components(separatedBy: marker).count
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      button.press(forDuration: 0.5)
      for _ in 0..<10 {
        if logText().components(separatedBy: marker).count > before { return true }
        Thread.sleep(forTimeInterval: 0.5)
      }
    }
    XCTFail("\(label): no '\(marker)' in the game log")
    return false
  }

  func waitLog(_ marker: String, timeout: Double) -> Bool {
    let before = logText().components(separatedBy: marker).count
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if logText().components(separatedBy: marker).count > before { return true }
      Thread.sleep(forTimeInterval: 1)
    }
    return false
  }

  func testTouchControls() {
    continueAfterFailure = false
    XCTAssertFalse(log.isEmpty, "OTTSEL_LOG not set")
    app.activate()
    shot("0-title")
    _ = press("START", until: "OTTSEL TITLE: start edge")
    shot("1-main-menu")
    _ = press("D-pad down", until: "edge screen=27 index=0 transition=#f")
    _ = press("Cross", until: "accept screen=27 index=1")
    shot("2-load-screen")
    // The save list reads the memory card first; give it time, then pick slot 1.
    Thread.sleep(forTimeInterval: 20)
    app.buttons["D-pad down"].press(forDuration: 0.6)
    Thread.sleep(forTimeInterval: 8)
    shot("2b-slot")
    _ = press("Cross", until: "GAMEPLAY: enter training", timeout: 300)
    Thread.sleep(forTimeInterval: 20)
    shot("3-loaded")
    let stick = app.otherElements["Move stick"]
    XCTAssertTrue(stick.waitForExistence(timeout: 10))
    let center = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let up = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.2))
    center.press(forDuration: 0.1, thenDragTo: up, withVelocity: .slow, thenHoldForDuration: 25)
    shot("4-after-walk")
    app.buttons["Cross"].press(forDuration: 0.6)
    Thread.sleep(forTimeInterval: 3)
    shot("5-jump")
    app.buttons["Menu"].tap()
    Thread.sleep(forTimeInterval: 2)
    app.buttons["Controls"].tap()
    Thread.sleep(forTimeInterval: 2)
    shot("6-menu-controls")
  }
}
