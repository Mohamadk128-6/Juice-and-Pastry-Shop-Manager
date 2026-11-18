import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reliable_sales_provider.dart';
import '../providers/menu_products_firestore_provider.dart';
import '../providers/worker_session_provider.dart';
import '../models/sale.dart';
import 'daily_sales_screen.dart';
import 'quick_order_screen.dart';
import '../src/app_lang.dart';
import '../widgets/animated_background.dart';
import '../widgets/sync_status_banner.dart';

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
    'chooseFromMenu': 'Tap to choose from the full menu',
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
    'chooseFromMenu': 'اضغط للاختيار من المنيو الكامل',
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
  final List<_CartItem> _cart = [];
  final TextEditingController _orderNoteController = TextEditingController();
  bool _isSaving = false;
  String? _submissionId;

  @override
  void dispose() {
    _orderNoteController.dispose();
    super.dispose();
  }

  Future<void> _editWorkerName(BuildContext context) async {
    final session = context.read<WorkerSessionProvider>();
    var editedName = session.workerName;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسم العامل'),
        content: TextFormField(
          initialValue: editedName,
          autofocus: true,
          onChanged: (value) => editedName = value,
          decoration: const InputDecoration(
            labelText: 'الاسم الذي سيظهر للمالك',
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedName),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null && name.trim().isNotEmpty) {
      await session.setWorkerName(name);
    }
  }

  Future<void> _pickProductFromMenu() async {
    final menu = context
        .read<MenuProductsFirestoreProvider>()
        .availableProducts
        .map(menuProductFromStored)
        .toList(growable: false);
    final selected = await showModalBottomSheet<Map<MenuProduct, int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MenuProductPicker(products: menu),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() {
      for (final entry in selected.entries) {
        final product = entry.key;
        final existingIndex =
            _cart.indexWhere((item) => item.productId == product.id);
        if (existingIndex == -1) {
          _cart.add(_CartItem(
            productId: product.id,
            name: product.name,
            unitPrice: product.priceLbp / widget.exchangeRate,
            qty: entry.value,
          ));
        } else {
          final existing = _cart[existingIndex];
          _cart[existingIndex] = _CartItem(
            productId: existing.productId,
            name: existing.name,
            unitPrice: existing.unitPrice,
            qty: existing.qty + entry.value,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final workerSession = context.watch<WorkerSessionProvider>();

    final cartTotalUsd =
        _cart.fold<double>(0.0, (sum, item) => sum + item.unitPrice * item.qty);
    final cartTotalLbp = cartTotalUsd * widget.exchangeRate;

    return Scaffold(
      appBar: AppBar(
        title: Text(TSale.of(lang, 'newSale')),
        actions: [
          IconButton(
            tooltip: 'منيو Sweet',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    QuickOrderScreen(exchangeRate: widget.exchangeRate),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SyncStatusBanner(compact: true),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(workerSession.hasWorkerName
                          ? workerSession.workerName
                          : 'حدد اسم العامل قبل تسجيل الطلب'),
                      subtitle:
                          const Text('يظهر الاسم عند صاحب المحل مع كل طلب'),
                      trailing: TextButton(
                        onPressed: () => _editWorkerName(context),
                        child: Text(
                            workerSession.hasWorkerName ? 'تغيير' : 'تحديد'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Full menu product picker
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      TSale.of(lang, 'product'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _pickProductFromMenu,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.restaurant_menu),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TSale.of(lang, 'chooseFromMenu'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  if (_cart.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_cart.length} أصناف في العربة • اضغط لإضافة المزيد',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
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
                            subtitle:
                                Text('x${item.qty} @ \$${item.unitPrice}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _cart.removeAt(i)),
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

                  const SizedBox(height: 12),
                  TextField(
                    controller: _orderNoteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة للطلب (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving
                          ? 'جاري حفظ الطلب...'
                          : TSale.of(lang, 'completeSale')),
                      onPressed: _isSaving
                          ? null
                          : () async {
                              if (!workerSession.hasWorkerName) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                      content: Text('حدد اسم العامل أولاً')),
                                );
                                return;
                              }
                              if (_cart.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(TSale.of(lang, 'pickProduct'))),
                                );
                                return;
                              }
                              setState(() => _isSaving = true);
                              final now = DateTime.now();
                              _submissionId ??=
                                  '${now.microsecondsSinceEpoch}-${workerSession.workerName.hashCode.abs()}';
                              final items = _cart
                                  .map((item) => Sale(
                                        id: '${item.productId}-${now.microsecondsSinceEpoch}',
                                        productId: item.productId,
                                        productName: item.name,
                                        quantity: item.qty,
                                        unitPriceUsd: item.unitPrice,
                                        exchangeRate: widget.exchangeRate,
                                        createdAt: now,
                                      ))
                                  .toList();
                              try {
                                await context
                                    .read<SalesFirestoreProvider>()
                                    .addTransaction(
                                      items: items,
                                      exchangeRate: widget.exchangeRate,
                                      workerName: workerSession.workerName,
                                      orderNote: _orderNoteController.text,
                                      transactionId: _submissionId,
                                    );
                              } catch (_) {
                                if (!mounted) return;
                                setState(() => _isSaving = false);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'تعذّر الحفظ المحلي، حاول مرة أخرى'),
                                  ),
                                );
                                return;
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'تم حفظ الطلب وسيتم مزامنته تلقائياً'),
                                ),
                              );
                              Navigator.pushReplacement(
                                this.context,
                                MaterialPageRoute(
                                    builder: (_) => const DailySalesScreen()),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuProductPicker extends StatefulWidget {
  final List<MenuProduct> products;

  const _MenuProductPicker({required this.products});

  @override
  State<_MenuProductPicker> createState() => _MenuProductPickerState();
}

class _MenuProductPickerState extends State<_MenuProductPicker> {
  final TextEditingController _searchController = TextEditingController();
  final Map<MenuProduct, int> _selected = {};
  MenuCategory? _category;
  String _query = '';

  int get _selectedCount =>
      _selected.values.fold(0, (total, quantity) => total + quantity);

  int get _selectedTotalLbp => _selected.entries.fold(
        0,
        (total, entry) => total + entry.key.priceLbp * entry.value,
      );

  void _add(MenuProduct product) {
    setState(() => _selected[product] = (_selected[product] ?? 0) + 1);
  }

  void _remove(MenuProduct product) {
    final quantity = _selected[product] ?? 0;
    if (quantity <= 1) {
      setState(() => _selected.remove(product));
    } else {
      setState(() => _selected[product] = quantity - 1);
    }
  }

  List<MenuProduct> get _products {
    final query = _query.trim().toLowerCase();
    return widget.products.where((product) {
      final categoryMatches =
          _category == null || product.category == _category;
      final queryMatches = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final categories =
        widget.products.map((product) => product.category).toSet().toList();
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu),
                SizedBox(width: 10),
                Text('اختر من المنيو',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 62,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(category.icon, size: 18),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('لا يوجد صنف مطابق'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final quantity = _selected[product] ?? 0;
                      return Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        color: quantity > 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () => _add(product),
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
                                Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  formatLbp(product.priceLbp),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: quantity == 0
                                          ? null
                                          : () => _remove(product),
                                      icon: const Icon(Icons.remove, size: 18),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    IconButton.filled(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _add(product),
                                      icon: const Icon(Icons.add, size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            Map<MenuProduct, int>.from(_selected),
                          ),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    _selected.isEmpty
                        ? 'اختر الأصناف'
                        : 'أضف $_selectedCount إلى العربة • ${formatLbp(_selectedTotalLbp)}',
                  ),
                ),
              ),
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
