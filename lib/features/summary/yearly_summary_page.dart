import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/money.dart';
import '../../core/domain/reporting.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';
import 'monthly_summary_page.dart';

class YearlySummaryPage extends StatefulWidget {
  const YearlySummaryPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<YearlySummaryPage> createState() => _YearlySummaryPageState();
}

class _YearlySummaryPageState extends State<YearlySummaryPage> {
  late int _year = widget.initialYear ?? DateTime.now().year;
  AppServices? _services;
  Stream<List<Account>>? _accounts;
  Stream<List<ReportingPeriod>>? _reports;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _accounts = _services!.queries.watchAccounts();
      _reports = _services!.queries.watchYearByMonth(_year);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zero = Money.zero('INR');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Yearly Summary')),
      body: StreamBuilder<List<Account>>(
        stream: _accounts,
        builder: (context, accountsSnapshot) {
          final accounts = accountsSnapshot.data ?? const <Account>[];
          return StreamBuilder<List<ReportingPeriod>>(
            stream: _reports,
            builder: (context, snapshot) {
              final reports = snapshot.data;
              final year = reports?.last;
              final income = year?.incomeTotal ?? zero;
              final expenses = year?.expenseTotal ?? zero;
              final closing = balanceTotals(
                accounts,
                year?.closingBalances ?? const {},
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  YearSelector(
                    year: _year,
                    onChanged: (y) => setState(() {
                      _year = y;
                      _reports = _services!.queries.watchYearByMonth(y);
                    }),
                  ),
                  const SizedBox(height: 20),
                  AmountTile(
                    title: 'Income',
                    amount: income,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  AmountTile(
                    title: 'Expenses',
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
                    subtitle: 'Bank, cash and wallets at year end',
                    amount: closing.assets,
                    icon: Icons.account_balance_rounded,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Monthly Breakdown',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (reports == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (var i = 0; i < 12; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            monthNames[i],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Income ${reports[i].incomeTotal.format()} • '
                            'Expenses ${reports[i].expenseTotal.format()}',
                          ),
                          trailing: Text(
                            (reports[i].incomeTotal - reports[i].expenseTotal)
                                .format(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MonthlySummaryPage(
                                initialMonth: DateTime(_year, i + 1),
                              ),
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
  }
}
