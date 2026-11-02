# P2.3C — Sottoscrizioni ICS HTTPS con aggiornamento manuale

**Stato 02/11/2026:** integrata su `main` con [PR #24](https://github.com/andreadada/simple-notes/pull/24), Flutter `0.28.0+30`; [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/41460378203) **success** (182 test, Windows EXE/MSIX, Android JDK17/21), [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41460378261) **success**. Test real-device e deploy non eseguiti. Non è un sistema di sincronizzazione cloud del calendario e non richiede alcuna migrazione backend.

## Flusso utente

1. Nella vista Calendario selezionare **Aggiungi URL ICS**, immettere un link `https://` e premere **Scarica feed**. Il contatto con il server avviene **solo** dopo questo gesto esplicito.
2. Il client scarica al massimo 1 MiB, analizza l'intero file con il parser fail-closed P2.3B e mostra il numero di eventi singoli e serie ricorrenti prima di salvare. Annullamento, errore rete o formato non supportato **non modificano lo storage**.
3. Su conferma, la sorgente URL e i suoi eventi sono conservati nello **stesso archivio locale per account** SharedPreferences, schema 3. La proiezione di eventi nella vista calendario è read-only, funziona anche offline ed è distinta da task e outbox.
4. L'azione **Aggiorna** accanto a ciascun feed URL è l'unico refresh: non esiste polling, timer, refresh al lancio, fetch al login o auto-refresh in background. Se fallisce download, redirect, parsing o salvataggio, la cache precedente resta inalterata.
5. **Rimuovi** cancella soltanto la sorgente locale selezionata, identificata da ID stabile, compresa la URL che può contenere un token in query string. Dopo rimozione non deve rimanere un riferimento al link nello storage ICS di quell'account. Non si inviano API o OAuth token.

## Sicurezza della rete

- Solo `https://` con nome di dominio DNS, senza `userinfo`, fragment, IP letterali o porta diversa da 443. Host `localhost`, `.local`, `.internal`, `.localhost`, `.test` e `.invalid` rifiutati.
- **DNS pinning per connessione:** il `HttpClient.connectionFactory` risolve l'host e controlla tutti gli indirizzi; se uno è privato, loopback, link-local, documentale, riservato o un tunnel IPv6 non consentito, l'intera richiesta fallisce. La connessione TCP usa soltanto l'indirizzo convalidato mentre TLS verifica il certificato contro il nome originale.
- **Proxy disabilitati** (`DIRECT`), niente credenziali aggiuntive, cookie inviati o bypass dei certificati. Accettate solo risposte HTTPS 200.
- Redirect automatici disabilitati; massimo **due** redirect espliciti, sempre stesso host HTTPS e porta 443, senza loop o downgrade. Ogni nuovo socket viene risolto e controllato nuovamente. Redirect cross-origin falliscono chiusi (anche se legittimi: è una limitazione deliberata di sicurezza).
- Timeout connessione 6 secondi, timeout totale download 20 secondi, limite di 1 MiB anche **dopo decompressione**; file vuoti o non-ICS bloccano il salvataggio.
- **Limite privacy:** l'URL completo (incluso l'eventuale token nella query) è memorizzato nello SharedPreferences del dispositivo, non cifrato ulteriormente dall'app. È protetto dalle normali restrizioni di accesso dell'OS, non da crittografia end-to-end; non importare feed sensibili su dispositivi non fidati. Una gestione separata in secure storage richiederebbe una migrazione futura.
- Gli URL possono includere token privati nella query: **non** mostrarli nelle etichette dei feed, nei messaggi errore, diagnostica, Analytics, log o PR. Sono salvati soltanto nelle preferenze locali dell'owner. Non rappresentano un login Google Calendar/Outlook; l'utente deve ottenere un URL ICS esportato e consentire esplicitamente la richiesta.
- Nessuna garanzia per feed con redirect verso provider/CDN esterni: in questa fase è richiesto un URL HTTPS diretto o un redirect sullo stesso host.

## Identità, formati, compatibilità

- La fonte ha `kind=url`, `sourceUrl`, `id` stabile; il nome visualizzato predefinito è il **solo hostname**, senza path o query.
- `lastFetchedUtc` è un campo ISO-8601 UTC **opzionale** aggiunto allo **schema 3 esistente**, non una nuova versione. Compatibile in lettura con i file locali schema 1/2/3 e URL metadata-only schema 2/3 precedenti (timestamp nullo fino al primo refresh).
- Un URL già importato viene aggiornato senza crearne una seconda copia e preserva nome, ID e altri file; sorgenti `file` e `url` possono avere la stessa etichetta senza collisioni.
- Limiti invariati: max 5 fonti locali, 500 VEVENT per sorgente, 1 MiB ICS; parser e ricorrenze con subset P2.3B.
- Un vecchio client P2.3A non può leggere lo schema 3: non effettuare downgrade distruttivi. L'app non riscrive preferenze durante il caricamento.

## Test e gate

- Validazione URL, blocco IP privati/IPv4/IPv6, risposta DNS mista pubblico+privato, redirect cross-origin/loop e downgrade.
- Download simulato: subscribe/refresh, preservazione ID e altri file, roundtrip JSON, rifiuto cache corrotta, disconnessione e limiti.
- Flutter analyze, widget test, Windows release EXE/MSIX, Android JDK17/21 e Markdown links sullo **stesso commit** prima del merge.
- Collaudo manuale Windows/Android e verifica end-to-end URL reale da effettuare nel batch finale; nessuna prova fisica o deploy Coolify è implicita nella CI.

## Passo successivo

**P2.3D:** UI gestione fonti più completa con etichetta editabile **inline**, vista dettagli/sorgenti, eventuale stato refresh senza esporre token, gestione UX degli errori e fixture reali. **P2/P3 successive:** export CSV, backup integrale, condivisione, integrazioni OAuth Calendar/Outlook distinte. Non anticipare OAuth, background fetch o cloud sync.

Collegamenti: [P2.3B](P2-ICS-RECURRENCE.md) · [P2.3A](P2-ICS-SOURCES.md) · [Stato](CURRENT-STATUS.md) · [Roadmap](../project.md) · [Regole](../AGENTS.md).

## Evoluzione P2.3D — Etichette e gestione

La P2.3D candidata aggiunge una label visibile opzionale e un pannello per controllare il feed, il refresh riuscito, il numero di eventi e il nome editabile inline. I feed continuano a usare la URL originaria e non mostrano mai path/query token, conservando ID ed etichetta dopo refresh anche quando il server è irraggiungibile. Nessun auto-refresh né backend. [Specifiche](P2-ICS-SOURCE-MANAGEMENT.md).

