import 'package:flutter/material.dart';

/// One entry on a section landing page. A null [page] marks a feature
/// that arrives in a later module and is shown disabled.
class SectionEntry {
  const SectionEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.page,
    this.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder? page;
  final Key? key;
}

/// Landing page for one of the four sections (Track, Manage,
/// Understand, Automate).
class SectionLandingPage extends StatelessWidget {
  const SectionLandingPage({
    super.key,
    required this.title,
    required this.intro,
    required this.entries,
    this.header,
    this.actions,
  });

  final String title;
  final String intro;
  final List<SectionEntry> entries;
  final Widget? header;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: actions,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          ?header,
          for (final entry in entries)
            Card(
              key: entry.key,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                enabled: entry.page != null,
                leading: CircleAvatar(child: Icon(entry.icon)),
                title: Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  entry.page == null
                      ? '${entry.subtitle} • Coming soon'
                      : entry.subtitle,
                ),
                trailing: entry.page == null
                    ? null
                    : const Icon(Icons.chevron_right_rounded),
                onTap: entry.page == null
                    ? null
                    : () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: entry.page!)),
              ),
            ),
        ],
      ),
    );
  }
}
