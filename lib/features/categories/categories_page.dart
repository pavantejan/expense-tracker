import 'package:flutter/material.dart';

import '../../core/categories/category.dart';
import '../../core/database/repository_provider.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Built-in categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...expenseCategories.map(
            (category) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(category.icon),
                ),
                title: Text(category.name),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Custom categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: customCategoryRepository.watchAllCategories(),
            builder: (context, snapshot) {
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
                      'No custom categories yet.',
                    ),
                  ),
                );
              }

              return Column(
                children: categories.map(
                  (category) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(
                            Icons.category_rounded,
                          ),
                        ),
                        title: Text(category.name),
                      ),
                    );
                  },
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}