# T4.2 — Verifica reale della sincronizzazione Windows ↔ Android

**Stato:** strumenti diagnostici implementati nel client Flutter. Prova fisica **non ancora eseguita** da questa chat.

## Evidenze già raccolte dall'utente (24 ottobre 2026)

- Container PostgreSQL di Simple Notes identificato come `db-gs0yzfz42hpriybaxcfbtjnk-20261024T114255` (ID temporaneo `9e408105e59e`; può cambiare nei deploy successivi).
- **PostgreSQL 17.11**, database `simplenotes`, Flyway **V1–V7** con `success=true` e **5 colonne V7**.
- Inventario reale: 1 utente, 5 attività, 4 note, 25 cambiamenti e 25 operazioni di sync, nessuna migrazione fallita.
- Backup reale: `simple-notes-20261024T132857Z-271921.dump`; manifest SHA256 valido e **restore isolato realmente riuscito** nel container temporaneo (`.restore-ok`).
- Copia cifrata offsite **non effettuata**; l'utente ha chiesto di fermare ulteriori attività di backup. Questo non viene considerato un gate completato.
- La presenza della V7 in PostgreSQL **non dimostra da sola** che l'API in esecuzione esponga il nuovo contratto: la diagnostica T4.2 verifica la capability autenticata.

## Funzione integrata — Diagnostica sincronizzazione

Dopo aver installato su entrambi i dispositivi una build Flutter aggiornata:

1. Accedere con **lo stesso account Google** su PC e telefono.
2. Aprire l'avatar → **Verifica sincronizzazione** (menu Forui disponibile su Windows e Android).
3. L'app esegue **solo** una GET autenticata di `/api/v1/capabilities` e letture del proprio database SQLite. **Non crea, invia, modifica o elimina task e note.**
4. Verificare `Backend scadenze: Compatibile (taskDueSchema 1)`, `Archivio/account: Coerente`, `Modifiche in attesa: 0` e `Ultima sincronizzazione` non vuota **dopo** una sincronizzazione riuscita.
5. Premere **Copia report** per condividere solo stato backend, conteggi, cursor e ultimo sync. **Non** contiene token, ID account, titoli, corpi delle note o URL segreti.

Se appare **Versione backend incompatibile** o il client riceve HTTP **426**, **non cancellare dati e non reinstallare l'app**: la coda locale rimane salvata; controllare che il backend API sia aggiornato. Se appare **API non raggiungibile**, verificare rete e login. Se appare **Archivio locale associato a un altro account**, non forzare la sincronizzazione.

La data di ultima sincronizzazione viene registrata **solo dopo upload e pull entrambi riusciti**. Una GET diagnostica non aggiorna mai quel valore. In caso di 426 la UI segnala l'upgrade e sospende il retry automatico fino a un comando manuale o a una nuova sessione; le modifiche non vengono scartate.


**Build di collaudo T4.2:** `0.4.0+4` (versione Flutter in `pubspec.yaml`); installare sul PC e su Android una build ottenuta dallo stesso commit. L'APK CI è di test e non incorpora automaticamente i parametri OAuth; non disinstallare la vecchia applicazione per aggiornare.

## Compilare i client con la vera configurazione cloud

Nella PowerShell del PC, in `apps/flutter` della repository aggiornata:

```powershell
git pull origin main
cd apps/flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_DESKTOP_CLIENT_ID=TUO_CLIENT_ID_DESKTOP
```

Per Android, con `flutter devices` ricavare l'ID corretto e scegliere il **client ID Web** (non Android e non un secret):

```powershell
flutter devices
flutter run -d ID_DEL_TUO_ANDROID --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_WEB_CLIENT_ID=TUO_CLIENT_ID_WEB
```

Sostituire i segnaposto con gli identificativi OAuth già configurati localmente; non condividerli in chat se includono segreti. Non inserire mai **Client Secret**, refresh token o password nelle opzioni Flutter, nei commit o nei report. La build generica di GitHub Actions **non contiene le opzioni OAuth reali**; il successo CI non basta per il test di accesso.

