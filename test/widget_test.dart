import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/models/product.dart';
import 'package:shop_manager/models/sale.dart';

void main() {
  group('Product', () {
    test('calculates total inventory value', () {
      final product = Product(
        id: 'orange-juice',
        category: Category.juices,
        name: 'Orange Juice',
        priceUsd: 2.5,
        stock: 8,
      );

      expect(product.totalValueUsd, 20);
      expect(product.category.displayName, 'Juices');
    });
  });

  group('Sale', () {
    test('calculates USD and LBP totals using the sale exchange rate', () {
      final sale = Sale(
        id: 'sale-1',
        productId: 'croissant',
        productName: 'Croissant',
        quantity: 3,
        unitPriceUsd: 1.5,
        exchangeRate: 89500,
        createdAt: DateTime(2026, 2, 28),
      );

      expect(sale.totalUsd, 4.5);
      expect(sale.totalLbp, 402750);
    });

    test('keeps the timestamp supplied for a transaction', () {
      final timestamp = DateTime(2026, 2, 28, 12, 30);
      final sale = Sale(
        id: 'sale-2',
        productId: 'lemonade',
        productName: 'Lemonade',
        quantity: 1,
        unitPriceUsd: 2,
        exchangeRate: 89500,
        createdAt: timestamp,
      );

      expect(sale.createdAt, timestamp);
    });
  });
}
