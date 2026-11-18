import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'providers/products_firestore_provider.dart';
import 'providers/menu_products_firestore_provider.dart';
import 'providers/reliable_sales_provider.dart';
import 'providers/worker_session_provider.dart';
import 'screens/menu_management_screen.dart';
import 'screens/new_sale_screen.dart';
import 'screens/daily_sales_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'src/app_lang.dart';
import 'widgets/animated_background.dart';
import 'services/firebase_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_backup_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/sync_status_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('shop_manager_settings');
  await LocalBackupService.init();

  await _startApplication();
}

Future<void> _startApplication() async {
  try {
    // Firebase Core must be ready before any Firestore-backed provider is
    // created. Creating those providers first causes [core/no-app].
    await FirebaseService().init();
  } catch (error) {
    runApp(_FirebaseStartupError(error: error));
    return;
  }

  // Authentication is needed by the Firestore security rules. A failed
  // network request must not prevent the app from opening; Firebase Auth can
  // restore a previously signed-in anonymous user when it is available.
  try {
    await FirebaseAuthService()
        .signInAnonymously()
        .timeout(const Duration(seconds: 10));
  } catch (_) {}

  runApp(_buildProviders());
}

Widget _buildProviders() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductsFirestoreProvider()),
        ChangeNotifierProvider(create: (_) => MenuProductsFirestoreProvider()),
        ChangeNotifierProvider(create: (_) => SalesFirestoreProvider()),
        ChangeNotifierProvider(create: (_) => WorkerSessionProvider()),
      ],
      child: const ShopManagerApp(),
    );

class _FirebaseStartupError extends StatefulWidget {
  final Object error;

  const _FirebaseStartupError({required this.error});

  @override
  State<_FirebaseStartupError> createState() => _FirebaseStartupErrorState();
}

class _FirebaseStartupErrorState extends State<_FirebaseStartupError> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await FirebaseService().init();
      try {
        await FirebaseAuthService()
            .signInAnonymously()
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
      runApp(_buildProviders());
    } catch (_) {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذّر الاتصال بـ Firebase',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تأكد من الإنترنت ثم حاول مرة أخرى.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label:
                        Text(_retrying ? 'جاري الاتصال...' : 'إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// --------------------
/// Currency helpers
/// --------------------
String formatUSD(num amount) =>
    NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);

String formatLBP(num amount) =>
    NumberFormat.currency(symbol: 'LBP ', decimalDigits: 0).format(amount);

/// --------------------
/// Simple translations (temporary)
/// --------------------

class T {
  static const _en = {
    'dashboard': 'Dashboard',
    'totalRevenue': 'Total Revenue',
    'todayRevenue': 'Today\'s Sales',
    'exchangeRate': 'Exchange rate',
    'newSale': 'New Sale',
    'products': 'Products',
    'recentSales': 'Recent Sales',
    'viewAll': 'View all',
    'noSalesToday': 'No sales today',
    'today': 'Today',
    'empty': 'No sales yet',
    'statistics': 'Statistics',
    'dailySales': 'Daily Sales',
    'settings': 'Settings',
    'bank': 'Bank',
  };

  static const _ar = {
    'dashboard': 'لوحة التحكم',
    'totalRevenue': 'إجمالي المبيعات',
    'todayRevenue': 'مبيعات اليوم',
    'exchangeRate': 'سعر الصرف',
    'newSale': 'عملية بيع',
    'products': 'المنتجات',
    'recentSales': 'آخر المبيعات',
    'viewAll': 'عرض الكل',
    'noSalesToday': 'لا توجد مبيعات اليوم',
    'today': 'اليوم',
    'empty': 'لا يوجد مبيعات بعد',
    'statistics': 'الإحصائيات',
    'dailySales': 'مبيعات اليوم',
    'settings': 'الإعدادات',
    'bank': 'المخزون',
  };

  static String of(AppLang lang, String key) {
    final map = lang == AppLang.ar ? _ar : _en;
    return map[key] ?? key;
  }
}

class ShopManagerApp extends StatefulWidget {
  const ShopManagerApp({super.key});

  @override
  State<ShopManagerApp> createState() => _ShopManagerAppState();
}

class _ShopManagerAppState extends State<ShopManagerApp> {
  AppLang _lang = AppLang.en;

  void _toggleLang() {
    setState(() {
      _lang = _lang == AppLang.en ? AppLang.ar : AppLang.en;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        _lang == AppLang.ar ? const Locale('ar') : const Locale('en');

    return MaterialApp(
      title: 'Sweet Sip',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFFFFF8ED),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B160D),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color.fromRGBO(255, 255, 255, 0.92),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.deepPurple.shade200),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: DashboardScreen(
        lang: _lang,
        onToggleLang: _toggleLang,
      ),
    );
  }
}

