import 'package:apk_idk/app/colpad_app.dart';
import 'package:apk_idk/app/providers.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_notification_gateway.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));
  testWidgets('dashboard and transaction form fit common sizes and landscape', (tester) async {
    final sizes = [const Size(320, 700), const Size(360, 780), const Size(393, 852), const Size(412, 915), const Size(800, 1100), const Size(700, 320)];
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(ProviderScope(overrides: [
        savingsDatabaseProvider.overrideWith((ref) {
          final db = SavingsDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        habitNotificationGatewayProvider.overrideWith((ref) => FakeHabitNotificationGateway()),
      ], child: const ColpadApp()));
      await tester.pumpAndSettle();
      expect(find.text('COLPAD SAVINGS'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size dashboard');
      await tester.tap(find.text('Catat'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah transaksi'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size transaction form');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
