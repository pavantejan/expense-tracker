import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/repository_provider.dart';
import '../../data/database/app_database.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

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
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
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

    final now = DateTime.now();

    await transactionRepository.addTransaction(
      TransactionsCompanion.insert(
        uuid: _uuid.v4(),
        type: _type,
        amount: amount,
        category: _category,
        description: Value(
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
        paymentMethod: _paymentMethod,
        transactionDate: _selectedDate,
        notes: Value(
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved successfully.'),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
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

            const SizedBox(height: 24),

            Text(
              'Amount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

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

            const SizedBox(height: 20),

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

            const SizedBox(height: 20),

            TextField(
              controller: _descriptionController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What was this transaction for?',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year}',
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveTransaction,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}