import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pause while the models screen is visible. This prevents a cloud download
/// from silently replacing the catalog currently being edited or applied.
final userTemplatesEditorVisibleProvider =
    StateProvider<bool>((ref) => false);

final userTemplatesEditRevisionProvider =
    StateProvider<int>((ref) => 0);

enum UserTemplateAutoSyncPhase {
  idle, aligned, uploaded, downloaded, conflict, unavailable, offline,
  invalid, paused,
}

class UserTemplateAutoSyncState {
  const UserTemplateAutoSyncState({
    this.ownerId,
    this.phase = UserTemplateAutoSyncPhase.idle,
  });

  final String? ownerId;
  final UserTemplateAutoSyncPhase phase;

  String get label => switch (phase) {
    UserTemplateAutoSyncPhase.idle =>
      'Sincronizzazione modelli non ancora verificata',
    UserTemplateAutoSyncPhase.aligned => 'Modelli cloud allineati',
    UserTemplateAutoSyncPhase.uploaded =>
      'Modelli pubblicati automaticamente sul cloud',
    UserTemplateAutoSyncPhase.downloaded =>
      'Modelli cloud aggiornati su questo dispositivo',
    UserTemplateAutoSyncPhase.conflict =>
      'Conflitto modelli: scegli Pubblica o Scarica per decidere '
      'quale catalogo conservare. Nessun dato sovrascritto.',
    UserTemplateAutoSyncPhase.unavailable =>
      'Catalogo modelli non disponibile sul backend (richiede V13)',
    UserTemplateAutoSyncPhase.offline =>
      'Modelli non sincronizzati: rete o server non disponibile',
    UserTemplateAutoSyncPhase.invalid =>
      'Modelli o checkpoint non validi: sincronizzazione sospesa',
    UserTemplateAutoSyncPhase.paused =>
      'Schermata modelli aperta: sincronizzazione automatica in pausa',
  };
}

final userTemplateAutoSyncStateProvider =
    StateProvider<UserTemplateAutoSyncState>(
        (ref) => const UserTemplateAutoSyncState());
