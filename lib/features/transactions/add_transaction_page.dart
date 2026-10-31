import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';

import '../../core/notifications/notification_manager.dart';
import '../../data/notifications/notification.dart';

import '../../core/categories/category.dart';
import '../../core/sync/google_sheets_service.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    this.transactionId,
  });

  final int? transactionId;

  bool get isEditMode => transactionId != null;

  @override
  State<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState
    extends State<AddTransactionPage> {
  String _type = 'Expense';
  String _category = 'Food';
  String _paymentMethod = 'UPI';
  DateTime _selectedDate = DateTime.now();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  final _uuid = const Uuid();

  bool _isSaving = false;

  final _paymentMethods = [
    'UPI',
    'Cash',
    'Card',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transactionId != null) {
      _loadTransaction(widget.transactionId!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD EXISTING TRANSACTION
  // ============================================================

  Future<void> _loadTransaction(int id) async {
    final transaction =
        await transactionRepository.getTransactionById(id);

    if (!mounted || transaction == null) {
      return;
    }

    setState(() {
      _type = transaction.type;
      _category = transaction.category;
      _paymentMethod = transaction.paymentMethod;

      _selectedDate = DateTime(
        transaction.transactionDate.year,
        transaction.transactionDate.month,
        transaction.transactionDate.day,
      );

      _amountController.text =
          transaction.amount.toString();

      _descriptionController.text =
          transaction.description ?? '';

      _notesController.text =
          transaction.notes ?? '';
    });
  }

  // ============================================================
  // SELECT DATE
  // ============================================================

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  // ============================================================
  // SAVE TRANSACTION
  // ============================================================

  Future<void> _saveTransaction() async {
    if (_isSaving) {
      return;
    }

    final amount =
        double.tryParse(
          _amountController.text.trim(),
        );

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid amount.',
          ),
        ),
      );

      return;
    }

    final description =
        _descriptionController.text.trim();

    final notes =
        _notesController.text.trim();

    final now = DateTime.now();

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // NEW TRANSACTION
      // ========================================================

      if (widget.transactionId == null) {
        await transactionRepository.addTransaction(
          TransactionsCompanion.insert(
            uuid: _uuid.v4(),
            type: _type,
            amount: amount,
            category: _category,
            description: Value(
              description.isEmpty
                  ? null
                  : description,
            ),
            paymentMethod: _paymentMethod,
            transactionDate: _selectedDate,
            notes: Value(
              notes.isEmpty
                  ? null
                  : notes,
            ),
            createdAt: now,
            updatedAt: now,
            syncStatus: 'pending',
          ),
        );

        NotificationManager.instance.add(
          type: NotificationType.transactionAdded,
          title: 'Transaction added',
          message:
              '${description.isEmpty ? _category : description} • '
              '₹${amount.toStringAsFixed(2)}',
        );

        // ======================================================
        // GOOGLE SHEETS BACKUP
        //
        // Important:
        // Local transaction is already saved above.
        //
        // If Google Sheets fails, the local transaction
        // remains safe.
        // ======================================================

        try {
          await GoogleSheetsService.instance
              .backupExpense(
            date:
                '${_selectedDate.year}-'
                '${_selectedDate.month.toString().padLeft(2, '0')}-'
                '${_selectedDate.day.toString().padLeft(2, '0')}',
            type: _type,
            category: _category,
            description: description,
            amount: amount,
          );

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Transaction saved and backed up to Google Sheets.',
              ),
            ),
          );
        } catch (error) {
          debugPrint(
            'Google Sheets backup failed: $error',
          );

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Transaction saved locally. '
                'Google Sheets backup failed.',
              ),
            ),
          );
        }
      }

      // ========================================================
      // EDIT EXISTING TRANSACTION
      // ========================================================

      else {
        await transactionRepository.updateTransaction(
          widget.transactionId!,
          TransactionsCompanion(
            type: Value(_type),
            amount: Value(amount),
            category: Value(_category),
            description: Value(
              description.isEmpty
                  ? null
                  : description,
            ),
            paymentMethod: Value(
              _paymentMethod,
            ),
            transactionDate: Value(
              _selectedDate,
            ),
            notes: Value(
              notes.isEmpty
                  ? null
                  : notes,
            ),
          ),
        );

        NotificationManager.instance.add(
          type: NotificationType.transactionUpdated,
          title: 'Transaction updated',
          message:
              '${description.isEmpty ? _category : description} • '
              '₹${amount.toStringAsFixed(2)}',
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transaction updated locally.',
            ),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit Transaction'
              : 'Add Transaction',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==================================================
            // TYPE
            // ==================================================

            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Expense',
                  label: Text('Expense'),
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                  ),
                ),
                ButtonSegment<String>(
                  value: 'Income',
                  label: Text('Income'),
                  icon: Icon(
                    Icons.arrow_downward_rounded,
                  ),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _isSaving
                  ? null
                  : (selection) {
                      setState(() {
                        _type =
                            selection.first;
                      });
                    },
            ),

            const SizedBox(height: 20),

            // ==================================================
            // AMOUNT
            // ==================================================

            TextField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // CATEGORY
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration:
                  const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: expenseCategories
                  .map(
                    (category) =>
                        DropdownMenuItem(
                      value: category.name,
                      child: Row(
                        children: [
                          Icon(
                            category.icon,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Text(category.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _category = value;
                        });
                      }
                    },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // PAYMENT METHOD
            // ==================================================

            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration:
                  const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods
                  .map(
                    (method) =>
                        DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _paymentMethod =
                              value;
                        });
                      }
                    },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            TextField(
              controller:
                  _descriptionController,
              enabled: !_isSaving,
              decoration:
                  const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // DATE
            // ==================================================

            ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today_outlined,
              ),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}',
              ),
              trailing: TextButton(
                onPressed:
                    _isSaving
                        ? null
                        : _selectDate,
                child: const Text('Change'),
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // NOTES
            // ==================================================

            TextField(
              controller: _notesController,
              enabled: !_isSaving,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // SAVE BUTTON
            // ==================================================

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : _saveTransaction,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        widget.isEditMode
                            ? Icons.save_rounded
                            : Icons.add_rounded,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEditMode
                          ? 'Update Transaction'
                          : 'Save Transaction',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}