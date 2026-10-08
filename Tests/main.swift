import Foundation
import CoreGraphics

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    guard condition() else { fputs("FAIL: \(label)\n", stderr); exit(1) }
}
func rejects(_ point: CGPoint, bounds: CGRect) {
    do { _ = try ControlCore.globalPoint(local: point, displayBounds: bounds); check(false, "invalid point accepted") }
    catch { check(true, "point rejected") }
}

let bounds = CGRect(x: -1920, y: -180, width: 1920, height: 1080)
let point = try ControlCore.globalPoint(local: CGPoint(x: 400, y: 100), displayBounds: bounds)
check(point == CGPoint(x: -1520, y: -80), "secondary display origin")
rejects(CGPoint(x: -1, y: 0), bounds: bounds)
rejects(CGPoint(x: 1920, y: 0), bounds: bounds)
rejects(CGPoint(x: 0, y: 1080), bounds: bounds)
rejects(CGPoint(x: CGFloat.nan, y: 0), bounds: bounds)
rejects(CGPoint(x: CGFloat.infinity, y: 0), bounds: bounds)
let rect = ControlCore.imageRect(image: CGSize(width: 2880, height: 1800), container: CGSize(width: 800, height: 600))
check(rect == CGRect(x: 0, y: 50, width: 800, height: 500), "Retina preview letterbox")
check(ControlCore.previewPoint(CGPoint(x: 200, y: 10), rect: rect, displaySize: CGSize(width: 1440, height: 900)) == nil, "padding must not select screen coordinate")
let mapped = ControlCore.previewPoint(CGPoint(x: 400, y: 300), rect: rect, displaySize: CGSize(width: 1440, height: 900))
check(mapped == CGPoint(x: 720, y: 450), "preview maps pixels to logical points")
check(ControlCore.imageRect(image: .zero, container: CGSize(width: 10, height: 10)) == .zero, "empty frame")
let events = try ControlCore.mouseEvents(.doubleClick, at: point)
check(events.map(\.type) == [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp], "double click balanced pairs")
check(events[3].getIntegerValueField(.mouseEventClickState) == 2, "second click state")
check(events.allSatisfy { $0.location == point }, "global mouse coordinates")
let right = try ControlCore.mouseEvents(.rightClick, at: point)
check(right.map(\.type) == [.mouseMoved, .rightMouseDown, .rightMouseUp], "right click")
let copy = try ControlCore.keyEvents(.copy)
check(copy.map(\.type) == [.keyDown, .keyUp], "keyboard balanced pair")
check(copy.allSatisfy { $0.flags.contains(.maskCommand) }, "command modifier")
check(copy[0].getIntegerValueField(.keyboardEventKeycode) == 8, "copy key code")
for character: Character in ["è", "🎵", "👨‍👩‍👧‍👦"] {
    let pair = try ControlCore.textEvents(character)
    for event in pair {
        var actual = 0
        var units = [UniChar](repeating: 0, count: 64)
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &actual, unicodeString: &units)
        check(String(decoding: units.prefix(actual), as: UTF16.self) == String(character), "Unicode round trip \(character)")
    }
}
let newline = try ControlCore.textEvents("\n")
let tab = try ControlCore.textEvents("\t")
check(newline[0].getIntegerValueField(.keyboardEventKeycode) == 36, "newline maps to Return")
check(tab[0].getIntegerValueField(.keyboardEventKeycode) == 48, "tab maps to Tab")
print("PASS: \(checks) checks · coordinates, Retina preview, paired mouse events, shortcuts, Unicode.")
print("These checks construct events; they do not test system delivery or screen capture.")
