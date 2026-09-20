import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';
import '../../core/notifications/notification_manager.dart';
import '../../data/notifications/notification.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/all_transactions_page.dart';
import '../settings/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  double _openingBalance = 0;
  double _previousBalance = 0;
  DateTime? _openingBalanceDate;

  @override
  void initState() {
    super.initState();

    _loadOpeningBalance();
  }

  Future<void> _loadOpeningBalance() async {
    final openingBalance =
        await appSettingsRepository.getOpeningBalance();

    final openingBalanceDate =
        await appSettingsRepository.getOpeningBalanceDate();

    final previousBalance =
        await transactionRepository.getBalanceBeforeMonth(
      _selectedMonth,
      openingBalanceDate,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _openingBalance = openingBalance;
      _openingBalanceDate = openingBalanceDate;
      _previousBalance = previousBalance;
    });
  }

  Future<void> _changeMonth(int monthOffset) async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthOffset,
      );
    });

    await _loadOpeningBalance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Transaction>>(
      stream: transactionRepository.watchTransactionsForMonth(
        _selectedMonth,
      ),
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

        final openingBalanceForMonth =
            _openingBalanceDate == null ||
                    _selectedMonth.isBefore(
                      DateTime(
                        _openingBalanceDate!.year,
                        _openingBalanceDate!.month,
                      ),
                    )
                ? 0
                : _openingBalance;

        final balance =
            openingBalanceForMonth +
            _previousBalance +
            income -
            expenses;

        final recentTransactions = [...transactions]
          ..sort(
            (a, b) => b.transactionDate.compareTo(
              a.transactionDate,
            ),
          );

        final displayedTransactions =
            recentTransactions.take(5).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Expense Tracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllTransactionsPage(
                        autoFocusSearch: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.search_rounded,
                ),
                tooltip: 'Search',
              ),
              AnimatedBuilder(
                animation: NotificationManager.instance,
                builder: (context, child) {
                  final unreadCount =
                      NotificationManager.instance.unreadCount;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          _showNotifications(context);
                        },
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                        ),
                        tooltip: 'Notifications',
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  );

                  await _loadOpeningBalance();
                },
                icon: const Icon(
                  Icons.settings_rounded,
                ),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        _changeMonth(-1);
                      },
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
                      onPressed: () {
                        _changeMonth(1);
                      },
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                      ),
                      tooltip: 'Next month',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatAmount(balance),
                          style:
                              theme.textTheme.headlineMedium?.copyWith(
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
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style:
                          theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AllTransactionsPage(),
                          ),
                        );
                      },
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
                            color:
                                theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style:
                                theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No transactions found for '
                            '${_formatMonth(_selectedMonth)}.',
                            textAlign: TextAlign.center,
                            style:
                                theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayedTransactions.map(
                    (transaction) => _TransactionCard(
                      transaction: transaction,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTransactionPage(
                              transactionId:
                                  transaction.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const AddTransactionPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Add Transaction',
            ),
          ),
        );
      },
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

