import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/product.dart';

class ProductsProvider extends ChangeNotifier {
  final List<Product> _items = [
    Product(
        id: 'p1',
        category: Category.juices,
        name: 'Orange',
        priceUsd: 3.0,
        stock: 0),
    Product(
        id: 'p2',
        category: Category.sweets,
        name: 'Jello',
        priceUsd: 2.0,
        stock: 0),
  ];

  List<Product> get allProducts => List.unmodifiable(_items);

  List<Product> byCategory(Category category) =>
      _items.where((p) => p.category == category).toList();

  void addProduct({
    required Category category,
    required String name,
    required double priceUsd,
    int initialStock = 0,
  }) {
    final p = Product(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: category,
      name: name.trim(),
      priceUsd: priceUsd,
      stock: initialStock,
    );
    _items.insert(0, p);
    notifyListeners();
  }

  void deleteProduct(String id) {
    _items.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void updateStock(String id, int newStock) {
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _items[idx].stock = newStock;
      notifyListeners();
    }
  }

  void adjustStock(String id, int delta) {
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _items[idx].stock += delta;
      if (_items[idx].stock < 0) _items[idx].stock = 0;
      notifyListeners();
    }
  }
}
