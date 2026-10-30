# P1.18 — Aspetto chiaro/scuro/sistema (Windows e Android)

**Implementazione:** branch `feature/p1-18-theme-modes`, candidata Flutter `0.23.0+25`. Questa specifica descrive il codice; test CI e prova visiva su dispositivi devono essere registrati separatamente in [CURRENT-STATUS](CURRENT-STATUS.md).

## Comportamento

- Menu account (anche senza login): **Tema: Scuro, Chiaro, Sistema**, con check sull'opzione selezionata. Vecchie installazioni restano in **Scuro** per compatibilità.
- La preferenza è `simple_notes.theme_mode.v1` in `SharedPreferences`, **locale al dispositivo** e non legata all'account Google. Non passa da SQLite, backend, outbox o sincronizzazione.
- `ThemeMode.system` segue il tema del sistema operativo. Material e Forui condividono token chiaro/scuro da `notes_theme.dart`; i widget richiedono `NotesPalette.of(context)`, non costanti scure in nuovi schermi.
- Le sottolineature degli input restano aderenti ai glifi; focus blu, background trasparente e no modal di rinomina.
- Le finestre Sticky Windows caricano la preferenza separatamente, ma **non** aprono database o motori sync. Una Sticky già aperta può mantenere il tema precedente fino a riapertura. In caso di errore plugin di preferenze resta scura, non cancella dati.

## Compatibilità e assenza di effetti dati

- Nessuna migration Flyway/Drift e nessun cambio API, identità MSIX o dati utente. Nessun salvataggio tema in cloud.
- L'eventuale scrittura fallita della preferenza mantiene il tema precedente. Un valore sconosciuto/mancante torna a Scuro.
- Nessun deploy backend necessario per questa feature isolata. Restano i gate cumulativi server-first V10 prima del rilascio delle feature sincronizzate.

## Test e collaudo

1. Unit test encode/decode, default legacy e persistenza/mock di `SharedPreferences`.
2. Widget test Material + Forui con palette coerenti in entrambi i temi; scope del controllo.
3. CI: `flutter analyze`, `flutter test`, Android debug JDK17/21, Windows EXE/MSIX, link Markdown sullo **SHA finale**.
4. In batch finale: Windows/Android, scuro/chiaro/sistema, rientro da app chiusa, account diverso, screenshot leggibilità/contrasto, input underline, Forui modal/menu, Sticky nuova vs già aperta, resize, nessun cambiamento SQLite/outbox.
5. Non installare MSIX di sviluppo su dati reali né eseguire reset/deploy automatici.

[Roadmap](../project.md) · [Guida](OPERATIONS.md) · [Design](../design.md).
