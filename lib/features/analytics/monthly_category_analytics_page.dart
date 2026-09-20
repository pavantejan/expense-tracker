import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';
import 'yearly_category_analytics_page.dart';

class MonthlyCategoryAnalyticsPage extends StatefulWidget {
  const MonthlyCategoryAnalyticsPage({
    super.key,
    this.initialMonth,
  });

  final DateTime? initialMonth;

  @override
  State<MonthlyCategoryAnalyticsPage> createState() =>
      _MonthlyCategoryAnalyticsPageState();
}

class _MonthlyCategoryAnalyticsPageState
    extends State<MonthlyCategoryAnalyticsPage> {
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
        title: const Text('Category Analytics'),
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

          final transactions = allTransactions.where(
            (transaction) =>
                transaction.type == 'Expense' &&
                !transaction.transactionDate.isBefore(monthStart) &&
                transaction.transactionDate.isBefore(nextMonthStart),
          );

          final categoryTotals = <String, double>{};

          for (final transaction in transactions) {
            categoryTotals.update(
              transaction.category,
              (current) => current + transaction.amount,
              ifAbsent: () => transaction.amount,
            );
          }

          final totalExpenses = categoryTotals.values.fold<double>(
            0,
            (total, amount) => total + amount,
          );

          final sortedCategories = categoryTotals.entries.toList()
            ..sort(
              (a, b) => b.value.compareTo(a.value),
            );

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Expenses',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatAmount(totalExpenses),
                        style:
                            theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category breakdown for '
                        '${_formatMonth(_selectedMonth)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (sortedCategories.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No expenses yet',
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No expenses found for '
                          '${_formatMonth(_selectedMonth)}.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...sortedCategories.map(
                  (entry) => _CategoryCard(
                    categoryName: entry.key,
                    amount: entry.value,
                    percentage: totalExpenses == 0
                        ? 0
                        : (entry.value / totalExpenses) * 100,
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
                    'Yearly Category Analytics',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'View category spending for a complete year',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => YearlyCategoryAnalyticsPage(
                          initialYear: _selectedMonth.year,
                        ),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  final String categoryName;
  final double amount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final category = _findCategory(categoryName);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(category?.icon ?? Icons.category_rounded),
        ),
        title: Text(
          categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  ExpenseCategory? _findCategory(String name) {
    for (final category in expenseCategories) {
      if (category.name == name) {
        return category;
      }
    }

    return null;
  }
}