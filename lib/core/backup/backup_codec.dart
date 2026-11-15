// Full backup and restore of the V2 database (Module 3).
//
// Format (JSON, UTF-8):
//   { "format": "expense-tracker-backup", "formatVersion": 1,
//     "schemaVersion": <db schema>, "createdAt": <ISO-8601 UTC>,
//     "tables": { "<table>": { "columns": [...], "rows": [[...], ...] } } }
//
// Values are the raw SQLite column values (integers, text, null), so
// amounts stay exact integer paise and nothing passes through `double`.
// Every table except in-app notifications is included, generically, so
// tables added by later modules are covered without changes here.
//
// SECURITY: backups are NOT encrypted (owner decision, ADR-011 v6). The
// UI must show the plain-file warning before creating one.
//
// Restore replaces all backed-up tables in ONE database transaction with
// deferred foreign keys; any validation failure rolls everything back.
// Table and column names from the file are checked against the live
// schema before they are used in SQL. Restored transactions are queued
// for Google Sheets sync so the V2 sheet converges by UUID.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/v2/app_database_v2.dart';

const String backupFormatName = 'expense-tracker-backup';
const int backupFormatVersion = 1;

/// Tables never written to a backup and never touched by restore.
const Set<String> _excludedTables = {'notifications'};

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

class RestoreSummary {
  const RestoreSummary({
    required this.createdAt,
    required this.schemaVersion,
    required this.rowCounts,
  });

  final DateTime? createdAt;
  final int schemaVersion;
  final Map<String, int> rowCounts;

  int get accounts => rowCounts['accounts'] ?? 0;
  int get transactions => rowCounts['financial_transactions'] ?? 0;
}

class BackupCodec {
  BackupCodec(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabaseV2 _database;
  final DateTime Function() _clock;

  Iterable<TableInfo<Table, Object?>> get _tables => _database.allTables.where(
    (t) => !_excludedTables.contains(t.actualTableName),
  );

  /// Serialises every backed-up table inside one read transaction.
  Future<String> export() async {
    final tables = <String, Object?>{};
    await _database.transaction(() async {
      for (final table in _tables) {
        final columns = table.$columns.map((c) => c.name).toList();
        final rows = await _database
            .customSelect(
              'SELECT ${columns.map(_quote).join(', ')} '
              'FROM ${_quote(table.actualTableName)} ORDER BY rowid',
              readsFrom: {table},
            )
            .get();
        tables[table.actualTableName] = {
          'columns': columns,
          'rows': [
            for (final row in rows) [for (final c in columns) row.data[c]],
          ],
        };
      }
    });
    return const JsonEncoder.withIndent(' ').convert({
      'format': backupFormatName,
      'formatVersion': backupFormatVersion,
      'schemaVersion': _database.schemaVersion,
      'createdAt': _clock().toUtc().toIso8601String(),
      'tables': tables,
    });
  }

  /// Reads and validates [json] without changing anything.
  RestoreSummary inspect(String json) {
    final parsed = _parse(json);
    return RestoreSummary(
      createdAt: parsed.createdAt,
      schemaVersion: parsed.schemaVersion,
      rowCounts: {
        for (final entry in parsed.tables.entries)
          entry.key: entry.value.rows.length,
      },
    );
  }

  /// Replaces all backed-up data with the contents of [json].
  Future<RestoreSummary> restore(String json) async {
    final parsed = _parse(json);
    await _database.transaction(() async {
      await _database.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in _tables.toList().reversed) {
        await _database.customStatement(
          'DELETE FROM ${_quote(table.actualTableName)}',
        );
      }
      for (final table in _tables) {
        final data = parsed.tables[table.actualTableName];
        if (data == null || data.rows.isEmpty) {
          continue;
        }
        final sql =
            'INSERT INTO ${_quote(table.actualTableName)} '
            '(${data.columns.map(_quote).join(', ')}) '
            'VALUES (${List.filled(data.columns.length, '?').join(', ')})';
        for (final row in data.rows) {
          await _database.customStatement(sql, row);
        }
      }
      await _verifyLedger();
      await _database.customStatement(
        "UPDATE financial_transactions SET sync_status = 'pending'",
      );
      final problems = await _database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (problems.isNotEmpty) {
        throw const BackupFormatException(
          'The backup contains broken references.',
        );
      }
    });
    _database.notifyUpdates({
      for (final table in _tables) TableUpdate.onTable(table),
    });
    return RestoreSummary(
      createdAt: parsed.createdAt,
      schemaVersion: parsed.schemaVersion,
      rowCounts: {
        for (final entry in parsed.tables.entries)
          entry.key: entry.value.rows.length,
      },
    );
  }

