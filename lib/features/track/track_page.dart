import 'package:flutter/material.dart';

import '../categories/categories_page.dart';
import '../common/section_landing.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/all_transactions_page.dart';
import 'merchants_tags_page.dart';
import 'templates_page.dart';

class TrackPage extends StatelessWidget {
  const TrackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionLandingPage(
      title: 'Track',
      intro: 'Record money movement quickly and keep it organised.',
      entries: [
        SectionEntry(
          key: const Key('track-add'),
          icon: Icons.add_rounded,
          title: 'Add transaction',
          subtitle: 'Expense, income or transfer',
          page: (_) => const AddTransactionPage(),
        ),
        SectionEntry(
          key: const Key('track-history'),
          icon: Icons.manage_search_rounded,
          title: 'Search & history',
          subtitle: 'Filter by date, category, account, merchant, tag, amount',
          page: (_) => const AllTransactionsPage(),
        ),
        SectionEntry(
          key: const Key('track-templates'),
          icon: Icons.bolt_rounded,
          title: 'Templates & favourites',
          subtitle: 'One-tap entries for things you log often',
          page: (_) => const TemplatesPage(),
        ),
        SectionEntry(
          key: const Key('track-merchants'),
          icon: Icons.storefront_rounded,
          title: 'Merchants & tags',
          subtitle: 'Rename, set default categories, tidy labels',
          page: (_) => const MerchantsTagsPage(),
        ),
        SectionEntry(
          icon: Icons.category_rounded,
          title: 'Categories',
          subtitle: 'Expense and income categories',
          page: (_) => const CategoriesPage(),
        ),
        const SectionEntry(
          icon: Icons.document_scanner_rounded,
          title: 'Import & Scan',
          subtitle: 'Receipts, statements, CSV and shared files',
        ),
      ],
    );
  }
}
