# Simple Notes — migrazione web e cutover (25/11/2026)

## Target e architettura
Il prodotto primario è la webapp browser-only in `apps/web`, ispirata al design Console DDone/Lark: HTML/CSS/JS, Nginx, Spring Boot, PostgreSQL 17. Nessun manifest, service worker, install prompt, APK/MSIX richiesto. Flutter è un client legacy conservato per recupero dati; CI nativa solo manuale. Il Compose esistente espone `web:80` e `api:8080`, con DB privato e volume esistente. Nessun segreto nel frontend. Migrazione additiva Flyway V20 (preferenze web), ultima VPS attestata V17: non è stato eseguito alcun deploy in questa sessione.

## Funzioni e limiti
- Attività, note, liste, cestino note e restore, griglia con inline titolo, selezione, filtri/ordinamenti/raggruppamenti, galleria, Kanban, matrice Eisenhower, dashboard riordinabili/ridimensionabili, tema, ricerca, Wiki, mobile, modelli e regole task manuali opt-in.
- Scadenze IANA date-only/timed/legacy, ricorrenze con gap/fold, tag/sottotask, fino a 12 blocchi, calendario giorno/settimana/mese e timeline con drag/resize (15 minuti, conserva identità e CAS). Eventi a cavallo di mezzanotte nella timeline sono visualizzati nel giorno iniziale; non equivale a piena parità di tutti gli editor.
- ICS read-only file/feed HTTPS (CORS richiesto, 1 MiB/5 sorgenti, subset RFC5545), Google/Outlook read-only con provider configurati, promemoria server opt-in, allegati S3 se abilitati con scanner. Nessun push OS/PWA.
- Sharing VIEWER/EDITOR e inviti, aggiornamento manuale snapshot, presenza effimera per lista e attività (single replica, heartbeat 10s/TTL35s, verifica ACL, nessun testo non salvato). Non è editing simultaneo a livello cella.
- Pomodoro avvio/pausa e storico locale, abitudini con target/streak, countdown timed/archivio. V20 sincronizza tema, viste, filtri, dashboard, abitudini e countdown per dominio e account con CAS e riconciliazione conservativa. ICS/feed URL e timer restano locali.
- Delta sync paginata, retry durevole localStorage per intenti individuali, versioni e tombstone. Conflitto confrontabile, nuova CAS per scelta keep-local. Non è una outbox offline-first multi-record né un'app apribile offline. Login Google richiesto dopo reload (bearer in memoria).
- CSV e JSON portabile, import atomico additivo massimo 500 record (nuove UUID), AES-GCM/PBKDF2 web backup, apertura .snb Flutter v1/Drift8 e conversione record attivi con conferma; migrazione tema/abitudini/countdown/focus storico. Nessun replay di outbox native, nessun ripristino distruttivo. Non importa automaticamente ICS, cataloghi locali o regole native; esportarli/migrarli separatamente. Backup web non contiene binari allegati né backup SQL completo. Il file Flutter va conservato anche dopo conversione.
- Resta da collaudare con dati/account reali e completare la parità di funzioni avanzate (configurazioni colonne, automazioni/cataloghi locali, calendario bidirezionale, backup/restore server, presenza per cella). Il vecchio client non deve essere cancellato dai dispositivi prima della migrazione verificata.

