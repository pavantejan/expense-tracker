import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/categories/category.dart';
import '../../core/domain/money.dart';
import '../../core/notifications/notification_manager.dart';
import '../../core/utils/formatting.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../../data/notifications/notification.dart';
import '../../data/repositories/financial_transaction_repository.dart';
import '../accounts/account_form_page.dart';
import '../common/ui.dart';

/// The three kinds a user enters directly. Card payments are entered
/// as a transfer to a credit-card account.
enum EntryType { expense, income, transfer }

/// Add a transaction, or view/edit an existing one ([transactionUuid]).
class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    this.transactionUuid,
    this.initialType = EntryType.expense,
    this.initialAccountUuid,
  });

  final String? transactionUuid;
  final EntryType initialType;
  final String? initialAccountUuid;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  late AppServices _services;
  bool _loading = true;
  bool _saving = false;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  FinancialTransaction? _existing;
  bool _existingReversed = false;

  EntryType _type = EntryType.expense;
  String? _accountUuid;
  String? _fromAccountUuid;
  String? _toAccountUuid;
  String? _categoryId;
  String _paymentMethod = 'UPI';
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.transactionUuid != null;

  /// Kinds with editable amount/accounts/category.
  bool get _fullyEditable {
    final kind = _existing?.kind;
    return kind == null ||
        kind == 'expense' ||
        kind == 'income' ||
        kind == 'transfer' ||
        kind == 'card_payment';
  }

  bool get _amountEditable => _fullyEditable || _existing?.kind == 'refund';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _services = AppScope.of(context);
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await _services.accounts.listAccounts();
    final categories = await _services.categories.listCategories();
    _type = widget.initialType;
    final uuid = widget.transactionUuid;
    if (uuid != null) {
      final views = await _services.queries.loadTransactions(
        includeDeleted: true,
      );
      final view = views.where((v) => v.uuid == uuid).firstOrNull;
      if (view != null) {
        final tx = view.transaction;
        _existing = tx;
        _existingReversed = view.isReversed;
        _type = switch (tx.kind) {
          'income' => EntryType.income,
          'transfer' || 'card_payment' => EntryType.transfer,
          _ => EntryType.expense,
        };
        _accountUuid = view.account?.uuid;
        _fromAccountUuid = tx.sourceAccountId;
        _toAccountUuid = tx.destinationAccountId;
        _categoryId = tx.categoryId;
        _paymentMethod = paymentMethodChoices.contains(tx.paymentChannel)
            ? tx.paymentChannel
            : 'UPI';
        _date = tx.occurredAt.toLocal();
        _amountController.text = Money(
          tx.amountMinorUnits,
          tx.currencyCode,
        ).toDecimalString();
        _descriptionController.text = tx.description ?? '';
        _notesController.text = tx.notes ?? '';
      }
    } else {
      final active = accounts.where((a) => !a.isArchived).toList();
      final initial = widget.initialAccountUuid;
      _accountUuid = initial ?? active.firstOrNull?.uuid;
      _fromAccountUuid =
          initial ??
          active.where((a) => !isLiabilityKind(a.kind)).firstOrNull?.uuid;
      _toAccountUuid = active
          .where((a) => a.uuid != _fromAccountUuid)
          .firstOrNull
          ?.uuid;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _ensureCategoryForType();
      _loading = false;
    });
  }

  void _ensureCategoryForType() {
    final side = _type == EntryType.income ? 'income' : 'expense';
    final choices = categoriesForSide(_categories, side);
    if (_categoryId == null ||
        !choices.any((c) => c.categoryId == _categoryId)) {
      // Keep an existing (possibly archived) category on edit.
      if (_isEdit && _categoryId != null) {
        return;
      }
      _categoryId = choices.firstOrNull?.categoryId;
    }
  }

  List<Account> _pickable({String? keep}) =>
      _accounts.where((a) => !a.isArchived || a.uuid == keep).toList();

  Account? _accountById(String? uuid) =>
      _accounts.where((a) => a.uuid == uuid).firstOrNull;

  DateTime _occurredAt() {
    final now = DateTime.now();
    final existing = _existing?.occurredAt.toLocal();
    if (existing != null &&
        existing.year == _date.year &&
        existing.month == _date.month &&
        existing.day == _date.day) {
      return existing;
    }
    if (_date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day) {
      return now;
    }
    return DateTime(_date.year, _date.month, _date.day, 12);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String? _validateAmount(String? value) {
    final money = Money.tryParse(value ?? '');
    if (money == null) {
      final text = value?.trim() ?? '';
      if (text.contains('.') && text.split('.').last.length > 2) {
        return 'Amounts support up to 2 decimal places';
      }
      return 'Enter a valid amount';
    }
    if (!money.isPositive) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();
    final amount = Money.parse(_amountController.text);
    final occurredAt = _occurredAt();

    if (_fullyEditable) {
      if (_type == EntryType.transfer) {
        if (_fromAccountUuid == null || _toAccountUuid == null) {
          showMessage(context, 'Choose both accounts.');
          return;
        }
        if (_fromAccountUuid == _toAccountUuid) {
          showMessage(context, 'Choose two different accounts.');
          return;
        }
      } else {
        if (_accountUuid == null) {
          showMessage(context, 'Choose an account.');
          return;
        }
        if (_categoryId == null) {
          showMessage(context, 'Choose a category.');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final transactions = _services.transactions;
      final existing = _existing;
      if (existing == null) {
        await _create(
          transactions,
          amount: amount,
          occurredAt: occurredAt,
          description: description.isEmpty ? null : description,
          notes: notes.isEmpty ? null : notes,
        );
        NotificationManager.instance.add(
          type: NotificationType.transactionAdded,
          title: 'Transaction added',
          message: '${amount.format()} saved.',
        );
      } else {
        await transactions.editTransaction(
          existing.uuid,
          _buildEdit(existing, amount, occurredAt, description, notes),
        );
        NotificationManager.instance.add(
          type: NotificationType.transactionUpdated,
          title: 'Transaction updated',
          message: 'Your changes were saved.',
        );
      }
      unawaited(_services.sync.requestSync());
      if (mounted) {
        Navigator.of(context).pop();
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

  Future<void> _create(
    FinancialTransactionRepository transactions, {
    required Money amount,
    required DateTime occurredAt,
    String? description,
    String? notes,
  }) async {
    switch (_type) {
      case EntryType.expense:
        await transactions.createExpense(
          accountUuid: _accountUuid!,
          categoryId: _categoryId!,
          amount: amount,
          occurredAt: occurredAt,
          paymentChannel: _paymentMethod,
          description: description,
          notes: notes,
        );
      case EntryType.income:
        await transactions.createIncome(
          accountUuid: _accountUuid!,
          categoryId: _categoryId!,
          amount: amount,
          occurredAt: occurredAt,
          paymentChannel: _paymentMethod,
          description: description,
          notes: notes,
        );
      case EntryType.transfer:
        final destination = _accountById(_toAccountUuid);
        if (destination != null && isLiabilityKind(destination.kind)) {
          await transactions.createCardPayment(
            sourceAccountUuid: _fromAccountUuid!,
            cardAccountUuid: _toAccountUuid!,
            amount: amount,
            occurredAt: occurredAt,
            paymentChannel: _paymentMethod,
            description: description,
            notes: notes,
          );
        } else {
          await transactions.createTransfer(
            sourceAccountUuid: _fromAccountUuid!,
            destinationAccountUuid: _toAccountUuid!,
            amount: amount,
            occurredAt: occurredAt,
            paymentChannel: _paymentMethod,
            description: description,
            notes: notes,
          );
        }
    }
  }

  TransactionEdit _buildEdit(
    FinancialTransaction existing,
    Money amount,
    DateTime occurredAt,
    String description,
    String notes,
  ) {
    final sameAmount = amount.amountMinorUnits == existing.amountMinorUnits;
    final sameDate = occurredAt == existing.occurredAt.toLocal();
    switch (existing.kind) {
      case 'expense':
      case 'income':
        return TransactionEdit(
          amount: sameAmount ? null : amount,
          accountUuid: _accountUuid,
          categoryId: _categoryId == existing.categoryId ? null : _categoryId,
          occurredAt: sameDate ? null : occurredAt,
          description: description,
          notes: notes,
          paymentChannel: _paymentMethod,
        );
      case 'transfer':
      case 'card_payment':
        return TransactionEdit(
          amount: sameAmount ? null : amount,
          sourceAccountUuid: _fromAccountUuid == existing.sourceAccountId
              ? null
              : _fromAccountUuid,
          destinationAccountUuid:
              _toAccountUuid == existing.destinationAccountId
              ? null
              : _toAccountUuid,
          occurredAt: sameDate ? null : occurredAt,
          description: description,
          notes: notes,
          paymentChannel: _paymentMethod,
        );
      case 'refund':
        return TransactionEdit(
          amount: sameAmount ? null : amount,
          occurredAt: sameDate ? null : occurredAt,
          description: description,
          notes: notes,
        );
      default:
        return TransactionEdit(description: description, notes: notes);
    }
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'It is removed from balances and reports. You can undo right '
          'after deleting.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    final deleted = await deleteWithUndo(context, _services, existing.uuid);
    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refund() async {
    final existing = _existing;
    if (existing == null) {
      return;
    }
    final capacity = await _services.transactions.refundableCapacity(
      existing.uuid,
    );
    if (!mounted) {
      return;
    }
    if (capacity <= 0) {
      showMessage(context, 'This transaction is already fully refunded.');
      return;
    }
    final result = await showDialog<_RefundInput>(
      context: context,
      builder: (_) => _RefundDialog(
        capacity: Money(capacity, existing.currencyCode),
        accounts: _pickable(),
        defaultAccountUuid: _accountUuid,
        isIncome: existing.kind == 'income',
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await _services.transactions.createRefund(
        originalUuid: existing.uuid,
        refundAccountUuid: result.accountUuid,
        amount: result.amount,
        occurredAt: DateTime.now(),
        paymentChannel: existing.paymentChannel,
        description: 'Refund: ${transactionTitleFor(existing)}',
      );
      unawaited(_services.sync.requestSync());
      if (mounted) {
        showMessage(context, 'Refund of ${result.amount.format()} recorded.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  String transactionTitleFor(FinancialTransaction tx) {
    final description = tx.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return _categories
            .where((c) => c.categoryId == tx.categoryId)
            .firstOrNull
            ?.name ??
        transactionKindLabels[tx.kind] ??
        tx.kind;
  }

  Future<void> _reverse() async {
    final existing = _existing;
    if (existing == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse transaction?'),
        content: const Text(
          'A reversal cancels the full effect of this transaction with a '
          'new entry dated today. The original stays in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _services.transactions.createReversal(
        originalUuid: existing.uuid,
        occurredAt: DateTime.now(),
        description: 'Reversal: ${transactionTitleFor(existing)}',
      );
      unawaited(_services.sync.requestSync());
      if (mounted) {
        showMessage(context, 'Transaction reversed.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final canAct =
        existing != null && existing.status == 'active' && !_existingReversed;
    final canRefund =
        canAct && (existing.kind == 'expense' || existing.kind == 'income');
    final canReverse =
        canAct && existing.kind != 'refund' && existing.kind != 'reversal';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          !_isEdit
              ? 'Add Transaction'
              : (existing == null
                    ? 'Transaction'
                    : transactionKindLabels[existing.kind] ?? 'Transaction'),
        ),
        actions: [
          if (existing != null && existing.status == 'active')
            PopupMenuButton<String>(
              key: const Key('transaction-menu'),
              onSelected: (value) {
                switch (value) {
                  case 'refund':
                    unawaited(_refund());
                  case 'reverse':
                    unawaited(_reverse());
                  case 'delete':
                    unawaited(_delete());
                }
              },
              itemBuilder: (_) => [
                if (canRefund)
                  const PopupMenuItem(value: 'refund', child: Text('Refund')),
                if (canReverse)
                  const PopupMenuItem(value: 'reverse', child: Text('Reverse')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isEdit && existing == null
          ? const Center(child: Text('This transaction no longer exists.'))
          : _accounts.where((a) => !a.isArchived).isEmpty && !_isEdit
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyStateCard(
                  icon: Icons.account_balance_rounded,
                  title: 'Add an account first',
                  message:
                      'Every transaction belongs to an account, such as your '
                      'bank account, cash, or a credit card.',
                  actionLabel: 'Add account',
                  onAction: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountFormPage(),
                      ),
                    );
                    setState(() => _loading = true);
                    await _load();
                  },
                ),
              ],
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final existing = _existing;
    final readOnlyNotice = existing != null && !_fullyEditable;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (existing == null)
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: EntryType.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  _ensureCategoryForType();
                });
              },
            ),
          if (readOnlyNotice)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  existing.kind == 'refund'
                      ? 'Refunds can change amount, date, description and '
                            'notes. The refund account is fixed.'
                      : 'Only the description and notes of this entry can '
                            'change. To undo its effect, use Reverse or '
                            'Delete.',
                ),
              ),
            ),
          if (_existingReversed)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This transaction has been reversed. Delete the reversal '
                  'to edit it again.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('amount-field'),
            controller: _amountController,
            enabled: _amountEditable && !_existingReversed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
            validator: _validateAmount,
          ),
          const SizedBox(height: 16),
          if (_fullyEditable && _type == EntryType.transfer) ...[
            _AccountDropdown(
              key: const Key('from-account'),
              label: 'From account',
              accounts: _pickable(keep: _fromAccountUuid)
                  .where((a) => !isLiabilityKind(a.kind))
                  .toList(),
              value: _fromAccountUuid,
              enabled: !_existingReversed,
              onChanged: (v) => setState(() => _fromAccountUuid = v),
            ),
            const SizedBox(height: 16),
            _AccountDropdown(
              key: const Key('to-account'),
              label: 'To account',
              accounts: _pickable(keep: _toAccountUuid),
              value: _toAccountUuid,
              enabled: !_existingReversed,
              onChanged: (v) => setState(() => _toAccountUuid = v),
            ),
            if (isLiabilityKind(_accountById(_toAccountUuid)?.kind ?? ''))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Paying a credit card: this reduces what you owe and is '
                  'not counted as a new expense.',
                ),
              ),
            const SizedBox(height: 16),
          ] else if (_fullyEditable) ...[
            _AccountDropdown(
              key: const Key('account'),
              label: 'Account',
              accounts: _pickable(keep: _accountUuid),
              value: _accountUuid,
              enabled: !_existingReversed,
              onChanged: (v) => setState(() => _accountUuid = v),
            ),
            const SizedBox(height: 16),
            _CategoryDropdown(
              categories: _categoryChoices(),
              value: _categoryId,
              enabled: !_existingReversed,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
          ],
          if (_amountEditable) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Date'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: _existingReversed ? null : _pickDate,
            ),
            const SizedBox(height: 8),
          ],
          if (_fullyEditable) ...[
            _Dropdown<String>(
              label: 'Payment method',
              value: _paymentMethod,
              items: [
                for (final method in paymentMethodChoices)
                  DropdownMenuItem(value: method, child: Text(method)),
              ],
              onChanged: _existingReversed
                  ? null
                  : (v) => setState(() => _paymentMethod = v ?? 'UPI'),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (existing == null || existing.status == 'active')
            FilledButton.icon(
              key: const Key('save-transaction'),
              onPressed: _saving || _existingReversed ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(existing == null ? 'Save Transaction' : 'Update'),
            ),
        ],
      ),
    );
  }

  List<Category> _categoryChoices() {
    final side = _type == EntryType.income ? 'income' : 'expense';
    final choices = categoriesForSide(_categories, side);
    final current = _categoryId;
    if (current != null && !choices.any((c) => c.categoryId == current)) {
      final stored = _categories.where((c) => c.categoryId == current);
      return [...stored, ...choices];
    }
    return choices;
  }
}

