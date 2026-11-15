import 'package:flutter/material.dart';

import '../../core/domain/money.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/repositories/ledger_query_service.dart';
import '../common/ui.dart';

/// Bottom sheet that edits a [TransactionFilter]. Pops the new filter
/// on Apply, an empty filter on Clear, and null on dismiss.
class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.accounts,
    required this.categories,
    required this.merchants,
    required this.tags,
  });

  final TransactionFilter initial;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Merchant> merchants;
  final List<Tag> tags;

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.toInclusive;
  late String? _accountUuid = widget.initial.accountUuid;
  late String? _categoryId = widget.initial.categoryId;
  late String? _merchantUuid = widget.initial.merchantUuid;
  late int? _tagId = widget.initial.tagId;
  late final Set<String> _kinds = {...widget.initial.kinds};
  late final TextEditingController _min = TextEditingController(
    text: _decimal(widget.initial.minAmountMinorUnits),
  );
  late final TextEditingController _max = TextEditingController(
    text: _decimal(widget.initial.maxAmountMinorUnits),
  );
  String? _amountError;

  static String _decimal(int? minor) =>
      minor == null ? '' : Money(minor, 'INR').toDecimalString();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  void _apply() {
    int? parse(String text) {
      if (text.trim().isEmpty) {
        return null;
      }
      return Money.tryParse(text)?.amountMinorUnits ?? -1;
    }

    final min = parse(_min.text);
    final max = parse(_max.text);
    if ((min != null && min < 0) || (max != null && max < 0)) {
      setState(() => _amountError = 'Enter amounts like 250 or 99.50');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _amountError = 'Minimum is above maximum');
      return;
    }
    Navigator.of(context).pop(
      TransactionFilter(
        from: _from,
        toInclusive: _to,
        accountUuid: _accountUuid,
        categoryId: _categoryId,
        merchantUuid: _merchantUuid,
        tagId: _tagId,
        minAmountMinorUnits: min,
        maxAmountMinorUnits: max,
        kinds: _kinds,
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          isExpanded: true,
          value: items.any((i) => i.value == value) ? value : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const kindChoices = [
      'expense',
      'income',
      'transfer',
      'card_payment',
      'refund',
      'adjustment',
      'opening_balance',
      'reversal',
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('filter-dates'),
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  _from == null
                      ? 'Any date'
                      : '${formatDate(_from!)} – ${formatDate(_to!)}',
                ),
              ),
              if (_from != null)
                TextButton(
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                  child: const Text('Any date'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final kind in kindChoices)
                    FilterChip(
                      label: Text(transactionKindLabels[kind] ?? kind),
                      selected: _kinds.contains(kind),
                      onSelected: (on) => setState(
                        () => on ? _kinds.add(kind) : _kinds.remove(kind),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Account',
                value: _accountUuid,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final a in widget.accounts)
                    DropdownMenuItem(value: a.uuid, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountUuid = v),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Category',
                value: _categoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.categoryId, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Merchant',
                value: _merchantUuid,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final m in widget.merchants)
                    DropdownMenuItem(value: m.uuid, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() => _merchantUuid = v),
              ),
              const SizedBox(height: 12),
              _dropdown<int>(
                label: 'Tag',
                value: _tagId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final t in widget.tags)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() => _tagId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('filter-min'),
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('filter-max'),
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_amountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _amountError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const TransactionFilter()),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('apply-filters'),
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
