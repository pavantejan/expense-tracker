import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/reporting.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';
import 'category_breakdown.dart';
import 'yearly_category_analytics_page.dart';

class MonthlyCategoryAnalyticsPage extends StatefulWidget {
  const MonthlyCategoryAnalyticsPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<MonthlyCategoryAnalyticsPage> createState() =>
      _MonthlyCategoryAnalyticsPageState();
}

class _MonthlyCategoryAnalyticsPageState
    extends State<MonthlyCategoryAnalyticsPage> {
  late DateTime _month = monthStart(widget.initialMonth ?? DateTime.now());
  bool _showIncome = false;
  AppServices? _services;
  Stream<ReportingPeriod>? _report;
  Stream<List<Category>>? _categories;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _categories = _services!.queries.watchCategories();
      _subscribe();
    }
  }

  void _subscribe() {
    _report = _services!.queries.watchReporting(
      periodStart: _month,
      periodEndExclusive: nextMonthStart(_month),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Category Analytics')),
      body: StreamBuilder<List<Category>>(
        stream: _categories,
        builder: (context, categoriesSnapshot) {
          return StreamBuilder<ReportingPeriod>(
            stream: _report,
            builder: (context, snapshot) {
              final report = snapshot.data;
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
                  const SizedBox(height: 12),
                  AnalyticsSideSwitch(
                    showIncome: _showIncome,
                    onChanged: (v) => setState(() => _showIncome = v),
                  ),
                  const SizedBox(height: 16),
                  if (report == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    CategoryBreakdown(
                      byCategory: _showIncome
                          ? report.incomeByCategory
                          : report.expenseByCategory,
                      categories: categoriesSnapshot.data ?? const [],
                      periodLabel: formatMonth(_month),
                      showIncome: _showIncome,
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.calendar_view_month_rounded),
                      ),
                      title: const Text(
                        'Yearly Category Analytics',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'View category totals for a complete year',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => YearlyCategoryAnalyticsPage(
                            initialYear: _month.year,
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
