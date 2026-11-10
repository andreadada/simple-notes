import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auto-sync only runs in the foreground, when the task sync gate and
/// owner binding are valid. A displayed automation editor pauses background
/// reconciliation, so it cannot race with a user confirmation or inline edit.
final taskActionEditorVisibleProvider = StateProvider<bool>((ref) => false);

/// Local edit or manual resolution wakes the existing debounced sync host.
final taskActionRulesEditRevisionProvider = StateProvider<int>((ref) => 0);

enum TaskActionAutoSyncPhase {
  idle, aligned, uploaded, downloaded, conflict, unavailable, offline,
  invalid, paused,
}

class TaskActionAutoSyncState {
  const TaskActionAutoSyncState({
    this.ownerId,
    this.phase = TaskActionAutoSyncPhase.idle,
  });
  final String? ownerId;
  final TaskActionAutoSyncPhase phase;

  String get label => switch (phase) {
    TaskActionAutoSyncPhase.idle => 'Sincronizzazione regole non ancora verificata',
    TaskActionAutoSyncPhase.aligned => 'Regole cloud allineate',
    TaskActionAutoSyncPhase.uploaded => 'Modifiche alle regole pubblicate automaticamente',
    TaskActionAutoSyncPhase.downloaded => 'Regole cloud aggiornate sul dispositivo',
    TaskActionAutoSyncPhase.conflict =>
      'Conflitto regole: modifiche offline su due dispositivi. '
      'Scegli Pubblica o Scarica per decidere quale catalogo conservare.',
    TaskActionAutoSyncPhase.unavailable =>
      'Catalogo cloud non disponibile sul backend installato (richiede V12)',
    TaskActionAutoSyncPhase.offline =>
      'Regole non sincronizzate: rete o API non disponibile',
    TaskActionAutoSyncPhase.invalid =>
      'Regole o checkpoint non validi: sincronizzazione sospesa senza cancellare dati',
    TaskActionAutoSyncPhase.paused =>
      'Modifica regole aperta: sincronizzazione automatica in pausa',
  };
}

final taskActionAutoSyncStateProvider =
    StateProvider<TaskActionAutoSyncState>(
        (ref) => const TaskActionAutoSyncState());
