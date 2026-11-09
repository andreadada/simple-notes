# P2 — Calendari ICS, modelli utente e widget Android

Aggiornato 9 novembre 2026. Ambito: client Flutter/Android e backup locale. **Nessuna nuova API, migrazione o deploy.**

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

## Widget Android

Aggiunto un AppWidgetProvider nella galleria launcher con «Oggi», «Inbox», «+ Attività» e PendingIntent immutabili. Il widget non espone titoli, note, task count, account o altri dati personali. Non ha bisogno di leggere lo storage dell'utente o di lavorare in background.

I pulsanti inviano soltanto le azioni consentite today, inbox e new a MainActivity e al canale Flutter. Navigano o focalizzano l'input; non creano task e non effettuano sync, OAuth o restore. Il gate di avvio fail-closed del recovery rimane precedente al bootstrap e non viene aggirato dall'intent.

## Gate residui

- Verifica fisica dei widget sul launcher, cold-start, aggiornamento e logout; Android CI verifica build, non gesture reali.
- Compatibilità di import ICS con Google Calendar/Outlook su app reali, senza autenticazioni provider.
- Sync fra dispositivi delle definizioni dei modelli richiederebbe un contratto API dedicato.
- Restore live, provider OAuth, liste condivise/ACL, allegati S3 e automazioni configurabili non sono conclusi.

Test dedicati: portable_task_calendar_test.dart, user_task_templates_test.dart, user_template_backup_test.dart, android_widget_navigation_test.dart. CI e merge si registrano dopo la verifica.