/// Soft-deletes a transaction and offers Undo (restore). Returns false
/// when the delete was rejected (the reason is shown).
Future<bool> deleteWithUndo(
  BuildContext context,
  AppServices services,
  String uuid,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await services.transactions.deleteTransaction(uuid);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    return false;
  }
  NotificationManager.instance.add(
    type: NotificationType.transactionDeleted,
    title: 'Transaction deleted',
    message: 'The transaction was removed.',
  );
  unawaited(services.sync.requestSync());
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Transaction deleted'),
      // An action SnackBar persists by default; auto-dismiss it after
      // five seconds while Undo stays available in that window.
      duration: const Duration(seconds: 5),
      persist: false,
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () async {
          try {
            await services.transactions.restoreTransaction(uuid);
            NotificationManager.instance.add(
              type: NotificationType.transactionRestored,
              title: 'Transaction restored',
              message: 'The transaction is back in your history.',
            );
            unawaited(services.sync.requestSync());
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text(friendlyError(error))),
            );
          }
        },
      ),
    ),
  );
  return true;
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = items.any((item) => item.value == value);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: hasValue ? value : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    super.key,
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<Account> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Dropdown<String>(
      label: label,
      value: value,
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.uuid,
            child: Row(
              children: [
                Icon(accountKindIcon(account.kind), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(account.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Category> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Dropdown<String>(
      label: 'Category',
      value: value,
      items: [
        for (final category in categories)
          DropdownMenuItem(
            value: category.categoryId,
            child: Row(
              children: [
                Icon(
                  iconForCategory(category.categoryId, category.iconCodePoint),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.isArchived
                        ? '${category.name} (archived)'
                        : category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _RefundInput {
  const _RefundInput(this.amount, this.accountUuid);

  final Money amount;
  final String accountUuid;
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({
    required this.capacity,
    required this.accounts,
    required this.defaultAccountUuid,
    required this.isIncome,
  });

  final Money capacity;
  final List<Account> accounts;
  final String? defaultAccountUuid;
  final bool isIncome;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.capacity.toDecimalString(),
  );
  late String? _accountUuid = widget.defaultAccountUuid;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final money = Money.tryParse(_amount.text);
    if (money == null || !money.isPositive) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (money > widget.capacity) {
      setState(
        () => _error = 'At most ${widget.capacity.format()} can be refunded',
      );
      return;
    }
    if (_accountUuid == null) {
      setState(() => _error = 'Choose an account');
      return;
    }
    Navigator.of(context).pop(_RefundInput(money, _accountUuid!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a refund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Up to ${widget.capacity.format()} can be refunded.'),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Refund amount',
              prefixText: '₹ ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          _AccountDropdown(
            label: widget.isIncome ? 'Paid out of' : 'Refunded to',
            accounts: widget.accounts,
            value: _accountUuid,
            onChanged: (v) => setState(() => _accountUuid = v),
          ),
          if (_accountUuid != widget.defaultAccountUuid)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This is a different account from the original '
                'transaction.',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save refund')),
      ],
    );
  }
}
