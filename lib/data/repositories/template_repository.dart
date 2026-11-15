// Saved transactions for one-tap entry (Module 2).
//
// A template never posts anything itself: applying it pre-fills the
// add form; saving that form creates a normal transaction with
// `source = template` and bumps the template's use count.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/ledger/posting_rules.dart';
import '../database/v2/app_database_v2.dart';

const Set<String> templateKinds = <String>{'expense', 'income', 'transfer'};

class TemplateRepository {
  TemplateRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? uuidGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newUuid = uuidGenerator ?? (() => const Uuid().v4());

  final AppDatabaseV2 _database;
  final DateTime Function() _clock;
  final String Function() _newUuid;

  SimpleSelectStatement<$TransactionTemplatesTable, TransactionTemplate>
  _ordered() {
    return _database.select(_database.transactionTemplates)..orderBy([
      (t) => OrderingTerm(expression: t.isFavourite, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.useCount, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
  }

  /// Favourites first, then most used.
  Future<List<TransactionTemplate>> listTemplates() => _ordered().get();

  Stream<List<TransactionTemplate>> watchTemplates() => _ordered().watch();

  Future<TransactionTemplate?> templateByUuid(String uuid) {
    return (_database.select(
      _database.transactionTemplates,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<TransactionTemplate> createTemplate({
    required String name,
    required String kind,
    int? amountMinorUnits,
    String? accountId,
    String? sourceAccountId,
    String? destinationAccountId,
    String? categoryId,
    String? merchantId,
    List<String> tagUuids = const [],
    String paymentChannel = 'UPI',
    String? description,
    String? notes,
    bool isFavourite = true,
  }) async {
    if (name.trim().isEmpty) {
      throw const PostingValidationException('Template name is empty.');
    }
    if (!templateKinds.contains(kind)) {
      throw PostingValidationException('Unknown template kind: $kind.');
    }
    if (amountMinorUnits != null && amountMinorUnits <= 0) {
      throw const PostingValidationException(
        'A template amount must be greater than zero.',
      );
    }
    final uuid = _newUuid();
    await _database
        .into(_database.transactionTemplates)
        .insert(
          TransactionTemplatesCompanion.insert(
            uuid: uuid,
            name: name.trim(),
            kind: kind,
            amountMinorUnits: Value(amountMinorUnits),
            accountId: Value(accountId),
            sourceAccountId: Value(sourceAccountId),
            destinationAccountId: Value(destinationAccountId),
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            tagIds: Value(tagUuids.join(',')),
            paymentChannel: Value(paymentChannel),
            description: Value(description),
            notes: Value(notes),
            isFavourite: Value(isFavourite),
            createdAt: _clock(),
          ),
        );
    return (await templateByUuid(uuid))!;
  }

  Future<void> renameTemplate(String uuid, String name) async {
    if (name.trim().isEmpty) {
      throw const PostingValidationException('Template name is empty.');
    }
    await (_database.update(_database.transactionTemplates)
          ..where((t) => t.uuid.equals(uuid)))
        .write(TransactionTemplatesCompanion(name: Value(name.trim())));
  }

  Future<void> setFavourite(String uuid, bool favourite) {
    return (_database.update(_database.transactionTemplates)
          ..where((t) => t.uuid.equals(uuid)))
        .write(TransactionTemplatesCompanion(isFavourite: Value(favourite)));
  }

  Future<void> deleteTemplate(String uuid) {
    return (_database.delete(
      _database.transactionTemplates,
    )..where((t) => t.uuid.equals(uuid))).go();
  }

  Future<void> markUsed(String uuid) async {
    final template = await templateByUuid(uuid);
    if (template == null) {
      return;
    }
    await (_database.update(
      _database.transactionTemplates,
    )..where((t) => t.uuid.equals(uuid))).write(
      TransactionTemplatesCompanion(
        useCount: Value(template.useCount + 1),
        lastUsedAt: Value(_clock()),
      ),
    );
  }
}
