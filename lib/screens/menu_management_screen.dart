import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/menu_product.dart';
import '../providers/menu_products_firestore_provider.dart';
import '../src/app_lang.dart';
import '../widgets/animated_background.dart';

class MenuManagementScreen extends StatefulWidget {
  final AppLang lang;

  const MenuManagementScreen({super.key, required this.lang});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _category;
  String _query = '';

  bool get _arabic => widget.lang == AppLang.ar;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([MenuProduct? product]) async {
    final menuProvider = context.read<MenuProductsFirestoreProvider>();
    final name = TextEditingController(text: product?.name ?? '');
    final description = TextEditingController(text: product?.description ?? '');
    final price = TextEditingController(
      text: product == null ? '' : product.priceLbp.toString(),
    );
    var category = product?.category ??
        _category ??
        (menuProvider.categories.isEmpty
            ? 'كريب'
            : menuProvider.categories.first);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product == null
                      ? (_arabic ? 'إضافة صنف' : 'Add product')
                      : (_arabic ? 'تعديل الصنف' : 'Edit product'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'الفئة' : 'Category',
                    border: const OutlineInputBorder(),
                  ),
                  items: menuProvider.categories
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'اسم الصنف' : 'Product name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: InputDecoration(
                    labelText: _arabic ? 'الوصف' : 'Description',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _arabic ? 'السعر بالليرة' : 'Price (LBP)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final parsedPrice = int.tryParse(price.text.trim());
                    if (name.text.trim().isEmpty ||
                        parsedPrice == null ||
                        parsedPrice <= 0) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(_arabic
                              ? 'أدخل الاسم وسعراً صحيحاً'
                              : 'Enter a name and a valid price'),
                        ),
                      );
                      return;
                    }
                    final provider =
                        this.context.read<MenuProductsFirestoreProvider>();
                    if (product == null) {
                      await provider.addProduct(
                        category: category,
                        name: name.text,
                        description: description.text,
                        priceLbp: parsedPrice,
                      );
                    } else {
                      await provider.updateProduct(product.copyWith(
                        category: category,
                        name: name.text.trim(),
                        description: description.text.trim(),
                        priceLbp: parsedPrice,
                      ));
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_arabic ? 'حفظ' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      name.dispose();
      description.dispose();
      price.dispose();
    });
  }

  Future<void> _addCategory() async {
    var typedName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_arabic ? 'إضافة فئة' : 'Add category'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) => typedName = value,
          decoration: InputDecoration(
            labelText: _arabic ? 'اسم الفئة' : 'Category name',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, typedName),
            child: Text(_arabic ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await context.read<MenuProductsFirestoreProvider>().addCategory(name);
    if (mounted) setState(() => _category = name.trim());
  }

  Future<void> _removeCategory(
    String category, {
    BuildContext? managerContext,
  }) async {
    final provider = context.read<MenuProductsFirestoreProvider>();
    final remaining = provider.categories
        .where((value) => value != category)
        .toList(growable: false);
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_arabic
              ? 'يجب أن تبقى فئة واحدة على الأقل'
              : 'At least one category must remain'),
        ),
      );
      return;
    }

    final productCount = provider.allProducts
        .where((product) => product.category == category)
        .length;
    var replacement = remaining.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_arabic ? 'حذف الفئة؟' : 'Delete category?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(category),
              if (productCount > 0) ...[
                const SizedBox(height: 12),
                Text(_arabic
                    ? 'سيتم نقل $productCount صنف إلى:'
                    : '$productCount products will be moved to:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: replacement,
                  items: remaining
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => replacement = value);
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_arabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_arabic ? 'حذف' : 'Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    // Close the provider-dependent category sheet before notifying listeners.
    // Updating the provider while this sheet and its confirmation dialog are
    // being deactivated can leave an InheritedElement with active dependents.
    if (managerContext != null && managerContext.mounted) {
      Navigator.of(managerContext).pop();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted) return;

    try {
      await provider.deleteCategory(
        category,
        moveProductsTo: productCount == 0 ? null : replacement,
      );
      if (mounted && _category == category) {
        setState(() => _category = null);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_arabic
              ? 'تعذّر حذف الفئة. حاول مجددًا.'
              : 'Could not delete the category. Please try again.'),
        ),
      );
    }
  }

  Future<void> _manageCategories() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Consumer<MenuProductsFirestoreProvider>(
            builder: (context, provider, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _arabic ? 'إدارة الفئات' : 'Manage categories',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: provider.categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = provider.categories[index];
                        final count = provider.allProducts
                            .where((product) => product.category == category)
                            .length;
                        return ListTile(
                          leading: Icon(menuCategoryIcon(category)),
                          title: Text(category),
                          subtitle: Text(
                              _arabic ? '$count أصناف' : '$count products'),
                          trailing: IconButton(
                            tooltip: _arabic ? 'حذف' : 'Delete',
                            onPressed: () => _removeCategory(
                              category,
                              managerContext: sheetContext,
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _confirmDelete(MenuProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_arabic ? 'حذف الصنف؟' : 'Delete product?'),
        content: Text(product.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_arabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<MenuProductsFirestoreProvider>()
          .deleteProduct(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MenuProductsFirestoreProvider>();
    final query = _query.trim().toLowerCase();
    final products = provider.allProducts.where((product) {
      final matchesCategory =
          _category == null || product.category == _category;
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_arabic ? 'إدارة المنيو' : 'Menu Management'),
        actions: [
          IconButton(
            tooltip: _arabic ? 'إضافة فئة' : 'Add category',
            onPressed: _addCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: _arabic ? 'إدارة الفئات' : 'Manage categories',
            onPressed: _manageCategories,
            icon: const Icon(Icons.folder_delete_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: Text(_arabic ? 'إضافة صنف' : 'Add product'),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: _arabic ? 'ابحث عن صنف...' : 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 58,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_arabic ? 'الكل' : 'All'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    ...provider.categories.map((category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(menuCategoryIcon(category), size: 18),
                            label: Text(category),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        )),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                            _arabic ? 'لا توجد أصناف' : 'No products found'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openEditor(product),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      child: Icon(
                                          menuCategoryIcon(product.category)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 3),
                                          Text(
                                              '${product.category} • ${formatLbp(product.priceLbp)}'),
                                          if (product.description.isNotEmpty)
                                            Text(
                                              product.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Switch(
                                          value: product.isAvailable,
                                          onChanged: (value) => provider
                                              .setAvailability(product, value),
                                        ),
                                        Text(
                                          product.isAvailable
                                              ? (_arabic
                                                  ? 'متوفر'
                                                  : 'Available')
                                              : (_arabic ? 'نافد' : 'Sold out'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: product.isAvailable
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: _arabic ? 'حذف' : 'Delete',
                                      onPressed: () => _confirmDelete(product),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
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
        ],
      ),
    );
  }
}
