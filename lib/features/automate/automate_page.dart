import 'package:flutter/material.dart';

import '../common/section_landing.dart';

class AutomatePage extends StatelessWidget {
  const AutomatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionLandingPage(
      title: 'Automate',
      intro: 'Recurring transactions, bills, reminders and smart rules.',
      entries: [
        SectionEntry(
          icon: Icons.autorenew_rounded,
          title: 'Recurring transactions',
          subtitle: 'Rent, salary, subscriptions',
        ),
        SectionEntry(
          icon: Icons.event_note_rounded,
          title: 'Upcoming bills',
          subtitle: 'What is due soon',
        ),
        SectionEntry(
          icon: Icons.alarm_rounded,
          title: 'Reminders',
          subtitle: 'Scheduled and delivered reminders',
        ),
        SectionEntry(
          icon: Icons.notifications_active_outlined,
          title: 'Budget alerts',
          subtitle: 'Warnings at 80% and 100% of a budget',
        ),
        SectionEntry(
          icon: Icons.rule_rounded,
          title: 'Smart rules',
          subtitle: 'Auto-categorise by merchant',
        ),
      ],
    );
  }
}
