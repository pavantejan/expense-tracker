import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.name,
    required this.icon,
  });

  final String name;
  final IconData icon;
}

const expenseCategories = [
  ExpenseCategory(
    name: 'Food',
    icon: Icons.restaurant_rounded,
  ),
  ExpenseCategory(
    name: 'Travel',
    icon: Icons.directions_car_rounded,
  ),
  ExpenseCategory(
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
  ),
  ExpenseCategory(
    name: 'Bills',
    icon: Icons.receipt_long_rounded,
  ),
  ExpenseCategory(
    name: 'Entertainment',
    icon: Icons.movie_rounded,
  ),
  ExpenseCategory(
    name: 'Health',
    icon: Icons.health_and_safety_rounded,
  ),
  ExpenseCategory(
    name: 'Education',
    icon: Icons.school_rounded,
  ),
  ExpenseCategory(
    name: 'Other',
    icon: Icons.more_horiz_rounded,
  ),
];