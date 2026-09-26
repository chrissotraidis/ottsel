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
    // The move stick floats: press anywhere in the left thumb's area and drag. The drag goes well past
    // the stick's rim, so the stick's centre has to follow the thumb.
    let zone = app.otherElements["Move area"]
    XCTAssertTrue(zone.waitForExistence(timeout: 10))
    let start = zone.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
    let up = zone.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.25))
    start.press(forDuration: 0.1, thenDragTo: up, withVelocity: .slow, thenHoldForDuration: 25)
    shot("4-after-walk")
    // Slide one thumb from Cross to Square without lifting (jump, then attack in the air).
    let cross = app.buttons["Cross"]
    let square = app.buttons["Square"]
    cross.press(forDuration: 0.3, thenDragTo: square, withVelocity: .fast, thenHoldForDuration: 0.6)
    Thread.sleep(forTimeInterval: 3)
    shot("5-jump-attack")
    app.buttons["Menu"].tap()
    Thread.sleep(forTimeInterval: 2)
    shot("6-menu")
    app.buttons["Controls"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Touch Control Settings…"].tap()
    Thread.sleep(forTimeInterval: 2)
    // Start the layout checks from the defaults, whatever an earlier run or a person left saved.
    app.buttons["Reset This Device Layout"].tap()
    app.alerts.buttons["Reset"].tap()
    Thread.sleep(forTimeInterval: 1)
    shot("7-settings-panel")
    app.buttons["Close touch control settings"].tap()
    app.buttons["Menu"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Controls"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Move Touch Controls"].tap()
    Thread.sleep(forTimeInterval: 2)
    let camera = app.otherElements["Camera stick"]
    let cameraHome = camera.frame
    camera.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(forDuration: 0.2,
             thenDragTo: camera.coordinate(withNormalizedOffset: CGVector(dx: -0.8, dy: -0.4)),
             withVelocity: .slow, thenHoldForDuration: 0.1)
    Thread.sleep(forTimeInterval: 1)
    shot("8-editing")
    app.buttons["Finish moving touch controls"].tap()
    Thread.sleep(forTimeInterval: 1)
    shot("9-after-edit")
    // Put the layout back, so a test run never leaves the controls moved for the next launch.
    app.buttons["Menu"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Controls"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Touch Control Settings…"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Reset This Device Layout"].tap()
    app.alerts.buttons["Reset"].tap()
    Thread.sleep(forTimeInterval: 1)
    app.buttons["Close touch control settings"].tap()
    Thread.sleep(forTimeInterval: 1)
    XCTAssertEqual(camera.frame, cameraHome, "Reset puts the camera stick back where it started")
  }
}
