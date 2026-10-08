import AppKit
import Foundation
import CoreFoundation

private struct RPCFailure: Error {
    let code: Int
    let message: String
    var data: [String: Any]? = nil
}

@MainActor
final class MCPServer {
    private let model: AppModel
    private var initialized = false
    private var tasks: [String: Task<Void, Never>] = [:]
    private var mutationID: String?
    private var snapshotID: String?
    private static let versions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

    init(model: AppModel) { self.model = model }

    func start() {
        // The stdio client owns this child process. There is no network listener.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while let line = readLine() {
                DispatchQueue.main.async { [weak self] in self?.receive(line) }
            }
            DispatchQueue.main.async { [weak self] in
                self?.model.emergencyStop()
                self?.tasks.values.forEach { $0.cancel() }
                NSApp.terminate(nil)
            }
        }
    }

    private func receive(_ line: String) {
        guard line.utf8.count <= 1_048_576,
              let data = line.data(using: .utf8),
              let request = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            write(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Invalid JSON request"]])
            return
        }
        guard request["jsonrpc"] as? String == "2.0", let method = request["method"] as? String else {
            write(["jsonrpc": "2.0", "id": request["id"] ?? NSNull(), "error": ["code": -32600, "message": "Invalid request"]])
            return
        }
        let params = request["params"] as? [String: Any] ?? [:]
        if request["id"] == nil {
            if method == "notifications/cancelled", let id = params["requestId"] {
                let key = String(describing: id)
                if mutationID == key { model.emergencyStop() }
                tasks.removeValue(forKey: key)?.cancel()
            }
            return
        }
        let id = request["id"]!
        guard id is String || (id is NSNumber && CFGetTypeID(id as CFTypeRef) != CFBooleanGetTypeID()) else {
            write(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32600, "message": "Invalid request ID"]])
            return
        }
        let key = String(describing: id)
        guard tasks[key] == nil else {
            write(["jsonrpc": "2.0", "id": id, "error": ["code": -32600, "message": "Request ID already active"]])
            return
        }
        tasks[key] = Task { [weak self] in
            guard let self else { return }
            defer { tasks.removeValue(forKey: key) }
            do {
                let result = try await handle(method: method, params: params, requestKey: key)
                if !Task.isCancelled { write(["jsonrpc": "2.0", "id": id, "result": result]) }
            } catch let failure as RPCFailure {
                var error: [String: Any] = ["code": failure.code, "message": failure.message]
                if let data = failure.data { error["data"] = data }
                if !Task.isCancelled { write(["jsonrpc": "2.0", "id": id, "error": error]) }
            } catch {
                if !Task.isCancelled {
                    write(["jsonrpc": "2.0", "id": id, "result": [
                        "isError": true, "content": [["type": "text", "text": error.localizedDescription]]
                    ]])
                }
            }
        }
    }

    private func write(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        FileHandle.standardOutput.write(data + Data([10]))
    }

    private func handle(method: String, params: [String: Any], requestKey: String) async throws -> [String: Any] {
        if method == "initialize" {
            guard let requested = params["protocolVersion"] as? String else {
                throw RPCFailure(code: -32602, message: "Missing protocolVersion")
            }
            initialized = true
            return [
                "protocolVersion": Self.versions.contains(requested) ? requested : Self.versions[0],
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "jarvisa-control", "title": "Jarvisa Control", "version": "0.2.0"],
                "instructions": "Local Mac tools. Query status and running apps first. Input requires explicit enable_control and an exact target_app bundle identifier. Mouse coordinates are logical points on the selected display, not image pixels. Escape or stop_control cancels input. Input tools report event posting; verify effects with a fresh screenshot."
            ]
        }
        // Classic MCP revisions are implemented deliberately. Modern clients probe
        // server/discover, receive method-not-found, and fall back to initialize.
        if method == "server/discover" { throw RPCFailure(code: -32601, message: "Use initialize; supported revisions: 2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05") }
        if method == "ping" { return [:] }
        guard initialized else { throw RPCFailure(code: -32000, message: "Initialize the MCP connection first") }
        if method == "tools/list" { return ["tools": Self.tools] }
        if method == "resources/list" { return ["resources": []] }
        if method == "resources/templates/list" { return ["resourceTemplates": []] }
        if method == "prompts/list" { return ["prompts": []] }
        guard method == "tools/call" else { throw RPCFailure(code: -32601, message: "Method not found") }
        guard let name = params["name"] as? String,
              let definition = Self.tools.first(where: { $0["name"] as? String == name }) else {
            throw RPCFailure(code: -32602, message: "Unknown tool")
        }
        if let arguments = params["arguments"], !(arguments is [String: Any]) {
            throw RPCFailure(code: -32602, message: "arguments must be an object")
        }
        let args = params["arguments"] as? [String: Any] ?? [:]
        try validate(args, definition: definition)
        do { return try await call(name, args: args, requestKey: requestKey) }
        catch let failure as RPCFailure { throw failure }
        catch {
            return ["isError": true, "content": [["type": "text", "text": error.localizedDescription]]]
        }
    }

    private func validate(_ args: [String: Any], definition: [String: Any]) throws {
        let schema = definition["inputSchema"] as! [String: Any]
        let properties = schema["properties"] as! [String: [String: Any]]
        let required = schema["required"] as! [String]
        guard Set(args.keys).isSubset(of: Set(properties.keys)), required.allSatisfy({ args[$0] != nil }) else {
            throw RPCFailure(code: -32602, message: "Missing or unexpected tool arguments")
        }
        for (name, value) in args {
            let rule = properties[name]!
            let type = rule["type"] as! String
            if type == "string" {
                guard let string = value as? String else { throw RPCFailure(code: -32602, message: "\(name) must be a string") }
                if let choices = rule["enum"] as? [String], !choices.contains(string) { throw RPCFailure(code: -32602, message: "Invalid \(name)") }
                if let max = rule["maxLength"] as? Int, string.utf16.count > max { throw RPCFailure(code: -32602, message: "\(name) exceeds \(max) UTF-16 units") }
                if let min = rule["minLength"] as? Int, string.isEmpty && min > 0 { throw RPCFailure(code: -32602, message: "\(name) must not be empty") }
            } else {
                guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else {
                    throw RPCFailure(code: -32602, message: "\(name) must be a finite number")
                }
                if type == "integer", number.doubleValue.rounded() != number.doubleValue { throw RPCFailure(code: -32602, message: "\(name) must be an integer") }
                if let min = rule["minimum"] as? NSNumber, number.doubleValue < min.doubleValue { throw RPCFailure(code: -32602, message: "\(name) is below its minimum") }
                if let max = rule["maximum"] as? NSNumber, number.doubleValue > max.doubleValue { throw RPCFailure(code: -32602, message: "\(name) exceeds its maximum") }
            }
        }
    }

    private func call(_ name: String, args: [String: Any], requestKey: String) async throws -> [String: Any] {
        switch name {
        case "get_status":
            model.refreshPermissions()
            return result(["screenPermission": model.screenPermission, "inputPermission": model.inputPermission,
                           "controlEnabled": model.controlEnabled, "actionBusy": model.actionBusy,
                           "actionOutcome": model.actionOutcome, "status": model.status])
        case "list_displays":
            model.refreshDisplays()
            return result(["displays": model.displays.map { display in
                ["display_id": display.id, "name": display.name,
                 "width_points": display.bounds.width, "height_points": display.bounds.height,
                 "origin_x": display.bounds.minX, "origin_y": display.bounds.minY] as [String: Any]
            }])
        case "list_apps":
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            }.compactMap { app -> [String: Any]? in
                guard let id = app.bundleIdentifier else { return nil }
                return ["name": app.localizedName ?? id, "bundle_id": id, "pid": app.processIdentifier]
            }
            return result(["apps": apps])
        case "enable_control":
            model.refreshPermissions()
            guard model.inputPermission else { throw ControlError.permissionRequired }
            guard mutationID == nil else { throw localError("Un comando è già in esecuzione.") }
            model.controlEnabled = true
            model.record("Controllo abilitato dal plugin. Esc per interrompere.")
            return result(["controlEnabled": true])
        case "stop_control":
            model.emergencyStop()
            return result(["controlEnabled": false, "actionOutcome": model.actionOutcome])
        case "capture_screen":
            return try await capture(args: args, requestKey: requestKey)
        case "mouse", "type_text", "press_key":
            guard mutationID == nil else { throw localError("Un comando è già in esecuzione.") }
            model.refreshPermissions()
            guard model.controlEnabled, model.inputPermission else { throw localError("Prima abilita il controllo con enable_control. Dopo STOP occorre abilitarlo nuovamente.") }
            let target = args["target_app"] as! String
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == target && !$0.isTerminated }),
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { throw ControlError.targetUnavailable }
            model.targetPID = app.processIdentifier
            mutationID = requestKey
            defer { mutationID = nil }
            if name == "mouse" {
                try setDisplay(args)
                model.x = String((args["x"] as! NSNumber).doubleValue)
                model.y = String((args["y"] as! NSNumber).doubleValue)
                guard let point = model.selectedPoint else { throw ControlError.invalidPoint }
                _ = try ControlCore.globalPoint(local: point, displayBounds: model.bounds)
                model.mouse = ["move": .move, "click": .click, "double_click": .doubleClick, "right_click": .rightClick][args["action"] as! String]!
                model.runMouse()
            } else if name == "type_text" {
                model.text = args["text"] as! String
                model.runText()
            } else {
                model.key = Self.keys[args["key"] as! String]!
                model.runKey()
            }
            guard model.actionBusy else { throw localError(model.status) }
            while model.actionBusy {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            guard model.actionOutcome == "sent" else { throw localError(model.status) }
            return result(["eventsPosted": true, "target_app": target, "message": model.status,
                           "deliveryVerified": false])
        default: throw RPCFailure(code: -32602, message: "Unknown tool")
        }
    }

    private func setDisplay(_ args: [String: Any]) throws {
        model.refreshDisplays()
        if let value = args["display_id"] as? NSNumber {
            let id = value.uint32Value
            guard model.displays.contains(where: { $0.id == id }) else { throw localError("Schermo non disponibile.") }
            model.displayID = id
        }
    }

    private func capture(args: [String: Any], requestKey: String) async throws -> [String: Any] {
        guard snapshotID == nil, !model.captureBusy else { throw localError("Un’acquisizione è già in corso.") }
        model.refreshPermissions()
        guard model.screenPermission else { throw localError("Autorizza Registrazione schermo per Jarvisa Control.") }
        if model.capturing, let id = args["display_id"] as? NSNumber, id.uint32Value != model.displayID {
            throw localError("Ferma l’acquisizione attiva prima di cambiare schermo.")
        }
        try setDisplay(args)
        snapshotID = requestKey
        let startedHere = !model.capturing
        defer {
            if startedHere {
                Task { @MainActor [self] in
                    while model.captureBusy { try? await Task.sleep(nanoseconds: 50_000_000) }
                    if model.capturing { model.toggleCapture() }
                    while model.captureBusy { try? await Task.sleep(nanoseconds: 50_000_000) }
                    snapshotID = nil
                }
            } else { snapshotID = nil }
        }
        let initialCount = model.frameCount
        if startedHere { model.toggleCapture() }
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            try Task.checkCancellation()
            if model.captureBusy { try await Task.sleep(nanoseconds: 50_000_000); continue }
            guard model.capturing else { throw localError(model.status) }
            let freshFrame = startedHere ? model.frameCount > 0 : model.frameCount > initialCount
            if freshFrame, let image = model.image {
                guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw localError("Impossibile codificare il fotogramma.") }
                let metadata: [String: Any] = ["display_id": model.displayID,
                    "image_width": image.width, "image_height": image.height,
                    "width_points": model.bounds.width, "height_points": model.bounds.height,
                    "origin_x": model.bounds.minX, "origin_y": model.bounds.minY,
                    "captured_at": ISO8601DateFormatter().string(from: Date()),
                    "coordinates": "Mouse x/y are logical points measured from the selected display's upper-left corner. Scale image coordinates by width_points/image_width and height_points/image_height."]
                return ["content": [
                    ["type": "text", "text": json(metadata)],
                    ["type": "image", "mimeType": "image/png", "data": png.base64EncodedString()]
                ], "structuredContent": metadata, "isError": false]
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw localError("Nessun fotogramma ricevuto entro il tempo previsto.")
    }

    private func localError(_ message: String) -> NSError {
        NSError(domain: "JarvisaControl", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    private func json(_ data: [String: Any]) -> String {
        let encoded = try! JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
        return String(data: encoded, encoding: .utf8)!
    }
    private func result(_ data: [String: Any]) -> [String: Any] {
        ["content": [["type": "text", "text": json(data)]], "structuredContent": data, "isError": false]
    }

    private static let keys: [String: KeyAction] = ["enter": .enter, "tab": .tab, "escape": .escape,
        "backspace": .backspace, "copy": .copy, "paste": .paste, "select_all": .selectAll,
        "left": .left, "right": .right, "up": .up, "down": .down]

    static var tools: [[String: Any]] {
        let display: [String: Any] = ["type": "integer", "minimum": 1, "maximum": 4_294_967_295.0]
        let target: [String: Any] = ["type": "string", "minLength": 1, "maxLength": 256,
            "description": "Exact bundle_id from list_apps; never guess. The app must already be running."]
        func tool(_ name: String, _ title: String, _ description: String, _ properties: [String: [String: Any]] = [:],
                  _ required: [String] = [], readOnly: Bool = true, destructive: Bool = false) -> [String: Any] {
            ["name": name, "title": title, "description": description,
             "inputSchema": ["type": "object", "properties": properties, "required": required, "additionalProperties": false],
             "annotations": ["readOnlyHint": readOnly, "destructiveHint": destructive, "openWorldHint": false]]
        }
        return [
            tool("get_status", "Stato di Jarvisa", "Read the Mac permissions, control state and latest action result. Does not request permissions or send input."),
            tool("list_displays", "Schermi del Mac", "List connected displays, logical dimensions and global origins for accurate coordinates."),
            tool("list_apps", "App aperte", "List running user apps and their exact bundle identifiers for input targeting."),
            tool("capture_screen", "Acquisisci schermo", "Capture a fresh real screenshot from the selected display. Returns a PNG and logical dimensions. Stops the capture after the frame; images are not saved on disk. Use to inspect the screen or verify an action.", ["display_id": display]),
            tool("enable_control", "Abilita controllo", "Enable mouse and keyboard control for this plugin session when the user has requested Mac control. Required before input and again after Escape or STOP. Does not itself post input.", readOnly: false),
            tool("stop_control", "Ferma controllo", "Immediately cancel pending input or typing and disable control. Always available, even while another request is running.", readOnly: false),
            tool("mouse", "Mouse sul Mac", "Move or click the mouse in the exact target app after a cancellable 3-second countdown. Coordinates are logical points relative to the selected display, not image pixels. Requires enable_control. Reports posting, not delivery.",
                 ["target_app": target, "display_id": display, "x": ["type": "number", "minimum": 0], "y": ["type": "number", "minimum": 0],
                  "action": ["type": "string", "enum": ["move", "click", "double_click", "right_click"]]],
                 ["target_app", "x", "y", "action"], readOnly: false, destructive: true),
            tool("type_text", "Scrivi testo", "Type Unicode text into the focused field of the exact target app after a 3-second countdown. Click the intended field first. Stops if focus changes. Maximum 1000 UTF-16 units per call. Requires enable_control.",
                 ["target_app": target, "text": ["type": "string", "minLength": 1, "maxLength": 1000]],
                 ["target_app", "text"], readOnly: false, destructive: true),
            tool("press_key", "Invia tasto", "Send a key or standard Command shortcut to the exact target app after a cancellable 3-second countdown. Requires enable_control. Verify the effect with capture_screen.",
                 ["target_app": target, "key": ["type": "string", "enum": keys.keys.sorted()]],
                 ["target_app", "key"], readOnly: false, destructive: true)
        ]
    }
}
