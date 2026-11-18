import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import '../models/sale_transaction.dart';
import '../services/firebase_service.dart';

class SalesFirestoreProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().firestore;
  final List<SaleTransaction> _transactions = [];
  StreamSubscription? _sub;

  SalesFirestoreProvider() {
    _listen();
  }

  void _listen() {
    _sub = _db
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _transactions.clear();
      for (var doc in snap.docs) {
        final data = doc.data();
        final items = <Sale>[];
        if (data['items'] is List) {
          for (final it in (data['items'] as List)) {
            items.add(Sale(
              id: it['id'] ?? '',
              productId: it['productId'] ?? '',
              productName: it['productName'] ?? '',
              quantity: (it['quantity'] ?? 0) as int,
              unitPriceUsd: (it['unitPriceUsd'] ?? 0).toDouble(),
              exchangeRate: (it['exchangeRate'] ?? 0).toDouble(),
              createdAt:
                  (it['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ));
          }
        }
        final created =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final exchangeRate = (data['exchangeRate'] ?? 0).toDouble();
        _transactions.add(SaleTransaction(
          id: doc.id,
          items: items,
          createdAt: created,
          exchangeRate: exchangeRate,
          workerName: (data['workerName'] ?? 'غير محدد').toString(),
          orderNote: (data['orderNote'] ?? '').toString(),
        ));
      }
      notifyListeners();
    });
  }

  List<SaleTransaction> get allTransactions => List.unmodifiable(_transactions);

  List<Sale> get allSales =>
      _transactions.expand((t) => t.items).toList(growable: false);

  List<SaleTransaction> get recentTransactions {
    final copy = [..._transactions];
    return copy.take(20).toList();
  }

  List<String> get workerNames {
    final names = _transactions
        .map((transaction) => transaction.workerName)
        .where((name) => name.isNotEmpty && name != 'غير محدد')
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<SaleTransaction> transactionsForWorker(String workerName) =>
      _transactions
          .where((transaction) => transaction.workerName == workerName)
          .toList(growable: false);

  double get totalUsdAll =>
      allSales.fold(0.0, (total, sale) => total + sale.totalUsd);

  double totalUsdForDay(DateTime day) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return allSales
        .where((s) => sameDay(s.createdAt, day))
        .fold(0.0, (total, sale) => total + sale.totalUsd);
  }

  double totalUsdForMonth(DateTime day) {
    return allSales
        .where((s) =>
            s.createdAt.year == day.year && s.createdAt.month == day.month)
        .fold(0.0, (total, sale) => total + sale.totalUsd);
  }

  Future<void> addTransaction({
    required List<Sale> items,
    required double exchangeRate,
    required String workerName,
    String orderNote = '',
  }) async {
    final doc = {
      'createdAt': FieldValue.serverTimestamp(),
      'exchangeRate': exchangeRate,
      'workerName': workerName.trim(),
      'orderNote': orderNote.trim(),
      'items': items
          .map((s) => {
                'id': s.id,
                'productId': s.productId,
                'productName': s.productName,
                'quantity': s.quantity,
                'unitPriceUsd': s.unitPriceUsd,
                'exchangeRate': s.exchangeRate,
                'createdAt': s.createdAt,
              })
          .toList(),
    };
    await _db.collection('transactions').add(doc);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
