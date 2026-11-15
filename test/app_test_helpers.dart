import 'package:drift/native.dart';
import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/database/database_factory.dart';
import 'package:expense_tracker/core/sync/sync_errors.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_contract.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sync backend that behaves like a signed-out device: every run
/// stops silently and leaves work pending, with no retry timer.
class SignedOutBackend implements SheetsV2SyncBackend {
  @override
  Future<String> resolveSpreadsheetId() async =>
      throw const SheetsNotSignedInException();

  @override
  Future<void> verifyV2Identity(String spreadsheetId) async {}

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async => const [];

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {}

  @override
  Future<List<SheetV2Row>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async => const [];

  @override
  Future<void> appendRow(
    String spreadsheetId,
    int year,
    SheetV2Row row,
  ) async {}

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetV2Row row,
  ) async {}
}

/// Seeded in-memory services, offline. Widget tests must call
/// [closeServices] in the test body: an open Drift connection leaves a
/// Timer pending in the widget-test binding.
Future<AppServices> createTestServices() async {
  final database = await const AppDatabaseV2Factory().create(
    executor: NativeDatabase.memory(),
  );
  return AppServices(database: database, syncBackend: SignedOutBackend());
}

Future<void> closeServices(WidgetTester tester, AppServices services) async {
  // Unmount first so stream subscriptions end before the database closes.
  await tester.pumpWidget(const SizedBox.shrink());
  await services.close();
  await tester.pumpAndSettle();
}

/// Pumps [child] inside an [AppScope] with a tall viewport.
Future<void> pumpWithServices(
  WidgetTester tester,
  AppServices services,
  Widget child,
) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}
