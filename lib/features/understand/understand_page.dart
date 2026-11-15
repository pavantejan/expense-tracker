import 'package:flutter/material.dart';

import '../analytics/monthly_category_analytics_page.dart';
import '../analytics/yearly_category_analytics_page.dart';
import '../common/section_landing.dart';
import '../summary/monthly_summary_page.dart';
import '../summary/yearly_summary_page.dart';

class UnderstandPage extends StatelessWidget {
  const UnderstandPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionLandingPage(
      title: 'Understand',
      intro: 'Summaries, analytics and where your money goes.',
      entries: [
        SectionEntry(
          icon: Icons.calendar_month_rounded,
          title: 'Monthly summary',
          subtitle: 'Opening and closing balance, income and expenses',
          page: (_) => const MonthlySummaryPage(),
        ),
        SectionEntry(
          icon: Icons.calendar_view_month_rounded,
          title: 'Yearly summary',
          subtitle: 'Month-by-month breakdown',
          page: (_) => const YearlySummaryPage(),
        ),
        SectionEntry(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Category analytics',
          subtitle: 'Where you spent and earned this month',
          page: (_) => const MonthlyCategoryAnalyticsPage(),
        ),
        SectionEntry(
          icon: Icons.donut_large_rounded,
          title: 'Yearly category analytics',
          subtitle: 'Category totals for a whole year',
          page: (_) => const YearlyCategoryAnalyticsPage(),
        ),
        const SectionEntry(
          icon: Icons.show_chart_rounded,
          title: 'Trends & charts',
          subtitle: 'Charts, comparisons, top merchants',
        ),
        const SectionEntry(
          icon: Icons.account_balance_rounded,
          title: 'Net worth',
          subtitle: 'Everything you own minus everything you owe',
        ),
        const SectionEntry(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Insights',
          subtitle: 'Unusual spending and helpful nudges',
        ),
      ],
    );
  }
}
