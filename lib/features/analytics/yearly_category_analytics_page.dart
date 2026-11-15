import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/reporting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';
import 'category_breakdown.dart';

class YearlyCategoryAnalyticsPage extends StatefulWidget {
  const YearlyCategoryAnalyticsPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<YearlyCategoryAnalyticsPage> createState() =>
      _YearlyCategoryAnalyticsPageState();
}

class _YearlyCategoryAnalyticsPageState
    extends State<YearlyCategoryAnalyticsPage> {
  late int _year = widget.initialYear ?? DateTime.now().year;
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
      periodStart: DateTime(_year),
      periodEndExclusive: DateTime(_year + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yearly Category Analytics')),
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
                  YearSelector(
                    year: _year,
                    onChanged: (y) => setState(() {
                      _year = y;
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
                      periodLabel: '$_year',
                      showIncome: _showIncome,
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