void _showNotifications(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.transparent,
    transitionDuration:
        const Duration(milliseconds: 200),
    pageBuilder:
        (context, animation, secondaryAnimation) {
      return const _NotificationPopup();
    },
    transitionBuilder:
        (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

class _NotificationPopup extends StatelessWidget {
  const _NotificationPopup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 56,
            right: 12,
            left: 24,
          ),
          child: Material(
            elevation: 8,
            borderRadius:
                BorderRadius.circular(24),
            color: theme.colorScheme.surface,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 360,
                maxHeight: 520,
              ),
              child: AnimatedBuilder(
                animation:
                    NotificationManager.instance,
                builder: (context, child) {
                  final notifications =
                      NotificationManager
                          .instance
                          .notifications;

                  return Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Notifications',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (notifications.any(
                              (notification) =>
                                  !notification.isRead,
                            ))
                              TextButton(
                                onPressed: () {
                                  NotificationManager
                                      .instance
                                      .markAllAsRead();
                                },
                                child: const Text(
                                  'Mark all read',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (notifications.isEmpty)
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(
                              vertical: 40,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons
                                      .notifications_none_rounded,
                                  size: 48,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No notifications',
                                ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child:
                                ListView.separated(
                              shrinkWrap: true,
                              itemCount:
                                  notifications.length,
                              separatorBuilder:
                                  (_, _) =>
                                      const Divider(
                                height: 1,
                              ),
                              itemBuilder:
                                  (context, index) {
                                final notification =
                                    notifications[
                                        index];

                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 4,
                                  ),
                                  leading:
                                      CircleAvatar(
                                    child: Icon(
                                      _notificationIcon(
                                        notification
                                            .type,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight:
                                          notification
                                                  .isRead
                                              ? FontWeight
                                                  .normal
                                              : FontWeight
                                                  .bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    notification.message,
                                  ),
                                  trailing:
                                      notification
                                              .isRead
                                          ? null
                                          : Container(
                                              width: 8,
                                              height: 8,
                                              decoration:
                                                  BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primary,
                                                shape:
                                                    BoxShape
                                                        .circle,
                                              ),
                                            ),
                                  onTap: () {
                                    NotificationManager
                                        .instance
                                        .markAsRead(
                                      notification.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.transactionAdded:
        return Icons.add_rounded;
      case NotificationType.transactionUpdated:
        return Icons.edit_rounded;
      case NotificationType.transactionDeleted:
        return Icons.delete_outline_rounded;
      case NotificationType.transactionRestored:
        return Icons.restore_rounded;
      case NotificationType.syncCompleted:
        return Icons.cloud_done_outlined;
      case NotificationType.syncFailed:
        return Icons.cloud_off_outlined;
    }
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              title,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
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
    required this.onTap,
  });

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome =
        transaction.type == 'Income';

    return Card(
      margin:
          const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: () {
          _showDeleteConfirmation(
            context,
            transaction,
          );
        },
        leading: CircleAvatar(
          child: Icon(
            isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
          ),
        ),
        title: Text(
          transaction.description
                      ?.isNotEmpty ==
                  true
              ? transaction.description!
              : transaction.category,
        ),
        subtitle: Text(
          '${transaction.category} • '
          '${transaction.paymentMethod}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}'
          '₹${transaction.amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

Future<void> _showDeleteConfirmation(
  BuildContext context,
  Transaction transaction,
) async {
  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(
          'Delete transaction?',
        ),
        content: Text(
          'Are you sure you want to delete '
          '${transaction.description?.isNotEmpty == true ? transaction.description : transaction.category} '
          'for ₹${transaction.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext)
                  .pop(false);
            },
            child: const Text(
              'Cancel',
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext)
                  .pop(true);
            },
            child: const Text(
              'Delete',
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true ||
      !context.mounted) {
    return;
  }

  final deleted =
      await transactionRepository
          .deleteTransaction(
    transaction.id,
  );

  if (!deleted ||
      !context.mounted) {
    return;
  }

  NotificationManager.instance.add(
    type:
        NotificationType.transactionDeleted,
    title:
        'Transaction deleted',
    message:
        '${transaction.description?.isNotEmpty == true ? transaction.description : transaction.category} • '
        '₹${transaction.amount.toStringAsFixed(2)}',
  );

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: const Text(
        'Transaction deleted',
      ),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () async {
          final restored =
              await transactionRepository
                  .restoreTransaction(
            transaction.id,
          );

          if (!restored ||
              !context.mounted) {
            return;
          }

          NotificationManager.instance.add(
            type: NotificationType
                .transactionRestored,
            title:
                'Transaction restored',
            message:
                '${transaction.description?.isNotEmpty == true ? transaction.description : transaction.category} • '
                '₹${transaction.amount.toStringAsFixed(2)}',
          );

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Transaction restored',
              ),
            ),
          );
        },
      ),
    ),
  );
}