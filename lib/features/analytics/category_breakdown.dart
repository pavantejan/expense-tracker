import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/domain/money.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';

/// Expense / income switch shared by the analytics pages.
class AnalyticsSideSwitch extends StatelessWidget {
  const AnalyticsSideSwitch({
    super.key,
    required this.showIncome,
    required this.onChanged,
  });

  final bool showIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Expenses')),
        ButtonSegment(value: true, label: Text('Income')),
      ],
      selected: {showIncome},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Total card plus one progress row per category, largest first.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.byCategory,
    required this.categories,
    required this.periodLabel,
    required this.showIncome,
  });

  final Map<String, Money> byCategory;
  final List<Category> categories;
  final String periodLabel;
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var total = Money.zero('INR');
    for (final amount in byCategory.values) {
      total = total + amount;
    }
    final entries = byCategory.entries.where((e) => !e.value.isZero).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final names = {for (final c in categories) c.categoryId: c};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showIncome ? 'Total Income' : 'Total Expenses',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  total.format(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category breakdown for $periodLabel',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          EmptyStateCard(
            icon: Icons.analytics_outlined,
            title: showIncome ? 'No income yet' : 'No expenses yet',
            message:
                'No ${showIncome ? 'income' : 'expenses'} found for '
                '$periodLabel.',
          )
        else
          for (final entry in entries)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  child: Icon(
                    names[entry.key] == null
                        ? Icons.category_rounded
                        : iconForCategory(
                            entry.key,
                            names[entry.key]!.iconCodePoint,
                          ),
                  ),
                ),
                title: Text(
                  names[entry.key]?.name ?? entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: displayRatio(entry.value, total),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.value.format(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(displayRatio(entry.value, total) * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
