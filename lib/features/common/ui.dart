import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/domain/ledger/posting_rules.dart';
import '../../core/domain/money.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/repositories/ledger_query_service.dart';

/// Payment methods offered on forms (stored labels).
const List<String> paymentMethodChoices = <String>[
  'UPI',
  'Cash',
  'Card',
  'Bank Transfer',
];

const Map<String, String> accountKindLabels = <String, String>{
  'bank': 'Bank account',
  'cash': 'Cash',
  'wallet': 'Wallet',
  'other_asset': 'Other asset',
  'credit_card_liability': 'Credit card',
};

IconData accountKindIcon(String kind) {
  switch (kind) {
    case 'bank':
      return Icons.account_balance_rounded;
    case 'cash':
      return Icons.payments_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'credit_card_liability':
      return Icons.credit_card_rounded;
    default:
      return Icons.savings_rounded;
  }
}

bool isLiabilityKind(String kind) => kind == 'credit_card_liability';

const Map<String, String> transactionKindLabels = <String, String>{
  'expense': 'Expense',
  'income': 'Income',
  'transfer': 'Transfer',
  'card_payment': 'Card payment',
  'refund': 'Refund',
  'adjustment': 'Balance adjustment',
  'opening_balance': 'Opening balance',
  'reversal': 'Reversal',
};

/// A user-facing message for a failed repository call. Validation
/// messages are written for users; anything else is generic so no
/// internal detail leaks.
String friendlyError(Object error) {
  if (error is PostingValidationException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  return 'Something went wrong. Nothing was saved.';
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Previous / next month header.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
        ),
        Text(
          formatMonth(month),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

/// Previous / next year header.
class YearSelector extends StatelessWidget {
  const YearSelector({super.key, required this.year, required this.onChanged});

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => onChanged(year - 1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous year',
        ),
        Text(
          '$year',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () => onChanged(year + 1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next year',
        ),
      ],
    );
  }
}

class AmountTile extends StatelessWidget {
  const AmountTile({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final Money amount;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Text(
          amount.format(),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icon for a transaction row.
IconData transactionIcon(TransactionView view) {
  final category = view.category;
  switch (view.kind) {
    case 'transfer':
      return Icons.swap_horiz_rounded;
    case 'card_payment':
      return Icons.credit_score_rounded;
    case 'opening_balance':
      return Icons.flag_rounded;
    case 'adjustment':
      return category == null
          ? Icons.tune_rounded
          : iconForCategory(category.categoryId, category.iconCodePoint);
    case 'reversal':
      return Icons.undo_rounded;
    default:
      return category == null
          ? Icons.receipt_long_rounded
          : iconForCategory(category.categoryId, category.iconCodePoint);
  }
}

String transactionTitle(TransactionView view) {
  final description = view.transaction.description?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }
  if (view.merchant != null) {
    return view.merchant!.name;
  }
  if ((view.kind == 'expense' || view.kind == 'income') &&
      view.category != null) {
    return view.category!.name;
  }
  return transactionKindLabels[view.kind] ?? view.kind;
}

String transactionSubtitle(TransactionView view) {
  final parts = <String>[formatDate(view.transaction.occurredAt)];
  if (view.sourceAccount != null && view.destinationAccount != null) {
    parts.add('${view.sourceAccount!.name} → ${view.destinationAccount!.name}');
  } else if (view.account != null) {
    parts.add(view.account!.name);
  }
  if (view.kind != 'expense' && view.kind != 'income') {
    parts.add(transactionKindLabels[view.kind] ?? view.kind);
  } else if (view.category != null &&
      (view.transaction.description?.trim().isNotEmpty ?? false)) {
    parts.add(view.category!.name);
  }
  if (view.merchant != null &&
      view.merchant!.name != view.transaction.description?.trim()) {
    parts.add(view.merchant!.name);
  }
  if (view.tags.isNotEmpty) {
    parts.add(view.tags.map((t) => '#${t.name}').join(' '));
  }
  if (view.isReversed) {
    parts.add('Reversed');
  }
  return parts.join(' • ');
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.view, this.onTap});

  final TransactionView view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = formatMinor(
      view.transaction.amountMinorUnits,
      currencyCode: view.transaction.currencyCode,
    );
    final String sign;
    final Color? color;
    switch (view.flow) {
      case DisplayFlow.inflow:
        sign = '+';
        color = Colors.green.shade700;
      case DisplayFlow.outflow:
        sign = '−';
        color = theme.colorScheme.error;
      case DisplayFlow.neutral:
        sign = '';
        color = null;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(transactionIcon(view))),
        title: Text(
          transactionTitle(view),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: view.isReversed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          transactionSubtitle(view),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '$sign$amount',
          semanticsLabel: switch (view.flow) {
            DisplayFlow.inflow => 'In $amount',
            DisplayFlow.outflow => 'Out $amount',
            DisplayFlow.neutral => amount,
          },
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Category picker list for a given side (`expense` or `income`).
List<Category> categoriesForSide(List<Category> all, String side) {
  return all
      .where((c) => !c.isArchived && (c.kind == 'both' || c.kind == side))
      .toList();
}

/// Asset total and credit-card dues from reporting balances. Card dues
/// are kept separate and are never netted into the asset total.
({Money assets, Money owed}) balanceTotals(
  List<Account> accounts,
  Map<String, Money> balances,
) {
  var assets = Money.zero('INR');
  var owed = Money.zero('INR');
  for (final account in accounts) {
    final balance = balances[account.uuid] ?? Money.zero('INR');
    if (isLiabilityKind(account.kind)) {
      owed = owed + balance;
    } else {
      assets = assets + balance;
    }
  }
  return (assets: assets, owed: owed);
}
