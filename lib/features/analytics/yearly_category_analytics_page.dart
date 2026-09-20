import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';

class YearlyCategoryAnalyticsPage extends StatefulWidget {
  const YearlyCategoryAnalyticsPage({
    super.key,
    this.initialYear,
  });

  final int? initialYear;

  @override
  State<YearlyCategoryAnalyticsPage> createState() =>
      _YearlyCategoryAnalyticsPageState();
}

class _YearlyCategoryAnalyticsPageState
    extends State<YearlyCategoryAnalyticsPage> {
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
        title: const Text('Yearly Category Analytics'),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: transactionRepository.watchAllTransactions(),
        builder: (context, snapshot) {
          final allTransactions = snapshot.data ?? [];

          final yearStart = DateTime(_selectedYear);
          final nextYearStart = DateTime(_selectedYear + 1);

          final transactions = allTransactions.where(
            (transaction) =>
                transaction.type == 'Expense' &&
                !transaction.transactionDate.isBefore(yearStart) &&
                transaction.transactionDate.isBefore(nextYearStart),
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
                        'Category breakdown for $_selectedYear',
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
                          'No expenses found for $_selectedYear.',
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
            ],
          );
        },
      ),
    );
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
          child: Icon(
            category?.icon ?? Icons.category_rounded,
          ),
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