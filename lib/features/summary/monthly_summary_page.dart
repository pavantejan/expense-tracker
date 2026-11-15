import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/money.dart';
import '../../core/domain/reporting.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';
import 'yearly_summary_page.dart';

class MonthlySummaryPage extends StatefulWidget {
  const MonthlySummaryPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<MonthlySummaryPage> createState() => _MonthlySummaryPageState();
}

class _MonthlySummaryPageState extends State<MonthlySummaryPage> {
  late DateTime _month = monthStart(widget.initialMonth ?? DateTime.now());
  AppServices? _services;
  Stream<List<Account>>? _accounts;
  Stream<ReportingPeriod>? _current;
  Stream<ReportingPeriod>? _previous;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _accounts = _services!.queries.watchAccounts();
      _subscribe();
    }
  }

  void _subscribe() {
    final queries = _services!.queries;
    _current = queries.watchReporting(
      periodStart: _month,
      periodEndExclusive: nextMonthStart(_month),
    );
    // The previous month's closing balances are this month's opening.
    final previous = DateTime(_month.year, _month.month - 1);
    _previous = queries.watchReporting(
      periodStart: previous,
      periodEndExclusive: _month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final zero = Money.zero('INR');
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Summary')),
      body: StreamBuilder<List<Account>>(
        stream: _accounts,
        builder: (context, accountsSnapshot) {
          final accounts = accountsSnapshot.data ?? const <Account>[];
          return StreamBuilder<ReportingPeriod>(
            stream: _previous,
            builder: (context, previousSnapshot) {
              return StreamBuilder<ReportingPeriod>(
                stream: _current,
                builder: (context, currentSnapshot) {
                  final report = currentSnapshot.data;
                  final opening = balanceTotals(
                    accounts,
                    previousSnapshot.data?.closingBalances ?? const {},
                  );
                  final closing = balanceTotals(
                    accounts,
                    report?.closingBalances ?? const {},
                  );
                  final income = report?.incomeTotal ?? zero;
                  final expenses = report?.expenseTotal ?? zero;
                  final adjustments = report == null
                      ? zero
                      : report.balanceCorrectionEffect +
                            report.openingCorrectionEffect +
                            report.feeCorrectionEffect +
                            report.otherAdjustmentEffect;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      MonthSelector(
                        month: _month,
                        onChanged: (m) => setState(() {
                          _month = monthStart(m);
                          _subscribe();
                        }),
                      ),
                      const SizedBox(height: 20),
                      AmountTile(
                        title: 'Opening balance',
                        subtitle: 'Bank, cash and wallets at month start',
                        amount: opening.assets,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      AmountTile(
                        title: 'Income',
                        amount: income,
                        icon: Icons.arrow_downward_rounded,
                      ),
                      AmountTile(
                        title: 'Expenses',
                        subtitle: 'Refunds are subtracted',
                        amount: expenses,
                        icon: Icons.arrow_upward_rounded,
                      ),
                      AmountTile(
                        title: 'Net (income − expenses)',
                        amount: income - expenses,
                        icon: Icons.swap_vert_rounded,
                      ),
                      AmountTile(
                        title: 'Closing balance',
                        subtitle: 'Bank, cash and wallets at month end',
                        amount: closing.assets,
                        icon: Icons.account_balance_rounded,
                      ),
                      if (accounts.any((a) => isLiabilityKind(a.kind)))
                        AmountTile(
                          title: 'Credit card dues',
                          subtitle: 'At month end',
                          amount: closing.owed,
                          icon: Icons.credit_card_rounded,
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Not counted as income or expenses',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      AmountTile(
                        title: 'Transfers between accounts',
                        amount: report?.transferTotal ?? zero,
                        icon: Icons.swap_horiz_rounded,
                      ),
                      AmountTile(
                        title: 'Credit card payments',
                        amount: report?.cardPaymentTotal ?? zero,
                        icon: Icons.credit_score_rounded,
                      ),
                      AmountTile(
                        title: 'Balance adjustments',
                        amount: adjustments,
                        icon: Icons.tune_rounded,
                      ),
                      AmountTile(
                        title: 'Opening balances added',
                        amount: report?.openingBalanceTotal ?? zero,
                        icon: Icons.flag_rounded,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.calendar_view_month_rounded),
                          ),
                          title: const Text(
                            'Yearly Summary',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'View the complete yearly breakdown',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  YearlySummaryPage(initialYear: _month.year),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
