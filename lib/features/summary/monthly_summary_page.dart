import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';
import 'yearly_summary_page.dart';

class MonthlySummaryPage extends StatefulWidget {
  const MonthlySummaryPage({
    super.key,
    this.initialMonth,
  });

  final DateTime? initialMonth;

  @override
  State<MonthlySummaryPage> createState() => _MonthlySummaryPageState();
}

class _MonthlySummaryPageState extends State<MonthlySummaryPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();

    final month = widget.initialMonth ?? DateTime.now();

    _selectedMonth = DateTime(
      month.year,
      month.month,
    );
  }

  void _changeMonth(int monthOffset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthOffset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: transactionRepository.watchAllTransactions(),
        builder: (context, snapshot) {
          final allTransactions = snapshot.data ?? [];

          final monthStart = DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
          );

          final nextMonthStart = DateTime(
            _selectedMonth.year,
            _selectedMonth.month + 1,
          );

          final transactions = allTransactions
              .where(
                (transaction) =>
                    !transaction.transactionDate.isBefore(monthStart) &&
                    transaction.transactionDate.isBefore(nextMonthStart),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                    ),
                    tooltip: 'Previous month',
                  ),
                  Text(
                    _formatMonth(_selectedMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    tooltip: 'Next month',
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
                    'Total transactions in '
                    '${_formatMonth(_selectedMonth)}',
                  ),
                  trailing: Text(
                    '${transactions.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.calendar_view_month_rounded,
                    ),
                  ),
                  title: const Text(
                    'Yearly Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'View the complete yearly breakdown',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const YearlySummaryPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatMonth(DateTime date) {
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

    return '${monthNames[date.month - 1]} ${date.year}';
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
          'For selected month',
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