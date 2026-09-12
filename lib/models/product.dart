enum Category { juices, sweets }

extension CategoryExtension on Category {
  String get displayName {
    switch (this) {
      case Category.juices:
        return 'Juices';
      case Category.sweets:
        return 'Sweets';
    }
  }
}

class Product {
  final String id;
  final Category category;
  final String name;
  final double priceUsd;
  int stock;

  Product({
    required this.id,
    required this.category,
    required this.name,
    required this.priceUsd,
    this.stock = 0,
  });

  double get totalValueUsd => stock * priceUsd;
}
