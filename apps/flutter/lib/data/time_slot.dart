import 'time_block.dart';

/// P1.4 block identity is independent of start/end: rescheduling keeps IDs.
class TimeSlot {
  const TimeSlot({required this.id, required this.block});
  final String id;
  final TimeBlock block;
  TimeSlot copyWith({TimeBlock? block}) =>
      TimeSlot(id: id, block: block ?? this.block);
}

class TimeSlotCollection {
  static const maxBlocks = 12;
  static List<TimeSlot> validate(List<TimeSlot> slots) {
    if (slots.length > maxBlocks) {
      throw const FormatException('Massimo 12 blocchi per attività.');
    }
    final ids = <String>{};
    for (final slot in slots) {
      if (slot.id.isEmpty || slot.id.length > 80 || !ids.add(slot.id)) {
        throw const FormatException('ID blocco duplicato o non valido.');
      }
    }
    return List<TimeSlot>.of(slots)
      ..sort((a, b) {
        final c = a.block.start.compareTo(b.block.start);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
  }

  static List<TimeSlot> fromPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('timeBlocks')) {
      final raw = payload['timeBlocks'];
      if (raw is! List) {
        throw const FormatException('Lista blocchi non valida.');
      }
      return validate(raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Blocco non valido.');
        }
        final data = Map<String, dynamic>.from(item);
        return TimeSlot(id: data['id'] as String,
            block: TimeBlock.fromJson({'kind': 'range', ...data}));
      }).toList());
    }
    final old = TimeBlock.optionalFromJson(payload['timeBlock']);
    return old == null ? [] : [TimeSlot(id: 'legacy', block: old)];
  }

  static List<Map<String, dynamic>> toJson(List<TimeSlot> slots) =>
      validate(slots).map((slot) => {
        'id': slot.id,
        'start': slot.block.start.toUtc().toIso8601String(),
        'end': slot.block.end.toUtc().toIso8601String(),
        'timeZone': slot.block.timeZone,
      }).toList();
}
