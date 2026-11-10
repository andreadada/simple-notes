# P2 — Sincronizzazione automatica conservativa dei modelli utente

**10 novembre 2026 — [PR #65](https://github.com/andreadada/simple-notes/pull/65) in verifica.** Nessun deploy, prova hardware o nuova migrazione. [Stato canonico](CURRENT-STATUS.md) · [Matrice di consegna](P2-DELIVERY-MATRIX.md).

## Scopo

La [PR #63](P2-CLOUD-TEMPLATES.md) ha introdotto il catalogo cloud modelli `GET/PUT /api/v1/templates/catalog` con owner JWT e CAS Flyway V13, ma solo con pulsanti manuali. La PR #65 aggiunge la **riconciliazione automatica conservativa delle definizioni** in primo piano fra installazioni Windows e Android dello stesso account. La stessa coda persistente di task/note resta indipendente: **nessuna nuova attività, modifica di task, outbox, endpoint o permesso Google**.

La sincronizzazione cloud dei modelli viene tentata dopo una sync riuscita delle attività e quando `AutoSyncHost` si sveglia: avvio, ritorno in primo piano, ripristino sessione, riconnessione, modifiche locali e refresh periodico ogni **60 secondi**. La finestra `Strumenti → Modelli` è un gate di pausa durante tutta la permanenza sullo schermo, così l'utente non perde un edit aperto né vede il catalogo sostituito mentre lo sta usando. Tornando a un'altra sezione si riprende il confronto.

## Decisioni automatiche

Il checkpoint `UserTemplateMirrorAnchor` registra **versione e catalogo comuni confermati**, con chiave SharedPreferences `simple_notes.templates.v1.{SHA256(owner)}.mirror.v1`, schema 1. Non contiene token Google, JWT, task o record di sync. Lo schema viene validato e non si cancella automaticamente un checkpoint corrotto.

| Stato locale/cloud | Comportamento |
|---|---|
| Identici | Allinea checkpoint senza PUT |
| Nuova installazione, nessuna preferenza locale, cloud revisionato | Scarica catalogo e salva checkpoint dopo aver scritto il locale |
| Modelli creati offline e nessun catalogo cloud (v0) | Pubblica con CAS expectedVersion=0 |
| Catalogo vuoto su entrambi i lati senza precedenti | Nessun PUT superfluo: checkpoint v0 |
| Dopo checkpoint, cambia solo il locale | Pubblica con CAS all'ultima revisione cloud, valida risposta incrementata |
| Dopo checkpoint, cambia solo il cloud | Scarica senza toccare task/outbox, dopo nuovo controllo owner |
| Cambiano entrambe le copie | **Conflitto**: nessun merge o cancellazione, utente sceglie manualmente |
| Locale esplicitamente svuotato, cloud già pubblicato, senza checkpoint | **Conflitto**, non presume che il catalogo vuoto sia una nuova installazione |
| Cloud arretra di versione o cambia payload senza incrementare la versione | **Conflitto**, rifiuta rollback incoerente |
| Account cambia, editor aperto, locali cambiano durante il GET | **Skip** senza sovrascrivere dati |
| HTTP 404/426, 409, rete, JSON o checkpoint malformato, recovery attiva | Stato distinto e fail-closed, nessun blocco del sync task/note |

Inizializzazione, checksum e cataloghi non sono automaticamente fusi: un modello eliminato può essere una cancellazione intenzionale. I pulsanti **Pubblica cloud** e **Scarica cloud** rimangono disponibili nella schermata Modelli con consenso esplicito, re-GET prima del download e CAS PUT prima di pubblicare. Dopo successo manuale, il checkpoint è aggiornato con la revisione scelta, quindi una successiva auto-sync non ripete la decisione.

Ordine anti-crash: prima il salvataggio della libreria locale e poi il checkpoint nel download; prima il PUT confermato dal backend e poi il checkpoint nell'upload. In caso di crash tra due scritture, il nuovo confronto rileva l'ancoraggio incompleto senza assumere un vincitore.

## Sicurezza e UX

- `AutoSyncHost` controlla sessione autenticata, `boundOwnerId` nel database Drift, restore sync gate e conflitti cloud di task prima del catalogo; nessuna operazione viene eseguita se account o gate non corrispondono.
- La schermata Modelli mostra lo stato della sincronizzazione, senza popup forzati: allineata, pubblicata, scaricata, in conflitto, sospesa, API V13 mancante, rete non disponibile o checkpoint non valido.
- La libreria modello è sincronizzata **solo mentre l'app è attiva** e il backend V13 è stato effettivamente deployato. Non è un servizio background Android né una sync delle definizioni di altri utenti.
- Il file JSON manuale rimane non cifrato; il backup `.snb` cifrato continua a includere le definizioni. Nessuna modifica al restore live.
- Nuovi modelli sul dispositivo B si vedono quando una nuova sessione/ritorno in primo piano/refresh attiva il confronto; la vista Modelli in modifica non si aggiorna alle sue spalle.

## Test

`user_template_catalog_mirror_test.dart`: installazione nuova, pubblicazione CAS e nessun doppio upload, download, no-op v0, modifiche offline su entrambi, checkpoint corrotto, local edit durante GET, owner switch, rollback, stesso-versione-diverso-contenuto, HTTP 409 e risposte PUT incongruenti. `user_template_cloud_widget_test.dart`: revisione del checkpoint solo dopo download confermato, mai per PUT 409. La verifica di Flutter analyze, test e build Android/Windows viene registrata in [CURRENT-STATUS](CURRENT-STATUS.md) dopo la CI.

**La P2 globale resta aperta:** OAuth Google Calendar/Outlook, collaborazione multi-account/ACL, scheduler server e reminder multi-device, storage S3 reale e lifecycle/cleanup, restore live e collaudi hardware/deploy.
