// V2 Google Sheets sync engine (blueprint sections 8.1-8.3).
//
// Pure Dart. Same rules as the V1 engine (`sheets_sync.dart`), applied
// to A:Y rows of the distinct V2 spreadsheet:
// - UUID is the only row identity; upsert in place, never duplicate.
// - Soft-deleted transactions keep their row with Deleted=TRUE; a
//   transaction deleted before its first sync writes nothing.
// - A year move tombstones old-year rows before writing the new row.
// - Worksheet discovery is all-or-nothing; duplicate UUID rows are
//   reported and never merged.
// - Acknowledgement is conditional on the uploaded revision.
// Additionally, before any read or write the backend must verify the
// spreadsheet's V2 identity (`_meta` worksheet), and a transaction
// whose amount exceeds the numeric-cell limit or whose data cannot be
// mapped stays pending and is reported.

import '../sheets_sync.dart'
    show SheetsAuthorizationMissingException, SheetsNotSignedInException;
import 'sheets_v2_contract.dart';
import 'sheets_v2_mapper.dart';

/// Pending local work for one transaction.
///
/// [syncRevision] and [status] are local-only acknowledgement tokens
/// and never reach the sheet.
class V2SyncItem {
  const V2SyncItem({
    required this.localId,
    required this.syncRevision,
    required this.status,
    required this.source,
  });

  final int localId;
  final int syncRevision;
  final String status;
  final SheetV2Source source;

  String get uuid => source.uuid;
  bool get deleted => source.deleted;
  int get year => source.year;
}

/// The spreadsheet failed V2 identity verification (no `_meta` on a
/// spreadsheet that already has data, or a different schema version).
/// Nothing is written.
class SheetsV2IdentityException implements Exception {
  const SheetsV2IdentityException(this.message);

  final String message;

  @override
  String toString() => 'SheetsV2IdentityException: $message';
}

/// Remote operations the V2 engine needs.
abstract class SheetsV2SyncBackend {
  /// Finds or creates the V2 spreadsheet (distinct title + Drive
  /// marker). Never resolves the V1 spreadsheet.
  Future<String> resolveSpreadsheetId();

  /// Verifies the `_meta` worksheet records sheet schema version 2,
  /// creating it only on a spreadsheet without data. Throws
  /// [SheetsV2IdentityException] otherwise.
  Future<void> verifyV2Identity(String spreadsheetId);

  /// Must throw on failure (all-or-nothing discovery).
  Future<List<int>> listYearSheets(String spreadsheetId);

  /// Creates the year worksheet with the A:Y header when missing, or
  /// writes/extends the header in place. Never touches data rows.
  Future<void> ensureYearSheet(String spreadsheetId, int year);

  /// Data rows (header excluded), empty when the worksheet is missing.
  Future<List<SheetV2Row>> readYearSheet(String spreadsheetId, int year);

  Future<void> appendRow(String spreadsheetId, int year, SheetV2Row row);

  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetV2Row row,
  );
}

class V2SyncRunResult {
  const V2SyncRunResult({
    required this.syncedUuids,
    required this.failedUuids,
    this.duplicateUuids = const <String>[],
    this.unsyncableUuids = const <String>[],
  });

  final List<String> syncedUuids;

  /// Every UUID left pending, including duplicates and unsyncable.
  final List<String> failedUuids;

  /// Ambiguous duplicate rows in Sheets; need manual cleanup.
  final List<String> duplicateUuids;

  /// Amount above the Sheets limit or incomplete data; stays pending
  /// until the local data changes. Never truncated or rounded.
  final List<String> unsyncableUuids;
}

