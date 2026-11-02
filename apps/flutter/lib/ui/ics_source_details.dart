import 'ics_calendar.dart';

/// Presentation-only metadata. Never display sourceUrl (may contain a token).
String icsSourceKindLabel(IcsCalendar source) {
  if (source.kind == IcsSourceKind.file) return 'File locale';
  final host = Uri.tryParse(source.sourceUrl ?? '')?.host ?? '';
  return host.isEmpty ? 'Feed HTTPS' : 'Feed HTTPS · $host';
}

String icsSourceEventCount(IcsCalendar source) =>
    '${source.events.length} eventi · ${source.series.length} serie';

/// Displays successful refresh time only, never a failed attempt.
String icsSourceRefreshLabel(IcsCalendar source) {
  if (source.kind == IcsSourceKind.file) {
    return 'Importazione locale · aggiornamento tramite nuovo file';
  }
  final last = source.lastFetchedUtc;
  if (last == null) return 'Ultimo aggiornamento non disponibile';
  final local = last.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final duration = offset.abs();
  final tz = '$sign${two(duration.inHours)}:'
      '${two(duration.inMinutes % 60)}';
  return 'Ultimo aggiornamento riuscito: '
      '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)} (UTC$tz)';
}
