import 'package:flutter/material.dart';

import '../accounts/accounts_page.dart';
import '../common/section_landing.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionLandingPage(
      title: 'Manage',
      intro: 'Your accounts, budgets, cards and goals.',
      entries: [
        SectionEntry(
          key: const Key('manage-accounts'),
          icon: Icons.account_balance_rounded,
          title: 'Accounts',
          subtitle: 'Bank, cash, wallets and credit cards with balances',
          page: (_) => const AccountsPage(),
        ),
        const SectionEntry(
          icon: Icons.pie_chart_rounded,
          title: 'Budgets',
          subtitle: 'Monthly limits and spending pace',
        ),
        const SectionEntry(
          icon: Icons.credit_card_rounded,
          title: 'Credit cards & EMI',
          subtitle: 'Limits, statements, due dates and instalments',
        ),
        const SectionEntry(
          icon: Icons.savings_rounded,
          title: 'Savings goals',
          subtitle: 'Save towards what matters',
        ),
      ],
    );
  }
}
