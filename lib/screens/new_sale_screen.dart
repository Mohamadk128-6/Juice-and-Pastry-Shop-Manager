import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_firestore_provider.dart';
import '../providers/sales_firestore_provider.dart';
import '../models/sale.dart';
import 'daily_sales_screen.dart';
import '../src/app_lang.dart';
import '../widgets/animated_background.dart';

class TSale {
  static const _en = {
    'newSale': 'New Sale',
    'category': 'Category',
    'juices': 'Juices',
    'sweets': 'Sweets',
    'product': 'Product',
    'quantity': 'Quantity',
    'confirm': 'Confirm Sale',
    'pickProduct': 'Please select a product',
    'invalidQty': 'Quantity must be at least 1',
    'saleDone': 'Sale added',
    'completeSale': 'Complete Sale',
    'cart': 'Cart',
    'addProduct': 'Add to cart',
  };

  static const _ar = {
    'newSale': 'عملية بيع',
    'category': 'الفئة',
    'juices': 'عصائر',
    'sweets': 'حلويات',
    'product': 'المنتج',
    'quantity': 'الكمية',
    'confirm': 'تأكيد البيع',
    'pickProduct': 'الرجاء اختيار منتج',
    'invalidQty': 'الكمية يجب أن تكون 1 أو أكثر',
    'saleDone': 'تمت إضافة عملية البيع',
    'completeSale': 'إتمام البيع',
    'cart': 'عربة',
    'addProduct': 'أضف إلى العربة',
  };

  static String of(AppLang lang, String key) {
    final map = lang == AppLang.ar ? _ar : _en;
    return map[key] ?? key;
  }
}

class NewSaleScreen extends StatefulWidget {
  final AppLang lang;
  final double exchangeRate; // USD -> LBP

  const NewSaleScreen({
    super.key,
    required this.lang,
    required this.exchangeRate,
  });

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _CartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int qty;

  _CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
  });
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  Category _category = Category.juices;
  String? _selectedProductId;
  int _qty = 1;
  final List<_CartItem> _cart = [];

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    final products =
        context.watch<ProductsFirestoreProvider>().byCategory(_category);
    final selected = products.where((p) => p.id == _selectedProductId).toList();
    final Product? product = selected.isEmpty ? null : selected.first;

    final cartTotalUsd =
        _cart.fold<double>(0.0, (sum, item) => sum + item.unitPrice * item.qty);
    final cartTotalLbp = cartTotalUsd * widget.exchangeRate;

    return Scaffold(
      appBar: AppBar(
        title: Text(TSale.of(lang, 'newSale')),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Category
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<Category>(
                        segments: [
                          ButtonSegment(
                            value: Category.juices,
                            label: Text(TSale.of(lang, 'juices')),
                            icon: const Icon(Icons.local_drink),
                          ),
                          ButtonSegment(
                            value: Category.sweets,
                            label: Text(TSale.of(lang, 'sweets')),
                            icon: const Icon(Icons.cake),
                          ),
                        ],
                        selected: {_category},
                        onSelectionChanged: (set) {
                          setState(() {
                            _category = set.first;
                            _selectedProductId = null;
                            _qty = 1;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Product dropdown
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    TSale.of(lang, 'product'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  items: products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                '${p.name}  -  \$${p.priceUsd.toStringAsFixed(2)}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),

                const SizedBox(height: 16),

                // Quantity
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    TSale.of(lang, 'quantity'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_qty > 1) setState(() => _qty--);
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_qty',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _qty++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Add to cart button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(TSale.of(lang, 'addProduct')),
                    onPressed: () {
                      if (_selectedProductId == null || product == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(TSale.of(lang, 'pickProduct'))),
                        );
                        return;
                      }
                      if (_qty < 1) return;
                      setState(() {
                        _cart.add(_CartItem(
                          productId: product.id,
                          name: product.name,
                          unitPrice: product.priceUsd,
                          qty: _qty,
                        ));
                        _selectedProductId = null;
                        _qty = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_cart.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      TSale.of(lang, 'cart'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final item = _cart[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text('x${item.qty} @ \$${item.unitPrice}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _cart.removeAt(i)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Totals card
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Line(
                            label: 'USD',
                            value: '\$${cartTotalUsd.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _Line(
                            label: 'LBP',
                            value: 'LBP ${cartTotalLbp.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _Line(
                          label: 'Rate',
                          value:
                              'LBP ${widget.exchangeRate.toStringAsFixed(0)} / 1 USD',
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(TSale.of(lang, 'completeSale')),
                    onPressed: () {
                      if (_cart.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(TSale.of(lang, 'pickProduct'))),
                        );
                        return;
                      }
                      // create Sale objects from cart
                      final items = _cart
                          .map((item) => Sale(
                                id: DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                                productId: item.productId,
                                productName: item.name,
                                quantity: item.qty,
                                unitPriceUsd: item.unitPrice,
                                exchangeRate: widget.exchangeRate,
                                createdAt: DateTime.now(),
                              ))
                          .toList();
                      context.read<SalesFirestoreProvider>().addTransaction(
                            items: items,
                            exchangeRate: widget.exchangeRate,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(TSale.of(lang, 'saleDone'))),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DailySalesScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
