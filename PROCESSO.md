# Jarvisa Control 0.2 — processo e risultati

Prototipo realizzato l’8 ottobre 2026 da Cristiano Zenato (Krizar) insieme all’assistente Codex, chiamato Jarvisa dall’utente. Verificato su Mac Intel x86_64 con macOS 26.7.1. Il pacchetto comprende il progetto Swift, l’app universale compilata, il plugin locale e gli script del collegamento remoto.

## Scopo e rapporto con il caso OpenAI

L’utente desiderava acquisire lo schermo e controllare le app del proprio Mac anche dalle chat di ChatGPT. Nel caso di assistenza Computer Use aveva già documentato l’indisponibilità del percorso nativo OpenAI. Abbiamo costruito un componente locale indipendente e lo abbiamo esposto mediante MCP e un tunnel privato ufficiale. Il risultato non dimostra che il servizio Computer Use/AppShot integrato di OpenAI sia stato corretto né identifica la causa delle anomalie già segnalate.

## 1. App locale

Abbiamo implementato un’app SwiftUI/AppKit con ScreenCaptureKit per la cattura dello schermo selezionato, fino a 10 fotogrammi al secondo e larghezza massima 1440 pixel. La finestra di Jarvisa è esclusa dall’acquisizione. L’interfaccia permette di avviare e fermare la cattura e salvare un PNG; non registra video.

Per mouse e tastiera abbiamo usato eventi Core Graphics. La destinazione è un’app scelta esplicitamente; le coordinate sono punti logici del monitor, con conversione dalla risoluzione dell’immagine e supporto delle origini negative. Sono disponibili spostamento, clic, doppio clic, clic destro, testo Unicode e un insieme di tasti/combinazioni standard.

## 2. Permessi e arresto

L’utente ha concesso Registrazione schermo e Accessibilità nelle impostazioni di macOS. Il controllo parte disabilitato. Prima di ogni input c’è un conto alla rovescia cancellabile di tre secondi; l’app destinataria viene attivata e Jarvisa nascosta. La scrittura si ferma se cambia l’app in primo piano. Esc e STOP disabilitano il controllo e annullano gli input in attesa. Il menu nella barra di macOS permette di fermarlo anche nella modalità senza finestra.

Abbiamo distinto due risultati: gli eventi possono essere inviati al sistema senza che il testo arrivi al campo previsto. Per questo gli strumenti riportano deliveryVerified=false; una verifica separata del documento o una nuova cattura deve confermare l’effetto.

## 3. Compilazione e prove locali

Abbiamo compilato il bundle universale Intel/Apple Silicon con Swift 6.1.2 e target minimo macOS 13. La firma è ad hoc. La copia eseguita è stata installata in ~/Applications, poiché il file provider della cartella di lavoro sincronizzata aggiungeva metadati che interferivano con la firma dentro dist.

Sono passati 25 controlli sulla logica di coordinate, Retina, bordi, eventi bilanciati, combinazioni di tasti e Unicode. Le prove reali hanno confermato un PNG del desktop di 1440×900 pixel su uno schermo di 1536×960 punti, il clic a 600,400 e la scrittura di testo con accenti ed emoji in un nuovo documento TextEdit. Esc durante il conto alla rovescia ha lasciato il documento invariato.

## 4. Server MCP e plugin locale

Abbiamo aggiunto la modalità --mcp, con JSON-RPC su stdin/stdout e senza log sul canale del protocollo. Il server espone nove strumenti: get_status, list_displays, list_apps, capture_screen, enable_control, stop_control, mouse, type_text e press_key. Valida i parametri, limita la dimensione del testo, serializza l’input e permette la cancellazione. EOF chiude il processo e disabilita il controllo.

Il test sul vero server installato ha superato 22 verifiche, incluse cattura PNG, Unicode consegnato a TextEdit, rifiuto di parametri non validi e STOP durante un comando. Il marketplace locale jarvisa-local e il plugin jarvisa-control 0.2.0 sono stati installati e abilitati nel registro Codex. Questo registro, da solo, non prova che una nuova chat Codex abbia caricato gli strumenti.

## 5. Collegamento a ChatGPT

L’utente ha completato gli accessi a ChatGPT e OpenAI Platform con la propria passkey. Abbiamo creato un tunnel privato Jarvisa Control nell’organizzazione e associato il workspace ChatGPT disponibile. Il client tunnel ufficiale 0.0.16 per Intel è stato scaricato dalla release OpenAI e verificato con il checksum pubblicato.

