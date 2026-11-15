import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/categories/category.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/repositories/ledger_query_service.dart';
import '../common/ui.dart';
import '../transactions/all_transactions_page.dart';

class MerchantsTagsPage extends StatefulWidget {
  const MerchantsTagsPage({super.key});

  @override
  State<MerchantsTagsPage> createState() => _MerchantsTagsPageState();
}

class _MerchantsTagsPageState extends State<MerchantsTagsPage> {
  AppServices? _services;
  Stream<void>? _changes;
  Stream<List<Category>>? _categories;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      final services = _services = AppScope.of(context);
      final db = services.database;
      _categories = services.queries.watchCategories(includeArchived: false);
      _changes = (() async* {
        yield null;
        yield* db.tableUpdates(
          TableUpdateQuery.onAllTables([db.merchants, db.tags]),
        );
      })();
    }
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('rename-field'),
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name == null || name.isEmpty ? null : name;
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      unawaited(_services!.sync.requestSync());
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  Future<void> _merchantActions(
    Merchant merchant,
    List<Category> categories,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                merchant.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('View transactions'),
              onTap: () => Navigator.of(sheetContext).pop('view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Default category'),
              onTap: () => Navigator.of(sheetContext).pop('category'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'view':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AllTransactionsPage(
              initialFilter: TransactionFilter(merchantUuid: merchant.uuid),
            ),
          ),
        );
      case 'rename':
        final name = await _askName('Rename merchant', merchant.name);
        if (name != null) {
          await _run(
            () => _services!.merchantsTags.renameMerchant(merchant.uuid, name),
          );
        }
      case 'category':
        final choice = await showDialog<String>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Default category'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: const Text('None'),
              ),
              for (final category in categories)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(category.categoryId),
                  child: Text(category.name),
                ),
            ],
          ),
        );
        if (choice != null) {
          await _run(
            () => _services!.merchantsTags.setMerchantDefaultCategory(
              merchant.uuid,
              choice.isEmpty ? null : choice,
            ),
          );
        }
      case 'delete':
        if (await _confirm(
          'Delete merchant?',
          'Transactions keep their description; only the merchant link is '
              'removed.',
        )) {
          await _run(
            () => _services!.merchantsTags.deleteMerchant(merchant.uuid),
          );
        }
    }
  }

  Future<void> _tagActions(Tag tag) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                tag.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('View transactions'),
              onTap: () => Navigator.of(sheetContext).pop('view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'view':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AllTransactionsPage(
              initialFilter: TransactionFilter(tagId: tag.id),
            ),
          ),
        );
      case 'rename':
        final name = await _askName('Rename tag', tag.name);
        if (name != null) {
          await _run(() => _services!.merchantsTags.renameTag(tag.id, name));
        }
      case 'delete':
        if (await _confirm(
          'Delete tag?',
          'The tag is removed from every transaction. The transactions '
              'themselves are kept.',
        )) {
          await _run(() => _services!.merchantsTags.deleteTag(tag.id));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Merchants & tags'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Merchants'),
              Tab(text: 'Tags'),
            ],
          ),
        ),
        body: StreamBuilder<List<Category>>(
          stream: _categories,
          builder: (context, categoriesSnapshot) {
            final categories = categoriesSnapshot.data ?? const <Category>[];
            final names = {for (final c in categories) c.categoryId: c};
            return StreamBuilder<void>(
              stream: _changes,
              builder: (context, _) {
                return TabBarView(
                  children: [
                    FutureBuilder<List<Merchant>>(
                      future: _services!.merchantsTags.listMerchants(),
                      builder: (context, snapshot) {
                        final merchants = snapshot.data ?? const <Merchant>[];
                        if (merchants.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: const [
                              EmptyStateCard(
                                icon: Icons.storefront_rounded,
                                title: 'No merchants yet',
                                message:
                                    'Type a merchant when adding an expense. '
                                    'Next time, its category is suggested '
                                    'for you.',
                              ),
                            ],
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final merchant in merchants)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      names[merchant.defaultCategoryId] == null
                                          ? Icons.storefront_rounded
                                          : iconForCategory(
                                              merchant.defaultCategoryId!,
                                              names[merchant.defaultCategoryId]!
                                                  .iconCodePoint,
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    merchant.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      'used ${merchant.useCount}×',
                                      if (names[merchant.defaultCategoryId] !=
                                          null)
                                        'usually '
                                            '${names[merchant.defaultCategoryId]!.name}',
                                    ].join(' • '),
                                  ),
                                  onTap: () =>
                                      _merchantActions(merchant, categories),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    FutureBuilder<List<Tag>>(
                      future: _services!.merchantsTags.listTags(),
                      builder: (context, snapshot) {
                        final tags = snapshot.data ?? const <Tag>[];
                        if (tags.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: const [
                              EmptyStateCard(
                                icon: Icons.sell_outlined,
                                title: 'No tags yet',
                                message:
                                    'Add tags such as "trip-goa" or '
                                    '"tax-2026" when adding a transaction.',
                              ),
                            ],
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tag in tags)
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.sell_outlined,
                                      size: 16,
                                    ),
                                    label: Text(tag.name),
                                    onPressed: () => _tagActions(tag),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
