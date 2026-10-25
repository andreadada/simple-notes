import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

import '../auth/cloud_auth.dart';
import '../data/local_store.dart';
import 'reminder_planner.dart';
import 'reminder_reconcile.dart';

/// Device-only opt-in. Does not change the task sync schema or shared account.
class ReminderStatus {
  const ReminderStatus({
    this.enabled = false, this.busy = false, this.pending = 0, this.error,
  });
  final bool enabled;
  final bool busy;
  final int pending;
  final String? error;
}

final reminderControllerProvider =
    StateNotifierProvider<ReminderController, ReminderStatus>(
      (ref) => ReminderController(ref),
    );

class ReminderController extends StateNotifier<ReminderStatus> {
  ReminderController(this._ref) : super(const ReminderStatus()) {
    _loaded = _restore();
  }

  final Ref _ref;
  late final Future<void> _loaded;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'simple_notes.reminders.v1.enabled';
  static const _ledgerKey = 'simple_notes.reminders.v1.ledger';
  bool _pluginInitialized = false;
  Future<void> _queue = Future<void>.value();

  /// Android only until Windows is shipped with package identity/MSIX.
  static bool get supported => Platform.isAndroid;

  Future<void> _restore() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = ReminderStatus(enabled: prefs.getBool(_enabledKey) ?? false);
      if (state.enabled) reconcile();
    } catch (_) {
      if (mounted) {
        state = const ReminderStatus(
          error: 'Impossibile leggere le preferenze dei promemoria.');
      }
    }
  }

  Future<void> _initialize() async {
    if (_pluginInitialized) return;
    time_zone_data.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _pluginInitialized = true;
  }

  /// Only call on explicit user interaction (Android 13+ permission prompt).
  Future<void> setEnabled(bool enabled) async {
    if (!supported || !mounted) return;
    await _loaded;
    if (!mounted || state.busy) return;
    state = ReminderStatus(
      enabled: state.enabled, pending: state.pending, busy: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await _initialize();
      if (enabled) {
        final owner = _ref.read(cloudAuthProvider).userId;
        if (owner == null ||
            await _ref.read(databaseProvider).setting('boundOwnerId') != owner) {
          throw StateError('Completa prima la sincronizzazione di questo account.');
        }
        final permission = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        if (permission != true) {
          throw StateError('Permesso notifiche non concesso.');
        }
        await prefs.setBool(_enabledKey, true);
        if (!mounted) return;
        state = ReminderStatus(enabled: true, pending: state.pending);
        await _enqueueSync();
      } else {
        // Do not leave previously scheduled personal reminders on logout
        // or opt-out. An unsuccessful cancel leaves the opt-in intact.
        await _enqueueSync(forceEmpty: true);
        await prefs.setBool(_enabledKey, false);
        if (mounted) state = const ReminderStatus();
      }
    } catch (e) {
      if (mounted) {
        state = ReminderStatus(
          enabled: state.enabled, pending: state.pending,
          error: 'Promemoria non aggiornati: $e');
      }
    } finally {
      if (mounted && state.busy) {
        state = ReminderStatus(
          enabled: state.enabled, pending: state.pending, error: state.error);
      }
    }
  }

  /// Cancel prior owner's reminders *before* clearing the Google session.
  Future<bool> cancelBeforeLogout() async {
    if (!supported) return true;
    await _loaded;
    try {
      await _enqueueSync(forceEmpty: true);
      return true;
    } catch (e) {
      if (mounted) {
        state = ReminderStatus(enabled: state.enabled,
          pending: state.pending, error: 'Impossibile annullare i promemoria: $e');
      }
      return false;
    }
  }

  /// Called after local task changes, remote delta/reload and app resume.
  /// No permission dialog, no network traffic, no destructive task mutations.
  void reconcile() {
    if (!supported || !mounted) return;
    unawaited(_loaded.then((_) async {
      if (!mounted || !state.enabled || state.busy) return;
      try {
        await _enqueueSync();
      } catch (e) {
        if (mounted) {
          state = ReminderStatus(enabled: state.enabled,
            pending: state.pending, error: 'Promemoria non aggiornati: $e');
        }
      }
    }));
  }

  Future<void> _enqueueSync({bool forceEmpty = false}) {
    final work = _queue.then((_) => _sync(forceEmpty: forceEmpty));
    _queue = work.catchError((Object _) {});
    return work;
  }

  Future<void> _sync({required bool forceEmpty}) async {
    if (!mounted || !supported) return;
    final owner = _ref.read(cloudAuthProvider).userId;
    if (!forceEmpty) {
      if (!state.enabled || owner == null) return;
      // Never schedule data from an unbound SQLite database for a new account.
      if (await _ref.read(databaseProvider).setting('boundOwnerId') != owner) {
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_ledgerKey);
    final ledger = <String, int>{};
    if (encoded != null) {
      final value = jsonDecode(encoded);
      if (value is! Map) throw const FormatException('Ledger non valido.');
      for (final entry in value.entries) {
        if (entry.key is! String || entry.value is! int) {
          throw const FormatException('Ledger non valido.');
        }
        ledger[entry.key as String] = entry.value as int;
      }
    }
    final plans = forceEmpty ? <ReminderPlan>[] :
        ReminderPlanner.desiredSchedule(
          _ref.read(localStoreProvider).tasks,
          ownerId: owner!, now: DateTime.now().toUtc(),
          dueLeadMinutes: 15, blockLeadMinutes: 15,
        );
    final changes = ReminderReconciler.diff(recorded: ledger, desired: plans);
    if (changes.cancelIds.isEmpty && changes.schedule.isEmpty) {
      if (mounted && !state.busy && state.pending != ledger.length) {
        state = ReminderStatus(enabled: state.enabled, pending: ledger.length);
      }
      return;
    }
    await _initialize();
    for (final id in changes.cancelIds) {
      await _plugin.cancel(id);
      ledger.removeWhere((_, value) => value == id);
      await prefs.setString(_ledgerKey, jsonEncode(ledger));
    }
    for (final plan in changes.schedule) {
      // Deliberately inexact: do not request restricted Android exact alarms.
      // No personal titles displayed on a locked screen.
      await _plugin.zonedSchedule(
        plan.notificationId, 'Simple Notes',
        'Hai un’attività in programma.',
        tz.TZDateTime.from(plan.fireAtUtc, tz.UTC),
        const NotificationDetails(android: AndroidNotificationDetails(
          'simple_notes_tasks_v1', 'Promemoria attività',
          channelDescription: 'Scadenze e blocchi orari di Simple Notes',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        )),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.taskId,
      );
      ledger[plan.key] = plan.notificationId;
      await prefs.setString(_ledgerKey, jsonEncode(ledger));
    }
    if (mounted && !state.busy) {
      state = ReminderStatus(enabled: state.enabled, pending: ledger.length);
    }
  }
}
