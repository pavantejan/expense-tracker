// Merchants and tags (Module 2, blueprint section 5.2).
//
// Names are unique case-insensitively (stored `nameKey`). A merchant
// learns its default category from the last categorised transaction it
// was used on. Deleting a merchant nulls the reference on transactions
// and templates; deleting a tag removes only its links. In both cases
// the affected transactions return to pending sync because their
// Merchant/Tags sheet columns change. Renames do not re-sync history,
// consistent with category renames.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/ledger/posting_rules.dart';
import '../database/v2/app_database_v2.dart';

String nameKeyOf(String name) => name.trim().toLowerCase();

class MerchantTagRepository {
  MerchantTagRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? uuidGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newUuid = uuidGenerator ?? (() => const Uuid().v4());

  final AppDatabaseV2 _database;
  final DateTime Function() _clock;
  final String Function() _newUuid;

  // ---------------------------------------------------------------
  // Merchants.
  // ---------------------------------------------------------------

  /// Most used first, then by name.
  Future<List<Merchant>> listMerchants() {
    return (_database.select(_database.merchants)..orderBy([
          (t) => OrderingTerm(expression: t.useCount, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.nameKey),
        ]))
        .get();
  }

  Future<Merchant?> merchantByName(String name) {
    return (_database.select(
      _database.merchants,
    )..where((t) => t.nameKey.equals(nameKeyOf(name)))).getSingleOrNull();
  }

