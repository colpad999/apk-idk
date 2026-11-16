import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/civil_date.dart';
import '../data/app_settings_repository.dart';
import '../data/habit_repository.dart';

class HabitNotificationRequest {
  const HabitNotificationRequest({
    required this.id,
    required this.habitId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.repeatWeekly,
    required this.sound,
    required this.vibration,
  });
  final int id, habitId;
  final String title, body;
  final DateTime scheduledAt;
  final bool repeatWeekly, sound, vibration;
  String get tag => 'habit_$habitId';
  String get payload => 'habit:$habitId';
}

/// Platform boundary: widget/unit tests use a deterministic in-memory gateway.
abstract class HabitNotificationGateway {
  Future<void> initialize(void Function(String? payload) onTap);
  Future<String?> launchPayload();
  Future<bool> areNotificationsEnabled();
  Future<bool> requestPermission();
  Future<void> refreshTimezone();
  Future<void> cancelHabit(int habitId);
  Future<void> cancelAll();
  Future<void> schedule(HabitNotificationRequest request);
  Future<void> showTest(HabitNotificationRequest request);
}

class AndroidHabitNotificationGateway implements HabitNotificationGateway {
  AndroidHabitNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _timezoneReady = false;
  static const alarmChannel = MethodChannel('colpad/habit_alarm');
  Future<bool> alarmEnabled() async => await alarmChannel.invokeMethod<bool>('enabled') ?? false;
  Future<void> setAlarmEnabled(bool enabled) => alarmChannel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  Future<bool> exactAllowed() async => await alarmChannel.invokeMethod<bool>('exactAllowed') ?? false;
  Future<void> openExactSettings() => alarmChannel.invokeMethod<void>('openExactSettings');
  Future<void> clearAlarmHabit(int habitId) => alarmChannel.invokeMethod<void>('clearHabit', {'habit': habitId});

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    tz_data.initializeTimeZones();
    await refreshTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> refreshTimezone() async {
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(zone));
      _timezoneReady = true;
    } catch (_) {
      // Never silently schedule in UTC when the device's IANA zone is unknown.
      _timezoneReady = false;
      rethrow;
    }
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> areNotificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> cancelHabit(int habitId) async {
    // Android cancels scheduled alarms by ID, not by notification tag. Query
    // the plugin's persisted schedule so removed reminders and old one-shots
    // are cancelled even after an app or device restart.
    await alarmChannel.invokeMethod<void>('cancelHabit', {'habit': habitId});
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload == 'habit:$habitId') await _plugin.cancel(request.id);
    }
    await _plugin.cancel(0x7ffffffd);
    // Clean up alarms created by the incomplete v5 implementation (untagged).
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(habitId * 10 + weekday);
    }
  }

  @override
  Future<void> cancelAll() async {
    await alarmChannel.invokeMethod<void>('cancelAll');
    await _plugin.cancelAll();
  }

  NotificationDetails _details(HabitNotificationRequest request) {
    final suffix = '${request.sound ? 's' : ''}${request.vibration ? 'v' : ''}';
    final channelId = 'habit_reminders_${suffix.isEmpty ? 'silent' : suffix}';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Pengingat habit',
        channelDescription: 'Pengingat kebiasaan dan tinjauan keuangan Colpad',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        playSound: request.sound,
        enableVibration: request.vibration,
      ),
    );
  }

  @override
  Future<void> schedule(HabitNotificationRequest request) async {
    if (!_timezoneReady) {
      throw StateError('Zona waktu perangkat belum berhasil dibaca.');
    }
    if (await alarmEnabled()) {
      await alarmChannel.invokeMethod<void>('schedule', {
        'id': request.id, 'habit': request.habitId, 'title': request.title,
        'body': request.body, 'at': request.scheduledAt.millisecondsSinceEpoch,
        'weekly': request.repeatWeekly, 'sound': request.sound,
        'vibration': request.vibration,
      });
      return;
    }
    final local = request.scheduledAt;
    final scheduled = tz.TZDateTime(tz.local, local.year, local.month, local.day,
        local.hour, local.minute);
    final android = _details(request).android!;
    await _android?.createNotificationChannel(AndroidNotificationChannel(
      android.channelId,
      android.channelName,
      description: android.channelDescription,
      importance: Importance.defaultImportance,
      playSound: request.sound,
      enableVibration: request.vibration,
    ));
    await _plugin.zonedSchedule(
      request.id,
      request.title,
      request.body,
      scheduled,
      _details(request),
      payload: request.payload,
      // Ordinary inexact alarms do not need SCHEDULE_EXACT_ALARM permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          request.repeatWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  @override
  Future<void> showTest(HabitNotificationRequest request) => _plugin.show(
        request.id,
        request.title,
        request.body,
        _details(request),
        payload: request.payload,
      );
}

class HabitSyncResult {
  const HabitSyncResult({
    this.scheduled = 0,
    this.permissionDenied = false,
    this.globallyDisabled = false,
  });
  final int scheduled;
  final bool permissionDenied, globallyDisabled;
}

class HabitNotificationService {
  HabitNotificationService({
    required HabitRepository repository,
    required AppSettingsRepository settings,
    required HabitNotificationGateway gateway,
    DateTime Function()? clock,
  })  : _repository = repository,
        _settings = settings,
        _gateway = gateway,
        _clock = clock ?? DateTime.now;

  final HabitRepository _repository;
  final AppSettingsRepository _settings;
  final HabitNotificationGateway _gateway;
  final DateTime Function() _clock;
  Future<void> _tail = Future.value();
  int? _pendingHabitId;
  void Function(int habitId)? onHabitSelected;
  Object? initializationError;

  Future<void> initialize() async {
    try {
      await _gateway.initialize(_handlePayload);
      _handlePayload(await _gateway.launchPayload());
    } catch (error) {
      // A missing platform channel must not prevent offline accounting UI.
      initializationError = error;
    }
  }

  void _handlePayload(String? payload) {
    final match = RegExp(r'^habit:([1-9][0-9]*)$').firstMatch(payload ?? '');
    final id = match == null ? null : int.tryParse(match.group(1)!);
    if (id == null) return;
    final callback = onHabitSelected;
    if (callback == null) {
      _pendingHabitId = id;
    } else {
      callback(id);
    }
  }

  int? takePendingHabitId() {
    final id = _pendingHabitId;
    _pendingHabitId = null;
    return id;
  }

  Future<bool> requestPermission() => _gateway.requestPermission();
  Future<bool> permissionGranted() async {
    try {
      return await _gateway.areNotificationsEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> globallyEnabled() => _settings.habitNotificationsEnabled();

  Future<HabitSyncResult> setGloballyEnabled(bool enabled) async {
    await _settings.setHabitNotificationsEnabled(enabled);
    return syncAll();
  }

  Future<void> refreshTimezone() => _gateway.refreshTimezone();

  Future<HabitSyncResult> syncAll() => _serialized(() async {
        if (!await _settings.habitNotificationsEnabled()) {
          await _gateway.cancelAll();
          return const HabitSyncResult(globallyDisabled: true);
        }
        if (!await _gateway.areNotificationsEnabled()) {
          await _gateway.cancelAll();
          return const HabitSyncResult(permissionDenied: true);
        }
        var scheduled = 0;
        for (final habit in await _repository.list()) {
          await _gateway.cancelHabit(habit.id);
          scheduled += await _scheduleHabit(habit);
        }
        return HabitSyncResult(scheduled: scheduled);
      });

  Future<HabitSyncResult> syncHabit(int habitId) => _serialized(() async {
        final habit = await _repository.get(habitId);
        await _gateway.cancelHabit(habitId);
        if (habit == null) {
          if (_gateway is AndroidHabitNotificationGateway) {
            await _gateway.clearAlarmHabit(habitId);
          }
          return const HabitSyncResult();
        }
        if (!await _settings.habitNotificationsEnabled()) {
          return const HabitSyncResult(globallyDisabled: true);
        }
        if (!await _gateway.areNotificationsEnabled()) {
          return const HabitSyncResult(permissionDenied: true);
        }
        return HabitSyncResult(scheduled: await _scheduleHabit(habit));
      });

  Future<void> cancelHabit(int habitId) => _serialized(() async {
        await _gateway.cancelHabit(habitId);
        if (_gateway is AndroidHabitNotificationGateway) {
          await _gateway.clearAlarmHabit(habitId);
        }
      });

  Future<HabitSyncResult> testReminder(
          Habit habit, HabitReminder reminder) =>
      _serialized(() async {
        if (!await _settings.habitNotificationsEnabled()) {
          return const HabitSyncResult(globallyDisabled: true);
        }
        if (!await _gateway.areNotificationsEnabled()) {
          return const HabitSyncResult(permissionDenied: true);
        }
        validateReminder(reminder);
        await _gateway.showTest(HabitNotificationRequest(
          id: 0x7ffffffd,
          habitId: habit.id,
          title: reminder.title,
          body: reminder.body,
          scheduledAt: _clock(),
          repeatWeekly: false,
          sound: reminder.sound,
          vibration: reminder.vibration,
        ));
        return const HabitSyncResult(scheduled: 1);
      });

  Future<int> _scheduleHabit(Habit habit) async {
    if (!habit.isActive) return 0;
    var count = 0;
    final now = _clock();
    for (final reminder in habit.reminders) {
      if (!reminder.enabled) continue;
      validateReminder(reminder);
      if (habit.endDate == null) {
        for (final weekday in reminder.days.toList()..sort()) {
          final next = nextReminderOccurrence(
            habit: habit,
            reminder: reminder,
            now: now,
            weekday: weekday,
          );
          if (next == null) continue;
          await _gateway.schedule(_request(habit, reminder, next,
              repeatWeekly: true, identity: 'week:$weekday'));
          count++;
        }
      } else {
        // Finite habits use one-shots so alarms cannot outlive their end date.
        // Keep a bounded rolling window; opening/resuming refreshes the window.
        final horizon = CivilDate.from(now).addDays(90);
        var day = CivilDate.max(CivilDate.from(now), reminder.startDate);
        day = CivilDate.max(day, habit.startDate);
        final last = CivilDate.min(habit.endDate!, horizon);
        while (day.isAtOrBefore(last)) {
          if (reminder.days.contains(day.weekday)) {
            final at = DateTime(day.year, day.month, day.day,
                reminder.hour, reminder.minute);
            if (at.isAfter(now)) {
              await _gateway.schedule(_request(habit, reminder, at,
                  repeatWeekly: false, identity: day.key));
              count++;
            }
          }
          day = day.nextDay;
        }
      }
    }
    return count;
  }

  HabitNotificationRequest _request(
    Habit habit,
    HabitReminder reminder,
    DateTime at, {
    required bool repeatWeekly,
    required String identity,
  }) =>
      HabitNotificationRequest(
        id: stableNotificationId('${reminder.id}:$identity'),
        habitId: habit.id,
        title: reminder.title,
        body: reminder.body,
        scheduledAt: at,
        repeatWeekly: repeatWeekly,
        sound: reminder.sound,
        vibration: reminder.vibration,
      );

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }
}

/// FNV-1a, restricted to Android's signed 31-bit notification ID range.
int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

DateTime? nextReminderOccurrence({
  required Habit habit,
  required HabitReminder reminder,
  required DateTime now,
  required int weekday,
}) {
  if (weekday < 1 || weekday > 7 || !reminder.days.contains(weekday)) {
    return null;
  }
  var day = CivilDate.max(CivilDate.from(now), reminder.startDate);
  day = CivilDate.max(day, habit.startDate);
  final end = habit.endDate;
  for (var offset = 0; offset < 8; offset++) {
    final candidate = day.addDays(offset);
    if (end != null && candidate.isAfter(end)) return null;
    if (candidate.weekday != weekday) continue;
    final at = DateTime(candidate.year, candidate.month, candidate.day,
        reminder.hour, reminder.minute);
    if (at.isAfter(now)) return at;
  }
  return null;
}
