import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/colpad_app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final container = ProviderContainer();
  // Initialization never requests notification permission on first launch and
  // never blocks the offline ledger if the notification platform is unavailable.
  await container.read(habitNotificationServiceProvider).initialize();
  runApp(UncontrolledProviderScope(
    container: container,
    child: const ColpadApp(),
  ));
}
