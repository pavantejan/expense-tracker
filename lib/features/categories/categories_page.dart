import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/categories/category.dart';
import '../../core/database/repository_provider.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/custom_category_repository.dart';

/// Validates a category name entered in the add/edit form.
///
/// Returns an error message, or `null` when the name is usable.
/// [existingNames] are the other custom category names (the
/// edited category's own name excluded by the caller); the
/// check is case-insensitive and ignores surrounding
/// whitespace. Names colliding with a built-in category are
/// rejected with their own message.
String? validateCategoryName(String? value, Iterable<String> existingNames) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter a category name.';
  }
  final lowered = trimmed.toLowerCase();
  if (expenseCategories.any(
    (category) => category.name.toLowerCase() == lowered,
  )) {
    return '"$trimmed" is already a built-in category.';
  }
  if (existingNames.any((name) => name.trim().toLowerCase() == lowered)) {
    return 'A category with this name already exists.';
  }
  return null;
}

/// Result of the add/edit category dialog: the trimmed name
/// and the selected icon's code point.
class CategoryFormResult {
  const CategoryFormResult({required this.name, required this.iconCodePoint});

  final String name;
  final int iconCodePoint;
}

/// Add/edit form for one custom category.
///
/// Shown as a dialog by [CategoriesPage]. Validation follows
/// Flutter's standard form pattern (`Form` + `TextFormField`
/// validator); the dialog only returns a result when the form
/// is valid. It never touches the database itself, so it can
/// be widget-tested without one.
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.initialName,
    this.initialIconCodePoint,
    required this.existingNames,
    required this.isEditing,
  });

  final String? initialName;
  final int? initialIconCodePoint;
  final Iterable<String> existingNames;
  final bool isEditing;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _selectedIconCodePoint;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIconCodePoint =
        widget.initialIconCodePoint ?? categoryIconChoices.first.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      CategoryFormResult(
        name: _nameController.text.trim(),
        iconCodePoint: _selectedIconCodePoint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit category' : 'Add category'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Icon(categoryIconData(_selectedIconCodePoint)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          validateCategoryName(value, widget.existingNames),
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Icon',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: categoryIconChoices.map((icon) {
                  final isSelected = icon.codePoint == _selectedIconCodePoint;
                  return IconButton(
                    key: ValueKey('category-icon-${icon.codePoint}'),
                    tooltip: icon.toString(),
                    onPressed: () {
                      setState(() {
                        _selectedIconCodePoint = icon.codePoint;
                      });
                    },
                    icon: Icon(icon),
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primaryContainer
                          : null,
                      foregroundColor: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.repository});

  /// Injected for tests; production code uses the app-wide
  /// repository backed by the real Drift database.
  final CustomCategoryRepository? repository;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _uuid = const Uuid();

  /// Created once in [initState]: building a new watch stream
  /// on every build would make the StreamBuilder resubscribe
  /// on each rebuild and re-query forever.
  late final Stream<List<CustomCategory>> _categoriesStream;

  CustomCategoryRepository get _repository =>
      widget.repository ?? customCategoryRepository;

  @override
  void initState() {
    super.initState();
    _categoriesStream = _repository.watchAllCategories();
  }

  Future<void> _showAddDialog() async {
    final existing = await _repository.getAllCategories();
    if (!mounted) {
      return;
    }
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (dialogContext) => CategoryFormDialog(
        existingNames: existing.map((category) => category.name),
        isEditing: false,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await _repository.addCategory(
        uuid: _uuid.v4(),
        name: result.name,
        iconCodePoint: result.iconCodePoint,
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Category added.'),
        duration: Duration(seconds: 5),
        persist: false,
      ),
    );
  }

  Future<void> _showEditDialog(CustomCategory category) async {
    final existing = await _repository.getAllCategories();
    if (!mounted) {
      return;
    }
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (dialogContext) => CategoryFormDialog(
        initialName: category.name,
        initialIconCodePoint: category.iconCodePoint,
        existingNames: existing
            .where((other) => other.id != category.id)
            .map((other) => other.name),
        isEditing: true,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final nameChanged = result.name != category.name;
    bool updated;
    try {
      updated = await _repository.renameCategory(
        id: category.id,
        name: result.name,
        iconCodePoint: result.iconCodePoint,
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) {
      return;
    }
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category no longer exists.')),
      );
      return;
    }
    // Renamed transactions are pending; sync them through the
    // existing coordinator. Icon-only edits change no
    // transaction row and need no sync.
    if (nameChanged) {
      unawaited(sheetsSyncCoordinator.requestSync());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Category updated.'),
        duration: Duration(seconds: 5),
        persist: false,
      ),
    );
  }

  Future<void> _confirmDelete(CustomCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${category.name}"? Transactions using this '
          'category will keep their category name.',
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
    final deleted = await _repository.deleteCategory(category.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Category deleted. Transactions keep their category name.'
              : 'Category no longer exists.',
        ),
        duration: const Duration(seconds: 5),
        persist: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-category'),
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Built-in categories',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('Built-in categories cannot be edited or deleted.'),
          const SizedBox(height: 8),
          ...expenseCategories.map(
            (category) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(category.icon)),
                title: Text(category.name),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Custom categories',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: _categoriesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Could not load custom categories.'),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final categories = snapshot.data ?? [];

              if (categories.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No custom categories yet. Add one to use it '
                      'when entering a transaction.',
                    ),
                  ),
                );
              }

              return Column(
                children: categories.map((category) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(categoryIconData(category.iconCodePoint)),
                      ),
                      title: Text(category.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('edit-category-${category.id}'),
                            tooltip: 'Edit category',
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _showEditDialog(category),
                          ),
                          IconButton(
                            key: Key('delete-category-${category.id}'),
                            tooltip: 'Delete category',
                            icon: const Icon(Icons.delete_rounded),
                            onPressed: () => _confirmDelete(category),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Room for the floating action button.
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
