import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/savings_home_page.dart';
import 'theme/neo_theme.dart';
import 'providers.dart';

class ColpadApp extends ConsumerWidget {
  const ColpadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Colpad Savings',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: NeoTheme.light(),
      darkTheme: NeoTheme.dark(),
      home: const SavingsHomePage(),
    );
  }
}