class SheetsV2SyncEngine {
  Future<V2SyncRunResult> syncAll({
    required List<V2SyncItem> pending,
    required SheetsV2SyncBackend backend,
    required Future<bool> Function(V2SyncItem item) onSynced,
  }) async {
    if (pending.isEmpty) {
      return const V2SyncRunResult(syncedUuids: [], failedUuids: []);
    }

    final spreadsheetId = await backend.resolveSpreadsheetId();
    await backend.verifyV2Identity(spreadsheetId);
    final existingYears = await backend.listYearSheets(spreadsheetId);

    final rowsByYear = <int, List<SheetV2Row>>{};
    for (final year in existingYears) {
      rowsByYear[year] = await backend.readYearSheet(spreadsheetId, year);
    }

    final ensuredYears = <int>{};
    Future<void> prepareYear(int year) async {
      if (ensuredYears.contains(year)) {
        return;
      }
      await backend.ensureYearSheet(spreadsheetId, year);
      ensuredYears.add(year);
      rowsByYear[year] = await backend.readYearSheet(spreadsheetId, year);
    }

    SheetV2Row? findRow(int year, String uuid) {
      for (final row in rowsByYear[year] ?? const <SheetV2Row>[]) {
        if (row.uuid == uuid) {
          return row;
        }
      }
      return null;
    }

    List<int> yearsWithRow(String uuid) => <int>[
      for (final year in existingYears)
        if (findRow(year, uuid) != null) year,
    ];

    bool hasDuplicateRows(String uuid) {
      var activeCount = 0;
      for (final year in existingYears) {
        var countInYear = 0;
        for (final row in rowsByYear[year] ?? const <SheetV2Row>[]) {
          if (row.uuid == uuid) {
            countInYear++;
            if (!row.deleted) {
              activeCount++;
            }
          }
        }
        if (countInYear > 1) {
          return true;
        }
      }
      return activeCount > 1;
    }

    final synced = <String>[];
    final failed = <String>[];
    final duplicates = <String>[];
    final unsyncable = <String>[];

    Future<void> acknowledge(V2SyncItem item) async {
      if (await onSynced(item)) {
        synced.add(item.uuid);
      } else {
        failed.add(item.uuid);
      }
    }

    for (final item in pending) {
      if (hasDuplicateRows(item.uuid)) {
        duplicates.add(item.uuid);
        failed.add(item.uuid);
        continue;
      }

      // Map before any remote write, so an unsyncable transaction
      // never causes a partial year move.
      SheetV2Row? mapped;
      if (!item.deleted) {
        try {
          mapped = mapToSheetV2Row(item.source);
        } on SheetAmountOutOfRangeException {
          unsyncable.add(item.uuid);
          failed.add(item.uuid);
          continue;
        } on SheetV2MappingException {
          unsyncable.add(item.uuid);
          failed.add(item.uuid);
          continue;
        }
      }

      try {
        final targetYear = item.year;
        final targetRow = findRow(targetYear, item.uuid);
        final otherRows = <MapEntry<int, SheetV2Row>>[
          for (final year in yearsWithRow(item.uuid))
            if (year != targetYear) MapEntry(year, findRow(year, item.uuid)!),
        ];
        final updatedAt = item.source.updatedAt.toUtc().toIso8601String();

        Future<void> tombstone(MapEntry<int, SheetV2Row> entry) async {
          final row = entry.value;
          if (row.rowIndex == null) {
            return;
          }
          await prepareYear(entry.key);
          await backend.updateRow(
            spreadsheetId,
            entry.key,
            row.rowIndex!,
            row.copyWith(deleted: true, updatedAt: updatedAt),
          );
        }

        if (item.deleted) {
          if (targetRow == null && otherRows.isEmpty) {
            // Deleted before first sync: no worksheet, no row.
            await acknowledge(item);
            continue;
          }
          if (targetRow != null) {
            await tombstone(MapEntry(targetYear, targetRow));
          }
          for (final entry in otherRows) {
            await tombstone(entry);
          }
        } else {
          for (final entry in otherRows) {
            await tombstone(entry);
          }
          await prepareYear(targetYear);
          final current = findRow(targetYear, item.uuid);
          if (current != null && current.rowIndex != null) {
            await backend.updateRow(
              spreadsheetId,
              targetYear,
              current.rowIndex!,
              mapped!.copyWith(rowIndex: current.rowIndex),
            );
          } else {
            await backend.appendRow(spreadsheetId, targetYear, mapped!);
          }
        }

        await acknowledge(item);
      } on SheetsNotSignedInException {
        rethrow;
      } on SheetsAuthorizationMissingException {
        rethrow;
      } catch (_) {
        failed.add(item.uuid);
      }
    }

    return V2SyncRunResult(
      syncedUuids: synced,
      failedUuids: failed,
      duplicateUuids: duplicates,
      unsyncableUuids: unsyncable,
    );
  }
}
