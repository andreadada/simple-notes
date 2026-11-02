# P2.3D — Gestione sorgenti ICS e nomi editabili inline

**Stato:** candidata Flutter `0.29.0+31` nel branch `feature/p2-3d-ics-source-management` (2 novembre 2026). CI, merge e test dispositivi reali da attestare separatamente. Nessuna migrazione Flyway, Drift o backend; nessun deploy Coolify.

## Obiettivo e UX

Nella schermata Calendario rimangono i pulsanti **Importa ICS** e **Aggiungi URL ICS**. Il controllo **Sorgenti (N)** apre, solo su richiesta, un pannello compatto che elenca fino a cinque file/feed. Ogni sorgente presenta:

- **Nome immediatamente editabile sul testo**, con `InlineEditableTitle`: Enter o perdita del focus salva; Esc annulla. Nessun dialog o bottone Rinomina. L'input usa l'underline largo esattamente quanto il testo e i token dei temi chiaro/scuro.
- Tipo **File locale** oppure **Feed HTTPS · hostname**. Per i feed non si mostrano path, query string o token.
- Conteggio eventi singoli e serie ricorrenti, separati (NON il numero di occorrenze generate, potenzialmente infinito).
- **Ultimo aggiornamento riuscito** soltanto per feed HTTPS (data/ora locali e offset); i vecchi file e feed senza metadato mostrano una descrizione esplicita. In caso di refresh fallito compare un errore sulla specifica sorgente, senza aggiornare il timestamp né cancellare la cache.
- **Aggiorna** solo per URL, senza esecuzioni automatiche; **Rimuovi** con conferma per sorgente ID. Le fonti sono sempre read-only e non possono creare task, promemoria o outbox.

## Dati e compatibilità

Il valore persistito `IcsCalendar.name` resta **immutabile per tutta la vita della sorgente** (filename originale nei file, nome host nei feed). Serve per associare un nuovo import dello stesso file e verificare le sorgenti degli eventi nel JSON. Per il display viene aggiunta la proprietà opzionale **`displayLabel`**, che ammette fino a 80 caratteri, senza controlli o stringhe vuote. La UI usa `calendar.label = displayLabel ?? name`.

- `IcsLibrary.renameById(id, label)` modifica soltanto `displayLabel`, conserva ID, URL e timestamp, ordine di sorgenti, eventi, UID, RRULE/exception e JSON degli altri calendari. Nessuna rete.
- `IcsLibrary.onDay(day)` proietta l'etichetta corrente nel campo visualizzato `IcsEvent.source` **soltanto per il rendering**; gli eventi archiviati mantengono la sorgente originale per reimport e validazione.
- Un reimport dello stesso filename, `subscribe` di URL già presente o `refresh` conserva il `displayLabel` personalizzato senza confonderlo con le chiavi originali. Nomi visibili identici sono permessi su calendari diversi: non determinano alcuna sostituzione o rimozione.
- La persistenza resta JSON **schema 3 nella chiave esistente** `simple_notes.ics.v1.<sha256(owner)>`: vecchi schemi 1/2/3 si leggono con `displayLabel = null`, **senza riscrittura al caricamento**. La prima azione confermata serializza schema 3. I vecchi client P2.2/P2.3A non devono essere reinstallati sopra uno schema 3 senza migrazione.
- Nessuna nuova richiesta HTTP al semplice avvio/espansione/rename e nessun cambio token, secure storage, cloud o API. La limitazione dei feed HTTPS della P2.3C (SSRF, host e redirect, 1 MiB, refresh manuale) rimane invariata.

## Limitazioni deliberatamente escluse

- **Nessuna cifratura aggiuntiva dei token**: gli URL con query-token restano nel JSON locale SharedPreferences esistente. Mai stamparli in UI, log o report; una futura migrazione a secure storage richiede strategia dedicata.
- Il filename originario di un file locale non viene rinominato, e l'URL/feed non viene modificato con l'editing dell'etichetta. Per cambiare URL occorre eliminare e aggiungere una nuova fonte con conferma.
- Non implementati polling, sync multi-device dei calendari esterni, autorefresh, OAuth Calendar/Outlook, RSS, export CSV, backup completo o condivisione liste.

## Gate e test

- JSON schema 1/2/3 retrocompatibili, roundtrip `displayLabel`, rifiuto di nomi invalidi; reimport file/URL con label personalizzata e stesso ID.
- Sovrapposizioni di nomi visibili, isolamento owner, cancellazione per ID e RRULE/istanze con label proiettata ma master immutato.
- Widget Forui: pannello chiuso di default, apertura, input inline Enter/blur/Esc, refresh solo URL, hostname e stato senza query token, cambio owner senza dati incrociati.
- CI Flutter analyze/test, Windows EXE/MSIX, Android JDK17+21 e Markdown link sullo **stesso commit**. Verifica fisica Windows/Android e server-first Flyway V10 restano gate separati del batch finale.

**Seguito raccomandato:** pausa nuove estensioni del calendario e completamento del gate reale server-first (VPS Flyway V10 + capability), Windows/Android E2E e conservazione dati. Successive P2: CSV e backup completo, poi condivisione/integrazioni con esplicito progetto di sicurezza.

Collegamenti: [P2.3C](P2-ICS-FEEDS.md) · [P2.3B](P2-ICS-RECURRENCE.md) · [Stato](CURRENT-STATUS.md) · [Roadmap](../project.md) · [AGENTS](../AGENTS.md).
