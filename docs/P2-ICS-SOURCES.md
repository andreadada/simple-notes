# P2.3A — Identità e storage delle sorgenti ICS

**Stato 01/11/2026:** integrata su `main` con [PR #22](https://github.com/andreadada/simple-notes/pull/22), Flutter `0.26.0+28`; [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/41339906564) success (**166 test**, Windows EXE/MSIX, Android JDK17/21), [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41339910458) success. Nessun deploy o collaudo hardware. È un prerequisito per P2.3B (ricorrenze) e P2.3C (sottoscrizioni HTTPS); **non abilita ancora né fetch URL né RRULE**. Non richiede deployment Spring Boot, Flyway o Drift.

## Problema e modello

P2.2 memorizza `schema=1`, cinque calendari locali con `name` ed `events`; sostituzione e rimozione usano il nome. Questo impedisce di distinguere file e futuri feed con etichette simili e rende i nomi identificativi fragili.

P2.3A introduce il **formato JSON schema 2 nello stesso storage owner-scoped** `simple_notes.ics.v1.<sha256(owner)>`, senza modificare la chiave SharedPreferences: 

```json
{
  "schema": 2,
  "calendars": [
    {
      "id": "file-4d6c...",
      "kind": "file",
      "name": "personale.ics",
      "events": [{ "uid": "e1", "title": "Visita", "source": "personale.ics", "startDay": "2026-11-03", "endDay": "2026-11-04", "startUtc": null, "endUtc": null }]
    }
  ]
}
```

- `id`: identità stabile; per import nuovi viene generato UUID v4; per `schema=1` deriva in modo deterministico da SHA-256 del nome file con prefisso `file-`. L'identità **non** è l'UID dell'evento.
- `kind`: `file` o `url`. In questo incremento la UI crea **solo file**; `url` è metadato riservato e non viene mai scaricato né aggiornato.
- `name`: etichetta/display, mentre per i file correnti continua a rappresentare il filename di reimport. Due sorgenti di tipi diversi possono condividere il nome senza essere rimosse insieme.
- `sourceUrl`: presente soltanto per `kind=url`; il modello accetta esclusivamente URL HTTPS con host e senza credenziali nell'autorità o fragment. **Questa validazione non basta per permettere fetch**: P2.3C dovrà implementare protezioni SSRF, DNS/redirect, limite risposta, timeout e consenso esplicito.
- `events`: forma e vincoli P2.2 invariati; fino a 500 eventi per sorgente, massimo cinque sorgenti, UID evento e sorgente visualizzata mantenuti. Non sono task né dati sincronizzati.

## Migrazione sicura e sostituzioni

1. La lettura accetta solo `schema=1` e `schema=2`, validando completamente tutti i record. Versioni sconosciute, JSON malformato, ID duplicati, file omonimi, eventi inconsistenti o metadati URL invalidi bloccano la modifica **senza cancellare i dati**.
2. Il caricamento legacy **non scrive**: genera gli ID in memoria. Soltanto una successiva importazione/rimozione confermata salva l'intero archivio nel nuovo schema.
3. Reimport dello stesso filename `kind=file` mantiene il vecchio ID e sostituisce soltanto il calendario corrispondente.
4. La rimozione usa `removeById`; l'interfaccia rende gli ID come chiavi widget ma mostra il nome. Restano validi l'isolation owner, SharedPreferences, il parser fail-closed e la vista read-only.
5. Se l'account cambia durante file picker o conferma, l'operazione precedente non può scrivere nel nuovo owner. I client non cancellano/ripristinano automaticamente preferenze corrotte.
6. Rollback: il client P2.2 non conosce `schema=2` e deve rifiutare la lettura, **non** cancellare l'archivio. Prima di usare versioni precedenti, non riutilizzare la preferenza P2.3A con client P2.2. Non dichiarare compatibilità all'indietro di scrittura.

## Test richiesti

- schema 1 → lettura immutabile → schema 2 su scrittura esplicita, ID deterministici, dati ed eventi identici;
- schema 2 → round-trip, reimport e identità invariata, distinzione file/URL e rimozione per ID;
- rifiuto di schema 3, dati corrotti, ID duplicati, kind ignoto, URL HTTP/credential/fragment;
- regressione parser UTC/IANA/DST, limite cinque file, overlay locale in calendario;
- Flutter analyze/test e build Windows + Android su SHA finale; prova di picker/dispositivo reale resta al batch di rilascio.

## Limiti deliberati

P2.3A non offre rinomina etichette, import URL, fetch remoto, refresh, espansione RRULE, OAuth Google/Outlook, migrazioni PostgreSQL/Drift, nuovi endpoint, notifiche o sync eventi. URL e relativi query token (quando P2.3C sarà implementata) saranno dati sensibili locali: mai esporli in log o diagnostica e prevedere una policy esplicita per la loro cancellazione.

Collegamenti: [P2.2 ICS](P2-ICS.md) · [Stato corrente](CURRENT-STATUS.md) · [Roadmap](../project.md) · [Regole agenti](../AGENTS.md).

## Evoluzione schema 3 con P2.3B

La P2.3A schema 2 è compatibile in lettura con P2.3B; il nuovo schema 3 aggiunge `series` e salva solo a seguito di azione esplicita. Client P2.3A non leggono archivi schema 3: non fare downgrade non pianificati. [Specifiche](P2-ICS-RECURRENCE.md).

## Evoluzione P2.3C — URL feed

`kind=url` non è più soltanto metadato: la P2.3C candidata permette import/refresh HTTPS su richiesta. `lastFetchedUtc` opzionale nello schema 3, label solo hostname, token URI in query non visualizzato. Su errore restano le occorrenze cached. [Specifiche](P2-ICS-FEEDS.md).