**Importante:** non disinstallare/azzerare i dati delle vecchie app: operazioni offline potrebbero essere ancora nella SQLite locale. Usare il medesimo package Android `it.andreadada.simplenotes` e la chiave debug Google OAuth compatibile con l'APK locale. L'app Flutter Web non è attualmente operativa.

## Sequenza di collaudo non distruttiva

Usare **una sola attività nuova di prova**, per evitare di toccare i dati personali precedenti.

| # | Dispositivo | Azione | Risultato atteso |
|---|---|---|---|
| 1 | Windows | Aprire diagnostica, poi **Sincronizza ora**, riaprire diagnostica | Backend compatibile, ultimo successo visibile, pending 0 |
| 2 | Android | Ripetere diagnostica e **Sincronizza ora** | Stesso stato compatibile e pending 0 |
| 3 | Windows | Creare attività `T4-verifica-PC` con **Solo giorno, 27/10/2026** | Nella diagnostica pending scende a 0 dopo sync |
| 4 | Android | **Sincronizza ora**, aprire `T4-verifica-PC` | Stessa attività e data **27/10**, senza ora |
| 5 | Android | Sul task di prova selezionare **Data e ora**, `27/10/2026 · 00:00 · Europe/Rome` | Modalità `datetime`, mezzanotte esplicita |
| 6 | Windows | **Sincronizza ora**, aprire task | Data+ora e fuso corretti, non convertiti in `legacy` |
| 7 | Windows | Modificare **solo il titolo** del task di prova | Alla sync Android conserva stesso tipo/ora/fuso |
| 8 | Android | Mettere il dispositivo offline e creare nota `T4-prova-offline`; riavviare app | Nota presente localmente, pending positivo, nessuna perdita |
| 9 | Android → Windows | Riattivare rete, sincronizzare Android e poi Windows | Nota ricevuta dal PC e pending 0 su entrambi |

La verifica di **ora ripetuta** è aggiuntiva: sullo stesso task di prova selezionare `25/10/2026 02:30 Europe/Rome`, scegliere la prima (+02:00) o la seconda (+01:00) occorrenza, sincronizzare e verificare la stessa scelta sull'altro dispositivo. L'orario inesistente `29/03/2026 02:30 Europe/Rome` deve essere rifiutato. Eseguire entrambe solo se si vuole completare l'intera matrice DST; nessun test di questo tipo deve alterare gli altri task.

**Non cancellare la nota o il task di prova prima di aver verificato il risultato su entrambi i dispositivi.** Non eseguire test di conflitto 409 su note importanti; utilizzare dati di prova e seguire la checklist completa solo in modo intenzionale.

## Scheda rapida del risultato

```text
Data test: ____________
Flutter commit Windows/Android: ____________
API/backend: taskDueSchema 1 verificato?  SI / NO
PC: pending ____ | ultimo sync ____ | backend ____________
Android: pending ____ | ultimo sync ____ | backend ____________
Solo giorno PC → Android: PASS / FAIL / NON TESTATO
Data+ora Android → PC: PASS / FAIL / NON TESTATO
Rinomina senza modifica della scadenza: PASS / FAIL / NON TESTATO
Offline → online: PASS / FAIL / NON TESTATO
DST gap/fold: PASS / FAIL / NON TESTATO
Note (senza credenziali o dati privati): __________________
```

**Criterio di completamento T4.2:** screenshot o diagnostiche copiate dai **due dispositivi aggiornati**, insieme al risultato della sequenza; passaggio test offline e riconciliazione cloud. La CI simulata è distinta dalla prova reale e non basta da sola.

Non occorre alcun nuovo deploy PostgreSQL: **Flyway V7 è stata verificata sul database reale**. Il contratto API va comunque controllato con il nuovo comando diagnostico autenticato.