## Procedura Coolify (manuale)
1. Su ogni dispositivo Flutter: accedi allo stesso account, sincronizza fino a pending 0, verifica note/task/liste/cestino e crea backup .snb e export portabile. Non disinstallare, non resettare. Dati già sincronizzati sono nel DB; non importarli nuovamente come copie.
2. Backup PostgreSQL e prova restore isolata secondo [OPERATIONS](OPERATIONS.md). Conserva anche backup offsite e annota conteggi. Nessun `down -v`, reset o Flyway repair.
3. Nella **stessa** risorsa Compose Coolify: branch main, base directory /, compose /docker-compose.yml. Conserva postgres_data, credenziali e variabili API esistenti. Configura `WEB_GOOGLE_CLIENT_ID` e aggiungi lo stesso Web OAuth client ID a `GOOGLE_CLIENT_IDS` senza eliminare quelli nativi durante transizione.
4. Google Cloud OAuth Web: origine JavaScript autorizzata `https://notes.ddone.it` (o dominio effettivo), niente secret frontend. DNS e dominio HTTPS del servizio `web:80`; conserva `https://api.notes.ddone.it` su `api:8080`. Provider calendar opzionali mantengono le callback esistenti e richiedono configurazione distinta.
5. Solo con CI verdi sullo SHA effettivo: Redeploy della risorsa. Flyway V18/V19/V20 si applicano in ordine. Verifica `https://notes.ddone.it/healthz`, `https://api.notes.ddone.it/actuator/health`, `infra/release-v20-readiness.sh` con token temporaneo, senza stamparlo.
6. Login con account reale, confronta inventario e conteggi, crea una nota/task di test, prova restore, condivisione, conflitti due browser e sincronizzazione delle preferenze. Verifica desktop/mobile, provider/allegati se configurati.
7. Solo se mancano dati non sincronizzabili: Impostazioni → Migrazione e backup → Analizza archivio. Apri .snb con password e account originario; importa copie **solo dopo aver verificato cosa manca**. Import ripetuto crea duplicati, max 500 record per batch. Preferenze native compatibili aggiunte per ID senza sovrascrivere quelle presenti. Conserva il file originale.
8. Dopo collaudo positivo, usa esclusivamente il dominio web. Puoi mantenere i client nativi come archivio di recupero senza eseguirli. In caso di problemi ripristina routing/revisione applicativa compatibile senza downgrade distruttivo del DB. Non cancellare volumi.

## Verifiche e fonti
- [GitHub Actions](https://github.com/andreadada/simple-notes/actions) è la fonte per esito effettivo per SHA; CI web include test unitari, build Docker, smoke container e Chromium con OAuth/API simulate. Backend CI usa PostgreSQL Testcontainers; Compose e Markdown CI separati.
- Il gate V19 è storico: [readiness V19](RELEASE-V19-READINESS.md). Gate V20: `bash infra/release-v20-readiness.sh`. Nessuna prova live dichiarata.
- Dettagli storici in [CURRENT-STATUS](CURRENT-STATUS.md); questa pagina prevale per il nuovo frontend e cutover.

### V21 — griglia e automazioni
Colonne per vista (ordine, larghezza, visibilità), campi custom tipizzati e valori persistiti sul task, modifiche inline e bulk. Client legacy che omettono customFields mantengono il dato. Definizioni e layout sincronizzati per account. Regole created/completed server-side opt-in nella stessa transazione e replay immutabile; import esclusi. Flyway V21 additiva, VPS non modificata.

### Coda e notifiche
Coda persistente fino a 100 intenti indipendenti (un intento per record), replay ordinato, bozza rifiutata conservata e confronto CAS. Login e prima lettura richiedono rete, niente cache di avvio PWA. Notifiche opt-in mentre la pagina è aperta su browser compatibili, senza push o service worker.

### Cataloghi e collaborazione per cella
Backup web include inventario e cataloghi cloud; recupero modelli e taskActions nativi/web per ID con CAS e conservazione dei conflitti. Regole promemoria native esportabili separatamente. Liste condivise: modifica inline di titolo, descrizione, priorità e completamento, aggiornamento foreground e presenza per cella. Non sono CRDT: le revisioni rimangono per record; modifiche contemporanee richiedono confronto. Le azioni del collaboratore non attivano regole owner che potrebbero spostare il record fuori lista. Gate corrente: `infra/release-v21-readiness.sh`.

### V22 — collegamenti calendario
Import Google/Outlook come attività collegate, aggiornamento esplicito titolo e scadenza dal provider con CAS task e revisione evento. Google: pubblicazione idempotente per task e aggiornamento condizionale If-Match di eventi personali senza invitati/ricorrenze; `APP_CALENDAR_GOOGLE_WRITE_ENABLED=false` di default, riconnessione OAuth necessaria per scope scrittura. Nessun push automatico, cancellazione remota o aggiornamento Outlook non verificato. Il gate corrente è `infra/release-v22-readiness.sh`.
