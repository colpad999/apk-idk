import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/habit_repository.dart';

class HabitNotificationService {
  HabitNotificationService._();
  static final instance = HabitNotificationService._();
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings, onDidReceiveNotificationResponse: (_) {});
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> reschedule(Habit habit) async {
    await cancel(habit.id);
    if (!habit.isActive || !habit.reminderEnabled) return;
    for (final weekday in habit.reminderDays) {
      final id = habit.id * 10 + weekday;
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day,
          habit.reminderMinutes ~/ 60, habit.reminderMinutes % 60);
      while (next.weekday != weekday || !next.isAfter(now))
        next = next.add(const Duration(days: 1));
      await plugin.zonedSchedule(
          id,
          habit.reminderTitle,
          habit.reminderBody,
          next,
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'habit_reminders', 'Pengingat habit',
                  channelDescription: 'Pengingat kebiasaan Colpad',
                  importance: Importance.defaultImportance,
                  priority: Priority.defaultPriority)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
    }
  }

  Future<void> cancel(int habitId) async {
    for (var weekday = 1; weekday <= 7; weekday++)
      await plugin.cancel(habitId * 10 + weekday);
  }
}
