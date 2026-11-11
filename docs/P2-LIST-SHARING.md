# P2 — Condivisione delle liste, prima fase in sola lettura (Flyway V16)

**11 novembre 2026 — incremento in revisione.** [Stato canonico](CURRENT-STATUS.md) · [Matrice P2](P2-DELIVERY-MATRIX.md) · [Readiness V16](RELEASE-V16-READINESS.md).

## Obiettivo e perimetro

Una lista di attività già sincronizzata può essere condivisa con un'altra persona autenticata, ma solo dopo consenso esplicito. Questa è una **fondazione backend**, non ancora la collaborazione completa della P2: non contiene UI Flutter di invito/accettazione, email automatiche, editing multiutente, notifiche push o condivisione di note.

Ogni lista conserva **un unico proprietario**. Il proprietario può creare e revocare inviti, vedere e rimuovere collaboratori; il destinatario può accettare una chiave una volta, leggere le liste ricevute e abbandonarle. Ruolo unico **VIEWER** (sola lettura): il futuro EDITOR richiederà nuove autorizzazioni, gestione di conflitti e protocollo di sync. **Non** è supportata una modifica di task dal dispositivo del collaboratore.

## Inviti: token sicuri e consenso

- `POST /api/v1/sharing/lists/{listId}/invitations` solo proprietario: **201** `{id,token,expiresAt}`. `token` è segreto **solo nella risposta iniziale**: 32 byte da SecureRandom codificati base64url. Nel database viene salvato **solo SHA-256**. Non inoltrare il token in query string, email non cifrata generata dal backend, log o screenshot.
- `GET /api/v1/sharing/lists/{listId}/invitations` solo proprietario: ID, creazione e scadenza degli inviti ancora utilizzabili; **mai** il token originale.
- `DELETE /api/v1/sharing/lists/{listId}/invitations/{id}`: revoca prima dell'utilizzo, HTTP 204.
- `POST /api/v1/sharing/invitations/accept` con JWT del destinatario e JSON `{"token":"..."}`: accetta una sola volta, crea membership VIEWER, **mai** auto-accettazione del proprietario. Il link/token non è associato in anticipo a un'email: chiunque ne sia legittimamente in possesso e abbia un account può accettarlo; non è un invito riservato a un indirizzo specifico.
- TTL invito **7 giorni**; massimo **5 inviti attivi** per lista e **20 membri** per lista. Accettazione con `SELECT ... FOR UPDATE` sull'invito e sulla lista per serializzare il consumo e la capacità. Token sconosciuto 404, scaduto/revocato/usato 409, formato non valido 400.
- Nessun inoltro automatico tramite email. L'eventuale UI Flutter dovrà fornire una modalità per copiare un invito e una finestra per inserire il token (senza URL GET e senza renderlo in analytics).

## Lettura con ACL

Tutte le route richiedono il **JWT applicativo**; nessun permesso viene dedotto dal possesso del token dopo l'accettazione.

| Endpoint | Permessi ed effetto |
|---|---|
| `GET /api/v1/sharing/lists` | Liste ricevute dal collaboratore, soltanto se ancora attive |
| `GET /api/v1/sharing/lists/{listId}/snapshot?offset=0` | Soltanto membro VIEWER accettato: `{listId,title,readOnly:true,tasks,nextOffset}`, max **50 task** per pagina e offset 0–10000 |
| `GET /api/v1/sharing/lists/{listId}/members` | Solo proprietario; ID, display name e data accettazione |
| `DELETE /api/v1/sharing/lists/{listId}/members/{memberId}` | Solo proprietario: revoca immediata per richieste successive |
| `DELETE /api/v1/sharing/lists/{listId}/membership` | Il collaboratore lascia una lista ricevuta |

Il filtro di ogni snapshot usa **sia owner_id sia list_id**, e scarta task soft-deleted. Non include note, liste private del proprietario, outbox, refresh tokens, account email o storici `sync_change`. Un non-membro riceve **404**, non un errore che esponga il nome della lista. La rimozione di una membership non deve riscrivere il task del proprietario; una lista messa nel cestino non è leggibile.

## Persistenza e compatibilità

`V16__list_sharing_read_only.sql` crea `list_share_invitation` e `list_share_member` senza modificare i dati storici, i proprietari dei task o gli indici della sincronizzazione. Le membership sono lato server, con ruolo `VIEWER` esplicito; nessun record degli inviti viene inserito in `sync_change` o `sync_operation`. `GET /api/v1/capabilities` annuncia `sharingReadSchema:1`; il [gate V16](RELEASE-V16-READINESS.md) lo verifica insieme alle tabelle **soltanto dopo un eventuale deploy autorizzato**.

## Test e aspetti non conclusi

Backend PostgreSQL 17 Testcontainers: JWT necessario, owner-only, token non salvato in chiaro, una sola accettazione, scadenza/revoca, limiti, isolamento fra liste, snapshot paginato, separazione dal normale `/sync`, eliminazione membership. Rehearsal migrazione V6→V16 senza perdita dei record precedenti. Il successo CI **non prova** UI Windows/Android, inoltro token, compatibilità API della VPS, attacchi di rate limiting, inviti phishing e concorrenza live.

Rimangono per P2: UI Forui e passaggio token, eventuali inviti legati a destinatario, ruolo editor, condivisione write-through con consenso/versioni e sync multi-account, alert/reminder condivisi, protezione anti-abuso e collaudo su dispositivi reali.

## Client Flutter/Forui — incremento successivo in revisione

La sezione **STRUMENTI → Condivise** su Windows/Android rende accessibile la fase VIEWER: codice da incollare in input Forui, token visualizzato solo dopo creazione, comando Copia esplicito, elenco liste ricevute, anteprima task paginata in sola lettura, revoca di inviti/collaboratori e uscita. La UI controlla `boundOwnerId` e l'account Google prima e dopo le richieste, non usa redirects HTTP e non trasferisce alcuna risposta al database locale o all'outbox. A server V10 non disponibile mostra errore esplicito senza alterare il profilo. Il codice è **in revisione**, non va dichiarato rilasciato prima di CI e deploy.
