# P1.17 — Windows System Tray

**Stato 29/10/2026:** P1.17 **integrata su `main`** con [PR #18](https://github.com/andreadada/simple-notes/pull/18) (merge `66927c7`), Flutter `0.22.0+24` e MSIX sviluppo `0.22.0.0`. [Flutter CI verde](https://github.com/andreadada/simple-notes/actions/runs/40797207231) per analyze/test, Windows EXE/MSIX e Android JDK17/JDK21; [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40797207130). Test reali Windows/Android, deploy e rilascio ancora aperti. Nessun reset.

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
- **Test automatizzati:** unit test sullo stato di close-to-tray in presenza o assenza di icona/platform, CI Flutter analyze/test + Windows EXE/MSIX + Android JDK17/JDK21. Il pacchetto tray_manager 0.8 usa nativeapi: il runner Linux della CI deve avere i pacchetti di sviluppo `libgtk-3-dev`, `libx11-dev` e `libxi-dev` **solo per compilare gli asset nativi dei test**, non perché l'app Android usi una tray. La CI **non può confermare l'icona, le azioni click o la persistenza del processo nascosto sul desktop fisico**.
- **Test Windows reali:** lanciare ZIP completo con DLL; verificare icona visibile, X → tray, click per riaprire, nuovo hide, menu Esci, nessuna tray orfana dopo exit/relaunch. Ripetere con finestra Sticky aperta e una nota modificata; verificare sync/outbox intatte.
- Test MSIX **solo** su profilo di prova con identity/publisher/firma stabili, conservando SQLite, secure storage e SharedPreferences. Android deve avviarsi e chiudersi normalmente, senza icone tray e senza side effect di plugin desktop.
- Prima del rilascio cumulativo verificare server Coolify reale Flyway **V10**/capability (`taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`); ultima attestazione utente Flyway **V8**. Nessun reset database, SQLite/outbox, profilo Google o volumi.

## Gate di rilascio

1. [x] CI verificata sullo SHA della PR #18: Flutter analyze/test, Windows EXE/MSIX, Android JDK17+21 e Markdown tutti verdi; merge su `main` confermato.
2. [ ] Test funzionale Windows ZIP/MSIX in ambiente di prova, incluse le azioni del menu, chiusura app e persistenza sessione quando nascosta.
3. [ ] Verifica assenza di seconda tray nelle Sticky Windows e regressione Android.
4. [ ] Convalida server-first e batch Windows↔Android con dati reali senza reinstallazioni/reset.

[Stato operativo](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [P1.16 Responsive](P1-RESPONSIVE.md) · [Roadmap](../project.md).
