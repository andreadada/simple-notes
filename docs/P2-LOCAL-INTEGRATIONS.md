# P2 — Calendari ICS, modelli utente e widget Android

Aggiornato 9 novembre 2026. Ambito: client Flutter/Android e backup locale. **Nessuna nuova API, migrazione o deploy.**

**Incremento successivo integrato:** [PR #58](https://github.com/andreadada/simple-notes/pull/58) (merge `e926a5a`) permette export/import JSON manuale dei modelli personali; definizioni locali, non cifrate e non sincronizzate. [Dettagli](P2-TEMPLATE-TRANSFER.md).

**Integrato su `main`:** [PR #57](https://github.com/andreadada/simple-notes/pull/57), merge `90e5e26a`. [Flutter CI #42634429343](https://github.com/andreadada/simple-notes/actions/runs/42634429343) PASS (365 test, Android 17/21, Windows), [Markdown #42634428206](https://github.com/andreadada/simple-notes/actions/runs/42634428206) PASS. Test fisici e provider OAuth rimangono fuori scope.

## Esportazione calendari ICS

Nel menu account, «Esporta calendario ICS» produce un file importabile manualmente in Google Calendar, Outlook e altre app. Le informazioni provengono dallo snapshot SQLite: vengono inclusi soltanto task incompleti con scadenze o blocchi orari. Le note, password, identità Google, token e code sync non sono esportati.

- Le scadenze date-only producono un evento di un giorno, con DTSTART;VALUE=DATE e DTEND;VALUE=DATE sul giorno civile successivo; non si inventa la mezzanotte UTC.
- Le scadenze datetime e legacy producono eventi istantanei UTC, senza una durata fittizia.
- I blocchi orari diventano eventi separati, con inizio e fine UTC esatti.
- Gli UID sono stabili e ottenuti mediante SHA-256 di task e blocco; SUMMARY è escapato e i contenuti sono ripiegati a non più di 75 byte UTF-8 per riga, CRLF, massimo 10.000 eventi / 8 MiB.
- È un'**esportazione unidirezionale** e manuale: nessun OAuth, refresh automatico o modifica del calendario remoto. Il file ICS non è cifrato; contiene titoli che possono essere privati.

Le ricorrenze non vengono espanse in una serie infinita di occorrenze; si esportano solo le scadenze e i blocchi realmente presenti.

## Modelli personalizzati

La sezione Modelli permette di creare, modificare ed eliminare modelli con titolo, descrizione, tag e checklist, oltre ai cinque modelli predefiniti. Le definizioni sono locali al dispositivo e **separate per account**; SharedPreferences usa una chiave derivata dal digest SHA-256 dell'owner. I task creati sono normali entità SQLite con nuovi UUID e un'operazione outbox persistente. Modificare o eliminare il modello non tocca i task precedenti.

Il catalogo ha uno schema locale v1, massimo 50 modelli, 50 sottotask per modello e validazioni di lunghezze, tag e unicità. Se un archivio è corrotto, la UI lo blocca senza resettarlo. I backup cifrati .snb includono la nuova preferenza opzionale templates, ma i vecchi backup v1 con le cinque preferenze storiche restano leggibili. Non cambiano schema SQLite V8 né envelope AES-GCM.

Le definizioni **non si sincronizzano fra dispositivi**: sono locali, ma incluse nei nuovi backup cifrati. Il restore live .snb resta disabilitato.

Per l'import/export manuale delle definizioni locali, vedere [trasferimento modelli](P2-TEMPLATE-TRANSFER.md). Il JSON non è cifrato e non sincronizza fra dispositivi.

## Widget Android

Aggiunto un AppWidgetProvider nella galleria launcher con «Oggi», «Inbox», «+ Attività» e PendingIntent immutabili. Il widget non espone titoli, note, task count, account o altri dati personali. Non ha bisogno di leggere lo storage dell'utente o di lavorare in background.

I pulsanti inviano soltanto le azioni consentite today, inbox e new a MainActivity e al canale Flutter. Navigano o focalizzano l'input; non creano task e non effettuano sync, OAuth o restore. Il gate di avvio fail-closed del recovery rimane precedente al bootstrap e non viene aggirato dall'intent.

## Gate residui

- Verifica fisica dei widget sul launcher, cold-start, aggiornamento e logout; Android CI verifica build, non gesture reali.
- Compatibilità di import ICS con Google Calendar/Outlook su app reali, senza autenticazioni provider.
- Sync fra dispositivi delle definizioni dei modelli richiederebbe un contratto API dedicato.
- Restore live, provider OAuth, liste condivise/ACL, allegati S3 e automazioni configurabili non sono conclusi.

Test dedicati: portable_task_calendar_test.dart, user_task_templates_test.dart, user_template_backup_test.dart, android_widget_navigation_test.dart. CI e merge si registrano dopo la verifica.

## Estensione successiva in PR #63 — trasferimento cloud modelli

Le descrizioni storiche PR #57/#58 rimangono valide per JSON manuale e storage locale. La PR #63 aggiunge **un'opzione manuale** Pubblica/Scarica tramite cloud V13/CAS, non sincronizzazione automatica. [Contratto](P2-CLOUD-TEMPLATES.md).

## Estensione P2 in verifica — allegati note cloud S3 (PR #64)

Oltre a ICS, modelli e widget locali, la PR #64 introduce allegati per note **solo online**, isolati per owner, con storage S3 e nuova tabella Flyway V14: non esiste una coda file offline e i backup .snb non coprono i file. [Specifica](P2-NOTE-ATTACHMENTS.md).
