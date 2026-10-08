import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var model: AppModel!
    var statusItem: NSStatusItem!
    var mcpServer: MCPServer?
    let isMCP = CommandLine.arguments.contains("--mcp")

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 830),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Jarvisa Control"
        window.minSize = NSSize(width: 1080, height: 790)
        if !isMCP { window.contentView = NSHostingView(rootView: ContentView(model: model)) }
        window.center()
        window.isReleasedWhenClosed = false
        if !isMCP {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Mostra Jarvisa Control", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(withTitle: "STOP controllo", action: #selector(stopControl), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Jarvisa Control")
        statusItem.menu = menu

        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Mostra Jarvisa", action: #selector(showWindow), keyEquivalent: "1").target = self
        appMenu.addItem(withTitle: "STOP controllo", action: #selector(stopControl), keyEquivalent: ".").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Esci da Jarvisa Control", action: #selector(quit), keyEquivalent: "q").target = self
        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Modifica"); editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Taglia", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu

        if isMCP {
            mcpServer = MCPServer(model: model)
            mcpServer?.start()
        }

        if let index = CommandLine.arguments.firstIndex(of: "--smoke-test"), CommandLine.arguments.count > index + 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let view = window.contentView!
                    view.layoutSubtreeIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        throw NSError(domain: "Jarvisa", code: 1, userInfo: [NSLocalizedDescriptionKey: "UI render unavailable"])
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else {
                        throw NSError(domain: "Jarvisa", code: 2)
                    }
                    try png.write(to: directory.appendingPathComponent("interface.png"))
                    let report: [String: Any] = [
                        "app": "Jarvisa Control", "version": "0.2", "uiRendered": true,
                        "screenPermission": model.screenPermission, "inputPermission": model.inputPermission,
                        "displays": model.displays.count, "controlEnabled": model.controlEnabled,
                        "captureTested": false, "inputDeliveryTested": false,
                        "architecture": ProcessInfo.processInfo.machineArchitecture,
                        "windowWidth": view.bounds.width, "windowHeight": view.bounds.height
                    ]
                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                        .write(to: directory.appendingPathComponent("smoke-test.json"))
                    NSApp.terminate(nil)
                } catch {
                    try? error.localizedDescription.write(to: directory.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
                    NSApp.terminate(nil)
                }
            }
        }
    }

    @objc func showWindow() {
        if window.contentView == nil { window.contentView = NSHostingView(rootView: ContentView(model: model)) }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func stopControl() { model.emergencyStop(); showWindow() }
    @objc func quit() { model.emergencyStop(); NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !isMCP }
}

extension ProcessInfo {
    var machineArchitecture: String {
        #if arch(x86_64)
        return "x86_64"
        #elseif arch(arm64)
        return "arm64"
        #else
        return "unknown"
        #endif
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(delegate.isMCP ? .accessory : .regular)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
