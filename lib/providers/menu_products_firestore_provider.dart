import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/menu_product.dart';
import '../services/firebase_service.dart';
import '../services/local_backup_service.dart';

class MenuProductsFirestoreProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().firestore;
  List<MenuProduct> _items = List.of(defaultSweetMenu);
  List<String> _categories = List.of(defaultMenuCategories);
  Map<String, List<String>> _categoryDocumentIds = {};
  StreamSubscription? _subscription;
  bool _seedStarted = false;
  bool _isLoading = true;
  String? _lastError;

  MenuProductsFirestoreProvider() {
    _loadLocalBackup();
    _listen();
  }

  List<MenuProduct> get allProducts => List.unmodifiable(_items);
  List<String> get categories => List.unmodifiable(_categories);
  List<MenuProduct> get availableProducts =>
      _items.where((product) => product.isAvailable).toList(growable: false);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  void _loadLocalBackup() {
    final backup = LocalBackupService.menuBackup;
    if (backup == null) return;
    final categories = backup['categories'];
    final products = backup['products'];
    if (categories is List) {
      _categories = categories.map((value) => value.toString()).toList();
    }
    if (products is List) {
      _items = products.whereType<Map>().map((value) {
        final data = Map<String, dynamic>.from(value);
        return MenuProduct(
          id: data['id']?.toString() ?? '',
          category: data['category']?.toString() ?? 'كريب',
          name: data['name']?.toString() ?? '',
          description: data['description']?.toString() ?? '',
          priceLbp: (data['priceLbp'] as num?)?.round() ?? 0,
          isAvailable: data['isAvailable'] as bool? ?? true,
        );
      }).toList();
    }
    _isLoading = false;
  }

  void _listen() {
    _subscription = _db.collection('products').snapshots().listen(
      (snapshot) {
        final remote = <MenuProduct>[];
        final categoryNames = <String>{};
        final categoryDocumentIds = <String, List<String>>{};
        for (final document in snapshot.docs) {
          final data = document.data();
          if (data['type'] == 'menu_category') {
            final name = (data['name'] as String? ?? '').trim();
            if (name.isNotEmpty) {
              categoryNames.add(name);
              categoryDocumentIds.putIfAbsent(name, () => []).add(document.id);
            }
            continue;
          }
          if (data['type'] != 'menu') continue;
          final category = _normalizeCategory(data['menuCategory']);
          categoryNames.add(category);
          remote.add(MenuProduct(
            id: document.id,
            category: category,
            name: data['name'] as String? ?? '',
            description: data['description'] as String? ?? '',
            priceLbp: (data['priceLbp'] as num?)?.round() ?? 0,
            isAvailable: data['isAvailable'] as bool? ?? true,
          ));
        }
        if (remote.isEmpty) {
          _seedDefaults();
          return;
        }
        remote.sort((a, b) {
          final categoryCompare = a.category.compareTo(b.category);
          return categoryCompare != 0
              ? categoryCompare
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        _items = remote;
        _categories = categoryNames.toList(growable: false);
        _categoryDocumentIds = categoryDocumentIds;
        _isLoading = false;
        _lastError = null;
        unawaited(_saveLocalBackup());
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _lastError = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _saveLocalBackup() => LocalBackupService.saveMenu({
        'categories': _categories,
        'products': _items
            .map((product) => {
                  'id': product.id,
                  'category': product.category,
                  'name': product.name,
                  'description': product.description,
                  'priceLbp': product.priceLbp,
                  'isAvailable': product.isAvailable,
                })
            .toList(growable: false),
      });

  Future<void> _seedDefaults() async {
    if (_seedStarted) return;
    _seedStarted = true;
    final batch = _db.batch();
    for (final product in defaultSweetMenu) {
      batch.set(
        _db.collection('products').doc(product.id),
        _dataFor(product),
        SetOptions(merge: true),
      );
    }
    for (var index = 0; index < defaultMenuCategories.length; index++) {
      batch.set(
        _db.collection('products').doc('menu-category-$index'),
        {
          'type': 'menu_category',
          'name': defaultMenuCategories[index],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    try {
      await batch.commit();
    } catch (_) {
      _seedStarted = false;
    }
  }

  Map<String, Object?> _dataFor(MenuProduct product) => {
        'type': 'menu',
        'menuCategory': product.category,
        'name': product.name.trim(),
        'description': product.description.trim(),
        'priceLbp': product.priceLbp,
        'isAvailable': product.isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<void> addProduct({
    required String category,
    required String name,
    required String description,
    required int priceLbp,
  }) async {
    final reference = _db.collection('products').doc();
    await reference.set(_dataFor(MenuProduct(
      id: reference.id,
      category: category,
      name: name,
      description: description,
      priceLbp: priceLbp,
    )));
  }

  Future<void> updateProduct(MenuProduct product) =>
      _db.collection('products').doc(product.id).set(
            _dataFor(product),
            SetOptions(merge: true),
          );

  Future<void> setAvailability(MenuProduct product, bool value) =>
      updateProduct(product.copyWith(isAvailable: value));

  Future<void> addCategory(String name) async {
    final value = name.trim();
    if (value.isEmpty || _categories.contains(value)) return;
    _categories = [..._categories, value];
    notifyListeners();
    final reference = await _db.collection('products').add({
      'type': 'menu_category',
      'name': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _categoryDocumentIds[value] = [reference.id];
  }

  Future<void> deleteCategory(
    String name, {
    String? moveProductsTo,
  }) async {
    final affected =
        _items.where((product) => product.category == name).toList();
    if (affected.isNotEmpty &&
        (moveProductsTo == null || moveProductsTo == name)) {
      throw ArgumentError('A replacement category is required.');
    }

    final batch = _db.batch();
    for (final product in affected) {
      batch.update(_db.collection('products').doc(product.id), {
        'menuCategory': moveProductsTo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final documentId in _categoryDocumentIds[name] ?? const <String>[]) {
      batch.delete(_db.collection('products').doc(documentId));
    }

    _items = _items
        .map((product) => product.category == name
            ? product.copyWith(category: moveProductsTo)
            : product)
        .toList(growable: false);
    _categories = _categories.where((category) => category != name).toList();
    _categoryDocumentIds.remove(name);
    notifyListeners();
    await batch.commit();
  }

  Future<void> deleteProduct(String id) =>
      _db.collection('products').doc(id).delete();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

String _normalizeCategory(Object? value) => switch (value?.toString()) {
      'crep' => 'كريب',
      'cocktail' => 'كوكتيل',
      'platter' => 'طبق مشكّل',
      'tripoli' => 'كعكة طرابلسية',
      'extras' => 'إضافات',
      final String name when name.trim().isNotEmpty => name.trim(),
      _ => 'كريب',
    };
