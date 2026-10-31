import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/database/repository_provider.dart';
import '../../core/notifications/notification_manager.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../data/database/app_database.dart';
import '../../data/notifications/notification.dart';
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

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(Transaction transaction) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final title = transaction.description?.isNotEmpty == true
                ? transaction.description!
                : transaction.category;

            return AlertDialog(
              title: const Text('Delete transaction?'),
              content: Text(
                'Are you sure you want to delete '
                '$title for ₹${transaction.amount.toStringAsFixed(2)}?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final deleted = await transactionRepository.deleteTransaction(
      transaction.id,
    );

    if (!deleted || !mounted) {
      return;
    }

    final title = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : transaction.category;

    NotificationManager.instance.add(
      type: NotificationType.transactionDeleted,
      title: 'Transaction deleted',
      message: '$title • ₹${transaction.amount.toStringAsFixed(2)}',
    );

    unawaited(sheetsSyncCoordinator.requestSync());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        // A SnackBar with an action defaults to persist: true, which
        // kept the Undo bar on screen until tapped. Explicitly
        // auto-dismiss after 5 seconds; Undo still works within
        // that window.
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            final restored = await transactionRepository.restoreTransaction(
              transaction.id,
            );

            if (!restored || !mounted) {
              return;
            }

            NotificationManager.instance.add(
              type: NotificationType.transactionRestored,
              title: 'Transaction restored',
              message: '$title • ₹${transaction.amount.toStringAsFixed(2)}',
            );

            unawaited(sheetsSyncCoordinator.requestSync());

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction restored'),
                duration: Duration(seconds: 5),
                persist: false,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'All Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: 'Clear search',
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Transaction>>(
                stream: _searchQuery.isEmpty
                    ? transactionRepository.watchAllTransactions()
                    : transactionRepository.searchTransactions(_searchQuery),
                builder: (context, snapshot) {
                  final transactions = snapshot.data ?? [];

                  if (transactions.isEmpty) {
                    return _EmptyTransactionsView(
                      isSearching: _searchQuery.isNotEmpty,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];

                      return Dismissible(
                        key: ValueKey(transaction.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.delete_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDelete(transaction),
                        onDismissed: (_) {
                          _deleteTransaction(transaction);
                        },
                        child: _AllTransactionCard(
                          transaction: transaction,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddTransactionPage(
                                  transactionId: transaction.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTransactionCard extends StatelessWidget {
  const _AllTransactionCard({required this.transaction, required this.onTap});

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'Income';

    final title = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : transaction.category;

    final date =
        '${transaction.transactionDate.day.toString().padLeft(2, '0')}/'
        '${transaction.transactionDate.month.toString().padLeft(2, '0')}/'
        '${transaction.transactionDate.year}';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(
            isIncome
                ? Icons.arrow_downward_rounded
                : _categoryIcon(transaction.category),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${transaction.category} • '
          '${transaction.paymentMethod}\n'
          '$date',
        ),
        isThreeLine: true,
        trailing: Text(
          '${isIncome ? '+' : '-'}'
          '₹${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String categoryName) {
    for (final category in expenseCategories) {
      if (category.name == categoryName) {
        return category.icon;
      }
    }

    return Icons.more_horiz_rounded;
  }
}

class _EmptyTransactionsView extends StatelessWidget {
  const _EmptyTransactionsView({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No transactions found' : 'No transactions yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term.'
                  : 'Your expenses and income will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
