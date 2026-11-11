# P2 — Readiness Flyway V17, collaboration EDITOR

**11/11/2026.** Il repository introduce **V17** (audit e ruolo EDITOR). La VPS è attestata a **Flyway V10 al 03/11**; nessuna migrazione o promozione di membri è stata eseguita in produzione.

## Gate post-deploy strettamente read-only

Soltanto dopo deploy **esplicitamente autorizzato**, backup coerente, verifica checksum e restore isolato, identificare il container PostgreSQL corrente. Mantenere il JWT temporaneo esclusivamente nella shell locale e non incollarlo in chat o nei log.

```bash
cd ~/simple-notes
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<DB_ATTUALE_VERIFICATO>' \
EXPECTED_POSTGRES_DB=simplenotes \
API_BASE_URL=https://api.notes.ddone.it \
  bash infra/release-v17-readiness.sh
```

Il gate legge, senza scrivere, PostgreSQL 17, **esattamente Flyway V17**, le dieci colonne dell'audit, il vincolo EDITOR e capability JWT `sharingReadSchema:1` / `sharingEditorSchema:1`. Non promuove membri, non crea task, non invia patch e non certifica che l'outbox e le notifiche funzionino.

Test successivi, soltanto su account e liste fittizie: promozione esplicita, revoca, VIEWER incapace di scrivere, conflitto 409, aggiornamento task sincronizzato nell'account proprietario, audit attore e zero contenuti privati nello storico, separazione dalle note e dalle altre liste. Non utilizzare dati reali o fare migrazioni solo per far passare il gate.

[Contratto EDITOR](P2-LIST-EDITOR.md) · [Stato canonico](CURRENT-STATUS.md) · [Criteri dispositivo](DEVICE-ACCEPTANCE-DEFERRED.md).
