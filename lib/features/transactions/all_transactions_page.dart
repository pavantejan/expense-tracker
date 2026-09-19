import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';
import 'add_transaction_page.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
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
                    : transactionRepository.searchTransactions(
                        _searchQuery,
                      ),
                builder: (context, snapshot) {
                  final transactions = snapshot.data ?? [];

                  if (transactions.isEmpty) {
                    return _EmptyTransactionsView(
                      isSearching: _searchQuery.isNotEmpty,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];

                      return _AllTransactionCard(
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
  const _AllTransactionCard({
    required this.transaction,
    required this.onTap,
  });

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
                : Icons.arrow_upward_rounded,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
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
}

class _EmptyTransactionsView extends StatelessWidget {
  const _EmptyTransactionsView({
    required this.isSearching,
  });

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
              isSearching
                  ? 'No transactions found'
                  : 'No transactions yet',
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