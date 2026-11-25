# Simple Notes — migrazione web e cutover (25/11/2026)

## Stato e architettura

Webapp browser-only in `apps/web`, ispirata a Console DDone/Lark. HTML/CSS/JS, Nginx, Spring Boot, PostgreSQL 17. Nessun manifest PWA, service worker, APK o MSIX richiesto. Flutter rimane nel repository come client legacy per recupero. Il Compose esistente espone web:80 e api:8080, conservando il volume DB. Schema sorgente Flyway V24; ultima VPS attestata V17. Nessun deploy effettuato in questa sessione.

## Funzioni disponibili

- Attività, note, liste, cestino e recupero note, ricerca, griglia, galleria, Kanban, calendario, dashboard, Eisenhower, viste personalizzate; colonne per vista (ordine, larghezza, visibilità), campi tipizzati (testo, numero, checkbox, data, scelta singola), editor mobile e inline, selezione e bulk, filtri composti AND/OR e ordinamento per campo. Preferenze per account con CAS.
- Scadenze IANA, ricorrenze, tag, sottoattività, fino a 12 blocchi, timeline drag/resize a 15 minuti, calendario giorno/settimana/mese.
- Cataloghi di modelli, azioni created/completed server-side opt-in, regole promemoria due/block per priorità e anticipo, inbox persistente deduplicata. Modalità regole V23 alternativa alla regola unica V19.
- Condivisione VIEWER/EDITOR, inviti, modifica per cella di titolo/descrizione/priorità/stato, presenza effimera e aggiornamento foreground con CAS per record (non CRDT). Azioni collaboratore non eseguono regole che potrebbero spostare il record fuori lista.
- Google/Outlook: import di eventi collegati e aggiornamento esplicito della relativa attività. Google: pubblicazione idempotente e aggiornamento con If-Match di eventi personali senza invitati o ricorrenze, opt-in `APP_CALENDAR_GOOGLE_WRITE_ENABLED=false` di default; richiede nuovo consenso OAuth. ICS file/feed HTTPS read-only (CORS, subset RFC5545).
- Pomodoro, abitudini, countdown, tema, wiki; preferenze compatibili sincronizzate per account. Timer e feed ICS locali.
- Outbox persistente fino a 100 intenti indipendenti (uno per record), proiezione locale, retry e conservazione bozze rifiutate; conflitti confrontabili. Login/prima lettura online, niente avvio offline PWA. Notifiche opt-in a pagina aperta.
- CSV/JSON, backup cifrato AES-GCM/PBKDF2, archivio Flutter .snb con password/account originari, migrazione di preferenze e cataloghi compatibili senza sovrascrivere conflitti. Import atomico additivo max 500 record; recupero con ID e timestamp originali solo per record senza storico, CAS cursor sotto lock, esclusione tombstone e record presenti. Backup include inventario, dati, note cestinate e cataloghi; binari S3 e dump SQL da salvare separatamente.

## Limiti da non confondere con un collaudo live

Non è prevista installazione PWA né push a browser chiuso. Il calendario Google è bidirezionale su comando esplicito, non un mirror automatico; Outlook è import/aggiornamento verso Simple Notes, non scrittura remota. Non sono previsti ripristini distruttivi, replay indiscriminato dell'outbox nativa o sovrascrittura di dati presenti. Feed ICS nativi vanno verificati/reimportati separatamente. Allegati S3 opzionali richiedono storage e scanner reali. Test OAuth/provider e accesso ai dati di produzione restano da fare sulla VPS.

## Cutover Coolify

