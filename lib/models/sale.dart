class Sale {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPriceUsd;
  final double exchangeRate; // USD -> LBP at sale time
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceUsd,
    required this.exchangeRate,
    required this.createdAt,
  });

  double get totalUsd => unitPriceUsd * quantity;
  double get totalLbp => totalUsd * exchangeRate;
}