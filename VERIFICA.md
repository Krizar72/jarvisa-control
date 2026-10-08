# Verifica del prototipo

Verifica locale eseguita sul Mac Intel (x86_64), macOS 26.7.1, Swift 6.1.2.

- Compilazione completata per x86_64 e arm64, bundle universale generato.
- Firma ad hoc verificata con `codesign --verify --deep --strict`.
- Copia pronta aperta da `~/Applications/Jarvisa Control.app`; firma verificata anche dopo l’avvio. La copia in `dist` è soggetta all’aggiunta automatica di metadati del file provider della cartella sincronizzata.
- 25 controlli passati: coordinate con origini negative, bordi e valori non finiti, mappatura dell’anteprima Retina, esclusione delle bande vuote, eventi mouse bilanciati e doppio clic, combinazioni di tasti, Unicode con accenti ed emoji, Tab e Invio.
- App avviata e interfaccia renderizzata a 1180 × 830 punti; immagine ispezionata senza tagli o sovrapposizioni.
- Un monitor rilevato dall’app. Il controllo è disabilitato all’avvio.
- Nella prima verifica i permessi non erano concessi. Dopo l’autorizzazione dell’utente, la nuova verifica dell’app ha confermato **Registrazione schermo e Accessibilità concessi**.

## Prove reali dopo l’autorizzazione

- ScreenCaptureKit ha ricevuto fotogrammi del desktop; l’interfaccia ha riportato 2724 fotogrammi prima dello stop. L’anteprima reale è stata osservata in una cattura del desktop.
- **Salva PNG** dell’app ha prodotto `verification-live/screen-from-app.png`, 1440 × 900 pixel; il contenuto è stato ispezionato.
- Jarvisa ha inviato un clic a 600, 400. Una lettura Core Graphics della posizione del mouse dopo il comando ha restituito esattamente `600,400`.
- Jarvisa ha scritto nel documento di prova di TextEdit `Ciao Krizar, è una prova 🎵 `, con uno spazio finale. Il testo è stato letto dall’app destinataria, salvato e confrontato esattamente con il valore atteso.
- Durante un secondo comando di scrittura, Esc è stato inviato nel conto alla rovescia. Il documento è rimasto invariato e il controllo è risultato disabilitato (valore del checkbox: 0).

Queste prove riguardano questo Mac Intel, un monitor e TextEdit. La versione arm64 è stata compilata, non eseguita su Apple Silicon.

Il rendering `verification/interface.png` mostra la vista di Jarvisa: non è un’acquisizione del desktop. `verification/smoke-test.json` contiene lo stato rilevato dall’app.

`verification-permissions/smoke-test.json` contiene i permessi confermati dopo l’autorizzazione; `verification-live/live-test.json` riepiloga le prove reali. I file di prova e le immagini sono esclusi da Git.

## Versione 0.2: MCP e plugin

- Bundle universale ricompilato e installato; versione 0.1 conservata in una copia di backup locale.
- Permessi rilevati dal processo MCP installato: Registrazione schermo e Accessibilità entrambi concessi.
- 25 controlli sulla costruzione degli eventi ancora superati.
- 22 verifiche sul vero server stdio: inizializzazione, fallback esplicito, nove strumenti, controllo inizialmente disabilitato, rifiuto dei parametri non validi, valori booleani e numeri fuori intervallo, testo vuoto o eccessivo, screenshot e input reali.
- capture_screen ha restituito un PNG del desktop di 1440 × 900 pixel; immagine decodificata e ispezionata. Dimensioni logiche rilevate: 1536 × 960 punti.
- mouse ha inviato un clic a TextEdit; type_text ha scritto `Jarvisa MCP: è una prova 🎵` in un nuovo documento di prova. Il testo è stato letto da TextEdit e confrontato esattamente.
- stop_control durante il conto alla rovescia ha annullato il comando, disabilitato il controllo e lasciato il documento invariato.
- EOF sullo stdio ha terminato il server con codice 0.
- Pacchetto jarvisa-control@jarvisa-local 0.2.0 installato tramite CLI; plugin list lo riporta installed=true ed enabled=true. Il caricamento dei suoi strumenti in una nuova chat non è ancora provato.
- Client tunnel ufficiale 0.0.16 scaricato dalla release OpenAI; checksum SHA-256 uguale a quello pubblicato, eseguibile avviato e versione letta.
- Login ChatGPT riuscito: plugin remoto **Jarvisa Control** creato attraverso Crea un server MCP personalizzato, con la connessione Tunnel e l’ID reale. Il dettaglio del plugin riporta **Connessa**; conferma visiva in `verification-mcp/plugin-installed.jpg`.
- Accesso a OpenAI Platform completato dall’utente con passkey. Tunnel Jarvisa Control creato realmente e associato all’organizzazione personale e al workspace ChatGPT disponibili; conferma visiva conservata in `verification-mcp/tunnel-created.jpg`.
- Chiave runtime creata con autorizzazione dell’utente: Restricted, soli permessi Tunnels Read + Use, scadenza 30 giorni. La prima chiave, comparsa in una lettura diagnostica, è stata revocata nella pagina del progetto; conferma visiva in `verification-mcp/key-revoked.jpg`. La sostitutiva è stata trasferita al processo locale attraverso un socket Unix privato, senza stamparla né salvarla in file. Non va pubblicato alcun segreto.
- ID reale del tunnel salvato localmente in `~/Library/Application Support/JarvisaControl/tunnel-id`; launcher `.command` predisposto per chiedere soltanto la chiave in Terminale.
- Runtime supervisionato avviato con la chiave sostitutiva: collegamento pronto e processo MCP in esecuzione. Profilo locale jarvisa-control con il vero ID del tunnel, comando dell’app installata e porta di diagnostica solo localhost assegnata automaticamente.
- Scoperta remota verificata: nove strumenti riconosciuti, identità jarvisa-control 0.2.0, protocollo negoziato 2025-11-25. Evidenza compatta in `verification-mcp/tunnel-health.json`.
- Nella chat ChatGPT di prova, get_status e capture_screen sono stati richiamati dal plugin. La risposta riporta i permessi schermo e input attivi e il controllo disabilitato. La risposta afferma che lo screenshot è mostrato, ma l’immagine non è visibile nella pagina: questa affermazione non costituisce una verifica della visualizzazione dello screenshot.
- Prova reale dalla chat ChatGPT completata: list_apps, enable_control, mouse a 600,400, press_key select_all, type_text con accento/emoji e stop_control. Il testo del documento temporaneo è stato letto indipendentemente da TextEdit e coincide esattamente con `Jarvisa dalla chat: prova riuscita 🎵`. Il server riporta correttamente deliveryVerified=false; la verifica della consegna è stata effettuata dal client di prova. Evidenza in `verification-mcp/chatgpt-input.json` e `chatgpt-input.jpg`.
- Richiesta finale dalla chat: get_status riporta controlEnabled=false e «STOP · controllo disattivato». Dopo un nuovo capture_screen, ChatGPT identifica TextEdit e trascrive il testo corretto del documento. L’immagine non è allegata nella risposta della chat. Evidenza in `verification-mcp/chatgpt-final.json` e `chatgpt-final.jpg`.

Evidenza locale: `verification-mcp/report.json`, `screen-from-mcp.png`, `input-delivered.txt`, `plugin-list.json`. Evidenza del collegamento ChatGPT: `plugin-installed.jpg`, `chatgpt-plugin.json`, `tunnel-health.json`. Le altre app non sono state provate. Il Mac deve essere acceso e il runtime attivo; non è configurato il riavvio automatico del collegamento e la chiave non è salvata in un archivio persistente.
