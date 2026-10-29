# P1.16 — Layout responsive Windows e Android

> **Stato operativo 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).

**Stato 28/10/2026:** **integrata su `main` con PR #17**, Flutter `0.21.0+23`, [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40761227373) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40761227307). P1.15 Keyboard shortcuts è integrata su `main` tramite [PR #16](https://github.com/andreadada/simple-notes/pull/16), Flutter `0.20.0+22`, CI Flutter/Markdown verde. La P1.16 ha superato CI e merge; il collaudo visivo hardware resta aperto. Nessun deploy Coolify o reset.

## Modifiche reali

- **Note in layout fluido**, mantenendo gli stessi ID, titolo e corpo editabili inline e la stessa sincronizzazione tramite LocalStore/outbox. Una griglia `Wrap` dispone le card secondo lo spazio effettivamente disponibile, con altezza libera (senza tagliare note lunghe): **1 colonna** con meno di 700 logical px di contenuto, **2** da 700 a 1119, **3** da 1120 in poi.
- `NotesResponsivePolicy` centralizza i gate esistenti per la sidebar (**950 px viewport**) e i dettagli task laterali (**1200 px viewport**); le dimensioni di ogni card dipendono dalla larghezza **residua dopo** sidebar/padding, non dal device type o da orientamento fittizio.
- Il comando nuova nota, il pop-out Sticky Windows e le azioni elimina restano invariati e accessibili; le card passano tra 1/2/3 colonne senza riscrivere dati, senza ricreare identità o svuotare input.
- La vista attività mantiene input e selettore data su viewport piccoli; **sotto 400 px** il filtro priorità mostra l'etichetta compatta `Tutte` o `P1/P2/P3` per prevenire overflow, senza cambiare i valori del filtro. Le note mantengono altezza **intrinseca**: non usare `GridView` a `childAspectRatio` fisso perché potrebbe ritagliare contenuti.
- Unit test a soglie, 0px/width safe, formule di larghezza. Widget test su viewport **320, 390, 1110 e 1600 logical px**, tre note e controllo overflow.

## Non incluso

- Non aggiunge tray, temi chiaro/scuro o salvataggio delle dimensioni finestra; rimangono milestone future.
- Non modifica API, dati Google, PostgreSQL, Flyway, schema Drift, sync cursor o outbox.
- Non trasforma Pomodoro/Habits/Countdown in entità sincronizzate: restano locali per account e dispositivo.
- Non implica che la build sia già installata sul PC o sul telefono. CI compile/test e collaudo fisico sono gate distinti.

## Gate della release

1. [ ] CI sullo SHA finale: `flutter analyze`, `flutter test`, APK Android JDK 17/21, Windows EXE/MSIX, controllo link Markdown.
2. [ ] Test su Windows: finestra stretta/larga, sidebar mobile/desktop, 3 note con titoli molto lunghi e corpo multilinea, rinomina inline, pop-out sticky, pressione `Ctrl+1..5` senza perdere focus.
3. [ ] Test Android: 320/390 px, landscape, note con testo lungo, tastiera software e vista task/quick due; verificare nessun overflow o clipping.
4. [ ] Verifica integrità: le note persistono e si sincronizzano come prima, senza riscritture durante il resize.
5. [ ] Prima della distribuzione cumulativa, verificare realmente Flyway V10/capability sulla VPS Coolify (ultima attestazione nota V8). Per ZIP→MSIX testare su profilo di prova preservando SQLite, secure storage, SharedPreferences e account. Nessun reset/deploy automatico.

[Stato canonico](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Roadmap](../project.md) · [Design](../design.md) · [P1.15 Keyboard](P1-DESKTOP-SHORTCUTS.md).
