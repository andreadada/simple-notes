import 'dart:convert';

/// Device-only P1.11: habit records never enter task sync or backend APIs.
/// Check-ins use YYYY-MM-DD local civil days, not UTC instants.
abstract final class HabitDay {
  static final RegExp _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String of(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime parse(String value) {
    if (!_pattern.hasMatch(value)) {
      throw const FormatException('Data abitudine non valida');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || of(parsed) != value) {
      throw const FormatException('Data calendario non valida');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime shift(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}

class LocalHabit {
  LocalHabit({
    required this.id,
    required this.title,
    required this.createdDay,
    this.archived = false,
    Iterable<String> checkIns = const [],
  }) : checkIns = Set.unmodifiable(checkIns) {
    if (id.isEmpty || title.trim().isEmpty || title.length > 120 ||
        title.trim() != title) {
      throw const FormatException('ID o titolo abitudine non valido');
    }
    HabitDay.parse(createdDay);
    if (this.checkIns.length > 5000) {
      throw const FormatException('Troppi check-in');
    }
    for (final day in this.checkIns) {
      HabitDay.parse(day);
      if (day.compareTo(createdDay) < 0) {
        throw const FormatException('Check-in prima della creazione');
      }
    }
  }

  final String id;
  final String title;
  final String createdDay;
  final bool archived;
  final Set<String> checkIns;

  bool checked(DateTime day) => checkIns.contains(HabitDay.of(day));

  LocalHabit renamed(String text) => LocalHabit(
    id: id, title: text.trim(), createdDay: createdDay,
    archived: archived, checkIns: checkIns);

  LocalHabit withArchived(bool value) => LocalHabit(
    id: id, title: title, createdDay: createdDay,
    archived: value, checkIns: checkIns);

  LocalHabit toggle(DateTime day, DateTime today) {
    final target = HabitDay.of(day);
    final current = HabitDay.of(today);
    if (target.compareTo(createdDay) < 0 || target.compareTo(current) > 0) {
      throw StateError('Non puoi segnare date future o prima della creazione');
    }
    final next = {...checkIns};
    if (!next.add(target)) next.remove(target);
    return LocalHabit(
      id: id, title: title, createdDay: createdDay,
      archived: archived, checkIns: next);
  }

  /// A streak remains intact until a day is missed. An unchecked today does
  /// not break yesterday's streak, unlike an unchecked day further in past.
  int streak(DateTime today) {
    var cursor = DateTime(today.year, today.month, today.day);
    if (!checked(cursor)) cursor = HabitDay.shift(cursor, -1);
    var run = 0;
    while (checkIns.contains(HabitDay.of(cursor))) {
      run++;
      cursor = HabitDay.shift(cursor, -1);
    }
    return run;
  }

  int countLast(DateTime today, int days) {
    if (days < 1 || days > 366) throw ArgumentError.value(days);
    var total = 0;
    for (var i = 0; i < days; i++) {
      if (checked(HabitDay.shift(today, -i))) total++;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdDay': createdDay,
    'archived': archived,
    'checkIns': checkIns.toList()..sort(),
  };

  factory LocalHabit.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final created = json['createdDay'];
    final archived = json['archived'];
    final days = json['checkIns'];
    if (id is! String || title is! String || created is! String ||
        archived is! bool || days is! List ||
        days.any((x) => x is! String) ||
        days.toSet().length != days.length) {
      throw const FormatException('Abitudine non valida');
    }
    return LocalHabit(id: id, title: title, createdDay: created,
      archived: archived, checkIns: days.cast<String>());
  }
}

class HabitsState {
  HabitsState({Iterable<LocalHabit> habits = const []})
      : habits = List.unmodifiable(habits) {
    if (this.habits.length > 200 ||
        this.habits.map((habit) => habit.id).toSet().length !=
            this.habits.length) {
      throw const FormatException('Archivio abitudini non valido');
    }
  }

  final List<LocalHabit> habits;

  List<LocalHabit> get active => habits.where((habit) => !habit.archived).toList();
  List<LocalHabit> get archived => habits.where((habit) => habit.archived).toList();

  int checkedToday(DateTime today) =>
      active.where((habit) => habit.checked(today)).length;

  HabitsState add(String id, String title, DateTime today) {
    if (habits.any((habit) => habit.id == id)) {
      throw StateError('ID abitudine già usato');
    }
    return HabitsState(habits: [
      ...habits,
      LocalHabit(id: id, title: title.trim(), createdDay: HabitDay.of(today)),
    ]);
  }

  HabitsState update(String id, LocalHabit Function(LocalHabit) edit) {
    if (!habits.any((habit) => habit.id == id)) {
      throw StateError('Abitudine non disponibile');
    }
    return HabitsState(habits: [
      for (final habit in habits) habit.id == id ? edit(habit) : habit,
    ]);
  }

  String serialize() => jsonEncode({
    'schema': 1,
    'habits': habits.map((habit) => habit.toJson()).toList(),
  });

  factory HabitsState.deserialize(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 1 || decoded['habits'] is! List) {
      throw const FormatException('Formato Habit Tracker non supportato');
    }
    final items = (decoded['habits'] as List).map((raw) {
      if (raw is! Map) throw const FormatException('Abitudine non valida');
      return LocalHabit.fromJson(Map<String, dynamic>.from(raw));
    }).toList();
    return HabitsState(habits: items);
  }
}
