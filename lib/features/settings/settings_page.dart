import 'package:flutter/material.dart';

import '../../core/database/repository_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _openingBalanceController = TextEditingController();

  DateTime _openingBalanceDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await appSettingsRepository.getSettings();

    if (!mounted) {
      return;
    }

    _openingBalanceController.text =
        (settings?.openingBalance ?? 0).toStringAsFixed(2);

    if (settings?.openingBalanceDate != null) {
      _openingBalanceDate = settings!.openingBalanceDate!;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectOpeningBalanceDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _openingBalanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _openingBalanceDate = selectedDate;
    });
  }

  Future<void> _saveOpeningBalance() async {
    final text = _openingBalanceController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid opening balance.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await appSettingsRepository.setOpeningBalance(
      amount: amount,
      date: _openingBalanceDate,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening balance saved.'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set the amount of money you had when you started using the app. This balance will be carried forward into future months.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _openingBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Opening balance',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starting date'),
                  subtitle: Text(
                    _formatDate(_openingBalanceDate),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month_rounded,
                  ),
                  onTap: _selectOpeningBalanceDate,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSaving ? null : _saveOpeningBalance,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}