import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_product.dart' as stored;
import '../providers/menu_products_firestore_provider.dart';
import '../models/sale.dart';
import '../providers/reliable_sales_provider.dart';
import '../providers/worker_session_provider.dart';

class QuickOrderScreen extends StatefulWidget {
  final double exchangeRate;

  const QuickOrderScreen({super.key, required this.exchangeRate});

  @override
  State<QuickOrderScreen> createState() => _QuickOrderScreenState();
}

class _QuickOrderScreenState extends State<QuickOrderScreen> {
  MenuCategory _selectedCategory = MenuCategory.crep;
  final Map<String, int> _cart = {};

  List<MenuProduct> get _allProducts => context
      .read<MenuProductsFirestoreProvider>()
      .availableProducts
      .map(menuProductFromStored)
      .toList(growable: false);

  List<MenuProduct> get _visibleProducts => _allProducts
      .where((product) => product.category == _selectedCategory)
      .toList(growable: false);

  int get _itemCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);

  int get _totalLbp => _allProducts
      .where((product) => _cart.containsKey(product.id))
      .fold(0, (sum, product) => sum + product.priceLbp * _cart[product.id]!);

  Future<void> _showProductInfo(MenuProduct product) async {
    var quantity = _cart[product.id] ?? 1;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(product.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(product.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text('السعر: ${formatLbp(product.priceLbp)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: quantity > 1
                          ? () => setSheetState(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('$quantity',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setSheetState(() => quantity++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _cart[product.id] = quantity);
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text('أضف $quantity إلى الطلب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCart() async {
    if (_cart.isEmpty) return;
    final workerSession = context.read<WorkerSessionProvider>();
    var saving = false;
    String? submissionId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected = _allProducts
              .where((product) => _cart.containsKey(product.id))
              .toList(growable: false);
          return AlertDialog(
            title: const Text('تأكيد الطلب'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: selected.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = selected[index];
                  final quantity = _cart[product.id]!;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text(
                        'x$quantity • ${formatLbp(product.priceLbp * quantity)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => _cart.remove(product.id));
                        setDialogState(() {});
                        if (_cart.isEmpty) Navigator.pop(dialogContext);
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: workerSession.hasWorkerName && !saving
                    ? () async {
                        setDialogState(() => saving = true);
                        final now = DateTime.now();
                        submissionId ??=
                            '${now.microsecondsSinceEpoch}-${workerSession.workerName.hashCode.abs()}';
                        final sales = selected
                            .map(
                              (product) => Sale(
                                id: '${product.id}-${now.microsecondsSinceEpoch}',
                                productId: product.id,
                                productName: product.name,
                                quantity: _cart[product.id]!,
                                unitPriceUsd:
                                    product.priceLbp / widget.exchangeRate,
                                exchangeRate: widget.exchangeRate,
                                createdAt: now,
                              ),
                            )
                            .toList(growable: false);
                        try {
                          await context
                              .read<SalesFirestoreProvider>()
                              .addTransaction(
                                items: sales,
                                exchangeRate: widget.exchangeRate,
                                workerName: workerSession.workerName,
                                transactionId: submissionId,
                              );
                        } catch (_) {
                          if (!mounted || !dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تعذّر الحفظ المحلي، حاول مرة أخرى',
                              ),
                            ),
                          );
                          return;
                        }
                        if (!mounted || !dialogContext.mounted) return;
                        setState(_cart.clear);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ الطلب')),
                        );
                      }
                    : null,
                child: Text(saving ? 'جاري الحفظ...' : 'حفظ الطلب'),
              ),
            ],
          );
        },
      ),
    );
    if (!workerSession.hasWorkerName && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد اسم العامل من شاشة البيع أولاً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProductsFirestoreProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('منيو Sweet'),
        actions: [
          IconButton(
            tooltip: 'سلة الطلب',
            onPressed: _cart.isEmpty ? null : _showCart,
            icon: Badge(
              isLabelVisible: _itemCount > 0,
              label: Text('$_itemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: menuProvider.categories
                  .map(MenuCategory.custom)
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.label),
                        selected: _selectedCategory == category,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _visibleProducts.length,
              itemBuilder: (context, index) {
                final product = _visibleProducts[index];
                final quantity = _cart[product.id] ?? 0;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showProductInfo(product),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(product.category.icon),
                              const Spacer(),
                              if (quantity > 0)
                                Badge(label: Text('x$quantity')),
                            ],
                          ),
                          const Spacer(),
                          Text(product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(formatLbp(product.priceLbp),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _showCart,
                  icon: const Icon(Icons.receipt_long),
                  label: Text('$_itemCount أصناف • ${formatLbp(_totalLbp)}'),
                ),
              ),
            ),
    );
  }
}

MenuProduct menuProductFromStored(stored.MenuProduct product) => MenuProduct(
      id: product.id,
      category: MenuCategory.custom(product.category),
      name: product.name,
      description: product.description,
      priceLbp: product.priceLbp,
    );

class MenuCategory {
  final String label;
  final IconData icon;

  const MenuCategory(this.label, this.icon);

