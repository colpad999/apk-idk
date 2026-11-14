import '../core/utils/civil_date.dart';

enum HabitFrequency { daily, weeklyDays, timesPerWeek }

enum ReminderRecurrence { daily, weekly }

const allWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
const weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const defaultReminderTitle = '⚡ Waktunya menabung!';
const defaultReminderBody =
    'Sempatkan mencatat tabungan hari ini dan lanjutkan progres tujuanmu. '
    'Kalau dana belum tersedia, cukup tinjau rencanamu—tidak perlu memaksakan setoran.';

class HabitReminder {
  const HabitReminder({
    this.id,
    required this.minutes,
    required this.days,
    required this.startDate,
    this.recurrence = ReminderRecurrence.weekly,
    this.enabled = true,
    this.sound = true,
    this.vibration = true,
    this.title = defaultReminderTitle,
    this.body = defaultReminderBody,
  });

  /// Database identity is assigned once and retained when a schedule is edited.
  final int? id;
  final int minutes;
  final Set<int> days;
  final CivilDate startDate;
  final ReminderRecurrence recurrence;
  final bool enabled, sound, vibration;
  final String title, body;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';

  HabitReminder copyWith({
    int? minutes,
    Set<int>? days,
    CivilDate? startDate,
    ReminderRecurrence? recurrence,
    bool? enabled,
    bool? sound,
    bool? vibration,
    String? title,
    String? body,
  }) =>
      HabitReminder(
        id: id,
        minutes: minutes ?? this.minutes,
        days: days ?? this.days,
        startDate: startDate ?? this.startDate,
        recurrence: recurrence ?? this.recurrence,
        enabled: enabled ?? this.enabled,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        title: title ?? this.title,
        body: body ?? this.body,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'minutes': minutes,
        'days': days.toList()..sort(),
        'start_date': startDate.key,
        'recurrence': recurrence.name,
        'enabled': enabled,
        'sound': sound,
        'vibration': vibration,
        'title': title,
        'body': body,
      };
}

class HabitPause {
  const HabitPause({required this.startDate, this.endDate});
  final CivilDate startDate;

  /// Exclusive: the day on which a habit is reactivated is an opportunity again.
  final CivilDate? endDate;

  bool contains(CivilDate date) =>
      date.isAtOrAfter(startDate) &&
      (endDate == null || date.isBefore(endDate!));
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.frequency,
    required this.scheduledDays,
    required this.targetPerWeek,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.completedDates,
    this.reminders = const [],
    this.pauses = const [],
  });

  final int id;
  final String name, description, icon;
  final int color, targetPerWeek;
  final HabitFrequency frequency;
  final Set<int> scheduledDays;
  final CivilDate startDate;
  final CivilDate? endDate;
  final bool isActive;
  final DateTime createdAt;
  final Set<String> completedDates;
  final List<HabitReminder> reminders;
  final List<HabitPause> pauses;

  bool get isFlexible => frequency == HabitFrequency.timesPerWeek;
  bool get hasReminder => reminders.any((reminder) => reminder.enabled);

  bool isPausedOn(DateTime date) =>
      pauses.any((pause) => pause.contains(CivilDate.from(date)));

  bool isInRange(DateTime date) {
    final day = CivilDate.from(date);
    return day.isAtOrAfter(startDate) &&
        (endDate == null || day.isAtOrBefore(endDate!));
  }

  bool isScheduled(DateTime date) =>
      isInRange(date) &&
      (frequency != HabitFrequency.weeklyDays ||
          scheduledDays.contains(date.weekday));

  /// An opportunity excludes pauses, but isScheduled describes the base schedule.
  bool isOpportunity(DateTime date) =>
      isScheduled(date) && !isPausedOn(date);

  String dateKey(DateTime date) => CivilDate.dateKey(date);
  bool isComplete(DateTime date) => completedDates.contains(dateKey(date));
  int get completionCount => completedDates.length;

  String get frequencyLabel => switch (frequency) {
        HabitFrequency.daily => 'Setiap hari',
        HabitFrequency.weeklyDays =>
          (scheduledDays.toList()..sort())
              .map((day) => weekdayLabels[day - 1])
              .join(', '),
        HabitFrequency.timesPerWeek => '$targetPerWeek× per minggu',
      };
}

void validateWeekdays(Set<int> days, {bool allowEmpty = false}) {
  if ((!allowEmpty && days.isEmpty) ||
      days.any((day) => day < 1 || day > 7)) {
    throw ArgumentError('Pilih hari Senin sampai Minggu dengan benar.');
  }
}

void validateReminder(HabitReminder reminder) {
  if (reminder.minutes < 0 || reminder.minutes >= 1440) {
    throw ArgumentError('Waktu pengingat harus antara 00.00 dan 23.59.');
  }
  validateWeekdays(reminder.days);
  if (reminder.title.trim().isEmpty || reminder.title.length > 100) {
    throw ArgumentError('Judul pengingat wajib diisi, maksimal 100 karakter.');
  }
  if (reminder.body.trim().isEmpty || reminder.body.length > 500) {
    throw ArgumentError('Pesan pengingat wajib diisi, maksimal 500 karakter.');
  }
}
