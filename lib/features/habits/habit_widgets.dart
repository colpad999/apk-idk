import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../data/habit.dart';
import '../../shared/neo_components.dart';

const habitIconOptions = <String, IconData>{
  'savings': Icons.savings_outlined,
  'edit_note': Icons.edit_note_outlined,
  'flag': Icons.flag_outlined,
  'account_balance_wallet': Icons.account_balance_wallet_outlined,
  'school': Icons.school_outlined,
  'checklist': Icons.checklist_rounded,
  'self_improvement': Icons.self_improvement_outlined,
  'track_changes': Icons.track_changes_outlined,
};

const habitColorOptions = <int>[
  0xFFB8F56A,
  0xFFFFD84D,
  0xFFFF8064,
  0xFFA7C7FF,
  0xFFD7B8FF,
];

IconData habitIcon(String key) => habitIconOptions[key] ?? Icons.savings_outlined;

class HabitIconBadge extends StatelessWidget {
  const HabitIconBadge({required this.habit, this.size = 46, super.key});
  final Habit habit;
  final double size;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(habit.color),
        border: Border.all(color: palette.border, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(habitIcon(habit.icon), color: const Color(0xFF171717), size: size * .52),
    );
  }
}

class NeoWeekdayPicker extends StatelessWidget {
  const NeoWeekdayPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var day = 1; day <= 7; day++)
          SizedBox(
            width: 42,
            height: 42,
            child: Material(
              color: selected.contains(day) ? palette.primary : palette.surface,
              child: InkWell(
                onTap: !enabled
                    ? null
                    : () {
                        final next = {...selected};
                        if (!next.remove(day)) next.add(day);
                        if (next.isNotEmpty) onChanged(next);
                      },
                child: Ink(
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Text(weekdayLabels[day - 1],
                        style: TextStyle(
                            color: selected.contains(day)
                                ? const Color(0xFF171717)
                                : palette.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NeoDateField extends StatelessWidget {
  const NeoDateField({
    required this.label,
    required this.value,
    required this.onPicked,
    this.firstDate,
    this.lastDate,
    super.key,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final DateTime? firstDate, lastDate;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final first = firstDate ?? DateTime(2000);
          final last = lastDate ?? DateTime(2100);
          var initial = value ?? now;
          if (initial.isBefore(first)) initial = first;
          if (initial.isAfter(last)) initial = last;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
          );
          if (picked != null) onPicked(CivilDate.from(picked).value);
        },
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(value == null
              ? label
              : '$label · ${DateFormat('d MMM yyyy', 'id_ID').format(value!)}'),
        ),
      );
}

class NeoEmptyState extends StatelessWidget {
  const NeoEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });
  final IconData icon;
  final String title, message, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return NeoCard(
      color: palette.highlight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 34, color: const Color(0xFF171717)),
        const SizedBox(height: 12),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: const Color(0xFF171717))),
        const SizedBox(height: 7),
        Text(message, style: const TextStyle(color: Color(0xFF171717))),
        const SizedBox(height: 15),
        FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionLabel)),
      ]),
    );
  }
}

class HabitCompletionButton extends StatelessWidget {
  const HabitCompletionButton({
    required this.habit,
    required this.date,
    required this.onPressed,
    super.key,
  });
  final Habit habit;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final done = habit.isComplete(date);
    final eligible = habit.isActive && habit.isOpportunity(date) &&
        !CivilDate.from(date).isAfter(CivilDate.today());
    final label = done
        ? 'Selesai'
        : !habit.isActive
            ? 'Dijeda'
            : !habit.isScheduled(date)
                ? 'Bukan jadwal'
                : habit.isPausedOn(date)
                    ? 'Dijeda'
                    : 'Tandai selesai';
    return TweenAnimationBuilder<double>(
      key: ValueKey('${habit.id}-${CivilDate.dateKey(date)}-$done'),
      tween: Tween(begin: done ? .92 : 1, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: done
          ? OutlinedButton.icon(
              onPressed: eligible ? onPressed : null,
              icon: const Icon(Icons.check_circle_outline, size: 19),
              label: Text(label))
          : FilledButton.icon(
              onPressed: eligible ? onPressed : null,
              icon: const Icon(Icons.circle_outlined, size: 18),
              label: Text(label)),
    );
  }
}
