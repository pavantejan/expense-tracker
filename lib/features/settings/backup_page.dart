import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/backup/backup_codec.dart';
import '../../core/backup/csv_export.dart';
import '../../core/utils/formatting.dart';
import '../common/ui.dart';

enum ExportPeriod { thisMonth, thisYear, allTime, custom }

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  ExportPeriod _period = ExportPeriod.thisMonth;
  DateTimeRange? _custom;
  bool _busy = false;

  AppServices get _services => AppScope.of(context);

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  ({DateTime? from, DateTime? toExclusive, String label}) _range() {
    final now = DateTime.now();
    switch (_period) {
      case ExportPeriod.thisMonth:
        return (
          from: monthStart(now),
          toExclusive: nextMonthStart(now),
          label: formatMonth(now),
        );
      case ExportPeriod.thisYear:
        return (
          from: DateTime(now.year),
          toExclusive: DateTime(now.year + 1),
          label: '${now.year}',
        );
      case ExportPeriod.allTime:
        return (from: null, toExclusive: null, label: 'all time');
      case ExportPeriod.custom:
        final range = _custom;
        if (range == null) {
          return (from: null, toExclusive: null, label: 'all time');
        }
        return (
          from: range.start,
          toExclusive: DateTime(
            range.end.year,
            range.end.month,
            range.end.day + 1,
          ),
          label: '${formatDate(range.start)} – ${formatDate(range.end)}',
        );
    }
  }

  /// The plain-file warning (owner decision: unencrypted export with an
  /// explicit, acknowledged warning).
  Future<bool> _acknowledgePlainFile() async {
    var understood = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.lock_open_rounded),
          title: const Text('This file is not encrypted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'It contains your financial data in plain text: amounts, '
                'account names, descriptions and notes. Anyone who gets '
                'the file can read it. Store or share it only somewhere '
                'you trust.',
              ),
              CheckboxListTile(
                key: const Key('ack-plain-file'),
                contentPadding: EdgeInsets.zero,
                value: understood,
                onChanged: (v) => setDialogState(() => understood = v ?? false),
                title: const Text('I understand'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('ack-continue'),
              onPressed: understood
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _busyRun(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is BackupFormatException ? error.message : friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportCsv({required bool share}) async {
    if (!await _acknowledgePlainFile()) {
      return;
    }
    await _busyRun(() async {
      final range = _range();
      final views = await _services.queries.loadTransactions(
        from: range.from,
        toExclusive: range.toExclusive,
      );
      final csv = transactionsToCsv(views.reversed.toList());
      final name = 'expense-tracker-transactions-${_stamp()}.csv';
      if (share) {
        await _services.files.shareText(
          fileName: name,
          content: csv,
          mimeType: 'text/csv',
        );
      } else {
        final saved = await _services.files.saveText(
          fileName: name,
          content: csv,
          mimeType: 'text/csv',
        );
        if (saved && mounted) {
          showMessage(
            context,
            'Exported ${views.length} transaction(s) for ${range.label}.',
          );
        }
      }
    });
  }

  Future<void> _backup({required bool share}) async {
    if (!await _acknowledgePlainFile()) {
      return;
    }
    await _busyRun(() async {
      final json = await _services.backup.export();
      final name = 'expense-tracker-backup-${_stamp()}.json';
      if (share) {
        await _services.files.shareText(
          fileName: name,
          content: json,
          mimeType: 'application/json',
        );
      } else {
        final saved = await _services.files.saveText(
          fileName: name,
          content: json,
          mimeType: 'application/json',
        );
        if (saved && mounted) {
          showMessage(context, 'Backup saved.');
        }
      }
    });
  }

  Future<void> _restore() async {
    String? json;
    RestoreSummary? summary;
    await _busyRun(() async {
      json = await _services.files.pickText(extensions: const ['json']);
      if (json != null) {
        summary = _services.backup.inspect(json!);
      }
    });
    if (json == null || summary == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestoreConfirmDialog(summary: summary!),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _busyRun(() async {
      final result = await _services.backup.restore(json!);
      unawaited(_services.sync.requestSync());
      if (mounted) {
        showMessage(
          context,
          'Restored ${result.accounts} account(s) and '
          '${result.transactions} transaction(s).',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _range();
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & export')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('Files are not encrypted'),
                subtitle: const Text(
                  'Exports and backups are plain files. Keep them private.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Export transactions (CSV)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (period, label) in [
                  (ExportPeriod.thisMonth, 'This month'),
                  (ExportPeriod.thisYear, 'This year'),
                  (ExportPeriod.allTime, 'All time'),
                  (ExportPeriod.custom, 'Custom'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _period == period,
                    onSelected: (_) async {
                      if (period == ExportPeriod.custom) {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (picked == null) {
                          return;
                        }
                        _custom = picked;
                      }
                      setState(() => _period = period);
                    },
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Exports active transactions for ${range.label}. Opens in '
                'Excel, Google Sheets and other spreadsheet apps.',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('save-csv'),
                    onPressed: () => _exportCsv(share: false),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportCsv(share: true),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share CSV'),
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Text('Full backup', style: theme.textTheme.titleMedium),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'A complete copy of your accounts, transactions, categories, '
                'merchants, tags, templates and settings. Use it to move to '
                'a new phone or to recover after reinstalling.',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('save-backup'),
                    onPressed: () => _backup(share: false),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _backup(share: true),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share backup'),
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Text('Restore', style: theme.textTheme.titleMedium),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Replaces everything in the app with the contents of a '
                'backup file. Save a backup of your current data first if '
                'you might need it.',
              ),
            ),
            OutlinedButton.icon(
              key: const Key('restore-backup'),
              onPressed: _restore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore from a backup file'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog({required this.summary});

  final RestoreSummary summary;

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final created = widget.summary.createdAt;
    final ready = _controller.text.trim() == 'RESTORE';
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Replace all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup from ${created == null ? 'an unknown date' : formatDate(created)}: '
            '${widget.summary.accounts} account(s), '
            '${widget.summary.transactions} transaction(s).',
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything currently in the app will be replaced. This cannot '
            'be undone. Type RESTORE to continue.',
          ),
          TextField(
            key: const Key('restore-confirm'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('restore-go'),
          onPressed: ready ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Replace'),
        ),
      ],
    );
  }
}
