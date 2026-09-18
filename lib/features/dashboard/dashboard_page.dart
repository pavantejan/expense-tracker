import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';
import '../transactions/add_transaction_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Transaction>>(
      stream: transactionRepository.watchAllTransactions(),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];

        final income = transactions
            .where((transaction) => transaction.type == 'Income')
            .fold<double>(
              0,
              (total, transaction) => total + transaction.amount,
            );

        final expenses = transactions
            .where((transaction) => transaction.type == 'Expense')
            .fold<double>(
              0,
              (total, transaction) => total + transaction.amount,
            );

        final balance = income - expenses;

        final recentTransactions = [...transactions]
          ..sort(
            (a, b) => b.transactionDate.compareTo(a.transactionDate),
          );

        final displayedTransactions =
            recentTransactions.take(5).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Expense Tracker',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'September 2026',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatAmount(balance),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Income',
                        amount: _formatAmount(income),
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Expenses',
                        amount: _formatAmount(expenses),
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View all'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (displayedTransactions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first expense or income.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayedTransactions.map(
                    (transaction) => _TransactionCard(
                      transaction: transaction,
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddTransactionPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Transaction'),
          ),
        );
      },
    );
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
  });

  final String title;
  final String amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
  });

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'Income';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
          ),
        ),
        title: Text(
          transaction.description?.isNotEmpty == true
              ? transaction.description!
              : transaction.category,
        ),
        subtitle: Text(
          '${transaction.category} • ${transaction.paymentMethod}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}