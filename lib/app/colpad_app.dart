import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_page.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007E70), brightness: Brightness.light, surface: const Color(0xFFF4F8F6)),
        scaffoldBackgroundColor: const Color(0xFFF4F8F6),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF4F8F6)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF51E3C0), brightness: Brightness.dark, surface: const Color(0xFF101F20)),
        scaffoldBackgroundColor: const Color(0xFF091516),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF091516)),
      ),
      home: const SavingsHomePage(),
    );
  }
}