# P2 — Collaborazione EDITOR, versione 17

**11 novembre 2026 — incremento backend in revisione.** [Matrice P2](P2-DELIVERY-MATRIX.md) · [Condivisione VIEWER](P2-LIST-SHARING.md) · [Readiness V17](RELEASE-V17-READINESS.md).

## Autorizzazioni e perimetro

L'account proprietario può promuovere un collaboratore già accettato da `VIEWER` a `EDITOR` o revocargli il diritto di modifica tornando a `VIEWER`. I token invito e i nuovi partecipanti restano **sempre VIEWER**: nessun codice condiviso concede modifica da solo.

Un membro EDITOR può modificare esclusivamente **titolo, descrizione, completamento e priorità** dei task esistenti nella lista condivisa, con JWT personale e versione ottimistica. Non può cancellare task, spostarli fra liste, creare note, modificare date/scadenze, time block, ricorrenze, tag o subtasks. I dati di altre liste restano privati.

## API JWT

| Endpoint | Uso |
|---|---|
| `PUT /api/v1/sharing/lists/{listId}/members/{memberId}/role` | Proprietario soltanto, body `{"role":"EDITOR"}` o `{"role":"VIEWER"}`; ritorna `{id,displayName,acceptedAt,role}` |
| `PATCH /api/v1/sharing/lists/{listId}/tasks/{taskId}` | EDITOR soltanto, modifica selettiva con `expectedVersion` obbligatoria. Ritorna `{version,changeId}` |
| `GET /api/v1/sharing/lists/{id}` | La risposta esistente presenta il ruolo aggiornato di ciascuna lista |
| `GET /api/v1/sharing/lists/{id}/snapshot` | `readOnly:false` solo per membri EDITOR, `readOnly:true` per VIEWER; include la versione del task |
| `GET /api/v1/sharing/lists/{id}/members` | Ora restituisce il ruolo per ciascun collaboratore |

Esempio patch con **una o più** modifiche consentite:

```json
{"expectedVersion":4,"title":"Nuovo titolo","completed":true}
```

`expectedVersion` deve provenire dall'ultima snapshot. Conflitto versioni o drift fra materializzazione e sync ledger → **409**; membro non autorizzato/lista eliminata/task di altra lista → **404** (non rivelare esistenza). Body senza modifiche, versioni negative, titolo vuoto, priorità fuori range o descrizione troppo lunga → **400**. Non applicare retry ciechi dopo 409: ricaricare snapshot e chiedere all'utente di confermare la nuova versione.

## Transazione, concorrenza e audit

1. Si risolve il proprietario soltanto da una membership EDITOR su lista attiva.
2. Si prende il **medesimo advisory lock owner** usato dalle operazioni `/sync/apply` e dalle promozioni/revoche, poi si riverifica la membership.
3. Si verifica che la riga task abbia owner/lista attivi e versione identica sia alla snapshot client sia al più recente `sync_change`. Se manca il ledger, la modifica viene rifiutata, mai riparata implicitamente.
4. Si compone una copia del **payload canonico completo** dall'ultimo ledger owner e si applicano **solo** i campi consentiti. Si passa da `SyncService.apply(owner, ...)` con version CAS: stesso percorso, versioning e `sync_change` del proprietario. Non si crea un ledger per l'account ospite.
5. Nello **stesso commit** si registra una riga in `list_share_audit` con owner, actor, lista, task, changeId e soli **nomi dei campi modificati**. Non si memorizzano titolo o descrizione nell'audit.
6. La promozione/revoca di ruolo registra un evento separato nella stessa tabella. Il proprietario conserva l'autorità; EDITOR non può promuovere altri membri.

La nuova Flyway **V17** amplia il vincolo `role IN ('VIEWER','EDITOR')` e crea il solo audit. Nessuna modifica ai proprietari, alle note, alle revisioni storiche o al cursor Flutter. `sharingEditorSchema:1` si aggiunge alle capability già previste dal server V16.

## Limiti ancora aperti

In questo incremento il client Flutter continua a usare la UI precedente finché la modifica EDITOR non viene integrata nel client. Il backend non implementa merge automatici multi-account, editing offline del collaboratore, websocket/push immediato, inviti destinatario-specifici o sincronizzazione dei contenuti condivisi nel Drift dell'ospite. È un protocollo online con CAS esplicito, audit e **refresh manuale** in caso di conflitto. La CI non certifica deploy reale, VPS, ruoli/utenti di produzione, test fisici, né restore live.
