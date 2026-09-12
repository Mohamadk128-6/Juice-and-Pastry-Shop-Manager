import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart' as models;
import '../services/firebase_service.dart';

class ProductsFirestoreProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().firestore;
  final List<models.Product> _items = [];
  StreamSubscription? _sub;

  ProductsFirestoreProvider() {
    _listen();
  }

  void _listen() {
    _sub = _db.collection('products').snapshots().listen((snap) {
      _items.clear();
      for (var doc in snap.docs) {
        final data = doc.data();
        final catStr = (data['category'] ?? 'juices') as String;
        final category = models.Category.values.firstWhere(
            (c) => c.toString().split('.').last == catStr,
            orElse: () => models.Category.juices);
        _items.add(models.Product(
          id: doc.id,
          category: category,
          name: data['name'] ?? '',
          priceUsd: (data['priceUsd'] ?? 0).toDouble(),
          stock: (data['stock'] ?? 0) as int,
        ));
      }
      notifyListeners();
    });
  }

  List<models.Product> get allProducts => List.unmodifiable(_items);

  List<models.Product> byCategory(models.Category category) =>
      _items.where((p) => p.category == category).toList();

  Future<void> addProduct({
    required models.Category category,
    required String name,
    required double priceUsd,
    int initialStock = 0,
  }) async {
    final doc = {
      'category': category.toString().split('.').last,
      'name': name.trim(),
      'priceUsd': priceUsd,
      'stock': initialStock,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('products').add(doc);
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  Future<void> updateStock(String id, int newStock) async {
    await _db.collection('products').doc(id).update({'stock': newStock});
  }

  Future<void> adjustStock(String id, int delta) async {
    final ref = _db.collection('products').doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['stock'] ?? 0) as int;
      final next = current + delta;
      tx.update(ref, {'stock': next < 0 ? 0 : next});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
