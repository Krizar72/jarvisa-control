# Jarvisa Control

Native macOS screen capture and mouse/keyboard control, exposed through a local MCP server and connected to ChatGPT using an official private OpenAI tunnel. Created by Krizar together with Codex on an Intel Mac.

This prototype provides an independent execution path when built-in Computer Use/AppShot is unavailable. On the tested Intel Mac, Jarvisa captured the real desktop, clicked native apps and delivered Unicode text from a ChatGPT chat. The existing OpenAI Computer Use issue remains separate and unresolved by these prototype tests.

## Download

[Download the complete 0.2 package](downloads/Jarvisa-Control-0.2-completo-2026-10-08.zip?raw=true): Universal app, Swift sources, local plugin, tests, connection scripts, instructions and verification summary. [ZIP SHA-256](downloads/Jarvisa-Control-0.2-completo-2026-10-08.zip.sha256). The app is ad hoc signed and is not notarized.

## Verified behavior

- Tested on Intel x86_64, macOS 26.7.1, one 1536×960 logical-point display. Captures return 1440×900 PNG images.
- 25 logic checks and 22 tests against the installed native MCP server passed.
- ChatGPT discovered all nine tools through the private tunnel, then clicked and typed into a scratch TextEdit document. A separate document read confirmed the exact text, including accents and emoji. A subsequent tool call confirmed STOP.
- During a Codex voice session, local Jarvisa calls captured the current conversation and DuckDuckGo, clicked the Gmail bookmark, and selected “Dati di analisi Mac” in Console. Console itself was launched using a macOS shell command and its window was visually verified.

See [the process and results](PROCESSO.md), [installation](INSTALLAZIONE.md), [verification details](VERIFICA.md) and [sanitized test summary](RISULTATI.json).

## Tools and operating limits

Tools: get_status, list_displays, list_apps, capture_screen, enable_control, stop_control, mouse, type_text, press_key. The app requires macOS Screen Recording and Accessibility permissions. Control starts disabled; each input has a cancellable three-second countdown and an explicit destination app. The physical pointer and foreground app can change during input. Escape/STOP disarms control. Input reports event posting; the target app must be checked to verify delivery.

The app has no tool for launching closed apps, no background/Locked Use implementation, and no guaranteed control of protected windows or every application. Apple Silicon was compiled, but not tested on a device. Screenshot images were read by ChatGPT during the remote test, but were not rendered as attachments in its reply.

The tunnel must remain running on an awake Mac. This prototype does not configure automatic restart or persist the runtime key. Each user must create their own tunnel and restricted runtime credential in their own OpenAI account/workspace. The vendor tunnel client is downloaded separately from OpenAI’s official distribution. Private credentials, tunnel IDs, account settings, personal screenshots and raw logs are not included.

## Context

