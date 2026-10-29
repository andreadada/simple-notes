# P1.17 — Windows System Tray

**Stato 29/10/2026:** candidata nel branch `feature/p1-17-windows-tray`, Flutter `0.22.0+24`, Windows MSIX di sviluppo `0.22.0.0`. La P1.16 Responsive [PR #17](https://github.com/andreadada/simple-notes/pull/17) è integrata su `main` (Flutter `0.21.0+23`) con [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40761227373) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40761227307). CI/merge e test Windows reali P1.17 ancora da verificare. Nessun deploy/reset.

## Comportamento e implementazione

- Solo su **Windows**: al lancio del processo principale viene predisposta l'icona nella tray di sistema. Un click sinistro sulla tray riapre e porta in primo piano la finestra; click destro apre il menu **Apri Simple Notes** / **Esci da Simple Notes**.
- Se la tray è disponibile, la **X** della finestra principale e l'icona `Nascondi nell’area di notifica` nell'header nascondono la finestra **senza chiudere il processo**, preservando stato dei widget, sessione, database SQLite e normale sync/outbox. Esci è un'azione **esplicita** dal menu tray: disabilita l'intercettazione di chiusura, libera l'icona e chiude normalmente la finestra.
- Il processo principale è l'unico proprietario di `WindowsTray`. Le finestre separate Sticky P1.14 escono dal bootstrap **prima** di inizializzare la tray e non creano una seconda icona, DB, OAuth o AutoSync.
- La tray usa `tray_manager ^0.8.0` con API native attuali e `window_manager ^0.5.2`. L'icona PNG è incorporata nel codice, non caricata da un path assoluto che potrebbe cambiare fra ZIP/MSIX. Un import condizionale usa uno stub in Flutter Web e il controllo `Platform.isWindows` impedisce il lancio nativo su Android.
- **Fail-open**: se il plugin tray non viene inizializzato, l'app deve conservare la normale X che chiude la finestra. In caso di errore durante `hide()` il listener tenta la chiusura esplicita e non lascia l'utente bloccato in un'app invisibile.
- Non esiste una nuova preferenza, né una sessione dati duplicata, né una richiesta al backend per mostrare/nascondere. Le funzionalità Pomodoro/Habits/Countdown restano locali a singolo dispositivo e le note task esistenti conservano la propria sync.

## Limiti, rischi e test

- Non è implementato **avvio automatico con Windows**, singleton globale o recupero autonomo dopo chiusura forzata. La sessione resta attiva **solo mentre l'app è nascosta**, non dopo il comando Esci, spegnimento o crash.
- Non confondere il menu tray con le notifiche Windows P1.7: i promemoria Windows hanno il loro vincolo **MSIX/package identity**; una build ZIP non abilita toast di sistema.
- **Test automatizzati:** unit test sullo stato di close-to-tray in presenza o assenza di icona/platform, CI Flutter analyze/test + Windows EXE/MSIX + Android JDK17/JDK21. La CI **non può confermare l'icona, le azioni click o la persistenza del processo nascosto sul desktop fisico**.
- **Test Windows reali:** lanciare ZIP completo con DLL; verificare icona visibile, X → tray, click per riaprire, nuovo hide, menu Esci, nessuna tray orfana dopo exit/relaunch. Ripetere con finestra Sticky aperta e una nota modificata; verificare sync/outbox intatte.
- Test MSIX **solo** su profilo di prova con identity/publisher/firma stabili, conservando SQLite, secure storage e SharedPreferences. Android deve avviarsi e chiudersi normalmente, senza icone tray e senza side effect di plugin desktop.
- Prima del rilascio cumulativo verificare server Coolify reale Flyway **V10**/capability (`taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`); ultima attestazione utente Flyway **V8**. Nessun reset database, SQLite/outbox, profilo Google o volumi.

## Gate di rilascio

1. [ ] CI sull'ultimo SHA: Flutter analyze/test, Windows EXE/MSIX, Android JDK17+21, link Markdown verdi.
2. [ ] Test funzionale Windows ZIP/MSIX in ambiente di prova, incluse le azioni del menu, chiusura app e persistenza sessione quando nascosta.
3. [ ] Verifica assenza di seconda tray nelle Sticky Windows e regressione Android.
4. [ ] Convalida server-first e batch Windows↔Android con dati reali senza reinstallazioni/reset.

[Stato operativo](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [P1.16 Responsive](P1-RESPONSIVE.md) · [Roadmap](../project.md).
