import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

const expenseCategories = [
  ExpenseCategory(
    id: 'food',
    name: 'Food',
    icon: Icons.restaurant_rounded,
  ),
  ExpenseCategory(
    id: 'travel',
    name: 'Travel',
    icon: Icons.directions_car_rounded,
  ),
  ExpenseCategory(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
  ),
  ExpenseCategory(
    id: 'bills',
    name: 'Bills',
    icon: Icons.receipt_long_rounded,
  ),
  ExpenseCategory(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_rounded,
  ),
  ExpenseCategory(
    id: 'health',
    name: 'Health',
    icon: Icons.health_and_safety_rounded,
  ),
  ExpenseCategory(
    id: 'education',
    name: 'Education',
    icon: Icons.school_rounded,
  ),
  ExpenseCategory(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz_rounded,
  ),
];