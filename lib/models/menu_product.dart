import 'package:flutter/material.dart';

const defaultMenuCategories = <String>[
  'كريب',
  'كوكتيل',
  'طبق مشكّل',
  'كعكة طرابلسية',
  'إضافات',
];

IconData menuCategoryIcon(String category) => switch (category) {
      'كريب' => Icons.breakfast_dining_outlined,
      'كوكتيل' => Icons.local_drink_outlined,
      'طبق مشكّل' => Icons.rice_bowl_outlined,
      'كعكة طرابلسية' => Icons.lunch_dining_outlined,
      'إضافات' => Icons.add_circle_outline,
      _ => Icons.fastfood_outlined,
    };

class MenuProduct {
  final String id;
  final String category;
  final String name;
  final String description;
  final int priceLbp;
  final bool isAvailable;

  const MenuProduct({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.priceLbp,
    this.isAvailable = true,
  });

  MenuProduct copyWith({
    String? category,
    String? name,
    String? description,
    int? priceLbp,
    bool? isAvailable,
  }) =>
      MenuProduct(
        id: id,
        category: category ?? this.category,
        name: name ?? this.name,
        description: description ?? this.description,
        priceLbp: priceLbp ?? this.priceLbp,
        isAvailable: isAvailable ?? this.isAvailable,
      );
}

String formatLbp(int value) => 'ل.ل ${value.toString().replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => '.',
    )}';

const defaultSweetMenu = <MenuProduct>[
  MenuProduct(
      id: 'crep-nutella',
      category: 'كريب',
      name: 'Nutella',
      description: 'كريب بالنوتيلا',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-white-nutella',
      category: 'كريب',
      name: 'White chocolate & Nutella',
      description: 'كريب بالشوكولا البيضاء والنوتيلا',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-lotus',
      category: 'كريب',
      name: 'Lotus',
      description: 'كريب لوتس',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-nutella-lotus',
      category: 'كريب',
      name: 'Nutella & Lotus',
      description: 'كريب نوتيلا ولوتس',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-kinder',
      category: 'كريب',
      name: 'Kinder',
      description: 'كريب كيندر',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-oreo',
      category: 'كريب',
      name: 'Oreo',
      description: 'كريب أوريو',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-pistachio',
      category: 'كريب',
      name: 'Pistachio',
      description: 'كريب فستق',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-pistachio-nutella',
      category: 'كريب',
      name: 'Pistachio & Nutella',
      description: 'كريب فستق ونوتيلا',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-brownie',
      category: 'كريب',
      name: 'Brownie',
      description: 'كريب براوني',
      priceLbp: 400000),
  MenuProduct(
      id: 'extra-fruits',
      category: 'إضافات',
      name: 'Added fruits',
      description: 'إضافة فواكه إلى الكريب',
      priceLbp: 50000),
  MenuProduct(
      id: 'cocktail-shaqf',
      category: 'كوكتيل',
      name: 'كوكتيل شقف',
      description: 'كوكتيل شقف',
      priceLbp: 450000),
  MenuProduct(
      id: 'cocktail-avocado-nutella',
      category: 'كوكتيل',
      name: 'Avocado & Nutella',
      description: 'أفوكادو ونوتيلا',
      priceLbp: 350000),
  MenuProduct(
      id: 'cocktail-avocado-cream',
      category: 'كوكتيل',
      name: 'Avocado & cream',
      description: 'أفوكادو وقشطة',
      priceLbp: 300000),
  MenuProduct(
      id: 'juice-lemon',
      category: 'كوكتيل',
      name: 'عصير ليمون',
      description: 'ليمون طازج',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-carrot',
      category: 'كوكتيل',
      name: 'عصير جزر',
      description: 'جزر طازج',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-fresh',
      category: 'كوكتيل',
      name: 'عصير فريز',
      description: 'عصير فريز',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-cocktail',
      category: 'كوكتيل',
      name: 'عصير كوكتيل',
      description: 'عصير كوكتيل',
      priceLbp: 200000),
  MenuProduct(
      id: 'platter-medium',
      category: 'طبق مشكّل',
      name: 'صحن وسط مشكّل',
      description: 'ذرة وفول وحامض وجزر وشمندر',
      priceLbp: 250000),
  MenuProduct(
      id: 'platter-large',
      category: 'طبق مشكّل',
      name: 'صحن كبير مشكّل',
      description: 'ذرة وفول وحامض وجزر وشمندر',
      priceLbp: 400000),
  MenuProduct(
      id: 'platter-corn',
      category: 'طبق مشكّل',
      name: 'Corn',
      description: 'ذرة',
      priceLbp: 150000),
  MenuProduct(
      id: 'tripoli-three-cheese',
      category: 'كعكة طرابلسية',
      name: '3 أجبان',
      description: 'كعكة طرابلسية بثلاثة أجبان',
      priceLbp: 200000),
  MenuProduct(
      id: 'tripoli-chicken',
      category: 'كعكة طرابلسية',
      name: 'حبش مدخن مع جبنة وخضرة',
      description: 'كعكة طرابلسية',
      priceLbp: 250000),
  MenuProduct(
      id: 'tripoli-turkey',
      category: 'كعكة طرابلسية',
      name: 'مرتديلا مع جبنة',
      description: 'كعكة طرابلسية',
      priceLbp: 200000),
  MenuProduct(
      id: 'tripoli-pepperoni',
      category: 'كعكة طرابلسية',
      name: 'بيبروني مع جبنة',
      description: 'كعكة طرابلسية',
      priceLbp: 200000),
];
