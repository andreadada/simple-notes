# P2 — Google Calendar e Outlook con OAuth separato (Flyway V18)

**12 novembre 2026 · [PR #77](https://github.com/andreadada/simple-notes/pull/77) in revisione.** Collegamento autonomo dal normale Google login di Simple Notes, con eventi **in sola lettura**. Non è stato effettuato alcun nuovo deploy né un consenso reale; i provider sono disabilitati per impostazione predefinita.

## Esperienza nell'app

La schermata Calendario include **Calendari collegati**. Collega apre il browser di sistema; dopo il consenso è necessario tornare nell'app e scegliere **Aggiorna**. Scollega richiede conferma Forui, cancella il collegamento sul server e non tocca le attività. Eventi cloud proiettati solo **in memoria** accanto agli ICS, senza modificarli o inserirli in Drift, outbox, backup o preferenze.

La prima versione consulta solo il calendario principale Google e quello predefinito Outlook, in una finestra di 30 giorni centrata sul giorno visualizzato. Fino a 100 eventi per provider; la risposta server espone un flag di paginazione troncata. Non ci sono selezione multipla dei calendari, scritture verso il provider, sincronizzazione bidirezionale, background sync, cache offline o notifiche cloud.

## Sicurezza server

- Autorizzazione distinta: scope Google **calendar.events.readonly** con accesso offline; Microsoft Graph **Calendars.Read** e **offline_access**.
- JWT Simple Notes obbligatorio per avviare l'autorizzazione, leggere stato/eventi e scollegare. Callback HTTPS pubblica collegata unicamente a un state casuale di 256 bit, conservato come hash SHA-256 e **consumabile una sola volta** entro 10 minuti. PKCE S256 e verifier cifrato.
- I token OAuth del provider non sono mai restituiti al client. Access e refresh token sono cifrati in PostgreSQL con AES-256-GCM, nonce distinto e AAD account/provider/scopo. Chiave configurata in un segreto Coolify separato dalla chiave JWT dell'app.
- Il client non segue redirect con bearer JWT e apre soltanto URL OAuth HTTPS dei domini ufficiali Google/Microsoft; il backend non segue redirect dei provider. Limiti di timeout e dimensione delle risposte, massimo 31 giorni per richiesta.
- Il refresh è server-side e la scrittura del nuovo token è condizionale. La cancellazione del collegamento blocca nuove richieste da Simple Notes, anche se un amministratore disabilita poi il provider. **Non** revoca da remoto il consenso: l'utente deve eventualmente farlo anche dal proprio account Google/Microsoft.

## API

Tutte le rotte seguenti sono sotto il prefisso /api/v1.

| Metodo | Percorso | Effetto |
|---|---|---|
| GET | /calendars | Stato disponibile/collegato per ciascun provider; JWT |
| POST | /calendars/google/authorize o /calendars/microsoft/authorize | URL consenso + scadenza; JWT |
| GET | /calendars/oauth/google/callback o /calendars/oauth/microsoft/callback | Scambio codice con state monouso, senza JWT |
| GET | /calendars/{provider}/events?start=ISO&end=ISO | Eventi normalizzati con giorno intero o UTC; JWT |
| DELETE | /calendars/{provider} | Disconnessione locale server; JWT |

## Configurazione futura Coolify (non richiesta per Flyway V17)

I due provider restano OFF fino alla configurazione esplicita dei seguenti **segreti server**, da non salvare nel repository:

- APP_CALENDAR_PUBLIC_ORIGIN = https://api.notes.ddone.it
- APP_CALENDAR_TOKEN_KEY_BASE64 = chiave **dedicata** di 32 byte casuali (generare nell'ambiente amministrativo con openssl rand -base64 32; non riusare APP_JWT_SECRET_BASE64)
- APP_CALENDAR_GOOGLE_CLIENT_ID e APP_CALENDAR_GOOGLE_CLIENT_SECRET: nuovo client OAuth Web di Google Cloud, redirect registrato esattamente a https://api.notes.ddone.it/api/v1/calendars/oauth/google/callback. Consent screen con scope eventi in sola lettura.
- APP_CALENDAR_MICROSOFT_CLIENT_ID e APP_CALENDAR_MICROSOFT_CLIENT_SECRET: registrazione **Web** Microsoft Entra, con account personali/organizzativi abilitati se si usa tenant common; redirect esatto https://api.notes.ddone.it/api/v1/calendars/oauth/microsoft/callback, permessi delegated Calendars.Read.

Se manca una coppia completa di credenziali, il relativo provider resta non disponibile. **Non ruotare la chiave di cifratura senza una migrazione controllata:** i grant esistenti diverrebbero illeggibili. Il consenso per Google Calendar è indipendente da quello per il login Google già in produzione.

Il codice OAuth transita in query HTTPS nella callback; configurare access log Traefik e telemetry in modo da non salvare query string e header sensibili. Usare HTTPS, callback registrati immutabili e account di test. La modalità Google Calendar e quella Microsoft richiedono verifica reale dei consent screen e degli account prima dell'abilitazione pubblica.

## Limiti e test

Test backend simulano provider e PostgreSQL 17: separazione account JWT, state consumato una sola volta, scadenza, AES-GCM con AAD, conversione eventi e disconnessione. Test Flutter coprono URL OAuth e HTTP sicuro. Manca ancora collaudo con provider reali e dispositivi Windows/Android, verifica rate limits/scadenze tenant e selezione multi-calendario. **Non dichiarare la P2 completata con la sola PR #77.**

[Gate V18](RELEASE-V18-READINESS.md) · [Matrice P2](P2-DELIVERY-MATRIX.md) · [Stato](CURRENT-STATUS.md).