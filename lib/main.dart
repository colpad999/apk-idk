import 'package:flutter/material.dart';

void main() {
  runApp(const ColpadApp());
}

class ColpadApp extends StatelessWidget {
  const ColpadApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF071411);
    const surface = Color(0xFF10221D);
    const accent = Color(0xFF55F2B3);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Colpad',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: surface,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF55F2B3);
    const muted = Color(0xFF9BB5AA);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF55F2B3), Color(0xFF1C9B78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Color(0xFF06130F), size: 29),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COLPAD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
                    SizedBox(height: 2),
                    Text('ANDROID STARTER', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1.8)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accent.withValues(alpha: .25)),
                  ),
                  child: const Text('READY', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
              ],
            ),
            const SizedBox(height: 36),
            const Text('Build something\nremarkable.', style: TextStyle(fontSize: 35, height: 1.13, fontWeight: FontWeight.w800, letterSpacing: -1.1)),
            const SizedBox(height: 13),
            const Text('A clean, modern Flutter foundation for your next Android project.', style: TextStyle(color: muted, fontSize: 15, height: 1.55)),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF17382D), Color(0xFF10221D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: accent.withValues(alpha: .20)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.rocket_launch_rounded, color: accent, size: 28),
                  SizedBox(height: 18),
                  Text('Your next idea starts here', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Push your code to GitHub. GitHub Actions builds the APK for you.', style: TextStyle(color: muted, height: 1.5, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('PROJECT BASELINE', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
            const SizedBox(height: 12),
            const _InfoTile(icon: Icons.android_rounded, title: 'Android 16 ready', subtitle: 'Target SDK 36 · Minimum SDK 24'),
            const _InfoTile(icon: Icons.speed_rounded, title: 'Flutter release build', subtitle: 'Compiled ahead-of-time for release'),
            const _InfoTile(icon: Icons.cloud_done_rounded, title: 'Cloud build workflow', subtitle: 'APK artifact from GitHub Actions'),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => showAboutDialog(context: context, applicationName: 'Colpad Android Starter', applicationVersion: '1.0.0', applicationLegalese: 'Crafted by Colpad ⚡'),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('About this project'),
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: const Color(0xFF06130F), minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 22),
            const Center(child: Text('CRAFTED BY COLPAD ⚡', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2.0, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF55F2B3);
    const muted = Color(0xFF9BB5AA);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF10221D), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .055))),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent, size: 23)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))])),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}
