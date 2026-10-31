import 'package:flutter/material.dart';

/// Curated Material icons a custom category can use. Kept small
/// and recognisable; the stored value is the icon code point.
const List<IconData> categoryIconChoices = <IconData>[
  Icons.category_rounded,
  Icons.fitness_center_rounded,
  Icons.directions_bike_rounded,
  Icons.pets_rounded,
  Icons.flight_rounded,
  Icons.hotel_rounded,
  Icons.local_cafe_rounded,
  Icons.local_grocery_store_rounded,
  Icons.shopping_cart_rounded,
  Icons.sports_esports_rounded,
  Icons.music_note_rounded,
  Icons.book_rounded,
  Icons.brush_rounded,
  Icons.medical_services_rounded,
  Icons.home_rounded,
  Icons.directions_car_rounded,
  Icons.phone_android_rounded,
  Icons.card_giftcard_rounded,
  Icons.spa_rounded,
  Icons.work_rounded,
  Icons.savings_rounded,
  Icons.credit_card_rounded,
  Icons.movie_rounded,
  Icons.celebration_rounded,
];

/// Icon for a stored custom category, rebuilt from its persisted
/// Material icon code point. The lookup is over the curated
/// picker icons, so an unknown code point falls back to the
/// generic category icon instead of failing.
IconData categoryIconData(int codePoint) {
  return categoryIconChoices.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.category_rounded,
  );
}

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
  ExpenseCategory(id: 'food', name: 'Food', icon: Icons.restaurant_rounded),
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
  ExpenseCategory(id: 'bills', name: 'Bills', icon: Icons.receipt_long_rounded),
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
  ExpenseCategory(id: 'other', name: 'Other', icon: Icons.more_horiz_rounded),
];
