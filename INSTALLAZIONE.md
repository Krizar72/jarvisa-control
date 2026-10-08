# Installazione e contenuto

Il pacchetto contiene App/Jarvisa Control.app (bundle universale 0.2), i sorgenti Swift, i test, il plugin MCP locale, gli script del tunnel e PROCESSO.md con il percorso seguito e i risultati.

1. Estrai lo ZIP e copia l’app in ~/Applications/Jarvisa Control.app. È un prototipo con firma ad hoc, non notarizzato: un altro Mac può applicare le proprie verifiche di sicurezza. Per valutare il codice puoi anche compilare con bash ./build.sh universal.
2. Avvia l’app e concedi Registrazione schermo e Accessibilità. Prima prova cattura, mouse e testo su un nuovo documento temporaneo TextEdit.
3. Per il plugin locale Codex usa i comandi marketplace del README. Il manifest avvia la copia in ~/Applications; JARVISA_APP_PATH può indicare un’altra copia.
4. Per ChatGPT, installa il client tunnel dal sito ufficiale OpenAI nel percorso indicato dal launcher. Crea un tunnel e una chiave runtime Tunnels Read + Use nel tuo account, associando il tuo workspace ChatGPT. Il client vendor non è incluso in questo archivio.
5. Avvia bash ./scripts/connect-chatgpt.sh dal Terminale: ID e chiave saranno richiesti localmente. Quindi crea il server MCP personalizzato in ChatGPT, connessione Tunnel, con il tuo ID. La chiave non va incollata in chat.
6. Verifica get_status, list_apps e capture_screen; per l’input serve enable_control. Verifica l’effetto sul documento destinatario e ferma il controllo dopo la prova.

L’archivio non contiene credenziali, ID del tunnel dell’utente, configurazioni del suo account, screenshot personali o log privati. CHECKSUMS.sha256 contiene l’impronta di ogni file distribuito; l’hash dell’intero ZIP è nel file esterno .sha256. Le cartelle verification citate nel resoconto originale sono evidenze private non distribuite. RISULTATI.json include soltanto gli esiti sintetici delle prove.

Non è configurato il riavvio automatico del tunnel dopo il riavvio del Mac. Il controllo di tutte le app e delle finestre protette non è garantito; arm64 è stato compilato e non provato su un dispositivo Apple Silicon.
