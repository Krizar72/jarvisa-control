import AppKit
import SwiftUI
import ScreenCaptureKit
import ApplicationServices

struct DisplayOption: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let bounds: CGRect
}

struct TargetOption: Identifiable {
    let id: pid_t
    let name: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var screenPermission = false
    @Published var inputPermission = false
    @Published var displays: [DisplayOption] = []
    @Published var displayID: CGDirectDisplayID = CGMainDisplayID()
    @Published var targets: [TargetOption] = []
    @Published var targetPID: pid_t = 0
    @Published var image: CGImage?
    @Published var capturing = false
    @Published var captureBusy = false
    @Published var actionBusy = false
    @Published var actionOutcome = "idle"
    @Published var controlEnabled = false
    @Published var x = "100"
    @Published var y = "100"
    @Published var text = ""
    @Published var key: KeyAction = .enter
    @Published var mouse: MouseAction = .click
    @Published var status = "Pronta. Abilita i permessi per iniziare."
    @Published var logs: [String] = []
    @Published var frameCount = 0
    private let engine = CaptureEngine()
    private var actionTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var stopped = false
    private var actionGeneration = UUID()
    var bounds: CGRect { displays.first(where: { $0.id == displayID })?.bounds ?? CGDisplayBounds(displayID) }
    var selectedPoint: CGPoint? {
        guard let px = Double(x), let py = Double(y), px.isFinite, py.isFinite else { return nil }
        return CGPoint(x: px, y: py)
    }

