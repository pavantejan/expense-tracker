import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/ledger/posting_rules.dart';
import '../../core/domain/money.dart';
import '../../core/domain/reporting.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/repositories/ledger_query_service.dart';
import '../common/ui.dart';
import '../transactions/add_transaction_page.dart';
import 'account_form_page.dart';

/// Reporting output for "now": current balances for every account.
Stream<ReportingPeriod> watchCurrentReporting(AppServices services) {
  final now = DateTime.now();
  return services.queries.watchReporting(
    periodStart: monthStart(now),
    periodEndExclusive: nextMonthStart(now),
  );
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late AppServices _services;
  Stream<List<Account>>? _accounts;
  Stream<ReportingPeriod>? _reporting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts == null) {
      _services = AppScope.of(context);
      _accounts = _services.queries.watchAccounts();
      _reporting = watchCurrentReporting(_services);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-account'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountFormPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
      body: StreamBuilder<List<Account>>(
        stream: _accounts,
        builder: (context, accountsSnapshot) {
          return StreamBuilder<ReportingPeriod>(
            stream: _reporting,
            builder: (context, reportingSnapshot) {
              final accounts = accountsSnapshot.data;
              if (accounts == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final balances =
                  reportingSnapshot.data?.currentBalances ??
                  const <String, Money>{};
              final active = accounts.where((a) => !a.isArchived).toList();
              final archived = accounts.where((a) => a.isArchived).toList();
              var assets = Money.zero('INR');
              var owed = Money.zero('INR');
              for (final account in active) {
                final balance = balances[account.uuid] ?? Money.zero('INR');
                if (isLiabilityKind(account.kind)) {
                  owed = owed + balance;
                } else {
                  assets = assets + balance;
                }
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (accounts.isEmpty)
                    EmptyStateCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Add your first account',
                      message:
                          'Add your bank accounts, cash, wallets and credit '
                          'cards to see each balance.',
                      actionLabel: 'Add account',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountFormPage(),
                        ),
                      ),
                    )
                  else ...[
                    AmountTile(
                      title: 'Available balance',
                      subtitle: 'Bank, cash, wallets and other assets',
                      amount: assets,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    if (active.any((a) => isLiabilityKind(a.kind)))
                      AmountTile(
                        title: 'Credit card dues',
                        subtitle: 'Shown separately, never subtracted',
                        amount: owed,
                        icon: Icons.credit_card_rounded,
                      ),
                    const SizedBox(height: 16),
                    for (final account in active)
                      _AccountTile(
                        account: account,
                        balance: balances[account.uuid] ?? Money.zero('INR'),
                      ),
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Archived',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final account in archived)
                        _AccountTile(
                          account: account,
                          balance: balances[account.uuid] ?? Money.zero('INR'),
                        ),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.balance});

  final Account account;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final isCard = isLiabilityKind(account.kind);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(accountKindIcon(account.kind))),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${accountKindLabels[account.kind] ?? account.kind}'
          '${account.isArchived ? ' • Archived' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balance.format(),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isCard) const Text('owed'),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountDetailPage(accountUuid: account.uuid),
          ),
        ),
      ),
    );
  }
}

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.accountUuid});

  final String accountUuid;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late AppServices _services;
  Stream<List<Account>>? _accounts;
  Stream<ReportingPeriod>? _reporting;
  Stream<List<TransactionView>>? _transactions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts == null) {
      _services = AppScope.of(context);
      _accounts = _services.queries.watchAccounts();
      _reporting = watchCurrentReporting(_services);
      _transactions = _services.queries.watchTransactions(
        accountUuid: widget.accountUuid,
      );
    }
  }

  Future<void> _toggleArchive(Account account) async {
    try {
      if (account.isArchived) {
        await _services.accounts.restoreAccount(account.uuid);
      } else {
        await _services.accounts.archiveAccount(account.uuid);
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  Future<void> _correctBalance(Account account, Money current) async {
    final isCard = isLiabilityKind(account.kind);
    final actual = await showDialog<Money>(
      context: context,
      builder: (_) => _CorrectBalanceDialog(current: current, isCard: isCard),
    );
    if (actual == null || !mounted) {
      return;
    }
    try {
      await correctAccountBalance(_services, account, current, actual);
      unawaited(_services.sync.requestSync());
      if (mounted) {
        showMessage(context, 'Balance updated to ${actual.format()}.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: _accounts,
      builder: (context, accountsSnapshot) {
        final account = accountsSnapshot.data
            ?.where((a) => a.uuid == widget.accountUuid)
            .firstOrNull;
        if (account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final isCard = isLiabilityKind(account.kind);
        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              IconButton(
                tooltip: 'Edit account',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountFormPage(accountUuid: account.uuid),
                  ),
                ),
              ),
              IconButton(
                tooltip: account.isArchived ? 'Restore' : 'Archive',
                icon: Icon(
                  account.isArchived
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded,
                ),
                onPressed: () => _toggleArchive(account),
              ),
            ],
          ),
          floatingActionButton: account.isArchived
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AddTransactionPage(initialAccountUuid: account.uuid),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add transaction'),
                ),
          body: StreamBuilder<ReportingPeriod>(
            stream: _reporting,
            builder: (context, reportingSnapshot) {
              final balance =
                  reportingSnapshot.data?.currentBalances[account.uuid] ??
                  Money.zero(account.currencyCode);
              return StreamBuilder<List<TransactionView>>(
                stream: _transactions,
                builder: (context, txSnapshot) {
                  final transactions = txSnapshot.data ?? const [];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCard ? 'Amount owed' : 'Balance',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                balance.format(),
                                key: const Key('account-balance'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                accountKindLabels[account.kind] ?? account.kind,
                              ),
                              if (!account.isArchived) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const Key('correct-balance'),
                                  onPressed: () =>
                                      _correctBalance(account, balance),
                                  icon: const Icon(Icons.tune_rounded),
                                  label: const Text('Correct balance'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (transactions.isEmpty)
                        const EmptyStateCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions yet',
                          message: 'Transactions for this account appear here.',
                        )
                      else
                        for (final view in transactions)
                          TransactionTile(
                            view: view,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddTransactionPage(
                                  transactionUuid: view.uuid,
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Brings an account to [actual] without rewriting history:
/// - no activity yet: records an opening balance;
/// - only an opening balance so far: edits (or removes) it;
/// - otherwise: a `balance_correction` adjustment for the difference.
Future<void> correctAccountBalance(
  AppServices services,
  Account account,
  Money current,
  Money actual,
) async {
  final delta = actual - current;
  if (delta.isZero) {
    return;
  }
  final history = await services.queries.loadTransactions(
    accountUuid: account.uuid,
  );
  if (history.isEmpty) {
    await services.transactions.createOpeningBalance(
      accountUuid: account.uuid,
      signedAmount: actual,
      occurredAt: DateTime.now(),
      paymentChannel: 'Bank Transfer',
    );
    return;
  }
  if (history.length == 1 && history.single.kind == 'opening_balance') {
    if (actual.isZero) {
      await services.transactions.deleteTransaction(history.single.uuid);
    } else {
      await services.transactions.editOpeningBalance(
        accountUuid: account.uuid,
        signedAmount: actual,
      );
    }
    return;
  }
  await services.transactions.createAdjustment(
    accountUuid: account.uuid,
    adjustmentReason: adjustmentReasonBalanceCorrection,
    direction: delta.isPositive
        ? AdjustmentDirection.increase
        : AdjustmentDirection.decrease,
    amount: delta.abs(),
    occurredAt: DateTime.now(),
    paymentChannel: 'Bank Transfer',
    description: 'Balance correction',
  );
}

class _CorrectBalanceDialog extends StatefulWidget {
  const _CorrectBalanceDialog({required this.current, required this.isCard});

  final Money current;
  final bool isCard;

  @override
  State<_CorrectBalanceDialog> createState() => _CorrectBalanceDialogState();
}

class _CorrectBalanceDialogState extends State<_CorrectBalanceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current.toDecimalString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final money = Money.tryParse(_controller.text);
    if (money == null) {
      setState(() => _error = 'Enter a valid amount (up to 2 decimals)');
      return;
    }
    Navigator.of(context).pop(money);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct balance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isCard
                ? 'Enter the amount you actually owe on this card.'
                : 'Enter the balance you actually have. Use a minus sign '
                      'for an overdrawn balance.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('actual-balance'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: widget.isCard ? 'Amount owed' : 'Actual balance',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The difference is recorded as a balance adjustment, not as '
            'income or an expense.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
