import 'dart:async';
import 'dart:io';

import 'ics_calendar.dart';

/// Explicit HTTPS-only feed policy. Reject reserved IP literals/hosts and
/// validate every resolved socket address at connection time (DNS pinning).
abstract final class IcsFeedPolicy {
  static Uri validate(String value) {
    if (value.isEmpty || value.length > 2048 || value != value.trim()) {
      throw const FormatException('Inserisci un URL HTTPS valido.');
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.hasFragment || uri.host.isEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException('Sono consentiti soltanto feed HTTPS sulla porta 443.');
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost') ||
        host.endsWith('.local') || host.endsWith('.internal') ||
        host.endsWith('.test') || host.endsWith('.invalid') ||
        InternetAddress.tryParse(host) != null || host.length > 253 ||
        !RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(host) ||
        host.split('.').any((label) => label.length > 63 ||
            label.startsWith('-') || label.endsWith('-'))) {
      throw const FormatException('Host del calendario non consentito.');
    }
    return uri;
  }

  static bool isPublicAddress(InternetAddress address) {
    final p = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      if (p.length != 4) return false;
      final a = p[0], b = p[1], c = p[2];
      if (a == 0 || a == 10 || a == 127 || a >= 224 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && (b == 168 || b == 0 || b == 88 && c == 99)) ||
          (a == 198 && (b == 18 || b == 19 ||
              b == 51 && c == 100)) ||
          (a == 203 && b == 0 && c == 113)) {
        return false;
      }
      return true;
    }
    if (address.type == InternetAddressType.IPv6 && p.length == 16) {
      // 2000::/3 only, excluding IETF special/reserved and transition ranges.
      if (p[0] < 0x20 || p[0] > 0x3f) return false;
      if (p[0] == 0x20 && p[1] == 0x01 &&
          (p[2] < 0x04 || p[2] == 0x0d && p[3] == 0xb8)) {
        return false;
      }
      if (p[0] == 0x20 && p[1] == 0x02) return false; // 6to4
      return true;
    }
    return false;
  }

  static InternetAddress chooseAddress(List<InternetAddress> addresses) {
    if (addresses.isEmpty || addresses.any((ip) => !isPublicAddress(ip))) {
      throw const FormatException(
          'Il feed risolve a un indirizzo privato o riservato.');
    }
    return addresses.first;
  }

  static Uri redirect(Uri original, Uri current, String? location,
      Set<String> visited) {
    if (location == null || location.isEmpty) {
      throw const FormatException('Reindirizzamento calendario non valido.');
    }
    final next = validate(current.resolve(location).toString());
    // No cross-origin redirects. Prevent leaking private query-token feed
    // URLs to other hosts/ports; limit is checked by the caller.
    if (next.host.toLowerCase() != original.host.toLowerCase() ||
        next.port != 443 || !visited.add(next.toString())) {
      throw const FormatException('Reindirizzamento del calendario bloccato.');
    }
    return next;
  }
}

/// Fetch a single ICS feed on demand. No background refresh, no OAuth tokens,
/// no cookies/proxy forwarding, no HTTP downgrade or unsafe DNS destinations.
class IcsFeedClient {
  const IcsFeedClient();
  static const maxRedirects = 2;
  static const requestTimeout = Duration(seconds: 20);

  Future<List<int>> download(String url) async {
    final initial = IcsFeedPolicy.validate(url);
    final client = HttpClient()
      ..findProxy = (_) => 'DIRECT'
      ..connectionTimeout = const Duration(seconds: 6)
      ..autoUncompress = true;
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      if (proxyHost != null || proxyPort != null) {
        throw const FormatException('Proxy del feed non consentito.');
      }
      IcsFeedPolicy.validate(uri.toString());
      final addresses = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 6));
      final address = IcsFeedPolicy.chooseAddress(addresses);
      // The HTTPS certificate and SNI are still verified against uri.host,
      // while the TCP socket uses the validated literal address.
      return Socket.startConnect(address, uri.port);
    };
    try {
      return await _download(client, initial).timeout(requestTimeout);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Impossibile scaricare il calendario. La cache resta invariata.');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _download(HttpClient client, Uri initial) async {
    var current = initial;
    final visited = <String>{initial.toString()};
    for (var redirectCount = 0; redirectCount <= maxRedirects;
        redirectCount++) {
      final request = await client.getUrl(current);
      request.followRedirects = false;
      request.persistentConnection = false;
      request.headers.set(HttpHeaders.acceptHeader, 'text/calendar');
      final response = await request.close();
      if (const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        if (redirectCount == maxRedirects) {
          throw const FormatException('Troppi redirect per il calendario.');
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        current = IcsFeedPolicy.redirect(initial, current, location, visited);
        await response.drain<void>();
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const FormatException(
            'Feed non disponibile: riprova senza perdere la cache.');
      }
      if (response.contentLength > IcsParser.maxBytes) {
        throw const FormatException('Calendario superiore a 1 MB.');
      }
      final data = <int>[];
      await for (final chunk in response) {
        if (data.length + chunk.length > IcsParser.maxBytes) {
          throw const FormatException('Calendario superiore a 1 MB.');
        }
        data.addAll(chunk);
      }
      if (data.isEmpty) {
        throw const FormatException('Il feed non contiene dati ICS.');
      }
      return data;
    }
    throw const FormatException('Redirect non supportato.');
  }
}

/// Pure replacement service: download+parse is complete *before* the caller
/// commits a new library. A failed refresh never mutates a cached snapshot.
class IcsFeedService {
  IcsFeedService({Future<List<int>> Function(String url)? download,
      DateTime Function()? now})
      : _download = download ?? const IcsFeedClient().download,
        _now = now ?? DateTime.now;
  final Future<List<int>> Function(String url) _download;
  final DateTime Function() _now;

  Future<IcsLibrary> subscribe(IcsLibrary existing, String url) async {
    final uri = IcsFeedPolicy.validate(url);
    final matching = existing.calendars.where((c) =>
        c.kind == IcsSourceKind.url && c.sourceUrl == url).toList();
    if (matching.length > 1) {
      throw const FormatException('Feed ICS duplicato.');
    }
    final prior = matching.isEmpty ? null : matching.single;
    if (prior == null && existing.calendars.length >= IcsLibrary.maxSources) {
      throw const FormatException('Massimo cinque calendari ICS.');
    }
    final label = prior?.name ?? uri.host;
    final parsed = IcsParser.parse(await _download(url), label);
    final candidate = IcsCalendar(label, parsed.events,
        id: prior?.id ?? '', kind: IcsSourceKind.url, sourceUrl: url,
        series: parsed.series, lastFetchedUtc: _now().toUtc());
    return existing.replace(candidate);
  }

  Future<IcsLibrary> refresh(IcsLibrary existing, String sourceId) async {
    final matches = existing.calendars.where((c) => c.id == sourceId &&
        c.kind == IcsSourceKind.url).toList();
    if (matches.length != 1) {
      throw const FormatException('Sorgente URL non trovata.');
    }
    final previous = matches.single;
    final url = previous.sourceUrl!;
    IcsFeedPolicy.validate(url);
    final parsed = IcsParser.parse(await _download(url), previous.name);
    return existing.replace(IcsCalendar(previous.name, parsed.events,
        id: previous.id, kind: IcsSourceKind.url, sourceUrl: url,
        series: parsed.series, lastFetchedUtc: _now().toUtc()));
  }
}
