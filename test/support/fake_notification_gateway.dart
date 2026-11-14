import 'package:apk_idk/services/habit_notification_service.dart';

class FakeHabitNotificationGateway implements HabitNotificationGateway {
  final scheduled = <int, HabitNotificationRequest>{};
  final shown = <HabitNotificationRequest>[];
  final cancelledHabits = <int>[];
  bool permission = true;
  int cancelAllCount = 0, refreshCount = 0;
  String? payloadOnLaunch;

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {}
  @override
  Future<String?> launchPayload() async => payloadOnLaunch;
  @override
  Future<bool> areNotificationsEnabled() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> refreshTimezone() async { refreshCount++; }
  @override
  Future<void> cancelHabit(int habitId) async {
    cancelledHabits.add(habitId);
    scheduled.removeWhere((_, request) => request.habitId == habitId);
  }
  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }
  @override
  Future<void> schedule(HabitNotificationRequest request) async {
    scheduled[request.id] = request;
  }
  @override
  Future<void> showTest(HabitNotificationRequest request) async {
    shown.add(request);
  }
}
