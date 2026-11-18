import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_firestore_provider.dart';
import '../src/app_lang.dart';
import '../widgets/animated_background.dart';

class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsFirestoreProvider>();
    final products = provider.allProducts;

    final lang = Localizations.localeOf(context).languageCode == 'ar'
        ? AppLang.ar
        : AppLang.en;
    final bankTitle = lang == AppLang.ar ? 'المخزون' : 'Bank';

    final totalStock = products.fold<int>(0, (sum, p) => sum + p.stock);
    final totalValue =
        products.fold<double>(0.0, (sum, p) => sum + p.totalValueUsd);

    // group by category
    final Map<Category, List<Product>> byCat = {};
    for (var p in products) {
      byCat.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      // make content readable when the global scaffold color is transparent
      backgroundColor: Theme.of(context).cardColor.withAlpha(242),
      appBar: AppBar(title: Text(bankTitle)),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatCard(
                          label: lang == AppLang.ar
                              ? 'إجمالي الكمية'
                              : 'Total Stock',
                          value: totalStock.toString(),
                        ),
                        const SizedBox(height: 8),
                        _StatCard(
                          label: lang == AppLang.ar
                              ? 'القيمة الإجمالية'
                              : 'Total Value',
                          value: '\$${totalValue.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: byCat.entries.map((entry) {
                      final cat = entry.key;
                      final list = entry.value;
                      final catStock =
                          list.fold<int>(0, (sum, p) => sum + p.stock);
                      final catValue = list.fold<double>(
                          0.0, (sum, p) => sum + p.totalValueUsd);
                      return ExpansionTile(
                        title: Text(
                            '${cat.displayName}  ($catStock items, \$${catValue.toStringAsFixed(2)})'),
                        children:
                            list.map((p) => _productTile(context, p)).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _productTile(BuildContext context, Product p) {
    final provider = context.read<ProductsFirestoreProvider>();
    return ListTile(
      title: Text(p.name),
      subtitle:
          Text('Stock: ${p.stock}  Price: \$${p.priceUsd.toStringAsFixed(2)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => provider.adjustStock(p.id, -1),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => provider.adjustStock(p.id, 1),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => provider.deleteProduct(p.id),
            color: Colors.redAccent,
          ),
        ],
      ),
      onTap: () => _showEditDialog(context, p),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    Category cat = Category.juices;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<Category>(
                  value: cat,
                  items: Category.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.displayName),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) cat = v;
                  },
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price (USD)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(labelText: 'Initial stock'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final stock = int.tryParse(stockCtrl.text) ?? 0;
                if (name.isNotEmpty && price > 0) {
                  context.read<ProductsFirestoreProvider>().addProduct(
                        category: cat,
                        name: name,
                        priceUsd: price,
                        initialStock: stock,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Product p) {
    final stockCtrl = TextEditingController(text: p.stock.toString());
    final priceCtrl = TextEditingController(text: p.priceUsd.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stockCtrl,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (USD)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final newStock = int.tryParse(stockCtrl.text) ?? p.stock;
                final newPrice = double.tryParse(priceCtrl.text) ?? p.priceUsd;
                if (newStock != p.stock) {
                  context
                      .read<ProductsFirestoreProvider>()
                      .updateStock(p.id, newStock);
                }
                if (newPrice != p.priceUsd) {
                  // Price editing can be added when the provider supports it.
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