  Future<Merchant?> merchantByUuid(String uuid) {
    return (_database.select(
      _database.merchants,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  /// Returns the merchant with this name (any case), creating it when
  /// missing. Blank names are rejected.
  Future<Merchant> findOrCreateMerchant(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PostingValidationException('Merchant name is empty.');
    }
    return _database.transaction(() async {
      final existing = await merchantByName(trimmed);
      if (existing != null) {
        return existing;
      }
      await _database
          .into(_database.merchants)
          .insert(
            MerchantsCompanion.insert(
              uuid: _newUuid(),
              name: trimmed,
              nameKey: nameKeyOf(trimmed),
              createdAt: _clock(),
            ),
          );
      return (await merchantByName(trimmed))!;
    });
  }

  /// Records one use: bumps the counter and learns the category.
  Future<void> recordMerchantUse(String uuid, {String? categoryId}) async {
    await _database.transaction(() async {
      final merchant = await merchantByUuid(uuid);
      if (merchant == null) {
        return;
      }
      await (_database.update(
        _database.merchants,
      )..where((t) => t.uuid.equals(uuid))).write(
        MerchantsCompanion(
          useCount: Value(merchant.useCount + 1),
          lastUsedAt: Value(_clock()),
          defaultCategoryId: categoryId == null
              ? const Value.absent()
              : Value(categoryId),
        ),
      );
    });
  }

  Future<Merchant> renameMerchant(String uuid, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PostingValidationException('Merchant name is empty.');
    }
    return _database.transaction(() async {
      final clash = await merchantByName(trimmed);
      if (clash != null && clash.uuid != uuid) {
        throw const PostingValidationException(
          'A merchant with this name already exists.',
        );
      }
      await (_database.update(
        _database.merchants,
      )..where((t) => t.uuid.equals(uuid))).write(
        MerchantsCompanion(
          name: Value(trimmed),
          nameKey: Value(nameKeyOf(trimmed)),
        ),
      );
      return (await merchantByUuid(uuid))!;
    });
  }

  Future<void> setMerchantDefaultCategory(String uuid, String? categoryId) {
    return (_database.update(_database.merchants)
          ..where((t) => t.uuid.equals(uuid)))
        .write(MerchantsCompanion(defaultCategoryId: Value(categoryId)));
  }

  /// Deletes a merchant; transactions keep their description text and
  /// return to pending sync because their Merchant column changes.
  Future<void> deleteMerchant(String uuid) async {
    final now = _clock();
    await _database.transaction(() async {
      final affected = await (_database.select(
        _database.financialTransactions,
      )..where((t) => t.merchantId.equals(uuid))).get();
      for (final tx in affected) {
        await (_database.update(
          _database.financialTransactions,
        )..where((t) => t.id.equals(tx.id))).write(
          FinancialTransactionsCompanion(
            merchantId: const Value(null),
            updatedAt: Value(now),
            syncRevision: Value(tx.syncRevision + 1),
            syncStatus: const Value('pending'),
          ),
        );
      }
      await (_database.update(_database.transactionTemplates)
            ..where((t) => t.merchantId.equals(uuid)))
          .write(const TransactionTemplatesCompanion(merchantId: Value(null)));
      await (_database.delete(
        _database.merchants,
      )..where((t) => t.uuid.equals(uuid))).go();
    });
  }

  // ---------------------------------------------------------------
  // Tags.
  // ---------------------------------------------------------------

  Future<List<Tag>> listTags() {
    return (_database.select(
      _database.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.nameKey)])).get();
  }

  Future<Tag?> tagByName(String name) {
    return (_database.select(
      _database.tags,
    )..where((t) => t.nameKey.equals(nameKeyOf(name)))).getSingleOrNull();
  }

  Future<Tag> findOrCreateTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PostingValidationException('Tag name is empty.');
    }
    return _database.transaction(() async {
      final existing = await tagByName(trimmed);
      if (existing != null) {
        return existing;
      }
      await _database
          .into(_database.tags)
          .insert(
            TagsCompanion.insert(
              uuid: _newUuid(),
              name: trimmed,
              nameKey: nameKeyOf(trimmed),
              createdAt: _clock(),
            ),
          );
      return (await tagByName(trimmed))!;
    });
  }

  Future<Tag> renameTag(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PostingValidationException('Tag name is empty.');
    }
    return _database.transaction(() async {
      final clash = await tagByName(trimmed);
      if (clash != null && clash.id != id) {
        throw const PostingValidationException(
          'A tag with this name already exists.',
        );
      }
      await (_database.update(
        _database.tags,
      )..where((t) => t.id.equals(id))).write(
        TagsCompanion(name: Value(trimmed), nameKey: Value(nameKeyOf(trimmed))),
      );
      return (await (_database.select(
        _database.tags,
      )..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Deletes a tag and its links; tagged transactions return to pending
  /// sync because their Tags column changes. Templates drop the tag.
  Future<void> deleteTag(int id) async {
    final now = _clock();
    await _database.transaction(() async {
      final tag = await (_database.select(
        _database.tags,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (tag == null) {
        return;
      }
      final links = await (_database.select(
        _database.transactionTags,
      )..where((t) => t.tagId.equals(id))).get();
      for (final link in links) {
        final tx = await (_database.select(
          _database.financialTransactions,
        )..where((t) => t.id.equals(link.transactionId))).getSingle();
        await (_database.update(
          _database.financialTransactions,
        )..where((t) => t.id.equals(tx.id))).write(
          FinancialTransactionsCompanion(
            updatedAt: Value(now),
            syncRevision: Value(tx.syncRevision + 1),
            syncStatus: const Value('pending'),
          ),
        );
      }
      await (_database.delete(
        _database.transactionTags,
      )..where((t) => t.tagId.equals(id))).go();
      final templates = await _database
          .select(_database.transactionTemplates)
          .get();
      for (final template in templates) {
        final ids = splitTagIds(template.tagIds);
        if (ids.remove(tag.uuid)) {
          await (_database.update(
            _database.transactionTemplates,
          )..where((t) => t.id.equals(template.id))).write(
            TransactionTemplatesCompanion(tagIds: Value(ids.join(','))),
          );
        }
      }
      await (_database.delete(
        _database.tags,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  /// Tags per transaction id, for a batch of transactions.
  Future<Map<int, List<Tag>>> tagsByTransactionIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    final links = await (_database.select(
      _database.transactionTags,
    )..where((t) => t.transactionId.isIn(ids))).get();
    final tags = {for (final t in await listTags()) t.id: t};
    final result = <int, List<Tag>>{};
    for (final link in links) {
      final tag = tags[link.tagId];
      if (tag != null) {
        result.putIfAbsent(link.transactionId, () => []).add(tag);
      }
    }
    for (final list in result.values) {
      list.sort((a, b) => a.nameKey.compareTo(b.nameKey));
    }
    return result;
  }
}

List<String> splitTagIds(String value) =>
    value.split(',').where((s) => s.isNotEmpty).toList();
