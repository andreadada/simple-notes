# Simple Notes — migrazione web (25/11/2026)

Primo incremento del porting da Flutter a webapp browser-only, design ispirato a Console DDone/Lark (senza codice privato o dati di Console nel repository pubblico). Non è ancora una sostituzione completa del client nativo.

## Architettura
- `apps/web`: HTML, CSS, moduli JS, Nginx. Nessun manifest, service worker, install prompt o PWA.
- Compose aggiunge il servizio web porta 80, proxy same-origin /api/v1/ verso api:8080. API e DB esistenti non modificati. Flyway nel codice resta V19; ultima VPS attestata V17.
- Google Identity Services usa WEB_GOOGLE_CLIENT_ID pubblico; deve essere un Web client ID incluso in GOOGLE_CLIENT_IDS. Token bearer in memoria, refresh durante sessione, accesso nuovamente richiesto dopo reload. Nessun secret nel frontend.
- Lettura delta paginata, versioni attese, UUID, tombstone e retry esplicito in sessionStorage per account/tab con operationId immutabile e confronto conflitto. Non usa CRUD legacy. Nessuna outbox offline duratura: sincronizzare tutti i client nativi prima di passare al web. Non cancellare vecchie installazioni/dati.
- Preferenze tema, viste multiple rinominabili e filtri per vista per account/browser; nessuna sync cloud delle preferenze web.

## Copertura iniziale
Dashboard, attività/liste, note e cestino con restore, griglia con titolo inline, filtri, ordinamento, raggruppamento, selezione e cancellazione confermata, galleria, Kanban per liste, calendario giorno/settimana/mese con ore pianificate e overlay ICS, matrice Eisenhower, ricerca task, CSV e snapshot JSON (non .snb), tema chiaro/scuro, menu contestuale, wiki con focus, layout mobile con navigazione schermata e overlay intercettante. Dashboard widget drag/resize desktop, reset e controllo tastiera, layout per browser. Editor di scadenze date-only e datetime IANA, priorità/tag/sottotask con checkbox e blocchi visuali; preserva campi moderni già presenti; ricorrenza civile e datetime con gap/fold DST. Ricerca globale, gestione ruoli e modifica online condivisa EDITOR. Pomodoro/abitudini/countdown locali. UI iniziale per inviti/snapshot condivisi, allegati opt-in, calendari esterni read-only, inbox server, editor strutturati dei cataloghi versionati, cinque modelli predefiniti/applicazione modelli personali, automazioni task opt-in su browser per creazione/completamento manuale e export JSON portabile.

## Mancanze / gate
Non dichiarare parità: timeline drag/resize e configurazioni avanzate, risoluzione conflitti con keep-local CAS e outbox duratura, scheduling server delle azioni e riconciliazione avanzata cataloghi, import/restore/backup cifrato, piena equivalenza ICS e provider senza CORS, presenza collaborativa, dashboard/viste personalizzate persistite lato server, funzioni native (tray/widget/sticky, notifiche OS) non portate. Il vecchio Flutter rimane per recupero dati e funzioni non portate. Il browser non è stato collaudato con account reali. CI web introdotta; esito da verificare sul commit effettivo. I nuovi test coprono anche ricorrenza DST e giorno IANA dei blocchi.

## Coolify
1. Prima del redeploy, backup e verifica secondo [OPERATIONS](OPERATIONS.md) e [RELEASE-V19-READINESS](RELEASE-V19-READINESS.md). Attenzione: V18/V19 verranno applicate se backend V17.
2. Conservare risorsa Compose esistente, base directory /, compose /docker-compose.yml, volume postgres_data, variabili API/DB. Non creare un secondo database e non usare down -v.
3. In Google Cloud creare/selezionare OAuth Web client; impostare origine JavaScript autorizzata https://notes.ddone.it (o dominio effettivo). Inserire WEB_GOOGLE_CLIENT_ID e aggiungerlo a GOOGLE_CLIENT_IDS mantenendo tutti i client già validi. Non serve un secret web per Google ID token.
4. Configurare dominio HTTPS del servizio web porta 80, mantenere api.notes.ddone.it su api:8080 durante transizione. DNS e domini da verificare nel pannello. Nessun cambio produzione eseguito qui.
5. Redeploy main, verificare web /healthz, API /actuator/health, gate V19, login reale, task/lista/nota e cestino, conflitto con due browser, visibilità cross-device, allegati/provider se configurati.
6. Se necessario ripristinare il routing/revision precedente senza downgrade DB distruttivo. Non eliminare Flutter o il volume DB.

## Test
`node --check apps/web/public/app.mjs`; `node --test apps/web/tests/*.test.mjs`; `docker compose config --quiet`; `docker compose build web`. CI include smoke container e smoke Chromium con OAuth/API sintetici. Non equivale al collaudo browser o VPS.

### Calendari ICS web
Import file e feed HTTPS diretto (richiede CORS, nessun redirect, 1 MiB, max 5 sorgenti). Sorgenti per browser/account, eventi read-only, ricorrenze DAILY/WEEKLY/MONTHLY/YEARLY con COUNT/UNTIL/BYDAY settimanale, RDATE/EXDATE e override. Rifiuto sintassi avanzata e limiti difensivi. Feed non sincronizzati; nessun proxy SSRF. Test unitari dedicati; non dichiarare parità completa con parser Flutter.
