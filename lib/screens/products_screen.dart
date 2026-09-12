import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/products_firestore_provider.dart';
import '../src/app_lang.dart';
import '../widgets/animated_background.dart';

class T {
  static const _en = {
    'products': 'Products',
    'juices': 'Juices',
    'sweets': 'Sweets',
    'addProduct': 'Add Product',
    'name': 'Name',
    'priceUsd': 'Price (USD)',
    'cancel': 'Cancel',
    'add': 'Add',
    'delete': 'Delete',
    'invalidName': 'Please enter a name',
    'invalidPrice': 'Please enter a valid price',
  };

  static const _ar = {
    'products': 'المنتجات',
    'juices': 'عصائر',
    'sweets': 'حلويات',
    'addProduct': 'إضافة منتج',
    'name': 'الاسم',
    'priceUsd': 'السعر (دولار)',
    'cancel': 'إلغاء',
    'add': 'إضافة',
    'delete': 'حذف',
    'invalidName': 'الرجاء إدخال الاسم',
    'invalidPrice': 'الرجاء إدخال سعر صحيح',
  };

  static String of(AppLang lang, String key) {
    final map = lang == AppLang.ar ? _ar : _en;
    return map[key] ?? key;
  }
}

class ProductsScreen extends StatefulWidget {
  final AppLang lang;
  const ProductsScreen({super.key, required this.lang});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Category get _currentCategory =>
      _tab.index == 0 ? Category.juices : Category.sweets;

  void _openAddDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(T.of(widget.lang, 'addProduct')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: T.of(widget.lang, 'name')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: T.of(widget.lang, 'priceUsd')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(T.of(widget.lang, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim());

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(T.of(widget.lang, 'invalidName'))),
                  );
                  return;
                }
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(T.of(widget.lang, 'invalidPrice'))),
                  );
                  return;
                }

                context.read<ProductsFirestoreProvider>().addProduct(
                      category: _currentCategory,
                      name: name,
                      priceUsd: price,
                    );

                Navigator.pop(ctx);
              },
              child: Text(T.of(widget.lang, 'add')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(lang, 'products')),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: T.of(lang, 'juices')),
            Tab(text: T.of(lang, 'sweets')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: Text(T.of(lang, 'addProduct')),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          TabBarView(
            controller: _tab,
            children: const [
              _ProductsList(category: Category.juices),
              _ProductsList(category: Category.sweets),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductsList extends StatelessWidget {
  final Category category;
  const _ProductsList({required this.category});

  @override
  Widget build(BuildContext context) {
    final items =
        context.watch<ProductsFirestoreProvider>().byCategory(category);

    if (items.isEmpty) {
      return const Center(child: Text('—'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = items[i];
        return Card(
          elevation: 0,
          child: ListTile(
            title: Text(p.name),
            subtitle: Text('\$${p.priceUsd.toStringAsFixed(2)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  context.read<ProductsFirestoreProvider>().deleteProduct(p.id),
            ),
          ),
        );
      },
    );
  }
}