  /// Every transaction's postings must still balance after restore.
  Future<void> _verifyLedger() async {
    final unbalanced = await _database.customSelect('''
      SELECT transaction_id FROM postings
      GROUP BY transaction_id
      HAVING SUM(CASE WHEN direction = 'debit' THEN amount_minor_units ELSE 0 END)
          != SUM(CASE WHEN direction = 'credit' THEN amount_minor_units ELSE 0 END)
      ''').get();
    if (unbalanced.isNotEmpty) {
      throw const BackupFormatException(
        'The backup contains unbalanced ledger entries.',
      );
    }
  }

  _ParsedBackup _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupFormatException('This file is not a backup.');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != backupFormatName) {
      throw const BackupFormatException('This file is not a backup.');
    }
    if (decoded['formatVersion'] != backupFormatVersion) {
      throw const BackupFormatException(
        'This backup format is not supported by this app version.',
      );
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion < 8) {
      throw const BackupFormatException('This backup has no valid version.');
    }
    if (schemaVersion > _database.schemaVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. Update the '
        'app, then restore again.',
      );
    }
    final createdAt = DateTime.tryParse('${decoded['createdAt']}');
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, Object?>) {
      throw const BackupFormatException('The backup has no data.');
    }
    final known = {
      for (final table in _tables)
        table.actualTableName: table.$columns.map((c) => c.name).toSet(),
    };
    final tables = <String, _TableData>{};
    for (final entry in rawTables.entries) {
      final columnsAllowed = known[entry.key];
      if (columnsAllowed == null) {
        throw BackupFormatException('Unknown table in backup: ${entry.key}.');
      }
      final value = entry.value;
      if (value is! Map<String, Object?> ||
          value['columns'] is! List ||
          value['rows'] is! List) {
        throw BackupFormatException('Malformed table: ${entry.key}.');
      }
      final columns = (value['columns'] as List).map((c) => '$c').toList();
      for (final column in columns) {
        if (!columnsAllowed.contains(column)) {
          throw BackupFormatException(
            'Unknown column in backup: ${entry.key}.$column.',
          );
        }
      }
      final rows = <List<Object?>>[];
      for (final row in value['rows'] as List) {
        if (row is! List || row.length != columns.length) {
          throw BackupFormatException('Malformed row in ${entry.key}.');
        }
        for (final cell in row) {
          if (cell != null && cell is! int && cell is! String) {
            throw BackupFormatException(
              'Unexpected value type in ${entry.key}.',
            );
          }
        }
        rows.add(List<Object?>.from(row));
      }
      tables[entry.key] = _TableData(columns, rows);
    }
    if (!tables.containsKey('financial_transactions') ||
        !tables.containsKey('accounts')) {
      throw const BackupFormatException('The backup is incomplete.');
    }
    return _ParsedBackup(schemaVersion, createdAt, tables);
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';
}

class _TableData {
  const _TableData(this.columns, this.rows);

  final List<String> columns;
  final List<List<Object?>> rows;
}

class _ParsedBackup {
  const _ParsedBackup(this.schemaVersion, this.createdAt, this.tables);

  final int schemaVersion;
  final DateTime? createdAt;
  final Map<String, _TableData> tables;
}
