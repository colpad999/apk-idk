import 'package:apk_idk/core/utils/civil_date.dart';
import 'package:apk_idk/data/app_settings_repository.dart';
import 'package:apk_idk/data/habit_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/habit_notification_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notification_gateway.dart';

void main() {
  late SavingsDatabase database;
  late HabitRepository repository;
  late AppSettingsRepository settings;
  late FakeHabitNotificationGateway gateway;
  late HabitNotificationService service;
  var now = DateTime(2026, 1, 14, 12); // Wednesday
  final start = CivilDate(DateTime(2026, 1, 1));

  setUp(() {
    now = DateTime(2026, 1, 14, 12);
    database = SavingsDatabase.forTesting(NativeDatabase.memory());
    repository = HabitRepository(database, clock: () => now);
    settings = AppSettingsRepository(database);
    gateway = FakeHabitNotificationGateway();
    service = HabitNotificationService(
      repository: repository,
      settings: settings,
      gateway: gateway,
      clock: () => now,
    );
  });
  tearDown(() => database.close());

  Future<int> createHabit({List<HabitReminder>? reminders, DateTime? end}) =>
      repository.save(
        name: 'Menabung',
        startDate: start.value,
        endDate: end,
        reminders: reminders ?? [
          HabitReminder(minutes: 19 * 60, days: {1, 2, 3, 4, 5}, startDate: start),
        ],
      );

  test('schedules selected weekdays at local time and reopening does not duplicate', () async {
    final id = await createHabit();
    final first = await service.syncAll();
    expect(first.scheduled, 5);
    final ids = gateway.scheduled.keys.toSet();
    expect(gateway.scheduled.values.every((request) =>
        request.scheduledAt.hour == 19 && request.scheduledAt.minute == 0 && request.repeatWeekly), isTrue);
    await service.syncAll();
    expect(gateway.scheduled.keys.toSet(), ids);
    expect(gateway.scheduled, hasLength(5));
    expect(gateway.scheduled.values.map((request) => request.habitId), everyElement(id));
  });

  test('editing time/days cancels stale alarms and keeps one current set', () async {
    final id = await createHabit();
    await service.syncHabit(id);
    final oldIds = gateway.scheduled.keys.toSet();
    final habit = (await repository.get(id))!;
    await repository.save(
      id: id,
      name: habit.name,
      startDate: habit.startDate.value,
      reminders: [habit.reminders.single.copyWith(minutes: 20 * 60 + 30, days: {1, 3})],
    );
    await service.syncHabit(id);
    expect(gateway.scheduled, hasLength(2));
    expect(gateway.scheduled.keys.toSet(), isNot(equals(oldIds)));
    expect(gateway.scheduled.values.every((request) => request.scheduledAt.hour == 20), isTrue);
  });

  test('disable, pause, delete and global off cancel owned alarms', () async {
    final id = await createHabit();
    await service.syncHabit(id);
    expect(gateway.scheduled, isNotEmpty);
    final habit = (await repository.get(id))!;
    await repository.save(id: id, name: habit.name, startDate: habit.startDate.value,
        reminders: [habit.reminders.single.copyWith(enabled: false)]);
    await service.syncHabit(id);
    expect(gateway.scheduled, isEmpty);

    await repository.save(id: id, name: habit.name, startDate: habit.startDate.value, reminders: habit.reminders);
    await service.syncHabit(id);
    await repository.setActive(id, false);
    await service.syncHabit(id);
    expect(gateway.scheduled, isEmpty);
    await repository.setActive(id, true);
    await service.syncHabit(id);
    expect(gateway.scheduled, isNotEmpty);

    await service.setGloballyEnabled(false);
    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelAllCount, 1);
    await service.setGloballyEnabled(true);
    expect(gateway.scheduled, isNotEmpty);
    await repository.delete(id);
    await service.syncHabit(id);
    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelledHabits, contains(id));
  });

  test('denied permission never schedules and test notification respects global switch', () async {
    final id = await createHabit();
    gateway.permission = false;
    final result = await service.syncHabit(id);
    expect(result.permissionDenied, isTrue);
    expect(gateway.scheduled, isEmpty);
    gateway.permission = true;
    final habit = (await repository.get(id))!;
    await service.testReminder(habit, habit.reminders.single);
    expect(gateway.shown, hasLength(1));
    expect(gateway.shown.single.payload, 'habit:$id');
    await settings.setHabitNotificationsEnabled(false);
    final blocked = await service.testReminder(habit, habit.reminders.single);
    expect(blocked.globallyDisabled, isTrue);
    expect(gateway.shown, hasLength(1));
  });

  test('finite habits use bounded one-shots that cannot pass the end date', () async {
    await createHabit(end: DateTime(2026, 1, 16));
    final result = await service.syncAll();
    expect(result.scheduled, 3); // Wednesday has not yet passed 19:00
    expect(gateway.scheduled.values.every((request) => !request.repeatWeekly), isTrue);
    expect(gateway.scheduled.values.every((request) =>
        !request.scheduledAt.isAfter(DateTime(2026, 1, 16, 19))), isTrue);
  });

  test('future reminder start and elapsed time move to the next valid occurrence', () {
    final reminder = HabitReminder(minutes: 19 * 60, days: {1, 3, 5}, startDate: CivilDate(DateTime(2026, 1, 20)));
    final value = Habit(
      id: 1, name: 'X', description: '', icon: 'savings', color: 0,
      frequency: HabitFrequency.weeklyDays, scheduledDays: {1, 3, 5}, targetPerWeek: 3,
      startDate: start, endDate: null, isActive: true, createdAt: now, completedDates: {},
    );
    final next = nextReminderOccurrence(habit: value, reminder: reminder, now: now, weekday: 3);
    expect(next, DateTime(2026, 1, 21, 19));
    final elapsed = nextReminderOccurrence(
      habit: value,
      reminder: reminder.copyWith(startDate: start),
      now: DateTime(2026, 1, 14, 20),
      weekday: 3,
    );
    expect(elapsed, DateTime(2026, 1, 21, 19));
  });

  test('concurrent sync operations are serialized without duplicate IDs', () async {
    final id = await createHabit();
    await Future.wait([service.syncHabit(id), service.syncAll(), service.syncHabit(id)]);
    expect(gateway.scheduled, hasLength(5));
  });

  test('notification payload opens the matching habit once on cold launch', () async {
    gateway.payloadOnLaunch = 'habit:42';
    await service.initialize();
    expect(service.takePendingHabitId(), 42);
    expect(service.takePendingHabitId(), isNull);
    gateway.payloadOnLaunch = 'not-a-habit';
    await service.initialize();
    expect(service.takePendingHabitId(), isNull);
  });

  test('stable IDs stay inside Android signed 31-bit range', () {
    expect(stableNotificationId('1:week:1'), stableNotificationId('1:week:1'));
    expect(stableNotificationId('1:week:1'), inInclusiveRange(0, 0x7fffffff));
  });
}
