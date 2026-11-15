import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/money.dart';
import '../../core/domain/reporting.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/repositories/ledger_query_service.dart';
import '../accounts/account_form_page.dart';
import '../accounts/accounts_page.dart';
import '../analytics/monthly_category_analytics_page.dart';
import '../common/notifications_popup.dart';
import '../common/ui.dart';
import '../settings/settings_page.dart';
import '../summary/monthly_summary_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/all_transactions_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _month = monthStart(DateTime.now());
  AppServices? _services;
  Stream<ReportingPeriod>? _reporting;
  Stream<List<TransactionView>>? _recent;
  Stream<List<Account>>? _accounts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _accounts = _services!.queries.watchAccounts(includeArchived: false);
      _subscribeMonth();
    }
  }

  void _subscribeMonth() {
    final services = _services!;
    _reporting = services.queries.watchReporting(
      periodStart: _month,
      periodEndExclusive: nextMonthStart(_month),
    );
    _recent = services.queries.watchTransactions(
      from: _month,
      toExclusive: nextMonthStart(_month),
      limit: 5,
    );
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _month = monthStart(month);
      _subscribeMonth();
    });
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                _open(const AllTransactionsPage(autoFocusSearch: true)),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
          const NotificationsButton(),
          IconButton(
            onPressed: () => _open(const SettingsPage()),
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-transaction'),
        onPressed: () => _open(const AddTransactionPage()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Account>>(
          stream: _accounts,
          builder: (context, accountsSnapshot) {
            final accounts = accountsSnapshot.data;
            return StreamBuilder<ReportingPeriod>(
              stream: _reporting,
              builder: (context, reportingSnapshot) {
                final report = reportingSnapshot.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    MonthSelector(month: _month, onChanged: _changeMonth),
                    const SizedBox(height: 16),
                    if (accounts != null && accounts.isEmpty)
                      EmptyStateCard(
                        icon: Icons.account_balance_rounded,
                        title: 'Welcome! Add your first account',
                        message:
                            'Start with the accounts you use: a bank account, '
                            'cash, a wallet or a credit card. Balances are '
                            'calculated from your transactions.',
                        actionLabel: 'Add account',
                        onAction: () => _open(const AccountFormPage()),
                      )
                    else
                      _BalanceCard(
                        month: _month,
                        accounts: accounts ?? const [],
                        report: report,
                        onTap: () => _open(const AccountsPage()),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Income',
                            amount: report?.incomeTotal ?? Money.zero('INR'),
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Expenses',
                            amount: report?.expenseTotal ?? Money.zero('INR'),
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                      onAdd: () => _open(const AddTransactionPage()),
                      onTransfer: () => _open(
                        const AddTransactionPage(
                          initialType: EntryType.transfer,
                        ),
                      ),
                      onAccounts: () => _open(const AccountsPage()),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.analytics_outlined),
                        ),
                        title: const Text(
                          'Monthly Summary',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'View details for ${formatMonth(_month)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _open(MonthlySummaryPage(initialMonth: _month)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.pie_chart_outline_rounded),
                        ),
                        title: const Text(
                          'Category Analytics',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'See where you spent in ${formatMonth(_month)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(
                          MonthlyCategoryAnalyticsPage(initialMonth: _month),
                        ),
                      ),
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
                          onPressed: () => _open(const AllTransactionsPage()),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<TransactionView>>(
                      stream: _recent,
                      builder: (context, snapshot) {
                        final recent = snapshot.data ?? const [];
                        if (recent.isEmpty) {
                          return EmptyStateCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions yet',
                            message:
                                'No transactions found for '
                                '${formatMonth(_month)}.',
                          );
                        }
                        return Column(
                          children: [
                            for (final view in recent)
                              TransactionTile(
                                view: view,
                                onTap: () => _open(
                                  AddTransactionPage(
                                    transactionUuid: view.uuid,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.month,
    required this.accounts,
    required this.report,
    required this.onTap,
  });

  final DateTime month;
  final List<Account> accounts;
  final ReportingPeriod? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var assets = Money.zero('INR');
    var owed = Money.zero('INR');
    var hasCard = false;
    for (final account in accounts) {
      final balance =
          report?.closingBalances[account.uuid] ?? Money.zero('INR');
      if (isLiabilityKind(account.kind)) {
        hasCard = true;
        owed = owed + balance;
      } else {
        assets = assets + balance;
      }
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Available balance', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                assets.format(),
                key: const Key('available-balance'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Across ${accounts.where((a) => !isLiabilityKind(a.kind)).length} '
                'account(s) at the end of ${formatMonth(month)}',
                style: theme.textTheme.bodySmall,
              ),
              if (hasCard) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text('Credit card dues'),
                    const Spacer(),
                    Text(
                      owed.format(),
                      key: const Key('card-dues'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAdd,
    required this.onTransfer,
    required this.onAccounts,
  });

  final VoidCallback onAdd;
  final VoidCallback onTransfer;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(icon),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.add_rounded, 'Add', onAdd),
        const SizedBox(width: 8),
        action(Icons.swap_horiz_rounded, 'Transfer', onTransfer),
        const SizedBox(width: 8),
        action(Icons.account_balance_rounded, 'Accounts', onAccounts),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
  });

  final String title;
  final Money amount;
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
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount.format(),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
