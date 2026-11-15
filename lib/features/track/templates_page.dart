import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';
import '../transactions/add_transaction_page.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  AppServices? _services;
  Stream<List<TransactionTemplate>>? _templates;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _templates = _services!.templates.watchTemplates();
    }
  }

  Future<void> _rename(TransactionTemplate template) async {
    final controller = TextEditingController(text: template.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename template'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await _run(() => _services!.templates.renameTemplate(template.uuid, name));
  }

  Future<void> _delete(TransactionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          'Delete "${template.name}"? Transactions you already saved '
          'from it are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => _services!.templates.deleteTemplate(template.uuid));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Templates & favourites')),
      body: StreamBuilder<List<TransactionTemplate>>(
        stream: _templates,
        builder: (context, snapshot) {
          final templates = snapshot.data;
          if (templates == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (templates.isEmpty)
                const EmptyStateCard(
                  icon: Icons.bolt_rounded,
                  title: 'No templates yet',
                  message:
                      'While adding a transaction, tap the bookmark icon to '
                      'save it as a template. Favourites appear as one-tap '
                      'chips on the add screen.',
                )
              else ...[
                const Text(
                  'Tap a template to start a new transaction from it. '
                  'Starred templates appear as one-tap chips when adding.',
                ),
                const SizedBox(height: 12),
                for (final template in templates)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: IconButton(
                        key: ValueKey('favourite-toggle-${template.uuid}'),
                        tooltip: template.isFavourite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        icon: Icon(
                          template.isFavourite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                        ),
                        onPressed: () => _run(
                          () => _services!.templates.setFavourite(
                            template.uuid,
                            !template.isFavourite,
                          ),
                        ),
                      ),
                      title: Text(
                        template.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          transactionKindLabels[template.kind] ?? template.kind,
                          if (template.amountMinorUnits != null)
                            formatMinor(
                              template.amountMinorUnits!,
                              currencyCode: template.currencyCode,
                            )
                          else
                            'amount each time',
                          'used ${template.useCount}×',
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AddTransactionPage(templateUuid: template.uuid),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') {
                            unawaited(_rename(template));
                          } else {
                            unawaited(_delete(template));
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
