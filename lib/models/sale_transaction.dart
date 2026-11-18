import 'sale.dart';

class SaleTransaction {
  final String id;
  final List<Sale> items;
  final DateTime createdAt;
  final double exchangeRate;
  final String workerName;
  final String orderNote;

  SaleTransaction({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.exchangeRate,
    this.workerName = 'غير محدد',
    this.orderNote = '',
  });

  double get totalUsd => items.fold(0.0, (s, item) => s + item.totalUsd);
  double get totalLbp => totalUsd * exchangeRate;
}
