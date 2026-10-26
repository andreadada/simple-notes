import 'dart:convert';

import '../data/task_due.dart';

/// P1.12 is device-only. A civil date remains a date, not an instant.
abstract final class CountdownClock {
  static int civilDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static String remaining(TaskDue due, DateTime now) {
    if (due.kind == 'date') {
      final local = due.displayLocal!;
      final days = civilDaysBetween(now.toLocal(), local);
      if (days == 0) return 'Oggi';
      if (days > 0) return '$days ${days == 1 ? 'giorno' : 'giorni'}';
      return 'Da ${-days} ${days == -1 ? 'giorno' : 'giorni'}';
    }
    final at = due.instant;
    if (at == null) throw const FormatException('Countdown senza data');
    final milliseconds = at.toUtc().difference(now.toUtc()).inMilliseconds;
    if (milliseconds <= 0) return 'Scaduto';
    final minutes = (milliseconds + 59999) ~/ 60000;
    final days = minutes ~/ (24 * 60);
    final hours = (minutes % (24 * 60)) ~/ 60;
    final mins = minutes % 60;
    if (days > 0) return '$days g · $hours h · $mins min';
    if (hours > 0) return '$hours h · $mins min';
    return '$mins min';
  }

  static bool overdue(TaskDue due, DateTime now) {
    if (due.kind == 'date') {
      return civilDaysBetween(now.toLocal(), due.displayLocal!) < 0;
    }
    return !(due.instant!.toUtc().isAfter(now.toUtc()));
  }

  static int compare(CountdownEvent a, CountdownEvent b) {
    // Calendar day first. For the same day, timed items sort by clock.
    final d1 = a.due.displayLocal!;
    final d2 = b.due.displayLocal!;
    final byDay = civilDaysBetween(d1, d2);
    if (byDay != 0) return -byDay;
    if (a.due.kind != b.due.kind) return a.due.kind == 'datetime' ? -1 : 1;
    if (a.due.kind == 'datetime') {
      final diff = a.due.instant!.compareTo(b.due.instant!);
      if (diff != 0) return diff;
    }
    return a.id.compareTo(b.id);
  }
}

class CountdownEvent {
  CountdownEvent({
    required this.id,
    required this.title,
    required this.due,
    this.archived = false,
  }) {
    if (id.trim().isEmpty || title.trim().isEmpty ||
        title.length > 120 || title != title.trim()) {
      throw const FormatException('Titolo o ID Countdown non valido');
    }
    if (due.kind != 'date' && due.kind != 'datetime') {
      throw const FormatException('Countdown richiede scadenza esplicita');
    }
    // Both kinds have already been validated by TaskDue.
    if (due.displayLocal == null) {
      throw const FormatException('Data Countdown non leggibile');
    }
  }

  final String id;
  final String title;
  final TaskDue due;
  final bool archived;

  CountdownEvent renamed(String value) => CountdownEvent(
    id: id, title: value.trim(), due: due, archived: archived);

  CountdownEvent rescheduled(TaskDue next) => CountdownEvent(
    id: id, title: title, due: next, archived: archived);

  CountdownEvent withArchived(bool value) => CountdownEvent(
    id: id, title: title, due: due, archived: value);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'due': due.toJson(),
    'archived': archived,
  };

  factory CountdownEvent.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String || value['title'] is! String ||
        value['archived'] is! bool || value['due'] is! Map) {
      throw const FormatException('Countdown non valido');
    }
    return CountdownEvent(
      id: value['id'] as String,
      title: value['title'] as String,
      due: TaskDue.fromJson(value['due']),
      archived: value['archived'] as bool,
    );
  }
}

class CountdownsState {
  CountdownsState({Iterable<CountdownEvent> events = const []})
      : events = List.unmodifiable(events) {
    if (this.events.length > 250 ||
        this.events.map((event) => event.id).toSet().length !=
            this.events.length) {
      throw const FormatException('Archivio Countdown non valido');
    }
  }
  final List<CountdownEvent> events;

  List<CountdownEvent> get active =>
      events.where((event) => !event.archived).toList()
        ..sort(CountdownClock.compare);
  List<CountdownEvent> get archived =>
      events.where((event) => event.archived).toList()
        ..sort(CountdownClock.compare);

  CountdownsState add(String id, String title, TaskDue due) {
    if (events.any((event) => event.id == id)) {
      throw StateError('ID Countdown duplicato');
    }
    return CountdownsState(events: [
      ...events,
      CountdownEvent(id: id, title: title.trim(), due: due),
    ]);
  }

  CountdownsState update(String id, CountdownEvent Function(CountdownEvent) f) {
    if (!events.any((event) => event.id == id)) {
      throw StateError('Countdown inesistente');
    }
    return CountdownsState(events: [
      for (final item in events) item.id == id ? f(item) : item,
    ]);
  }

  String serialize() => jsonEncode({
    'schema': 1,
    'events': events.map((event) => event.toJson()).toList(),
  });

  factory CountdownsState.deserialize(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 1 || decoded['events'] is! List) {
      throw const FormatException('Formato Countdown non supportato');
    }
    final raw = decoded['events'] as List;
    if (raw.length > 250) {
      throw const FormatException('Troppi Countdown');
    }
    return CountdownsState(events: raw.map((entry) {
      if (entry is! Map) throw const FormatException('Elemento non valido');
      return CountdownEvent.fromJson(Map<String, dynamic>.from(entry));
    }));
  }
}
