# P1.7 — Promemoria, fase fondativa

**Stato:** branch `feature/p1-7-reminders-foundation` **dipendente da P1.6**. Nessuna notifica è ancora programmata o mostrata dal sistema operativo; codice di pianificazione puro e test. Non integrare su `main` prima della PR P1.6. **Nessun deploy eseguito.**

## Implementato nel codice

- `apps/flutter/lib/ui/reminder_planner.dart`: proiezione deterministica di `TaskDue.datetime` e `TimeSlot.start` in un futuro istante UTC; opzioni 0/5/15/30/60/1440 minuti prima.
- Date-only senza ora **non** generano una notifica a mezzanotte, né vengono convertite silenziosamente; servirebbe scelta esplicita dell'orario.
- Identità della notifica = `ownerId|taskId|due|UTC occurrence|leadMinutes` oppure `ownerId|taskId|block:slotId|UTC occurrence|leadMinutes`; ID numerico stabile FNV-1a 31bit. Ciò prepara la **deduplica per occorrenza** e il cancel/reschedule quando mutano scadenze, slot, account o ricorrenza.
- Solo attività non completate e notifiche future; l'algoritmo limita orizzonte a 14 giorni e massimo 100 richieste per dispositivo, con limiti configurabili per i futuri scheduler nativi.
- Il planner opera solo in memoria e non contatta il server né SQLite né chiede permessi OS. Non afferma consegna se il desktop è spento e non crea notifiche su altri account.
- Unit test per time zone, scadenza date-only, promemoria passati, chiavi distinte su multi-block, ricorrenze e horizon.

## Da implementare prima di dichiarare P1.7 operativa

1. **UI Forui:** consenso esplicito alle notifiche, selezione tipo/scadenza/blocco, anticipi e snooze; nessuna richiesta di permessi all'avvio senza scelta.
2. **Persistenza/configurazione:** definire la semantica device-local vs sincronizzata delle preferenze, con migrazioni additive solo se necessarie; mai perdere pending outbox.
3. **Android:** scheduling nativo con autorizzazioni di notifica Android 13+, ricezione reboot, exact alarm se indispensabile (preferire inexact dove accettabile), fallback se OEM limita i background alarm. Non pianificare il singolo reminder con poll foreground come soluzione di produzione.
4. **Windows:** supporto toast con package identity / MSIX per garantire cancellazione/aggiornamento di notifiche già programmate. L'EXE Windows ZIP non confezionato attualmente non offre garanzia di cancel; prima confezionare o progettare un adapter Windows separato con ledger persistente e modalità degradante trasparente.
5. **Scheduler reconciliation:** ledger locale `key → notificationId, fireAt`; diff del desired schedule con l'effettivo e annullamento dei vecchi ID quando cambia un task, blocco, account o ricorrenza, includendo reboot e reinstallazione.
6. **Privacy:** contenuto notifiche minimo se schermo bloccato, opzione per nascondere titolo, non loggare token OAuth, identificatori Google o dati personali.
7. **Test e accettazione:** Windows app chiusa/riavvio macchina, Android permessi negati/consentiti, DST, due date-only, cambio account, modifica offline→online, deduplica, tap-to-open e assenza di notifiche spurie.

## Scelta librerie da verificare

`flutter_local_notifications` pubblica il supporto Windows (WinRT toast) e Android; tuttavia, **Windows** richiede package identity per cancellazione/recupero affidabile dei toast precedenti, e la ripetizione OS con `periodicallyShow` non è supportata su Windows. Le ricorrenze devono quindi essere espanse e pianificate come singole occorrenze versionate. Riferimenti: [documentazione plugin](https://pub.dev/documentation/flutter_local_notifications/latest/) e [Windows implementation](https://pub.dev/packages/flutter_local_notifications_windows). Non aggiungere a `pubspec.yaml` una dipendenza senza testarla sulle versioni Flutter reali Windows/Android e senza correggere manifest/Gradle/package identity.

## Gate

- PR #5 P1.6: CI verde e merge in `main` prima di integrare P1.7.
- Branch P1.7: solo **foundation**; i suoi test verificano la correttezza del piano, non il comportamento OS.
- Deploy backend successivo come batch soltanto dopo l'intero ciclo P1.7, non adesso.

**Da non dichiarare:** «notifiche funzionano su Android e Windows», «il telefono notifica a schermo spento», «promemoria sincronizzati», «snooze disponibile», fino alla verifica nativa reale.
