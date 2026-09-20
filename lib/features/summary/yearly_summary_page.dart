import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';

class YearlySummaryPage extends StatefulWidget {
  const YearlySummaryPage({
    super.key,
    this.initialYear,
  });

  final int? initialYear;

  @override
  State<YearlySummaryPage> createState() => _YearlySummaryPageState();
}

class _YearlySummaryPageState extends State<YearlySummaryPage> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();

    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  void _changeYear(int yearOffset) {
    setState(() {
      _selectedYear += yearOffset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yearly Summary'),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: transactionRepository.watchAllTransactions(),
        builder: (context, snapshot) {
          final allTransactions = snapshot.data ?? [];

          final yearStart = DateTime(_selectedYear);
          final nextYearStart = DateTime(_selectedYear + 1);

          final transactions = allTransactions
              .where(
                (transaction) =>
                    !transaction.transactionDate.isBefore(yearStart) &&
                    transaction.transactionDate.isBefore(nextYearStart),
              )
              .toList();

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

          final netChange = income - expenses;

          final openingBalance = allTransactions
              .where(
                (transaction) =>
                    transaction.transactionDate.isBefore(yearStart),
              )
              .fold<double>(
            0,
            (balance, transaction) {
              if (transaction.type == 'Income') {
                return balance + transaction.amount;
              }

              return balance - transaction.amount;
            },
          );

          final closingBalance = openingBalance + netChange;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeYear(-1),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                    ),
                    tooltip: 'Previous year',
                  ),
                  Text(
                    '$_selectedYear',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeYear(1),
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    tooltip: 'Next year',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SummaryCard(
                title: 'Opening Balance',
                amount: _formatAmount(openingBalance),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Income',
                amount: _formatAmount(income),
                icon: Icons.arrow_downward_rounded,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Expenses',
                amount: _formatAmount(expenses),
                icon: Icons.arrow_upward_rounded,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Net Change',
                amount: _formatAmount(netChange),
                icon: Icons.swap_vert_rounded,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Closing Balance',
                amount: _formatAmount(closingBalance),
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.receipt_long_rounded,
                    ),
                  ),
                  title: const Text(
                    'Transactions',
                  ),
                  subtitle: Text(
                    'Total transactions in $_selectedYear',
                  ),
                  trailing: Text(
                    '${transactions.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Monthly Breakdown',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildMonthlyBreakdown(
                context,
                allTransactions,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMonthlyBreakdown(
    BuildContext context,
    List<Transaction> allTransactions,
  ) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return List.generate(12, (index) {
      final month = index + 1;

      final monthStart = DateTime(
        _selectedYear,
        month,
      );

      final nextMonthStart = DateTime(
        _selectedYear,
        month + 1,
      );

      final monthTransactions = allTransactions.where(
        (transaction) =>
            !transaction.transactionDate.isBefore(monthStart) &&
            transaction.transactionDate.isBefore(nextMonthStart),
      );

      final income = monthTransactions
          .where((transaction) => transaction.type == 'Income')
          .fold<double>(
            0,
            (total, transaction) => total + transaction.amount,
          );

      final expenses = monthTransactions
          .where((transaction) => transaction.type == 'Expense')
          .fold<double>(
            0,
            (total, transaction) => total + transaction.amount,
          );

      final netChange = income - expenses;

      final openingBalance = allTransactions
          .where(
            (transaction) =>
                transaction.transactionDate.isBefore(monthStart),
          )
          .fold<double>(
        0,
        (balance, transaction) {
          if (transaction.type == 'Income') {
            return balance + transaction.amount;
          }

          return balance - transaction.amount;
        },
      );

      final closingBalance = openingBalance + netChange;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            monthNames[index],
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Opening: ${_formatAmount(openingBalance)}\n'
            'Income: ${_formatAmount(income)}\n'
            'Expenses: ${_formatAmount(expenses)}\n'
            'Closing: ${_formatAmount(closingBalance)}',
          ),
          isThreeLine: false,
          trailing: Text(
            _formatAmount(netChange),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: netChange >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    });
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: const Text(
          'For selected year',
        ),
        trailing: Text(
          amount,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}