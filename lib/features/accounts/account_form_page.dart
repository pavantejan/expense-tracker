import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/domain/money.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';

/// Create an account (with optional opening balance) or rename an
/// existing one ([accountUuid]).
class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key, this.accountUuid});

  final String? accountUuid;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController();
  String _kind = 'bank';
  bool _negativeOpening = false;
  DateTime _openingDate = DateTime.now();
  Account? _existing;
  bool _loading = true;
  bool _saving = false;
  late AppServices _services;

  bool get _isEdit => widget.accountUuid != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _services = AppScope.of(context);
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final uuid = widget.accountUuid;
    if (uuid != null) {
      final account = await _services.accounts.getAccountByUuid(uuid);
      _existing = account;
      _name.text = account?.name ?? '';
      _kind = account?.kind ?? 'bank';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _openingDate = picked);
    }
  }

  DateTime _openingOccurredAt() {
    final now = DateTime.now();
    if (_openingDate.year == now.year &&
        _openingDate.month == now.month &&
        _openingDate.day == now.day) {
      return now;
    }
    return DateTime(_openingDate.year, _openingDate.month, _openingDate.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = _existing;
      if (existing == null) {
        final text = _opening.text.trim();
        Money? opening;
        if (text.isNotEmpty) {
          final parsed = Money.parse(text);
          opening = _negativeOpening ? -parsed : parsed;
        }
        await _services.accounts.createAccount(
          name: _name.text.trim(),
          kind: _kind,
          openingBalance: opening,
          openingOccurredAt: opening == null ? null : _openingOccurredAt(),
        );
        unawaited(_services.sync.requestSync());
      } else {
        if (_kind != existing.kind) {
          await _services.accounts.changeClassification(
            existing.uuid,
            newKind: _kind,
          );
        }
        await _services.accounts.updateAccountPresentation(
          existing.uuid,
          name: _name.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCard = isLiabilityKind(_kind);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit account' : 'Add account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('account-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                      hintText: 'e.g. HDFC Savings, Cash, Paytm',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('account-kind'),
                        isExpanded: true,
                        value: _kind,
                        items: [
                          for (final entry in accountKindLabels.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Icon(accountKindIcon(entry.key), size: 20),
                                  const SizedBox(width: 8),
                                  Text(entry.value),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _kind = v ?? 'bank'),
                      ),
                    ),
                  ),
                  if (_isEdit)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'The type can only change before the account has '
                        'any transactions.',
                      ),
                    ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('opening-balance'),
                      controller: _opening,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: isCard
                            ? 'Amount currently owed (optional)'
                            : 'Current balance (optional)',
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return null;
                        }
                        final money = Money.tryParse(text);
                        if (money == null) {
                          return text.contains('.') &&
                                  text.split('.').last.length > 2
                              ? 'Amounts support up to 2 decimal places'
                              : 'Enter a valid amount';
                        }
                        if (money.isNegative) {
                          return 'Use the switch below for a negative balance';
                        }
                        return null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isCard
                            ? 'The card has a credit balance (bank owes me)'
                            : 'The balance is negative (overdrawn)',
                      ),
                      value: _negativeOpening,
                      onChanged: (v) => setState(() => _negativeOpening = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: const Text('Balance as of'),
                      subtitle: Text(formatDate(_openingDate)),
                      onTap: _pickDate,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('save-account'),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_isEdit ? 'Save changes' : 'Add account'),
                  ),
                ],
              ),
            ),
    );
  }
}
