import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/habits/habit_detail_page.dart';
import '../features/home/savings_home_page.dart';
import 'providers.dart';
import 'theme/neo_theme.dart';

class ColpadApp extends ConsumerStatefulWidget {
  const ColpadApp({super.key});
  @override
  ConsumerState<ColpadApp> createState() => _ColpadAppState();
}

class _ColpadAppState extends ConsumerState<ColpadApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(habitNotificationServiceProvider);
    notifications.onHabitSelected = _openHabit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = notifications.takePendingHabitId();
      if (pending != null) _openHabit(pending);
      _reconcileNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(habitNotificationServiceProvider).onHabitSelected = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-read the local calendar and IANA zone after clock/zone changes or
      // a long background period. Reconciliation is serialized and idempotent.
      ref.invalidate(habitsProvider);
      _reconcileNotifications();
    }
  }

  Future<void> _reconcileNotifications() async {
    final service = ref.read(habitNotificationServiceProvider);
    try {
      await service.refreshTimezone();
      await service.syncAll();
    } catch (_) {
      // The habit notification settings page exposes retry/status. Accounting
      // remains usable even when alarms or timezone detection are unavailable.
    }
  }

  void _openHabit(int habitId) {
    _navigatorKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => HabitDetailPage(habitId: habitId)));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Colpad Savings',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      themeMode: themeMode,
      theme: NeoTheme.light(),
      darkTheme: NeoTheme.dark(),
      home: const SavingsHomePage(),
    );
  }
}
