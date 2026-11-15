import 'package:drift/drift.dart';

import 'financial_transactions.dart';
import 'merchants_tags.dart';

/// N:M link between transactions and tags. Deleting a tag removes only
/// its links.
@TableIndex(name: 'transaction_tags_tag', columns: {#tagId})
class TransactionTags extends Table {
  IntColumn get transactionId =>
      integer().references(FinancialTransactions, #id)();

  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tagId};
}
