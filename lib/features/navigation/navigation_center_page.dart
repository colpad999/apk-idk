import 'package:flutter/material.dart';

import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';
import '../backup/backup_page.dart';
import '../budget/budget_page.dart';
import '../calendar/activity_calendar_page.dart';
import '../financial_calendar/financial_calendar_page.dart';
import '../money_journal/money_journal_page.dart';
import '../jars/virtual_jars_page.dart';
import '../challenges/saving_challenges_page.dart';
import '../settings/sound_settings_page.dart';
import '../settings/profile_page.dart';
import '../reminders/reminder_history_page.dart';
import '../habits/habit_settings_page.dart';
import '../habits/habits_page.dart';
import '../life/life_journal_page.dart';
import '../insights/life_insights_page.dart';
import '../simulator/savings_simulator_page.dart';
import '../wishlist/wishlist_page.dart';

class NavigationCenterPage extends StatefulWidget {
  const NavigationCenterPage({required this.openTab, super.key});
  final ValueChanged<int> openTab;
  @override
  State<NavigationCenterPage> createState() => _NavigationCenterPageState();
}

class _NavigationCenterPageState extends State<NavigationCenterPage> {
  String _query = '';

  void _tab(int index) {
    Navigator.pop(context);
    widget.openTab(index);
  }
  void _page(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final p = NeoPalette.of(context);
    final items = <(String, String, IconData, VoidCallback?)>[
      ('FINANCIAL', 'Dashboard', Icons.home_outlined, () => _tab(0)),
      ('FINANCIAL', 'Savings Goals', Icons.flag_outlined, () => _tab(1)),
      ('FINANCIAL', 'Transactions', Icons.receipt_long_outlined, () => _tab(2)),
      ('FINANCIAL', 'Income Tracker', Icons.trending_up, () => _tab(0)),
      ('FINANCIAL', 'Budget Planner', Icons.pie_chart_outline, () => _page(Scaffold(appBar: AppBar(title: const Text('BUDGET PLANNER')), body: const BudgetPage()))),
      ('FINANCIAL', 'Statistics', Icons.bar_chart, () => _tab(3)),
      ('FINANCIAL', 'Virtual Money Jar', Icons.savings_outlined, () => _page(const VirtualJarsPage())),
      ('PRODUCTIVITY', 'Habit Tracker', Icons.checklist, () => _page(const HabitsPage())),
      ('PRODUCTIVITY', 'Kalender aktivitas', Icons.calendar_month, () => _page(const ActivityCalendarPage())),
      ('PRODUCTIVITY', 'Pencapaian & statistik mood', Icons.emoji_events_outlined, () => _page(const LifeInsightsPage())),
      ('PRODUCTIVITY', 'Saving Challenge', Icons.emoji_events_outlined, () => _page(const SavingChallengesPage())),
      ('PRODUCTIVITY', 'Wishlist', Icons.favorite_border, () => _page(const WishlistPage())),
      ('PRODUCTIVITY', 'Financial Calendar', Icons.calendar_month, () => _page(const FinancialCalendarPage())),
      ('PRODUCTIVITY', 'Jurnal harian & mood', Icons.book_outlined, () => _page(const LifeJournalPage())),
      ('PRODUCTIVITY', 'Money Journal', Icons.book_outlined, () => _page(const MoneyJournalPage())),
      ('PRODUCTIVITY', 'Simulasi tabungan', Icons.calculate_outlined, () => _page(const SavingsSimulatorPage())),
      ('REMINDERS', 'Alarm manual stop', Icons.alarm, () => _page(const SoundSettingsPage())),
      ('REMINDERS', 'Pengingat habit', Icons.notifications_outlined, () => _page(const HabitsPage())),
      ('REMINDERS', 'Reminder History', Icons.history, () => _page(const ReminderHistoryPage())),
      ('DATA', 'Backup, Restore & Export CSV', Icons.backup_outlined, () => _page(const BackupPage())),
      ('DATA', 'Import Data', Icons.file_upload_outlined, () => _page(const BackupPage())),
      ('SETTINGS', 'Pengaturan habit & notifikasi', Icons.notifications_active_outlined, () => _page(const HabitSettingsPage())),
      ('SETTINGS', 'Pengaturan & About', Icons.tune, () => _tab(4)),
      ('SETTINGS', 'Profile', Icons.person_outline, () => _page(const ProfilePage())),
      ('SETTINGS', 'Sound Settings', Icons.volume_up_outlined, () => _page(const SoundSettingsPage())),
    ];
    final filtered = items.where((item) => '${item.$1} ${item.$2}'.toLowerCase().contains(_query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('PUSAT FITUR')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 30), children: [
        Text('Temukan fiturnya.', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Cari fitur')),
        const SizedBox(height: 18),
        if (filtered.isEmpty) const NeoCard(child: Text('Fitur tidak ditemukan.')),
        for (final section in ['FINANCIAL', 'PRODUCTIVITY', 'REMINDERS', 'DATA', 'SETTINGS']) ...[
          if (filtered.any((item) => item.$1 == section)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: switch (section) { 'FINANCIAL' => p.primary, 'PRODUCTIVITY' => p.secondary, 'REMINDERS' => p.accent, 'DATA' => p.highlight, _ => p.primary },
                border: Border.all(color: p.border, width: 2),
                boxShadow: [BoxShadow(color: p.shadow, offset: const Offset(3, 3))],
              ),
              child: Text(section, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ), const SizedBox(height: 12),
            NeoCard(shadow: false, padding: EdgeInsets.zero, child: Column(children: [
              for (final item in filtered.where((item) => item.$1 == section))
                ListTile(
                  leading: Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: switch (section) { 'FINANCIAL' => p.primary, 'PRODUCTIVITY' => p.secondary, 'REMINDERS' => p.accent, 'DATA' => p.highlight, _ => p.primary }, border: Border.all(color: p.border, width: 2), borderRadius: BorderRadius.circular(6)),
                    child: Icon(item.$3, color: p.text, size: 22)),
                  title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: item.$4 == null ? const Text('Belum tersedia') : item.$2 == 'Import Data' ? const Text('Pulihkan backup JSON Colpad ke database kosong') : item.$2 == 'Income Tracker' ? const Text('Lihat sumber pemasukan di Dashboard') : null,
                  trailing: item.$4 == null ? null : const Icon(Icons.chevron_right),
                  onTap: item.$4,
                ),
            ])),
            const SizedBox(height: 20),
          ],
        ],
      ]),
    );
  }
}
