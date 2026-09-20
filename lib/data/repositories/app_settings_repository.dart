import 'package:drift/drift.dart';

import '../database/app_database.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._database);

  final AppDatabase _database;

  Future<AppSetting?> getSettings() async {
    return (_database.select(_database.appSettings)
          ..where((setting) => setting.id.equals(1)))
        .getSingleOrNull();
  }

  Future<double> getOpeningBalance() async {
    final settings = await getSettings();

    return settings?.openingBalance ?? 0;
  }

  Future<DateTime?> getOpeningBalanceDate() async {
    final settings = await getSettings();

    return settings?.openingBalanceDate;
  }

  Future<void> setOpeningBalance({
    required double amount,
    required DateTime date,
  }) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            openingBalance: Value(amount),
            openingBalanceDate: Value(date),
          ),
        );
  }
}