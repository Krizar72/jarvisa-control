import Foundation
import CoreGraphics

enum ControlError: LocalizedError {
    case invalidPoint, eventUnavailable, permissionRequired, targetUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidPoint: return "Le coordinate devono essere dentro lo schermo selezionato."
        case .eventUnavailable: return "macOS non ha creato l’evento di input."
        case .permissionRequired: return "Abilita Accessibilità per Jarvisa Control."
        case .targetUnavailable: return "L’app destinataria non è più disponibile o non è in primo piano."
        }
    }
}

enum MouseAction: String, CaseIterable, Identifiable {
    case move = "Sposta", click = "Clic", doubleClick = "Doppio clic", rightClick = "Clic destro"
    var id: String { rawValue }
}

enum KeyAction: String, CaseIterable, Identifiable {
    case enter = "Invio", tab = "Tab", escape = "Esc", backspace = "Backspace"
    case copy = "⌘ C", paste = "⌘ V", selectAll = "⌘ A"
    case left = "←", right = "→", up = "↑", down = "↓"
    var id: String { rawValue }
    var code: CGKeyCode {
        switch self {
        case .enter: return 36; case .tab: return 48; case .escape: return 53
        case .backspace: return 51; case .copy: return 8; case .paste: return 9
        case .selectAll: return 0; case .left: return 123; case .right: return 124
        case .up: return 126; case .down: return 125
        }
    }
    var flags: CGEventFlags {
        [.copy, .paste, .selectAll].contains(self) ? .maskCommand : []
    }
}

enum ControlCore {
    // ScreenCaptureKit pixels map to Quartz points; origins may be negative on other monitors.
    static func globalPoint(local: CGPoint, displayBounds: CGRect) throws -> CGPoint {
        guard local.x.isFinite, local.y.isFinite,
              local.x >= 0, local.y >= 0,
              local.x < displayBounds.width, local.y < displayBounds.height else {
            throw ControlError.invalidPoint
        }
        return CGPoint(x: displayBounds.minX + local.x, y: displayBounds.minY + local.y)
    }

    static func imageRect(image: CGSize, container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }

    static func previewPoint(_ point: CGPoint, rect: CGRect, displaySize: CGSize) -> CGPoint? {
        guard rect.width > 0, rect.height > 0, rect.contains(point) else { return nil }
        return CGPoint(x: (point.x - rect.minX) / rect.width * displaySize.width,
                       y: (point.y - rect.minY) / rect.height * displaySize.height)
    }

    static func mouseEvents(_ action: MouseAction, at point: CGPoint) throws -> [CGEvent] {
        let source = CGEventSource(stateID: .privateState)
        let right = action == .rightClick
        let button: CGMouseButton = right ? .right : .left
        guard let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                 mouseCursorPosition: point, mouseButton: button) else { throw ControlError.eventUnavailable }
        if action == .move { return [move] }
        var events = [move]
        for click in 1...(action == .doubleClick ? 2 : 1) {
            guard let down = CGEvent(mouseEventSource: source, mouseType: right ? .rightMouseDown : .leftMouseDown,
                                     mouseCursorPosition: point, mouseButton: button),
                  let up = CGEvent(mouseEventSource: source, mouseType: right ? .rightMouseUp : .leftMouseUp,
                                   mouseCursorPosition: point, mouseButton: button) else { throw ControlError.eventUnavailable }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            events += [down, up]
        }
        return events
    }

    static func keyEvents(_ key: KeyAction) throws -> [CGEvent] {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key.code, keyDown: false) else { throw ControlError.eventUnavailable }
        down.flags = key.flags; up.flags = key.flags
        return [down, up]
    }

    static func textEvents(_ character: Character) throws -> [CGEvent] {
        if character == "\n" || character == "\r\n" || character == "\r" { return try keyEvents(.enter) }
        if character == "\t" { return try keyEvents(.tab) }
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { throw ControlError.eventUnavailable }
        let units = Array(String(character).utf16)
        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        return [down, up]
    }
}
