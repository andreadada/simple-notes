# P2.3B — Ricorrenze ICS locali e proiezione a richiesta

**Stato:** implementazione candidata sul branch `feature/p2-3b-ics-recurrence` (1 novembre 2026), Flutter `0.27.0+29`. Non attestare merge, CI o test real-device finché non confermati. Nessun endpoint, modifica Flyway, Drift, outbox o deploy Coolify.

## Modello e compatibilità dati

- File ICS esterno resta **read-only**, isolato per proprietario in SharedPreferences. Nessun evento diventa task o crea mutazioni remote.
- `IcsCalendar.series` memorizza master `VEVENT`, regola `RRULE` (se presente), `RDATE`, `EXDATE`, cancellazioni e override identificati dal valore originale `RECURRENCE-ID`.
- Il JSON persistito evolve a **schema 3** nella **stessa chiave** owner-scoped `simple_notes.ics.v1.<sha256(owner)>`. La lettura accetta schema 1/2/3; la lettura **non scrive**. Import/reimport/rimozione confermata serializza lo schema 3, senza modificare gli altri file.
- I client P2.2/P2.3A non leggono schema 3: **non effettuare downgrade** del client senza una strategia di conservazione o conversione esplicita. Non cancellare l'archivio in caso di versione sconosciuta.
- Le ricorrenze non vengono espanse nell'archivio. `IcsLibrary.onDay` combina eventi semplici e occorrenze generate **solo per il giorno civile visibile**, con fine esclusiva; l'interfaccia Forui e i controlli di import restano quelli della P2.2/P2.3A.

## Sottoinsieme RFC 5545 supportato

| Proprietà | Comportamento |
|---|---|
| `RRULE:FREQ=DAILY/WEEKLY/MONTHLY/YEARLY` | Supporto a intervallo intero 1–100, ancorato a `DTSTART` |
| `COUNT` | 1–500 occorrenze valide (include `DTSTART`; date impossibili e orari DST inesistenti non consumano un'occorrenza) |
| `UNTIL` | Limite incluso, `DATE` per eventi all-day, UTC per eventi timed; non combinabile con `COUNT` |
| `BYDAY` | Elenco MO–SU solo con `FREQ=WEEKLY`; richiede `DTSTART` coerente; nessun indice tipo `-1MO` |
| `RDATE` | Date aggiuntive dello stesso tipo dell'evento, senza duplicazioni; singole date/istanti, non `PERIOD` |
| `EXDATE` | Esclusione delle occorrenze, prevale sui valori inclusi da `DTSTART`/`RRULE`/`RDATE` |
| `RECURRENCE-ID` | `VEVENT` con stesso UID per spostamento/modifica di una singola occorrenza; `STATUS:CANCELLED` per sopprimerla |

**Timezone:** date-only restano giorni civili. Gli eventi UTC restano UTC, quelli con `TZID` IANA mantengono l'orario civile originario nelle occorrenze future. Nel passaggio all'ora legale gli orari inesistenti sono omessi; nelle ore ripetute viene scelta la prima occorrenza valida. Vengono conservati gli istanti originali per collegare gli override.

## Vincoli fail-closed

- File massimo 1 MiB, 500 `VEVENT` per sorgente, massimo 5 calendari.
- Una singola ricorrenza può durare massimo 7 giorni, max 100 date esplicite per categoria di eccezioni; `COUNT` e gli intervalli di ricerca hanno limiti difensivi.
- Rifiutare con `FormatException` e non salvare né un sottoinsieme parziale se compaiono `FREQ` unsupported, `BYMONTH`, `BYSETPOS`, `BYHOUR`, `BYMINUTE`, `BYSECOND`, `BYDAY` posizionali, `RANGE=THISANDFUTURE`, `DURATION`, `RDATE;VALUE=PERIOD`, RRULE multiple, componenti/UID contraddittori o date impossibili.
- Supporto a IANA TZID conosciuti dal database di timezone dell'app, non all'interpretazione arbitraria di componenti VTIMEZONE custom o orari floating.
- Qualsiasi errore di parsing/validazione o conferma annullata lascia intatto l'archivio preesistente; la UI non deve cancellarlo automaticamente.

## Test e gate

1. Proiezione giornaliera all-day, fine esclusiva, regole DAILY/WEEKLY con `BYDAY`, MONTHLY/YEARLY e giorni inesistenti.
2. `COUNT`/`UNTIL` inclusivi, `RDATE`/ `EXDATE` e precedenza delle eccezioni, spostamenti e cancellazioni `RECURRENCE-ID`.
3. IANA Europe/Rome inverno/estate, DST gap/fold, persistenza `schema 3`, lettura di schema 1/2 preesistenti, owner isolation, no outbox.
4. Flutter analyze/test, build Windows EXE+MSIX e Android JDK17+21, Markdown CI. Verifica manuale Windows/Android al batch finale, senza deploy per questa feature.

## Seguito

**P2.3C:** feed HTTPS, refresh esplicito e cache last-known-good con controlli su DNS/redirect/SSRF. Funzioni RRULE avanzate e semantiche complesse VTIMEZONE sono lavoro dedicato, non devono essere presentate come supporto iCalendar universale.

Collegamenti: [P2.3A](P2-ICS-SOURCES.md) · [P2.2](P2-ICS.md) · [Stato](CURRENT-STATUS.md) · [Roadmap](../project.md) · [AGENTS](../AGENTS.md).