  static const crep = MenuCategory('كريب', Icons.breakfast_dining_outlined);
  static const cocktail = MenuCategory('كوكتيل', Icons.local_drink_outlined);
  static const platter = MenuCategory('طبق مشكّل', Icons.rice_bowl_outlined);
  static const tripoli =
      MenuCategory('كعكة طرابلسية', Icons.lunch_dining_outlined);
  static const extras = MenuCategory('إضافات', Icons.add_circle_outline);

  static const values = [crep, cocktail, platter, tripoli, extras];

  factory MenuCategory.custom(String label) =>
      MenuCategory(label, stored.menuCategoryIcon(label));

  @override
  bool operator ==(Object other) =>
      other is MenuCategory && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

class MenuProduct {
  final String id;
  final MenuCategory category;
  final String name;
  final String description;
  final int priceLbp;

  const MenuProduct({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.priceLbp,
  });
}

String formatLbp(int value) => 'ل.ل ${value.toString().replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (match) => '.',
    )}';

const sweetMenu = <MenuProduct>[
  MenuProduct(
      id: 'crep-nutella',
      category: MenuCategory.crep,
      name: 'Nutella',
      description: 'كريب بالنوتيلا',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-white-nutella',
      category: MenuCategory.crep,
      name: 'White chocolate & Nutella',
      description: 'كريب بالشوكولا البيضاء والنوتيلا',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-lotus',
      category: MenuCategory.crep,
      name: 'Lotus',
      description: 'كريب لوتس',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-nutella-lotus',
      category: MenuCategory.crep,
      name: 'Nutella & Lotus',
      description: 'كريب نوتيلا ولوتس',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-kinder',
      category: MenuCategory.crep,
      name: 'Kinder',
      description: 'كريب كيندر',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-oreo',
      category: MenuCategory.crep,
      name: 'Oreo',
      description: 'كريب أوريو',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-pistachio',
      category: MenuCategory.crep,
      name: 'Pistachio',
      description: 'كريب فستق',
      priceLbp: 350000),
  MenuProduct(
      id: 'crep-pistachio-nutella',
      category: MenuCategory.crep,
      name: 'Pistachio & Nutella',
      description: 'كريب فستق ونوتيلا',
      priceLbp: 400000),
  MenuProduct(
      id: 'crep-brownie',
      category: MenuCategory.crep,
      name: 'Brownie',
      description: 'كريب براوني',
      priceLbp: 400000),
  MenuProduct(
      id: 'extra-fruits',
      category: MenuCategory.extras,
      name: 'Added fruits',
      description: 'إضافة فواكه إلى الكريب',
      priceLbp: 50000),
  MenuProduct(
      id: 'cocktail-shaqf',
      category: MenuCategory.cocktail,
      name: 'كوكتيل شقف',
      description: 'كوكتيل شقف',
      priceLbp: 450000),
  MenuProduct(
      id: 'cocktail-avocado-nutella',
      category: MenuCategory.cocktail,
      name: 'Avocado & Nutella',
      description: 'أفوكادو ونوتيلا',
      priceLbp: 350000),
  MenuProduct(
      id: 'cocktail-avocado-cream',
      category: MenuCategory.cocktail,
      name: 'Avocado & cream',
      description: 'أفوكادو وقشطة',
      priceLbp: 300000),
  MenuProduct(
      id: 'juice-lemon',
      category: MenuCategory.cocktail,
      name: 'عصير ليمون',
      description: 'ليمون طازج',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-carrot',
      category: MenuCategory.cocktail,
      name: 'عصير جزر',
      description: 'جزر طازج',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-fresh',
      category: MenuCategory.cocktail,
      name: 'عصير فريز',
      description: 'عصير فريز',
      priceLbp: 150000),
  MenuProduct(
      id: 'juice-cocktail',
      category: MenuCategory.cocktail,
      name: 'عصير كوكتيل',
      description: 'عصير كوكتيل',
      priceLbp: 200000),
  MenuProduct(
      id: 'platter-medium',
      category: MenuCategory.platter,
      name: 'صحن وسط مشكّل',
      description: 'ذرة وفول وحامض وجزر وشمندر',
      priceLbp: 250000),
  MenuProduct(
      id: 'platter-large',
      category: MenuCategory.platter,
      name: 'صحن كبير مشكّل',
      description: 'ذرة وفول وحامض وجزر وشمندر',
      priceLbp: 400000),
  MenuProduct(
      id: 'platter-corn',
      category: MenuCategory.platter,
      name: 'Corn',
      description: 'ذرة',
      priceLbp: 150000),
  MenuProduct(
      id: 'tripoli-three-cheese',
      category: MenuCategory.tripoli,
      name: '3 أجبان',
      description: 'كعكة طرابلسية بثلاثة أجبان',
      priceLbp: 200000),
  MenuProduct(
      id: 'tripoli-chicken',
      category: MenuCategory.tripoli,
      name: 'حبش مدخن مع جبنة وخضرة',
      description: 'كعكة طرابلسية',
      priceLbp: 250000),
  MenuProduct(
      id: 'tripoli-turkey',
      category: MenuCategory.tripoli,
      name: 'مرتديلا مع جبنة',
      description: 'كعكة طرابلسية',
      priceLbp: 200000),
  MenuProduct(
      id: 'tripoli-pepperoni',
      category: MenuCategory.tripoli,
      name: 'بيبروني مع جبنة',
      description: 'كعكة طرابلسية',
      priceLbp: 200000),
];