/// --------------------
/// Dashboard Screen
/// --------------------
class DashboardScreen extends StatelessWidget {
  final AppLang lang;
  final VoidCallback onToggleLang;

  const DashboardScreen({
    super.key,
    required this.lang,
    required this.onToggleLang,
  });

  // ثابت حالياً - بالخطوة الجاية منخليه Settings
  static const double exchangeRate = 90000; // updated per request

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesFirestoreProvider>();

    final now = DateTime.now();
    bool isToday(DateTime value) =>
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final todayTransactions = sales.allTransactions
        .where((transaction) => isToday(transaction.createdAt))
        .toList(growable: false);
    final totalUsd = todayTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.totalUsd,
    );
    final totalLbp = todayTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.totalLbp,
    );
    final recentTx = todayTransactions.take(5).toList(growable: false);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(T.of(lang, 'dashboard')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: onToggleLang,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF4B942),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(
              lang == AppLang.en ? 'AR' : 'EN',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SyncStatusBanner(compact: true),
                const SizedBox(height: 10),
                _RevenueCard(
                  title: T.of(lang, 'todayRevenue'),
                  usdText: formatUSD(totalUsd),
                  lbpText: formatLBP(totalLbp),
                  subtitle:
                      '${T.of(lang, 'exchangeRate')}: ${formatLBP(exchangeRate)} / 1 USD',
                ),
                const SizedBox(height: 16),

                // Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.point_of_sale),
                        label: Text(T.of(lang, 'newSale')),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NewSaleScreen(
                                lang: lang == AppLang.ar
                                    ? AppLang.ar
                                    : AppLang.en,
                                exchangeRate: exchangeRate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.inventory_2),
                        label: Text(T.of(lang, 'products')),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuManagementScreen(
                                lang: lang == AppLang.ar
                                    ? AppLang.ar
                                    : AppLang.en,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        T.of(lang, 'recentSales'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DailySalesScreen()),
                        );
                      },
                      child: Text(T.of(lang, 'viewAll')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Recent transactions list
                Expanded(
                  child: recentTx.isEmpty
                      ? Center(child: Text(T.of(lang, 'noSalesToday')))
                      : ListView.separated(
                          itemCount: recentTx.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final tx = recentTx[i];
                            final hh =
                                tx.createdAt.hour.toString().padLeft(2, '0');
                            final mm =
                                tx.createdAt.minute.toString().padLeft(2, '0');
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.receipt_long),
                                ),
                                title: Text(
                                  tx.workerName.isEmpty ||
                                          tx.workerName == 'غير محدد'
                                      ? (lang == AppLang.ar
                                          ? 'طلب جديد'
                                          : 'Order')
                                      : tx.workerName,
                                ),
                                subtitle: Text(
                                  lang == AppLang.ar
                                      ? '$hh:$mm • ${tx.items.length} أصناف'
                                      : '$hh:$mm • ${tx.items.length} items',
                                ),
                                trailing: Text(
                                  '\$${tx.totalUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionDetailScreen(
                                        transaction: tx,
                                      ),
                                    ),
                                  );
                                },
                              ),
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

/// --------------------
/// UI Widgets
/// --------------------
class _RevenueCard extends StatelessWidget {
  final String title;
  final String usdText;
  final String lbpText;
  final String subtitle;

  const _RevenueCard({
    required this.title,
    required this.usdText,
    required this.lbpText,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              usdText,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              lbpText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
