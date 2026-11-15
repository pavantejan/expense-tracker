import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/repositories/ledger_query_service.dart';
import '../common/ui.dart';
import 'add_transaction_page.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key, this.autoFocusSearch = false});

  final bool autoFocusSearch;

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  AppServices? _services;
  Stream<List<TransactionView>>? _transactions;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _transactions = _services!.queries.watchTransactions();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(TransactionView view) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: Text(
              'Delete "${transactionTitle(view)}"? It is removed from '
              'balances and reports. You can undo right after deleting.',
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('search-field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search description, category, account, notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TransactionView>>(
              stream: _transactions,
              builder: (context, snapshot) {
                final all = snapshot.data;
                if (all == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visible = _query.isEmpty
                    ? all
                    : all.where((v) => v.searchText.contains(_query)).toList();
                if (visible.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      EmptyStateCard(
                        icon: Icons.receipt_long_outlined,
                        title: _query.isEmpty
                            ? 'No transactions yet'
                            : 'No matches',
                        message: _query.isEmpty
                            ? 'Transactions you add appear here.'
                            : 'No transactions match "$_query".',
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final view = visible[index];
                    return Dismissible(
                      key: ValueKey(view.uuid),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                      // Delete inside confirmDismiss so a rejected delete
                      // (e.g. refunds still reference it) never leaves a
                      // dismissed tile in the tree.
                      confirmDismiss: (_) async {
                        if (!await _confirmDelete(view) || !context.mounted) {
                          return false;
                        }
                        return deleteWithUndo(context, _services!, view.uuid);
                      },
                      child: TransactionTile(
                        view: view,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddTransactionPage(transactionUuid: view.uuid),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
