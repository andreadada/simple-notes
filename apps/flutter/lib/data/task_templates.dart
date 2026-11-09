import 'package:uuid/uuid.dart';

import 'models.dart';

/// Built-in, offline templates. Applying a template creates ordinary tasks
/// and subtasks through the same SQLite/outbox pipeline as manual creation.
/// Template definitions never need cloud permissions or background jobs.
class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.subtasks,
    this.priority = 0,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String description;
  final List<String> subtasks;
  final int priority;
  final List<String> tags;

  LocalTask instantiate({String? listId, DateTime? createdAt}) {
    final time = createdAt ?? DateTime.now();
    return LocalTask(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueAt: null,
      createdAt: time,
      completed: false,
      listId: listId,
      priority: priority,
      tags: List.unmodifiable(tags),
      subtasks: [
        for (final title in subtasks)
          LocalSubtask(id: const Uuid().v4(), title: title),
      ],
    );
  }
}

abstract final class TaskTemplateCatalog {
  static const templates = <TaskTemplate>[
    TaskTemplate(
      id: 'study-session',
      title: 'Sessione di studio',
      description: 'Prepara, studia e consolida un argomento.',
      priority: 2,
      tags: ['studio'],
      subtasks: [
        'Definire l’obiettivo',
        'Ripassare la teoria',
        'Svolgere gli esercizi',
        'Verificare gli errori',
      ],
    ),
    TaskTemplate(
      id: 'weekly-plan',
      title: 'Pianificazione settimanale',
      description: 'Organizza gli obiettivi della settimana.',
      tags: ['organizzazione'],
      subtasks: [
        'Rivedere gli impegni',
        'Definire tre priorità',
        'Distribuire i blocchi di lavoro',
        'Rivedere i risultati',
      ],
    ),
    TaskTemplate(
      id: 'software-release',
      title: 'Rilascio software',
      description: 'Controlli essenziali prima di una release.',
      priority: 3,
      tags: ['sviluppo'],
      subtasks: [
        'Rivedere le modifiche',
        'Eseguire test e analisi',
        'Verificare backup e rollback',
        'Aggiornare la documentazione',
      ],
    ),
    TaskTemplate(
      id: 'meeting',
      title: 'Preparazione incontro',
      description: 'Preparati a una riunione e registra i follow-up.',
      tags: ['lavoro'],
      subtasks: [
        'Definire ordine del giorno',
        'Preparare materiali e domande',
        'Annotare decisioni',
        'Registrare le prossime azioni',
      ],
    ),
    TaskTemplate(
      id: 'personal-admin',
      title: 'Commissioni e pratiche',
      description: 'Checklist per un’attività amministrativa.',
      tags: ['personale'],
      subtasks: [
        'Raccogliere i documenti',
        'Verificare date e scadenze',
        'Completare la pratica',
        'Archiviare la ricevuta',
      ],
    ),
  ];

  static TaskTemplate find(String id) =>
      templates.firstWhere((template) => template.id == id,
        orElse: () => throw const FormatException('Modello sconosciuto.'));
}