Krizar’s existing [AppShot report](https://github.com/openai/codex/issues/41297) documents a failure on an Intel Mac. Other users have also reported [missing Computer Use service on Intel](https://github.com/openai/codex/issues/42514) and [external capture failure during realtime voice](https://github.com/openai/codex/discussions/45700). Those reports describe their own tested builds; Jarvisa’s results apply to the local prototype tested here and do not establish the cause or support status of the official implementation.

## Source and Italian guide

Build with Apple Command Line Tools: `bash ./build.sh universal`. Run logic checks with `bash ./test.sh`. The complete sources and plugin manifests are in this repository. The following Italian guide describes local use and setup.

## Guida del prototipo macOS

App nativa SwiftUI/AppKit per acquisire lo schermo e inviare eventi di mouse e tastiera sul Mac. macOS 13 o successivo. Compilabile per Intel, Apple Silicon e come app universale. La modalità normale lavora localmente. La versione 0.2 espone anche nove strumenti MCP su stdin/stdout, collegabili a un plugin locale o a ChatGPT tramite il tunnel privato ufficiale di OpenAI.

## Aprire l’app

La copia pronta e verificata si trova in `~/Applications/Jarvisa Control.app`. Il bundle compilato è anche in `dist/Jarvisa Control.app`. L’app è firmata localmente ad hoc; non è notarizzata per la distribuzione pubblica.

La copia in `~/Applications` evita i metadati aggiunti dal file provider alla cartella di lavoro sincronizzata, che nella verifica locale interferivano con la firma del bundle dentro `dist`.

1. Premi **Autorizza** per Registrazione schermo e Accessibilità. Abilita **Jarvisa Control** nelle impostazioni di macOS. Se il sistema chiede di riaprire l’app, fallo.
2. Seleziona lo schermo e premi **Avvia acquisizione**. L’anteprima riceve fino a 10 fotogrammi al secondo, con larghezza massima di 1440 pixel. La finestra di Jarvisa è esclusa dall’acquisizione per evitare l’effetto specchio.
3. **Salva PNG** salva il fotogramma corrente alla risoluzione dell’anteprima. Non viene registrato un video.
4. Seleziona l’**app destinataria** e abilita il controllo. La scelta vale sia per il mouse sia per la tastiera.
5. Clicca nell’anteprima per scegliere un punto, oppure inserisci X e Y in punti dello schermo selezionato, a partire dall’angolo superiore sinistro. Scegli Sposta, Clic, Doppio clic o Clic destro e premi **Esegui tra 3 secondi**.
6. Per la tastiera, posiziona il cursore in un campo nell’app destinataria; poi inserisci il testo in Jarvisa e premi **Scrivi testo**, oppure scegli un tasto e premi **Invia**. I comandi attendono 3 secondi, attivano l’app destinataria e nascondono Jarvisa. La scrittura si interrompe se cambia l’app in primo piano.
7. **Esc** annulla il comando in attesa o la scrittura e disabilita il controllo. Anche il menu di Jarvisa nella barra dei menu permette di fermare il controllo e riaprire la finestra. STOP agisce sul controllo; per fermare l’acquisizione usa **Ferma**.

Il controllo parte disabilitato ad ogni avvio. I comandi possono essere scelti nell’interfaccia o ricevuti dal client MCP. Lo stato “Eventi inviati” indica che gli eventi sono stati pubblicati nel sistema; la ricezione effettiva dipende dall’app destinataria. Campi protetti e app che reinterpretano gli eventi Unicode possono rifiutare il testo.

## Plugin e collegamento a ChatGPT

Il pacchetto in `plugin-marketplace/plugins/jarvisa-control` è installabile tramite il marketplace locale `jarvisa-local`. È stato installato e risulta abilitato nel registro Codex. Nell’account ChatGPT è stato inoltre creato e collegato **Jarvisa Control** attraverso il tunnel privato: la scoperta dei nove strumenti e la lettura dello stato dalla chat sono state verificate sul collegamento reale. I risultati e i limiti delle prove sono in `VERIFICA.md`.

```sh
codex plugin marketplace add ./plugin-marketplace --json
codex plugin add jarvisa-control@jarvisa-local --json
```

Una nuova chat Codex deve caricare il plugin installato. Il server viene avviato dalla copia in `~/Applications/Jarvisa Control.app`; `JARVISA_APP_PATH` permette di usare un’altra copia. In modalità `--mcp` la finestra rimane chiusa; l’icona nella barra dei menu permette di mostrarla o fermare il controllo. EOF sul canale del client chiude il processo e disabilita il controllo.

Per ChatGPT, crea un tunnel in [OpenAI Platform](https://platform.openai.com/settings/organization/tunnels) e usa una chiave runtime con permessi Tunnels Read + Use, associata all’account/workspace corretto. La chiave va inserita localmente, mai in una chat. Il client ufficiale è installato in `~/Library/Application Support/JarvisaControl/tunnel-client/` e il suo archivio è stato verificato con il checksum della release ufficiale.

```sh
bash ./scripts/connect-chatgpt.sh
```

Lo script chiede l’ID del tunnel e la chiave senza mostrarla, avvia il runtime supervisionato e ne legge lo stato. Non salva la chiave in un file. In ChatGPT: Plugin → Aggiungi → Crea un server MCP personalizzato; nome **Jarvisa Control**, Connessione **Tunnel**, ID del tunnel creato. Per questo server stdio non serve un ulteriore OAuth del server: il tunnel applica l’accesso OpenAI. Seleziona Nessuna autenticazione per il server e rivedi i permessi prima di creare il plugin. Prova prima get_status e list_apps in una nuova chat, poi screenshot e input in un documento di prova.

Quando il tunnel è collegato, screenshot e risultati richiesti da ChatGPT transitano verso OpenAI. Il server locale non apre una porta di rete e non salva screenshot. Le immagini prodotte dal test sono salvate dal client di verifica, non dal server.

Strumenti: `get_status`, `list_displays`, `list_apps`, `capture_screen`, `enable_control`, `stop_control`, `mouse`, `type_text`, `press_key`. Prima dell’input occorre `enable_control`; dopo Esc/STOP occorre abilitarlo di nuovo. La destinazione usa l’identificatore esatto restituito da list_apps. Le coordinate del mouse sono punti logici dello schermo selezionato: il risultato dello screenshot riporta dimensioni e conversione dai pixel. Un solo comando di input può essere attivo. Il server distingue invio degli eventi ed effetto nell’app; per verificare l’effetto richiedi un nuovo screenshot.

Protocollo implementato: MCP stdio con handshake initialize, revisioni 2025-11-25, 2025-06-18, 2025-03-26 e 2024-11-05. La scoperta moderna server/discover restituisce method-not-found per permettere il fallback dei client che lo supportano. Non è implementato il protocollo moderno 2026-07-28. Il collegamento reale con ChatGPT ha negoziato la revisione 2025-11-25 e riconosciuto tutti i nove strumenti.

Il prototipo mantiene la chiave runtime nella memoria dei processi e non configura un avvio automatico dopo il riavvio del Mac. La chiave di prova corrente ha scadenza a 30 giorni; la durata è una scelta della configurazione di prova. Per riavviare il collegamento occorre fornire una chiave valida al launcher locale.

Riferimenti: [creare un plugin](https://developers.openai.com/plugins/build/plugins), [collegarlo a ChatGPT](https://developers.openai.com/plugins/deploy/connect-chatgpt), [tunnel MCP privati](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels).

## Compilare e verificare

Sono sufficienti i Command Line Tools di Apple con un SDK macOS recente:

```sh
bash ./build.sh universal  # bundle Intel + Apple Silicon
bash ./test.sh            # test senza acquisizione o input reale
open "dist/Jarvisa Control.app"
```

Per la sola architettura corrente: `bash ./build.sh`.

Il rendering dell’interfaccia e lo stato dei permessi si possono verificare senza richiedere autorizzazioni:

```sh
open -W "dist/Jarvisa Control.app" --args --smoke-test "$PWD/verification"
```

Il comando apre l’app, rende la sua vista in `verification/interface.png`, scrive `verification/smoke-test.json` e chiude l’app. Questo rendering riguarda la vista dell’app, non uno screenshot del desktop. I test di logica verificano coordinate di monitor secondari, bordi e valori non validi, conversione dell’anteprima Retina, sequenze mouse/tastiera bilanciate e Unicode, senza pubblicare input sul sistema.

Per la prova completa, dopo aver autorizzato l’app: apri TextEdit con un documento vuoto, verifica l’anteprima e salva un PNG; seleziona TextEdit, usa un clic sul documento e scrivi `Ciao Krizar, è una prova 🎵`. Verifica nel documento il testo ricevuto. Prova STOP durante il conto alla rovescia per verificare che il comando venga annullato.

## Implementazione

- `Sources/CaptureEngine.swift`: ScreenCaptureKit, filtro schermo con esclusione dell’app, conversione Core Image e aggiornamenti dell’anteprima.
- `Sources/ControlCore.swift`: conversione coordinate e costruzione degli eventi Core Graphics.
- `Sources/AppModel.swift`: permessi, conto alla rovescia cancellabile, attivazione dell’app, blocco su cambio destinazione e salvataggio PNG.
- `Sources/ContentView.swift`: interfaccia SwiftUI in italiano.
- `Sources/main.swift`: ciclo di vita AppKit, finestra, menu e rendering di verifica.
- `Sources/MCPServer.swift`: protocollo stdio, strumenti, validazione, cancellazione e risposte PNG.
- `Tests/mcp_smoke.py`: test sul server installato, screenshot reale e input opzionale in un nuovo documento TextEdit.

Riferimenti Apple: [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit), [coordinate degli schermi](https://developer.apple.com/documentation/coregraphics/cgdisplaybounds(_:)), [permesso Accessibilità](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions), [eventi Unicode](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:)).
