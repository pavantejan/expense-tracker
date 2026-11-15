import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/categories/category.dart';
import '../../data/database/v2/app_database_v2.dart';
import '../common/ui.dart';

const Map<String, String> categoryKindLabels = <String, String>{
  'expense': 'Expenses only',
  'income': 'Income only',
  'both': 'Expenses and income',
};

/// Validates a category name entered in the add/edit form.
///
/// [existingNames] are the other categories' names (the edited
/// category's own name excluded by the caller), built-in and custom;
/// the check is case-insensitive and ignores surrounding whitespace.
String? validateCategoryName(String? value, Iterable<String> existingNames) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter a category name.';
  }
  final lowered = trimmed.toLowerCase();
  if (existingNames.any((name) => name.trim().toLowerCase() == lowered)) {
    return 'A category with this name already exists.';
  }
  return null;
}

/// Result of the add/edit category dialog.
class CategoryFormResult {
  const CategoryFormResult({
    required this.name,
    required this.iconCodePoint,
    required this.kind,
  });

  final String name;
  final int iconCodePoint;
  final String kind;
}

/// Add/edit form for one category. Never touches the database, so it
/// can be widget-tested without one.
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.initialName,
    this.initialIconCodePoint,
    this.initialKind = 'expense',
    this.categoryId,
    required this.existingNames,
    required this.isEditing,
  });

  final String? initialName;
  final int? initialIconCodePoint;
  final String initialKind;

  /// The edited category's id, so a built-in keeps its own icon.
  final String? categoryId;
  final Iterable<String> existingNames;
  final bool isEditing;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _iconCodePoint;
  late String _kind;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _iconCodePoint =
        widget.initialIconCodePoint ?? categoryIconChoices.first.codePoint;
    _kind = widget.initialKind;
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
        iconCodePoint: _iconCodePoint,
        kind: _kind,
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
                    child: Icon(
                      iconForCategory(widget.categoryId ?? '', _iconCodePoint),
                    ),
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
              const SizedBox(height: 16),
              Text(
                'Used for',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('category-kind'),
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'both', label: Text('Both')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 8),
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
                  final isSelected = icon.codePoint == _iconCodePoint;
                  return IconButton(
                    key: ValueKey('category-icon-${icon.codePoint}'),
                    onPressed: () =>
                        setState(() => _iconCodePoint = icon.codePoint),
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
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  AppServices? _services;
  Stream<List<Category>>? _categories;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _categories = _services!.queries.watchCategories();
    }
  }

  Future<void> _add(List<Category> all) async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (_) => CategoryFormDialog(
        existingNames: all.map((c) => c.name),
        isEditing: false,
      ),
    );
    if (result == null) {
      return;
    }
    await _run(
      () => _services!.categories.createCategory(
        name: result.name,
        kind: result.kind,
        iconCodePoint: result.iconCodePoint,
        displayOrder: all.length,
      ),
    );
  }

  Future<void> _edit(Category category, List<Category> all) async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (_) => CategoryFormDialog(
        initialName: category.name,
        initialIconCodePoint: category.iconCodePoint,
        initialKind: category.kind,
        categoryId: category.categoryId,
        existingNames: all
            .where((c) => c.categoryId != category.categoryId)
            .map((c) => c.name),
        isEditing: true,
      ),
    );
    if (result == null) {
      return;
    }
    await _run(() async {
      if (result.kind != category.kind) {
        await _services!.categories.changeCategoryKind(
          category.categoryId,
          newKind: result.kind,
        );
      }
      await _services!.categories.updateCategoryPresentation(
        category.categoryId,
        name: result.name == category.name ? null : result.name,
        iconCodePoint: result.iconCodePoint,
      );
    });
  }

  Future<void> _toggleArchive(Category category) async {
    await _run(() async {
      if (category.isArchived) {
        await _services!.categories.restoreCategory(category.categoryId);
      } else {
        await _services!.categories.archiveCategory(category.categoryId);
      }
    });
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
    return StreamBuilder<List<Category>>(
      stream: _categories,
      builder: (context, snapshot) {
        final all = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add-category'),
            onPressed: all == null ? null : () => unawaited(_add(all)),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add category'),
          ),
          body: all == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    const Text(
                      'Renaming a category never changes past '
                      'transactions. Archive a category to hide it from '
                      'new transactions while keeping its history.',
                    ),
                    const SizedBox(height: 12),
                    for (final category in all)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              iconForCategory(
                                category.categoryId,
                                category.iconCodePoint,
                              ),
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: category.isArchived
                                  ? Theme.of(context).disabledColor
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            [
                              categoryKindLabels[category.kind] ??
                                  category.kind,
                              if (category.origin == 'builtin') 'Built-in',
                              if (category.isArchived) 'Archived',
                            ].join(' • '),
                          ),
                          onTap: () => unawaited(_edit(category, all)),
                          trailing: IconButton(
                            key: ValueKey('archive-${category.categoryId}'),
                            tooltip: category.isArchived
                                ? 'Restore'
                                : 'Archive',
                            icon: Icon(
                              category.isArchived
                                  ? Icons.unarchive_rounded
                                  : Icons.archive_outlined,
                            ),
                            onPressed: () =>
                                unawaited(_toggleArchive(category)),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
