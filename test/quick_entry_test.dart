import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/sync/v2/drift_v2_sync_store.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_mapper.dart';
import 'package:expense_tracker/data/repositories/financial_transaction_repository.dart';
import 'package:expense_tracker/data/repositories/ledger_query_service.dart';
import 'package:expense_tracker/data/repositories/quick_entry_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

Money inr(int minor) => Money(minor, 'INR');

void main() {
  late AppServices services;
  late String bank;
  late String cash;

  setUp(() async {
    services = await createTestServices();
    bank = (await services.accounts.createAccount(
      name: 'Bank',
      kind: 'bank',
    )).uuid;
    cash = (await services.accounts.createAccount(
      name: 'Cash',
      kind: 'cash',
    )).uuid;
  });

  tearDown(() => services.close());

  EntryDraft expense({
    String? merchant,
    List<String> tags = const [],
    String category = 'food',
    String? account,
    String? templateUuid,
    int amount = 25000,
  }) {
    return EntryDraft(
      kind: EntryKind.expense,
      amount: inr(amount),
      occurredAt: DateTime.now().subtract(const Duration(minutes: 1)),
      paymentChannel: 'UPI',
      accountUuid: account ?? bank,
      categoryId: category,
      merchantName: merchant,
      tagNames: tags,
      templateUuid: templateUuid,
    );
  }

  group('QuickEntryService.create', () {
    test('creates merchant and tags, learns the category', () async {
      final tx = await services.entries.create(
        expense(merchant: ' Swiggy ', tags: ['trip-goa', 'Food-Delivery']),
      );
      expect(tx.source, 'manual');
      final merchant = (await services.merchantsTags.merchantByName('swiggy'))!;
      expect(tx.merchantId, merchant.uuid);
      expect(merchant.name, 'Swiggy');
      expect(merchant.useCount, 1);
      expect(merchant.defaultCategoryId, 'food');
      final tagIds = await services.transactions.tagIdsForTransaction(tx.uuid);
      expect(tagIds, hasLength(2));

      // Second use with another category updates the suggestion and
      // reuses the same merchant and tag (case-insensitive).
      await services.entries.create(
        expense(merchant: 'SWIGGY', tags: ['Trip-Goa'], category: 'shopping'),
      );
      final again = (await services.merchantsTags.merchantByName('swiggy'))!;
      expect(again.useCount, 2);
      expect(
        await services.entries.suggestCategoryForMerchant('swiggy'),
        'shopping',
      );
      expect(await services.merchantsTags.listMerchants(), hasLength(1));
      expect(await services.merchantsTags.listTags(), hasLength(2));
    });

    test(
      'a template-filled entry has source template and counts use',
      () async {
        final template = await services.templates.createTemplate(
          name: 'Coffee',
          kind: 'expense',
          amountMinorUnits: 15000,
          accountId: bank,
          categoryId: 'food',
        );
        final tx = await services.entries.create(
          expense(templateUuid: template.uuid, amount: 15000),
        );
        expect(tx.source, 'template');
        final used = (await services.templates.templateByUuid(template.uuid))!;
        expect(used.useCount, 1);
        expect(used.lastUsedAt, isNotNull);
      },
    );

    test('a failure rolls back the whole entry', () async {
      await expectLater(
        services.entries.create(expense(merchant: 'Ghost', category: 'nope')),
        throwsA(anything),
      );
      expect(await services.transactions.listTransactions(), isEmpty);
      expect(await services.merchantsTags.listMerchants(), isEmpty);
    });

    test('transfer to a credit card becomes a card payment', () async {
      final card = await services.accounts.createAccount(
        name: 'Visa',
        kind: 'credit_card_liability',
      );
      final tx = await services.entries.create(
        EntryDraft(
          kind: EntryKind.transfer,
          amount: inr(5000),
          occurredAt: DateTime.now(),
          paymentChannel: 'Bank Transfer',
          fromAccountUuid: bank,
          toAccountUuid: card.uuid,
        ),
      );
      expect(tx.kind, 'card_payment');
    });
  });

  group('QuickEntryService.edit', () {
    test(
      'changing merchant/tags bumps the revision and records history',
      () async {
        final tx = await services.entries.create(expense(merchant: 'Swiggy'));
        await services.entries.edit(
          tx.uuid,
          const TransactionEdit(),
          merchantName: 'Zomato',
          tagNames: ['dinner'],
        );
        final updated = (await services.transactions.getTransactionByUuid(
          tx.uuid,
        ))!;
        expect(updated.syncRevision, greaterThan(tx.syncRevision));
        expect(updated.syncStatus, 'pending');
        final zomato = (await services.merchantsTags.merchantByName('zomato'))!;
        expect(updated.merchantId, zomato.uuid);
        final history = await services.database
            .select(services.database.transactionHistory)
            .get();
        expect(history.where((h) => h.changeKind == 'edited'), isNotEmpty);
        expect(history.last.afterSnapshot, contains(zomato.uuid));
      },
    );

    test('clearing the merchant removes the link', () async {
      final tx = await services.entries.create(
        expense(merchant: 'Swiggy', tags: ['a']),
      );
      await services.entries.edit(
        tx.uuid,
        const TransactionEdit(),
        merchantName: '',
        tagNames: const [],
      );
      final updated = (await services.transactions.getTransactionByUuid(
        tx.uuid,
      ))!;
      expect(updated.merchantId, isNull);
      expect(
        await services.transactions.tagIdsForTransaction(tx.uuid),
        isEmpty,
      );
    });
  });

  test('smart defaults come from the latest entry of that kind', () async {
    expect(
      (await services.entries.defaultsFor(EntryKind.expense)).accountUuid,
      isNull,
    );
    await services.entries.create(expense(account: cash, category: 'travel'));
    final defaults = await services.entries.defaultsFor(EntryKind.expense);
    expect(defaults.accountUuid, cash);
    expect(defaults.categoryId, 'travel');
    expect(defaults.paymentChannel, 'UPI');
    expect(
      (await services.entries.defaultsFor(EntryKind.income)).accountUuid,
      isNull,
    );
  });

  group('merchant and tag lifecycle', () {
    test('names are unique case-insensitively', () async {
      await services.merchantsTags.findOrCreateMerchant('Swiggy');
      final other = await services.merchantsTags.findOrCreateMerchant('Zomato');
      await expectLater(
        services.merchantsTags.renameMerchant(other.uuid, 'swiggy'),
        throwsA(anything),
      );
      final tag = await services.merchantsTags.findOrCreateTag('goa');
      await services.merchantsTags.findOrCreateTag('work');
      await expectLater(
        services.merchantsTags.renameTag(tag.id, 'WORK'),
        throwsA(anything),
      );
    });

    test('deleting a merchant keeps transactions and re-syncs them', () async {
      final tx = await services.entries.create(expense(merchant: 'Swiggy'));
      await services.transactions.markSyncedIfUnchanged(
        id: tx.id,
        syncRevision: tx.syncRevision,
        status: 'active',
      );
      final merchant = (await services.merchantsTags.merchantByName('swiggy'))!;
      await services.merchantsTags.deleteMerchant(merchant.uuid);
      final after = (await services.transactions.getTransactionByUuid(
        tx.uuid,
      ))!;
      expect(after.merchantId, isNull);
      expect(after.syncStatus, 'pending');
      expect(after.status, 'active');
    });

    test('deleting a tag removes links and template references', () async {
      final tx = await services.entries.create(expense(tags: ['goa', 'work']));
      final goa = (await services.merchantsTags.tagByName('goa'))!;
      final template = await services.templates.createTemplate(
        name: 'Trip',
        kind: 'expense',
        tagUuids: [goa.uuid],
      );
      await services.merchantsTags.deleteTag(goa.id);
      final remaining = await services.transactions.tagIdsForTransaction(
        tx.uuid,
      );
      expect(remaining, hasLength(1));
      expect(
        (await services.templates.templateByUuid(template.uuid))!.tagIds,
        isEmpty,
      );
    });
  });

  test('Sheets rows carry merchant, sorted tags and template source', () async {
    final template = await services.templates.createTemplate(
      name: 'Lunch',
      kind: 'expense',
    );
    final tx = await services.entries.create(
      expense(
        merchant: 'Swiggy',
        tags: ['work', 'Goa'],
        templateUuid: template.uuid,
      ),
    );
    final store = DriftV2SyncStore(services.database, services.transactions);
    final item = (await store.getPending()).singleWhere(
      (i) => i.uuid == tx.uuid,
    );
    final row = mapToSheetV2Row(item.source);
    expect(row.merchant, 'Swiggy');
    expect(row.tags, 'Goa, work');
    expect(row.source, 'template');
  });

  group('TransactionFilter', () {
    test('matches every set field; empty matches all', () async {
      await services.entries.create(
        expense(merchant: 'Swiggy', tags: ['goa'], amount: 50000),
      );
      await services.entries.create(
        expense(account: cash, category: 'travel', amount: 2000),
      );
      final views = await services.queries.loadTransactions();
      final swiggy = (await services.merchantsTags.merchantByName('swiggy'))!;
      final goa = (await services.merchantsTags.tagByName('goa'))!;

      int count(TransactionFilter f) => views.where(f.matches).length;
      expect(count(const TransactionFilter()), 2);
      expect(const TransactionFilter().isEmpty, isTrue);
      expect(count(TransactionFilter(merchantUuid: swiggy.uuid)), 1);
      expect(count(TransactionFilter(tagId: goa.id)), 1);
      expect(count(TransactionFilter(accountUuid: cash)), 1);
      expect(count(const TransactionFilter(categoryId: 'travel')), 1);
      expect(count(const TransactionFilter(minAmountMinorUnits: 10000)), 1);
      expect(count(const TransactionFilter(maxAmountMinorUnits: 2000)), 1);
      expect(count(const TransactionFilter(kinds: {'income'})), 0);
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      expect(
        count(TransactionFilter(from: day, toInclusive: day)),
        2,
        reason: 'the end day is inclusive',
      );
      expect(
        count(TransactionFilter(from: day.add(const Duration(days: 1)))),
        0,
      );
      expect(
        const TransactionFilter(
          categoryId: 'food',
          minAmountMinorUnits: 1,
          maxAmountMinorUnits: 2,
        ).activeCount,
        2,
      );
    });
  });
}
