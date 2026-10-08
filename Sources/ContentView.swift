import SwiftUI
import AppKit

private let accent = Color(red: 0.35, green: 0.86, blue: 0.73)

struct ContentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 260)
            Divider().overlay(Color.white.opacity(0.08))
            VStack(alignment: .leading, spacing: 20) {
                header
                preview
                HStack {
                    Text("App destinataria").font(.system(size: 11)).foregroundStyle(.secondary)
                    Picker("App destinataria", selection: $model.targetPID) {
                        Text("Scegli app").tag(pid_t(0))
                        ForEach(model.targets) { Text($0.name).tag($0.id) }
                    }.labelsHidden().frame(width: 240).disabled(model.actionBusy)
                    Button { model.refreshTargets() } label: { Image(systemName: "arrow.clockwise") }.help("Aggiorna app aperte")
                    Spacer()
                }
                HStack(alignment: .top, spacing: 16) {
                    mousePanel.frame(maxWidth: .infinity)
                    keyboardPanel.frame(maxWidth: .infinity)
                }
                footer
            }
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.075, green: 0.085, blue: 0.10))
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .frame(minWidth: 1080, minHeight: 790)
        .onChange(of: model.displayID) { _ in
            model.image = nil; model.frameCount = 0
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Image(systemName: "cursorarrow.motionlines").font(.system(size: 27)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("JARVISA").font(.system(size: 20, weight: .bold, design: .rounded)).tracking(2)
                    Text("CONTROL / MAC").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(.secondary)
                }
            }.padding(.bottom, 12)
            Label("Postazione locale", systemImage: "desktopcomputer").foregroundStyle(accent)
            Divider()
            Text("PERMESSI MACOS").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            permissionCard(title: "Registrazione schermo", subtitle: "Anteprima e acquisizione", granted: model.screenPermission, action: model.requestScreenPermission)
            permissionCard(title: "Accessibilità", subtitle: "Mouse e tastiera", granted: model.inputPermission, action: model.requestInputPermission)
            Button("Aggiorna stato") { model.refreshPermissions(); model.refreshDisplays(); model.refreshTargets() }
                .buttonStyle(.borderless).foregroundStyle(accent)
            Divider()
            Toggle("Abilita controllo", isOn: $model.controlEnabled)
                .toggleStyle(.switch).disabled(!model.inputPermission || model.actionBusy)
            Text("I comandi partono dopo 3 secondi. L’app destinataria viene portata in primo piano.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { model.emergencyStop() } label: {
                Label("STOP CONTROLLO", systemImage: "stop.fill")
                    .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
            }.buttonStyle(.bordered).tint(.red)
            Text("Esc per interrompere. Puoi riaprire Jarvisa dalla barra dei menu.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack { Circle().fill(accent).frame(width: 6, height: 6); Text("Solo su questo Mac").font(.system(size: 11)).foregroundStyle(.secondary) }
            Text("PROTOTIPO 0.2 · PLUGIN").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.055, green: 0.065, blue: 0.075))
    }

    private func permissionCard(title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "lock.circle")
                    .foregroundStyle(granted ? accent : Color.orange)
            }
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            if granted { Text("Autorizzato").font(.system(size: 11)).foregroundStyle(accent) }
            else { Button("Autorizza", action: action).buttonStyle(.bordered).controlSize(.small) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Il tuo Mac, sotto controllo.").font(.system(size: 25, weight: .semibold))
                Text("Acquisisci lo schermo. Scegli un punto. Invia un comando.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(model.capturing ? accent : Color.gray).frame(width: 6, height: 6)
                Text(model.capturing ? "LIVE" : "IN ATTESA").font(.system(size: 10, weight: .bold)).tracking(1)
            }.padding(10).background(Color.white.opacity(0.04), in: Capsule())
        }
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $model.displayID) {
                    ForEach(model.displays) { Text($0.name).tag($0.id) }
                }.labelsHidden().frame(width: 240).disabled(model.capturing || model.captureBusy)
                Spacer()
                Button { model.saveSnapshot() } label: { Label("Salva PNG", systemImage: "square.and.arrow.down") }
                    .disabled(model.image == nil)
                Button { model.toggleCapture() } label: {
                    Label(model.capturing ? "Ferma" : "Avvia acquisizione", systemImage: model.capturing ? "stop.fill" : "record.circle")
                }.buttonStyle(.borderedProminent).disabled(model.captureBusy)
            }.padding(12).background(Color.white.opacity(0.04))
            GeometryReader { geometry in
                if let image = model.image {
                    let rect = ControlCore.imageRect(image: CGSize(width: image.width, height: image.height), container: geometry.size)
                    ZStack(alignment: .topLeading) {
                        Image(decorative: image, scale: 1).resizable()
                            .frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                        if let point = model.selectedPoint, point.x >= 0, point.y >= 0, point.x < model.bounds.width, point.y < model.bounds.height {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(accent)
                                .position(x: rect.minX + point.x / model.bounds.width * rect.width,
                                          y: rect.minY + point.y / model.bounds.height * rect.height)
                                .allowsHitTesting(false)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            if let point = ControlCore.previewPoint(value.location, rect: rect, displaySize: model.bounds.size) { model.selectPoint(point) }
                        })
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "display").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(accent.opacity(0.7))
                        Text("Lo schermo apparirà qui").font(.system(size: 15, weight: .medium))
                        Text("Autorizza la registrazione schermo e avvia l’acquisizione.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minHeight: 220, maxHeight: .infinity).background(Color.black.opacity(0.3))
            HStack {
                Text("Clic sull’anteprima = selezione coordinate")
                Spacer()
                Text(model.frameCount == 0 ? "Nessun fotogramma" : "\(model.frameCount) fotogrammi · max 10 fps")
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(10)
        }.clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07)))
    }

    private var canControl: Bool { model.controlEnabled && model.inputPermission && !model.actionBusy && model.targetPID != 0 }

    private var mousePanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Mouse", systemImage: "cursorarrow").font(.system(size: 14, weight: .semibold))
            HStack {
                Text("X").foregroundStyle(.secondary)
                TextField("X", text: $model.x).textFieldStyle(.roundedBorder)
                Text("Y").foregroundStyle(.secondary)
                TextField("Y", text: $model.y).textFieldStyle(.roundedBorder)
            }
            Text("Punti dallo spigolo superiore sinistro dello schermo.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Picker("Azione", selection: $model.mouse) { ForEach(MouseAction.allCases) { Text($0.rawValue).tag($0) } }
                .labelsHidden()
            Button("Esegui tra 3 secondi") { model.runMouse() }.buttonStyle(.bordered).disabled(!canControl)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var keyboardPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Tastiera", systemImage: "keyboard").font(.system(size: 14, weight: .semibold))
            Text("Posiziona prima il cursore nel campo da compilare.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("Testo da scrivere nell’app destinataria", text: $model.text, axis: .vertical)
                .lineLimit(1...3).textFieldStyle(.roundedBorder)
            HStack {
                Button("Scrivi testo") { model.runText() }.disabled(!canControl || model.text.isEmpty)
                Spacer()
                Picker("Tasto", selection: $model.key) { ForEach(KeyAction.allCases) { Text($0.rawValue).tag($0) } }
                    .labelsHidden().frame(width: 84)
                Button("Invia") { model.runKey() }.disabled(!canControl)
            }.buttonStyle(.bordered)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: model.actionBusy ? "timer" : "info.circle").foregroundStyle(accent)
                Text(model.status).font(.system(size: 11)).lineLimit(2)
                Spacer()
            }
            if let previous = model.logs.dropFirst().first {
                Text(previous).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
            }
        }.frame(minHeight: 36)
    }
}
