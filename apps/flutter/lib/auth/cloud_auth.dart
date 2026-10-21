import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CloudConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleDesktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static bool get enabled => apiBaseUrl.startsWith('https://') ||
      apiBaseUrl.startsWith('http://localhost:') ||
      apiBaseUrl.startsWith('http://127.0.0.1:') ||
      apiBaseUrl.startsWith('http://10.0.2.2:');
}

class CloudSession {
  final bool busy;
  final String? accessToken;
  final String? displayName;
  final String? userId;
  final String? error;
  final DateTime? accessExpiresAt;

  const CloudSession({
    this.busy = false,
    this.accessToken,
    this.displayName,
    this.userId,
    this.error,
    this.accessExpiresAt,
  });
  bool get authenticated => accessToken != null;
}

final cloudAuthProvider = StateNotifierProvider<CloudAuth, CloudSession>(
  (ref) => CloudAuth(),
);

class CloudAuth extends StateNotifier<CloudSession> {
  CloudAuth() : super(const CloudSession()) {
    if (CloudConfig.enabled) unawaited(restore());
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _http = http.Client();
  static const _refreshKey = 'simple_notes.refresh.v1';

  Future<void> restore() async {
    try {
      final refresh = await _storage.read(key: _refreshKey);
      if (refresh == null || refresh.isEmpty) return;
      final reply = await _exchange('/auth/refresh', {'refreshToken': refresh});
      await _setSession(reply);
    } on AuthHttpException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _storage.delete(key: _refreshKey);
        state = const CloudSession(error: 'Sessione scaduta: accedi di nuovo.');
      } else {
        state = const CloudSession(error: 'Server non disponibile. Dati locali conservati.');
      }
    } catch (_) {
      // Network outages must NOT erase the refresh token or the local dataset.
      state = const CloudSession(error: 'Offline: riprova il login cloud più tardi.');
    }
  }

  Future<void> loginGoogle() async {
    if (!CloudConfig.enabled) {
      state = const CloudSession(error: 'API_BASE_URL non configurato');
      return;
    }
    state = const CloudSession(busy: true);
    try {
      late final Map<String, dynamic> response;
      if (Platform.isAndroid) {
        if (CloudConfig.googleWebClientId.isEmpty) {
          throw StateError('GOOGLE_WEB_CLIENT_ID mancante');
        }
        final google = GoogleSignIn.instance;
        await google.initialize(serverClientId: CloudConfig.googleWebClientId);
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw StateError('Google non ha restituito un ID token');
        }
        response = await _exchange('/auth/google', {'idToken': idToken});
      } else if (Platform.isWindows) {
        response = await _desktopLogin();
      } else {
        throw UnsupportedError('Login supportato solo su Android e Windows');
      }
      await _setSession(response);
    } catch (e) {
      state = CloudSession(error: 'Login non riuscito: $e');
    }
  }

  Future<Map<String, dynamic>> _desktopLogin() async {
    final clientId = CloudConfig.googleDesktopClientId;
    if (clientId.isEmpty) throw StateError('GOOGLE_DESKTOP_CLIENT_ID mancante');
    final random = Random.secure();
    String nonce(int n) => base64Url.encode(
      List<int>.generate(n, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final verifier = nonce(48);
    final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final stateToken = nonce(24);
    final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${listener.port}/oauth/callback';
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': stateToken,
    });
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Impossibile aprire il browser');
      }
      final request = await listener.first.timeout(const Duration(minutes: 3));
      final receivedState = request.uri.queryParameters['state'];
      final code = request.uri.queryParameters['code'];
      final ok = request.uri.path == '/oauth/callback' &&
          receivedState == stateToken && code != null && code.isNotEmpty;
      request.response.headers.contentType = ContentType.html;
      request.response.write(ok
          ? '<h3>Accesso ricevuto. Puoi tornare a Simple Notes.</h3>'
          : '<h3>Accesso non valido. Torna a Simple Notes.</h3>');
      await request.response.close();
      if (!ok) throw StateError('Stato OAuth non valido o accesso annullato');
      return await _exchange('/auth/desktop/exchange', {
        'code': code,
        'codeVerifier': verifier,
        'redirectUri': redirect,
      });
    } finally {
      await listener.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _exchange(
      String path, Map<String, String> payload) async {
    final uri = Uri.parse('${CloudConfig.apiBaseUrl}/api/v1$path');
    final response = await _http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthHttpException(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _setSession(Map<String, dynamic> json) async {
    final refresh = json['refreshToken'] as String;
    final access = json['accessToken'] as String;
    await _storage.write(key: _refreshKey, value: refresh);
    state = CloudSession(
      accessToken: access,
      accessExpiresAt: DateTime.now().add(Duration(seconds: json['expiresInSeconds'] as int)),
      userId: json['userId'] as String?,
      displayName: json['displayName'] as String?,
    );
  }

  Future<String> validAccessToken() async {
    final current = state;
    if (current.accessToken != null &&
        current.accessExpiresAt != null &&
        current.accessExpiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return current.accessToken!;
    }
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null || refresh.isEmpty) {
      throw StateError('Sessione scaduta. Accedi nuovamente.');
    }
    final reply = await _exchange('/auth/refresh', {'refreshToken': refresh});
    await _setSession(reply);
    return state.accessToken!;
  }

  Future<void> logout() async {
    final raw = await _storage.read(key: _refreshKey);
    await _storage.delete(key: _refreshKey);
    state = const CloudSession();
    if (raw != null) {
      try {
        await _exchange('/auth/logout', {'refreshToken': raw});
      } catch (_) {
        state = const CloudSession(error:
          'Sessione rimossa dal dispositivo; revoca remota non confermata.');
      }
    }
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}

class AuthHttpException implements Exception {
  final int status;
  const AuthHttpException(this.status);
  @override
  String toString() => 'HTTP $status';
}
