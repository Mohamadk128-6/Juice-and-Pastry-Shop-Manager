import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/sale_transaction.dart';

class SalesProvider extends ChangeNotifier {
  // new transaction storage
  final List<SaleTransaction> _transactions = [];

  // legacy list computed from transactions for compatibility
  List<Sale> get allSales =>
      _transactions.expand((t) => t.items).toList(growable: false);

  List<Sale> get recentSales {
    final copy =
        recentTransactions.expand((t) => t.items).toList(growable: false);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(20).toList();
  }

  List<SaleTransaction> get allTransactions => List.unmodifiable(_transactions);

  List<SaleTransaction> get recentTransactions {
    final copy = [..._transactions];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(20).toList();
  }

  /// adds a whole transaction containing multiple sale items
  void addTransaction({
    required List<Sale> items,
    required double exchangeRate,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final tx = SaleTransaction(
      id: id,
      items: items,
      exchangeRate: exchangeRate,
      createdAt: DateTime.now(),
    );
    _transactions.add(tx);
    notifyListeners();
  }

  /// legacy convenience for a single-item sale, kept for backward compatibility
  void addSale({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPriceUsd,
    required double exchangeRate,
  }) {
    addTransaction(
      items: [
        Sale(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          productId: productId,
          productName: productName,
          quantity: quantity,
          unitPriceUsd: unitPriceUsd,
          exchangeRate: exchangeRate,
          createdAt: DateTime.now(),
        )
      ],
      exchangeRate: exchangeRate,
    );
  }

  double get totalUsdAll => allSales.fold(0.0, (sum, s) => sum + s.totalUsd);

  double totalUsdForDay(DateTime day) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return allSales
        .where((s) => sameDay(s.createdAt, day))
        .fold(0.0, (sum, s) => sum + s.totalUsd);
  }

  double totalUsdForMonth(DateTime day) {
    return allSales
        .where((s) =>
            s.createdAt.year == day.year && s.createdAt.month == day.month)
        .fold(0.0, (sum, s) => sum + s.totalUsd);
  }
}
