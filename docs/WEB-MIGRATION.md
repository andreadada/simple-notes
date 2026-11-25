# Simple Notes — migrazione web (25/11/2026)

Primo incremento del porting da Flutter a webapp browser-only, design ispirato a Console DDone/Lark (senza codice privato o dati di Console nel repository pubblico). Non è ancora una sostituzione completa del client nativo.

## Architettura
- `apps/web`: HTML, CSS, moduli JS, Nginx. Nessun manifest, service worker, install prompt o PWA.
- Compose aggiunge il servizio web porta 80, proxy same-origin /api/v1/ verso api:8080. API e DB esistenti non modificati. Flyway nel codice resta V19; ultima VPS attestata V17.
- Google Identity Services usa WEB_GOOGLE_CLIENT_ID pubblico; deve essere un Web client ID incluso in GOOGLE_CLIENT_IDS. Token bearer in memoria, refresh durante sessione, accesso nuovamente richiesto dopo reload. Nessun secret nel frontend.
- Lettura delta paginata, versioni attese, UUID, tombstone e retry in memoria con operationId immutabile. Non usa CRUD legacy. Nessuna outbox persistente/offline: sincronizzare tutti i client nativi prima di passare al web. Non cancellare vecchie installazioni/dati.
- Preferenze tema e vista per account/browser; nessuna sync cloud delle preferenze web.

## Copertura iniziale
Dashboard, attività/liste, note e cestino con restore, griglia con titolo inline, filtri, ordinamento, raggruppamento, selezione e cancellazione confermata, galleria, Kanban per liste, calendario mensile, matrice Eisenhower, ricerca task, CSV e snapshot JSON (non .snb), tema chiaro/scuro, menu contestuale, wiki, layout mobile. Editor di scadenze date-only, priorità/tag/sottotask e blocchi JSON; preserva campi moderni già presenti; ricorrenza date-only. Pomodoro/abitudini/countdown locali. UI iniziale per inviti/snapshot condivisi, allegati opt-in, calendari esterni read-only, inbox server e cataloghi JSON versionati.

## Mancanze / gate
Non dichiarare parità: completamento ricorrenze con orario/DST, editor visuale time-block e timeline, check di subtasks e configurazioni avanzate, conflitti UI con confronto e outbox duratura, automazioni eseguibili, modelli applicabili, import/restore/backup cifrato, ICS, collaborazione EDITOR e presenza, dashboard drag/resize, viste personalizzate multiple persistite lato server, ricerca globale e tutorial focus, funzioni native (tray/widget/sticky, notifiche OS) non portate. Il vecchio Flutter rimane per recupero dati e funzioni non portate. Il browser non è stato collaudato con account reali. CI web introdotta; esito da verificare sul commit effettivo.

## Coolify
1. Prima del redeploy, backup e verifica secondo [OPERATIONS](OPERATIONS.md) e [RELEASE-V19-READINESS](RELEASE-V19-READINESS.md). Attenzione: V18/V19 verranno applicate se backend V17.
2. Conservare risorsa Compose esistente, base directory /, compose /docker-compose.yml, volume postgres_data, variabili API/DB. Non creare un secondo database e non usare down -v.
3. In Google Cloud creare/selezionare OAuth Web client; impostare origine JavaScript autorizzata https://notes.ddone.it (o dominio effettivo). Inserire WEB_GOOGLE_CLIENT_ID e aggiungerlo a GOOGLE_CLIENT_IDS mantenendo tutti i client già validi. Non serve un secret web per Google ID token.
4. Configurare dominio HTTPS del servizio web porta 80, mantenere api.notes.ddone.it su api:8080 durante transizione. DNS e domini da verificare nel pannello. Nessun cambio produzione eseguito qui.
5. Redeploy main, verificare web /healthz, API /actuator/health, gate V19, login reale, task/lista/nota e cestino, conflitto con due browser, visibilità cross-device, allegati/provider se configurati.
6. Se necessario ripristinare il routing/revision precedente senza downgrade DB distruttivo. Non eliminare Flutter o il volume DB.

## Test
`node --check apps/web/public/app.mjs`; `node --test apps/web/tests/*.test.mjs`; `docker compose config --quiet`; `docker compose build web`. CI include smoke container. Non equivale al collaudo browser o VPS.
