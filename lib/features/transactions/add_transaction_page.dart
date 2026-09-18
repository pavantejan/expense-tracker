import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    this.transactionId,
  });

  final int? transactionId;

  bool get isEditMode => transactionId != null;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  String _type = 'Expense';
  String _category = 'Food';
  String _paymentMethod = 'UPI';
  DateTime _selectedDate = DateTime.now();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  final _uuid = const Uuid();

  final _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Other',
  ];

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

  Future<void> _loadTransaction(int id) async {
    final transaction = await transactionRepository.getTransactionById(id);

    if (!mounted || transaction == null) {
      return;
    }

    setState(() {
      _type = transaction.type;
      _category = transaction.category;
      _paymentMethod = transaction.paymentMethod;
      _selectedDate = transaction.transactionDate;

      _amountController.text = transaction.amount.toString();
      _descriptionController.text = transaction.description ?? '';
      _notesController.text = transaction.notes ?? '';
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount.'),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();
    final now = DateTime.now();

    if (widget.transactionId == null) {
      await transactionRepository.addTransaction(
        TransactionsCompanion.insert(
          uuid: _uuid.v4(),
          type: _type,
          amount: amount,
          category: _category,
          description: Value(
            description.isEmpty ? null : description,
          ),
          paymentMethod: _paymentMethod,
          transactionDate: _selectedDate,
          notes: Value(
            notes.isEmpty ? null : notes,
          ),
          createdAt: now,
          updatedAt: now,
          syncStatus: 'pending',
        ),
      );
    } else {
      await transactionRepository.updateTransaction(
        widget.transactionId!,
        TransactionsCompanion(
          type: Value(_type),
          amount: Value(amount),
          category: Value(_category),
          description: Value(
            description.isEmpty ? null : description,
          ),
          paymentMethod: Value(_paymentMethod),
          transactionDate: Value(_selectedDate),
          notes: Value(
            notes.isEmpty ? null : notes,
          ),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditMode
              ? 'Transaction updated successfully.'
              : 'Transaction saved successfully.',
        ),
      ),
    );

    Navigator.of(context).pop();
  }

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
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment<String>(
                  value: 'Income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                });
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _paymentMethod = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}',
              ),
              trailing: TextButton(
                onPressed: _selectDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveTransaction,
                icon: Icon(
                  widget.isEditMode
                      ? Icons.save_rounded
                      : Icons.add_rounded,
                ),
                label: Text(
                  widget.isEditMode
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