Abbiamo creato una chiave runtime Restricted con soli permessi Tunnels Read e Use e scadenza di trenta giorni. Questa durata è una scelta per il prototipo, non un requisito tecnico. Una prima chiave comparsa durante una lettura diagnostica è stata revocata nella pagina del progetto e sostituita. La sostitutiva è stata trasferita al processo attraverso un socket Unix locale con directory privata 0700 e socket 0600, senza stamparla o salvarla in file.

Il runtime supervisionato usa l’app installata come server stdio e presenta solo una porta diagnostica localhost. Le pagine del browser possono essere chiuse senza fermarlo. Mac e runtime devono restare attivi; il prototipo non configura un avvio automatico dopo il riavvio e non conserva la chiave in un archivio persistente.

## 6. Registrazione del plugin remoto

In ChatGPT abbiamo creato Jarvisa Control mediante «Crea un server MCP personalizzato», connessione Tunnel e ID reale del tunnel. Il server stdio non aggiunge un proprio OAuth: l’accesso è autenticato dal tunnel OpenAI. Il dettaglio del plugin ha mostrato «Connessa».

La scoperta remota ha riconosciuto tutti e nove gli strumenti, identità jarvisa-control 0.2.0 e revisione MCP 2025-11-25. Il server implementa il protocollo classico initialize/tools/list; server/discover risponde method-not-found per il fallback. Il protocollo moderno 2026-07-28 non è implementato.

## 7. Prova effettiva dalla chat ChatGPT

Nella chat con Jarvisa selezionata abbiamo richiesto stato e screenshot: i permessi schermo/input risultavano attivi e il controllo disabilitato. Abbiamo poi chiesto list_apps, enable_control, un clic sul documento temporaneo TextEdit, select_all, la scrittura «Jarvisa dalla chat: prova riuscita 🎵» e stop_control.

Il testo è stato letto indipendentemente dal documento TextEdit tramite AppleScript e confrontato esattamente con il valore atteso: corrispondenza completa, inclusa l’emoji. La successiva richiesta get_status ha riportato controlEnabled=false e «STOP · controllo disattivato». Dopo una nuova cattura, ChatGPT ha identificato TextEdit e trascritto il testo corretto. La chat non ha mostrato l’immagine come allegato, anche se una prima risposta lo aveva affermato: abbiamo rilevato e documentato questa differenza.

## 8. Prove durante la conversazione vocale Codex

Abbiamo acquisito nuove immagini della conversazione corrente e di DuckDuckGo con il server locale Jarvisa, mostrandole all’utente. Su DuckDuckGo abbiamo usato il vero mouse tramite Jarvisa per cliccare il segnalibro Gmail: una nuova cattura ha confermato la navigazione alla pagina di accesso Google. Non è stata verificata l’apertura della casella di posta autenticata.

Console è stata aperta con il comando di avvio macOS, poi verificata visivamente: l’apertura tramite shell è distinta dal controllo nativo. Con il mouse Jarvisa abbiamo selezionato «Dati di analisi Mac» nell’app Console. La lista mostrava due resoconti e il più recente era indicato alle 05:52; non abbiamo prodotto un’analisi degli ultimi dieci minuti. L’utente ha concluso la prova e chiuso Console; il tentativo successivo è stato rifiutato quando la destinazione non era più disponibile.

## Limiti e riproduzione

Il prototipo è firmato ad hoc e non notarizzato. L’architettura arm64 è stata compilata, non provata su un Mac Apple Silicon. Le prove riguardano questo Mac Intel, un monitor, TextEdit, DuckDuckGo e una selezione in Console; non garantiscono il controllo di tutte le app o delle finestre protette. Il server non dispone di un tool per lanciare app chiuse.

Per riprodurre l’integrazione su un altro Mac servono i permessi locali e un tunnel/chiave propri, associati al proprio account/workspace ChatGPT. Le credenziali e gli ID privati dell’utente non sono distribuiti. Il client tunnel vendor non è incluso; i riferimenti ufficiali e le istruzioni si trovano nel README. Screenshot e risultati richiesti da ChatGPT vengono trasmessi a OpenAI.

Condividiamo il progetto perché il supporto e il team tecnico possano esaminarlo, compilare il codice e riprodurre il percorso. Il pacchetto non include le chiavi, le pagine personali catturate, la trascrizione completa né i log privati della sessione.
