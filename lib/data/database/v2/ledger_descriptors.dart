// Mapping from V2 Drift rows to pure-domain ledger descriptors.
//
// The posting builders and the balance calculator work with
// [LedgerDescriptor] values, never with Drift rows, so the data layer
// needs exactly one conversion. It lives here so every V2 repository
// shares it instead of each inventing its own.

import '../../../core/domain/ledger/posting_rules.dart';
import 'app_database_v2.dart';

/// Converts a [LedgerAccount] row to the descriptor the pure domain
/// layer validates and builds postings from.
LedgerDescriptor ledgerDescriptorOf(LedgerAccount row) {
  return LedgerDescriptor(
    ledgerAccountId: row.ledgerAccountId,
    kind: row.kind,
    normalBalance: ledgerDirectionFromValue(row.normalBalance),
    userAccountId: row.userAccountId,
    categoryId: row.categoryId,
    isSystem: row.isSystem,
    isArchived: row.isArchived,
  );
}
