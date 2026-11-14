/// A calendar identity in the device's local civil calendar, not an instant.
///
/// Arithmetic deliberately uses calendar constructors instead of adding 24-hour
/// durations. This keeps streaks and completion keys stable across DST changes.
extension type const CivilDate(DateTime value) {
  CivilDate.from(DateTime value)
      : value = DateTime(value.year, value.month, value.day);

  CivilDate.parse(String key) : value = DateTime.parse(key) {
    if (key != dateKey(value)) {
      throw FormatException('Tanggal kalender tidak valid', key);
    }
  }

  static CivilDate today() => CivilDate.from(DateTime.now());

  String get key => dateKey(value);
  int get year => value.year;
  int get month => value.month;
  int get day => value.day;
  int get weekday => value.weekday;

  CivilDate addDays(int days) =>
      CivilDate(DateTime(year, month, day + days));
  CivilDate get nextDay => addDays(1);
  CivilDate get previousDay => addDays(-1);
  CivilDate get weekStart => addDays(1 - weekday);
  CivilDate get monthStart => CivilDate(DateTime(year, month));
  CivilDate get nextMonth => CivilDate(DateTime(year, month + 1));

  bool isBefore(CivilDate other) => value.isBefore(other.value);
  bool isAfter(CivilDate other) => value.isAfter(other.value);
  bool isAtOrAfter(CivilDate other) => !isBefore(other);
  bool isAtOrBefore(CivilDate other) => !isAfter(other);

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static CivilDate min(CivilDate a, CivilDate b) => a.isBefore(b) ? a : b;
  static CivilDate max(CivilDate a, CivilDate b) => a.isAfter(b) ? a : b;
}