    init() {
        refreshPermissions(); refreshDisplays(); refreshTargets()
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() {
            targetPID = front.processIdentifier
        }
        engine.onFrame = { [weak self] image in
            guard let self else { return }
            self.image = image; self.frameCount += 1
            if self.frameCount == 1 { self.record("Acquisizione attiva: primo fotogramma ricevuto.") }
        }
        engine.onError = { [weak self] error in
            self?.capturing = false
            self?.record("Acquisizione interrotta: \(error.localizedDescription)")
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.emergencyStop() } }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.emergencyStop() }
            return event
        }
    }

    func refreshPermissions() {
        screenPermission = CGPreflightScreenCaptureAccess()
        inputPermission = AXIsProcessTrusted() && CGPreflightPostEventAccess()
        if !inputPermission && controlEnabled { emergencyStop() }
    }

    func requestScreenPermission() {
        _ = CGRequestScreenCaptureAccess()
        refreshPermissions()
        if !screenPermission { openSettings("Privacy_ScreenCapture") }
        record("Autorizza Jarvisa Control in Registrazione schermo. Se macOS lo richiede, chiudi e riapri l’app.")
    }

    func requestInputPermission() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openSettings("Privacy_Accessibility")
        refreshPermissions()
        record("Autorizza Jarvisa Control in Accessibilità.")
    }

    func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }

    func refreshDisplays() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &ids, &count) == .success else { return }
        displays = ids.prefix(Int(count)).enumerated().map { index, id in
            let rect = CGDisplayBounds(id)
            return DisplayOption(id: id, name: "Schermo \(index + 1) · \(Int(rect.width)) × \(Int(rect.height))", bounds: rect)
        }
        if !displays.contains(where: { $0.id == displayID }) { displayID = displays.first?.id ?? CGMainDisplayID() }
    }

    func refreshTargets() {
        targets = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != getpid()
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }.map { TargetOption(id: $0.processIdentifier, name: $0.localizedName ?? "App") }.sorted { $0.name < $1.name }
        if !targets.contains(where: { $0.id == targetPID }) { targetPID = targets.first?.id ?? 0 }
    }

    func toggleCapture() {
        guard !captureBusy else { return }
        captureBusy = true
        Task {
            defer { captureBusy = false }
            if capturing {
                do { try await engine.stop(); capturing = false; record("Acquisizione fermata.") }
                catch { capturing = false; record(error.localizedDescription) }
            } else {
                refreshPermissions(); refreshDisplays()
                guard screenPermission else { record("Abilita Registrazione schermo prima di acquisire."); return }
                let selectedID = displayID
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    guard let display = content.displays.first(where: { $0.displayID == selectedID }) else {
                        record("Schermo non disponibile. Aggiorna l’elenco."); return
                    }
                    frameCount = 0; image = nil
                    try await engine.start(display: display, content: content)
                    capturing = true
                    record("Acquisizione avviata.")
                } catch { record("Acquisizione non riuscita: \(error.localizedDescription)") }
            }
        }
    }

    func saveSnapshot() {
        guard let image else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Jarvisa-\(Int(Date().timeIntervalSince1970)).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            guard let data else { record("Impossibile creare il PNG."); return }
            try data.write(to: url, options: .atomic)
            record("PNG salvato: \(url.lastPathComponent)")
        } catch { record(error.localizedDescription) }
    }

    func selectPoint(_ point: CGPoint) { x = String(Int(point.x)); y = String(Int(point.y)) }

    func runMouse() {
        do {
            guard let point = selectedPoint else { throw ControlError.invalidPoint }
            let global = try ControlCore.globalPoint(local: point, displayBounds: bounds)
            let events = try ControlCore.mouseEvents(mouse, at: global)
            schedule(label: "\(mouse.rawValue) a \(x), \(y)") { _ in
                // Down/up pairs are posted together, so cancellation never leaves a button pressed.
                for event in events { event.post(tap: .cghidEventTap) }
            }
        } catch { record(error.localizedDescription) }
    }

    func runKey() {
        do {
            let events = try ControlCore.keyEvents(key)
            schedule(label: "Tasto \(key.rawValue)") { _ in
                for event in events { event.post(tap: .cghidEventTap) }
            }
        } catch { record(error.localizedDescription) }
    }

    func runText() {
        let value = text
        guard !value.isEmpty else { return }
        schedule(label: "Scrittura di \(value.count) caratteri") { pid in
            for character in value {
                try Task.checkCancellation()
                guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { throw ControlError.permissionRequired }
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw ControlError.targetUnavailable }
                for event in try ControlCore.textEvents(character) { event.post(tap: .cghidEventTap) }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }
    }

    private func schedule(label: String, operation: @escaping @MainActor (pid_t) async throws -> Void) {
        refreshPermissions()
        guard controlEnabled, inputPermission, !actionBusy else { record("Abilita il controllo e Accessibilità."); return }
        let pid = targetPID
        guard pid != 0, let target = NSRunningApplication(processIdentifier: pid), !target.isTerminated else {
            record(ControlError.targetUnavailable.localizedDescription); return
        }
        actionBusy = true; stopped = false
        actionOutcome = "pending"
        let generation = UUID(); actionGeneration = generation
        actionTask = Task {
            defer {
                if actionGeneration == generation { actionBusy = false; actionTask = nil }
            }
            do {
                for second in (1...3).reversed() {
                    record("\(label) tra \(second) s · Esc per annullare")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                try Task.checkCancellation()
                guard controlEnabled, AXIsProcessTrusted(), CGPreflightPostEventAccess() else { throw ControlError.permissionRequired }
                guard !target.isTerminated else { throw ControlError.targetUnavailable }
                target.activate(options: [.activateIgnoringOtherApps])
                NSApp.hide(nil)
                try await Task.sleep(nanoseconds: 250_000_000)
                try Task.checkCancellation()
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw ControlError.targetUnavailable }
                try await operation(pid)
                actionOutcome = "sent"
                record("Eventi inviati: \(label).")
            } catch is CancellationError { /* stop already records the outcome */ }
            catch { actionOutcome = "failed"; record(error.localizedDescription) }
        }
    }

    func emergencyStop() {
        if actionBusy { actionOutcome = "cancelled" }
        actionTask?.cancel(); actionTask = nil
        actionGeneration = UUID(); actionBusy = false; controlEnabled = false
        guard !stopped else { return }
        stopped = true
        record("STOP · controllo disattivato.")
    }

    func record(_ message: String) {
        status = message
        logs.insert("\(Date().formatted(date: .omitted, time: .standard))  \(message)", at: 0)
        if logs.count > 60 { logs.removeLast(logs.count - 60) }
    }
}
