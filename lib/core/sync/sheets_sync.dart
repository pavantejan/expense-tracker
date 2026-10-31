/// Pure sync logic for Google Sheets backup.
///
/// This file has no Flutter or googleapis imports so the sync rules can
/// be unit-tested with a fake backend and no Google account.
///
/// Header schema (A:J), documented in docs/sheets-sync.md. The first
/// five columns keep the order used by the previous implementation so
/// any 5-column sheet it created remains readable; the UUID and the
/// remaining fields are appended as columns F:J:
///
/// Date, Type, Category, Description, Amount,
/// UUID, PaymentMethod, Notes, UpdatedAt, Deleted
const List<String> sheetHeaders = <String>[
  'Date',
  'Type',
  'Category',
  'Description',
  'Amount',
  'UUID',
  'PaymentMethod',
  'Notes',
  'UpdatedAt',
  'Deleted',
];

/// Thrown by a backend when no Google account is signed in.
///
/// The coordinator treats this differently from other failures: it
/// stays silent and leaves work pending instead of notifying or
/// retrying on a timer, because signing in is a user action.
class SheetsNotSignedInException implements Exception {
  const SheetsNotSignedInException([this.message = 'Not signed in.']);

  final String message;

  @override
  String toString() => 'SheetsNotSignedInException: $message';
}

/// Thrown when Sheets scopes have not been authorized yet and the
/// caller is in silent/background mode, where prompting for
/// authorization is forbidden. The user must authorize explicitly
/// from Settings; pending work is retained.
class SheetsAuthorizationMissingException implements Exception {
  const SheetsAuthorizationMissingException([
    this.message = 'Sheets authorization is missing.',
  ]);

  final String message;

  @override
  String toString() => 'SheetsAuthorizationMissingException: $message';
}

/// A local transaction, reduced to the fields Sheets needs.
///
/// This is deliberately separate from the Drift `Transaction` row so
/// the engine never depends on the database layer.
class SyncTransaction {
  const SyncTransaction({
    required this.localId,
    required this.uuid,
    required this.transactionDate,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.updatedAt,
    required this.deleted,
  });

  final int localId;
  final String uuid;
  final DateTime transactionDate;
  final String type;
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final DateTime updatedAt;
  final bool deleted;

  int get year => transactionDate.year;
}

/// One row in a year worksheet, including its 1-based sheet row index
/// when it already exists in the sheet (`null` for a row not yet
/// written).
class SheetRowData {
  const SheetRowData({
    required this.uuid,
    required this.date,
    required this.dateText,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.updatedAt,
    required this.deleted,
    this.rowIndex,
  });

  final String uuid;
  final DateTime date;
  final String dateText;
  final String type;
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  final String notes;
  final DateTime updatedAt;
  final bool deleted;
  final int? rowIndex;

  factory SheetRowData.fromTransaction(
    SyncTransaction transaction, {
    int? rowIndex,
  }) {
    return SheetRowData(
      uuid: transaction.uuid,
      date: transaction.transactionDate,
      dateText: _formatDate(transaction.transactionDate),
      type: transaction.type,
      category: transaction.category,
      description: transaction.description,
      amount: transaction.amount,
      paymentMethod: transaction.paymentMethod,
      notes: transaction.notes ?? '',
      updatedAt: transaction.updatedAt,
      deleted: transaction.deleted,
      rowIndex: rowIndex,
    );
  }

  factory SheetRowData.fromValues(List<Object?> values, int rowIndex) {
    String textAt(int index) {
      if (index >= values.length) {
        return '';
      }
      final value = values[index];
      return value == null ? '' : value.toString();
    }

    double amountAt(int index) {
      if (index >= values.length) {
        return 0;
      }
      final value = values[index];
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse(value.toString()) ?? 0;
    }

    final dateText = textAt(0);
    final parsedDate = DateTime.tryParse(dateText);
    final updatedText = textAt(8);
    final parsedUpdated =
        DateTime.tryParse(updatedText) ?? parsedDate ?? DateTime(1970);

    return SheetRowData(
      uuid: textAt(5),
      date: parsedDate ?? DateTime(1970),
      dateText: dateText,
      type: textAt(1),
      category: textAt(2),
      description: textAt(3),
      amount: amountAt(4),
      paymentMethod: textAt(6),
      notes: textAt(7),
      updatedAt: parsedUpdated,
      deleted: textAt(9).toLowerCase() == 'true',
      rowIndex: rowIndex,
    );
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<Object?> toValues() {
    return <Object?>[
      dateText,
      type,
      category,
      description,
      amount,
      uuid,
      paymentMethod,
      notes,
      updatedAt.toIso8601String(),
      deleted ? 'TRUE' : 'FALSE',
    ];
  }

  SheetRowData copyWith({
    String? uuid,
    DateTime? date,
    String? dateText,
    String? type,
    String? category,
    String? description,
    double? amount,
    String? paymentMethod,
    String? notes,
    DateTime? updatedAt,
    bool? deleted,
    int? rowIndex,
  }) {
    return SheetRowData(
      uuid: uuid ?? this.uuid,
      date: date ?? this.date,
      dateText: dateText ?? this.dateText,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowIndex: rowIndex ?? this.rowIndex,
    );
  }
}

/// The remote Sheets/Drive operations the sync engine needs.
///
/// Implementations must never log tokens, secrets, or transaction
/// data. A missing year worksheet is reported as an empty read, not
/// as an error, so the engine can create it on demand.
abstract class SheetsSyncBackend {
  /// Returns the id of the one master spreadsheet, creating the
  /// "Expense Tracker" folder and spreadsheet only if they do not
  /// already exist. Must not create duplicates on repeated calls.
  Future<String> resolveSpreadsheetId();

