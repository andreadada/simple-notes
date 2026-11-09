# P2 — Trasferimento manuale dei modelli personali

**9 novembre 2026 — incremento client in sviluppo. CI e merge da verificare.** Le definizioni personali nella pagina **Modelli** sono locali per account/dispositivo e incluse nel backup cifrato .snb. Questo incremento aggiunge un trasferimento volontario e non distruttivo via JSON, senza cloud o migrazioni.

## Windows e Android

- **Esporta modelli:** salva il catalogo personale corrente in un file JSON su Windows oppure usa la condivisione di Android. Non comprende i cinque preset, task esistenti, account, token, UUID dei task, outbox o cursore.
- **Importa modelli:** selezione file, validazione stretta UTF-8/formato/schema/modelli, controllo della capienza e conferma Forui del numero di modelli. Soltanto dopo la conferma viene salvato l'intero catalogo sul dispositivo per l'owner attivo.
- Ogni definizione importata riceve un **nuovo ID** e viene aggiunta senza sovrascrivere o cancellare modelli già presenti. Massimo 50 modelli personali. Un errore, file non valido, annullamento, cambio account, capienza esaurita o file vuoto non scrive alcun dato.
- JSON **non cifrato**: contiene potenzialmente titoli, descrizioni, tag e checklist privati. Usare soltanto destinazioni affidabili; il backup .snb con password rimane distinto e non è ripristinabile con questa importazione.
- L'importazione di definizioni non crea task né operazioni outbox. Solo usare successivamente un modello crea un normale task locale da sincronizzare.

## Formato e verifica

`PortableTemplateArchive` usa `format=simple-notes-custom-templates`, `schema=1`, campo `library` che contiene lo schema validato `UserTaskTemplateLibrary`; dimensione massima 128 KiB. Le chiavi radice inattese, gli schemi futuri e le definizioni non valide vengono rifiutati senza correzioni silenziose.

`test/portable_template_archive_test.dart` copre roundtrip, copie ID, UTF-8 malformato, schema e campi extra, limite dimensione, quota e libreria vuota. Le verifiche automatiche **non** provano picker e condivisione su hardware né un trasferimento reale fra Windows e Android: rimangono rinviati al batch finale.

Nessun deploy Coolify, nuovo permesso OAuth, sync dei modelli, restore live o migrazione Drift/Flyway. P2 complessiva ancora aperta: [matrice](P2-DELIVERY-MATRIX.md) · [stato](CURRENT-STATUS.md).