1. Sincronizzare Flutter con lo stesso account fino a pending 0; esportare backup .snb e JSON. Non disinstallare o resettare i client.
2. Eseguire backup PostgreSQL, copia offsite e restore isolato secondo [OPERATIONS](OPERATIONS.md). Conservare conteggi e backup S3 se usato. Mai down -v, reset o Flyway repair.
3. Usare la stessa risorsa Compose Coolify, branch main, base directory /, compose /docker-compose.yml. Conservare postgres_data e variabili esistenti. Configurare `WEB_GOOGLE_CLIENT_ID` e includerlo in `GOOGLE_CLIENT_IDS` mantenendo i client nativi durante la transizione.
4. Google Cloud OAuth Web: origine JavaScript autorizzata https://notes.ddone.it (o dominio effettivo). DNS/HTTPS del servizio web:80; mantenere api.notes.ddone.it su api:8080. Provider calendario opzionali con proprie callback e credenziali.
5. Dopo CI verdi sullo SHA da rilasciare, redeploy. Flyway applica V18–V24 in ordine. Verificare /healthz del web, /actuator/health API e `bash infra/release-v24-readiness.sh` con DB_CONTAINER corretto e JWT temporaneo senza stamparlo.
6. Login reale, confronto inventario/conteggi, creazione nota/task di test, recupero cestino, griglia/viste, coda e conflitti con due browser, collaborazione e mobile. Verificare promemoria, provider e allegati se abilitati.
7. Impostazioni → Migrazione e backup → Analizza archivio: per dati non presenti usare recupero ID originali con anteprima, oppure copie solo se volute. Non importare indiscriminatamente dati già sincronizzati.
8. Solo dopo collaudo positivo usare esclusivamente il web. Conservare archivi nativi. In caso di problemi ripristinare routing/revisione compatibile senza downgrade distruttivo del DB.

## Verifiche

[GitHub Actions](https://github.com/andreadada/simple-notes/actions) è la fonte per esito per SHA: web unitari, build Docker, smoke container e Chromium simulato; backend con PostgreSQL Testcontainers; Compose e Markdown CI. Il gate corrente è V24; gate V19/V20/V21/V22 storici. [CURRENT-STATUS](CURRENT-STATUS.md) contiene la cronologia; questa pagina prevale per il cutover.

## Creazione inline e configurazione delle viste
Riga/carta vuota sempre disponibile, salvataggio su Invio o uscita dal campo; bozza locale per account e contesto, nessun dialog obbligatorio. Note modificabili nel corpo direttamente; Kanban e calendario creano record nel contesto della corsia/giorno. Tutte le viste, comprese predefinite, possono essere rinominate, duplicate, riordinate e nascoste; configurazione immediata di densità, campi, dimensioni schede, raggruppamento Kanban, periodo e visibilità calendario, widget dashboard e soglia Eisenhower. Preferenze salvate nel dominio esistente viewOptions, senza migrazioni DB. I pulsanti + restano come scorciatoie per l'editor completo.

Anche Home e la sezione Calendario dispongono di controlli di visualizzazione. Le intestazioni della griglia offrono trascinamento, menu di ordinamento e visibilità; la nuova riga è allineata alla colonna Titolo. Le modifiche rapide mantengono i valori in bozza durante richieste in corso.

## Workspace V24
Le note possono essere aperte direttamente nella sidebar come documenti a pagina intera, con editor formattato, elenchi, tabelle semplici e bozza locale/autosalvataggio. Il backend mantiene la proiezione plain text per Flutter e il contenuto formattato separato. La formattazione viene ricostruita da una whitelist DOM, senza script o attributi arbitrari. Il client Flutter resta legacy. CSS e sprite SVG selezionati provengono direttamente da Console DDone, adattati al nuovo workspace.

Tabelle indipendenti con campi testo/numero/checkbox/data/scelta/link, griglia, galleria, Kanban, calendario e dashboard; configurazione per vista, filtri, raggruppamento, ordinamento, densità, colonne ridimensionabili, righe inline, bozze locali e pulsante Salva (CAS tabella), archiviazione reversibile. Limiti iniziali: 100 tabelle/account, 500 righe/tabella, 40 campi, 20 viste e 1 MiB JSON/tabella. Tabelle private per account; condivisione attuale resta dedicata alle liste attività. Export JSON per tabella, dump DB include tutte le tabelle. Gate V24: `infra/release-v24-readiness.sh`.