  /// Years that already have a worksheet in the spreadsheet.
  /// Must throw on failure: the engine aborts the whole run
  /// rather than syncing against a partial worksheet list.
  Future<List<int>> listYearSheets(String spreadsheetId);

  /// Creates the worksheet for [year] and writes the header row
  /// when the sheet is new or empty, or extends a legacy A:E
  /// header to A:J when one is present. Does nothing to existing
  /// data rows and invents no UUIDs for them.
  Future<void> ensureYearSheet(String spreadsheetId, int year);

  /// Data rows (header excluded) for [year], in sheet order.
  /// Returns an empty list when the worksheet does not exist yet.
  Future<List<SheetRowData>> readYearSheet(String spreadsheetId, int year);

  Future<void> appendRow(String spreadsheetId, int year, SheetRowData row);

  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  );
}

class SyncRunResult {
  const SyncRunResult({
    required this.syncedUuids,
    required this.failedUuids,
    this.duplicateUuids = const <String>[],
  });

  final List<String> syncedUuids;
  final List<String> failedUuids;

  /// UUIDs skipped because the spreadsheet already contains
  /// ambiguous duplicate rows for them (see below). These need
  /// manual cleanup in Sheets; the engine never deletes or merges
  /// them automatically. They are also listed in [failedUuids]
  /// and remain pending locally.
  final List<String> duplicateUuids;
}

/// Idempotent, UUID-based synchronization of pending transactions.
///
/// Rules:
/// - A transaction is identified only by its UUID.
/// - Retrying a sync can never duplicate a row: an existing row in
///   the target year worksheet is updated in place.
/// - A soft-deleted transaction keeps its row with Deleted=TRUE.
///   Restoring flips it back to FALSE without a new row.
/// - A transaction deleted before it was ever synced creates no
///   row and no worksheet: if no row for its UUID exists in any
///   existing worksheet, the pending deletion is acknowledged
///   locally without any remote write. Existing worksheets are
///   read first; a worksheet is only created when a write to it
///   is actually needed.
/// - Worksheet discovery is not best-effort: if listing the
///   existing year worksheets fails, the whole run aborts before
///   any remote write or local acknowledgement, and the
///   coordinator handles the retry. A partial worksheet list
///   could otherwise miss a row that moved years and leave two
///   active rows for one UUID.
/// - Moving a transaction across calendar years marks its old-year
///   row(s) deleted and writes the row in the new year. This is not
///   atomic across worksheets: tombstoning, target write, and local
///   acknowledgement are separate operations. A failure at any
///   boundary leaves the transaction pending, and a retry re-reads
///   the sheets and converges to exactly one active row (tombstone
///   and target update are both idempotent; the local acknowledgement
///   is conditional on the uploaded revision, see
///   `markTransactionSyncedIfUnchanged`).
/// - Duplicate UUID rows in a worksheet, or more than one active
///   row for a UUID across worksheets, are ambiguous pre-existing
///   data. The engine reports them, writes nothing for that
///   transaction, and never deletes or merges rows automatically.
/// - One failing transaction does not block the others, and a
///   failure never marks that transaction synced.
class SheetsSyncEngine {
  Future<SyncRunResult> syncAll({
    required List<SyncTransaction> pending,
    required SheetsSyncBackend backend,
    required Future<bool> Function(SyncTransaction transaction) onSynced,
  }) async {
    if (pending.isEmpty) {
      return const SyncRunResult(syncedUuids: [], failedUuids: []);
    }

    final spreadsheetId = await backend.resolveSpreadsheetId();

    // Worksheet discovery is all-or-nothing. If listing fails,
    // this throws before any remote write or acknowledgement,
    // so the coordinator can retry the whole run. Never fall
    // back to the pending transactions' years alone: a year
    // move from an unlisted year would then be missed.
    final existingYears = await backend.listYearSheets(spreadsheetId);

    // Read the worksheets that already exist. Do NOT ensure
    // anything yet: ensuring a year creates it, and a
    // transaction deleted before its first sync must not
    // create a worksheet or a row.
    final rowsByYear = <int, List<SheetRowData>>{};
    for (final year in existingYears) {
      rowsByYear[year] = await backend.readYearSheet(spreadsheetId, year);
    }

    // A year is ensured (created if missing, header extended if
    // legacy — see the backend) only when a write to it is about
    // to happen. After ensuring, the year is re-read so the
    // engine works from the sheet's actual contents.
    final ensuredYears = <int>{};
    Future<void> prepareYear(int year) async {
      if (ensuredYears.contains(year)) {
        return;
      }
      await backend.ensureYearSheet(spreadsheetId, year);
      ensuredYears.add(year);
      rowsByYear[year] = await backend.readYearSheet(spreadsheetId, year);
    }

    SheetRowData? findRow(int year, String uuid) {
      for (final row in rowsByYear[year] ?? const <SheetRowData>[]) {
        if (row.uuid == uuid) {
          return row;
        }
      }
      return null;
    }

    /// Years that currently have a row for [uuid] in the
    /// snapshot read above. Computed from the snapshot, not
    /// from [rowsByYear] after writes, so the duplicate check
    /// below sees the pre-run state.
    List<int> yearsWithRow(String uuid) {
      final years = <int>[];
      for (final year in existingYears) {
        if (findRow(year, uuid) != null) {
          years.add(year);
        }
      }
      return years;
    }

    bool hasDuplicateRows(String uuid) {
      var activeCount = 0;
      for (final year in existingYears) {
        var countInYear = 0;
        for (final row in rowsByYear[year] ?? const <SheetRowData>[]) {
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

    for (final transaction in pending) {
      // Ambiguous pre-existing rows: report and skip. Never
      // delete or merge them automatically.
      if (hasDuplicateRows(transaction.uuid)) {
        duplicates.add(transaction.uuid);
        failed.add(transaction.uuid);
        continue;
      }

      try {
        final targetYear = transaction.year;
        final rowYears = yearsWithRow(transaction.uuid);
        final targetRow = findRow(targetYear, transaction.uuid);
        final otherRows = <MapEntry<int, SheetRowData>>[];
        for (final year in rowYears) {
          if (year == targetYear) {
            continue;
          }
          final row = findRow(year, transaction.uuid);
          if (row != null) {
            otherRows.add(MapEntry(year, row));
          }
        }

        if (transaction.deleted) {
          if (targetRow == null && otherRows.isEmpty) {
            // Deleted before first sync and never written
            // anywhere: acknowledge locally without creating
            // a worksheet or a remote row.
            final acknowledged = await onSynced(transaction);
            if (acknowledged) {
              synced.add(transaction.uuid);
            } else {
              failed.add(transaction.uuid);
            }
            continue;
          }
          // Previously synchronized: keep every existing row,
          // marked deleted. No row is created for a deleted
          // transaction.
          final rowsToTombstone = <MapEntry<int, SheetRowData>>[];
          if (targetRow != null && targetRow.rowIndex != null) {
            rowsToTombstone.add(MapEntry(targetYear, targetRow));
          }
          rowsToTombstone.addAll(otherRows);
          for (final entry in rowsToTombstone) {
            final row = entry.value;
            if (row.rowIndex == null) {
              continue;
            }
            await prepareYear(entry.key);
            await backend.updateRow(
              spreadsheetId,
              entry.key,
              row.rowIndex!,
              row.copyWith(deleted: true, updatedAt: transaction.updatedAt),
            );
          }
        } else {
          // Mark rows in other years deleted before writing the
          // target-year row, so a year move never leaves two
          // active rows for the same UUID.
          for (final entry in otherRows) {
            final row = entry.value;
            if (row.rowIndex == null) {
              continue;
            }
            await prepareYear(entry.key);
            await backend.updateRow(
              spreadsheetId,
              entry.key,
              row.rowIndex!,
              row.copyWith(deleted: true, updatedAt: transaction.updatedAt),
            );
          }

          await prepareYear(targetYear);
          final currentTargetRow = findRow(targetYear, transaction.uuid);
          if (currentTargetRow != null && currentTargetRow.rowIndex != null) {
            final updatedRow = SheetRowData.fromTransaction(
              transaction,
              rowIndex: currentTargetRow.rowIndex,
            );
            await backend.updateRow(
              spreadsheetId,
              targetYear,
              currentTargetRow.rowIndex!,
              updatedRow,
            );
          } else {
            final newRow = SheetRowData.fromTransaction(transaction);
            await backend.appendRow(spreadsheetId, targetYear, newRow);
            // Pending rows carry unique UUIDs (unique constraint in
            // the local database), so the same UUID cannot appear
            // twice in one run.
          }
        }

        // Conditional acknowledgement: only mark synced if the
        // local row is still the revision that was uploaded. A
        // concurrent edit makes this return false, so the newer
        // revision stays pending and the next retry uploads it.
        // (For a deleted-before-first-sync transaction this is
        // the only step, already handled above.)
        final acknowledged = await onSynced(transaction);
        if (acknowledged) {
          synced.add(transaction.uuid);
        } else {
          failed.add(transaction.uuid);
        }
      } on SheetsNotSignedInException {
        // Auth state changed mid-run: stop the batch and let
        // the coordinator handle it silently, rather than
        // marking these rows as ordinary failures.
        rethrow;
      } on SheetsAuthorizationMissingException {
        rethrow;
      } catch (_) {
        // Leave the transaction pending. The coordinator retries it.
        failed.add(transaction.uuid);
      }
    }

    return SyncRunResult(
      syncedUuids: synced,
      failedUuids: failed,
      duplicateUuids: duplicates,
    );
  }
}
