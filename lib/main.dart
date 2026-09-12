import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/products_firestore_provider.dart';
import 'providers/sales_firestore_provider.dart';
import 'screens/products_screen.dart';
import 'screens/new_sale_screen.dart';
import 'screens/daily_sales_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'src/app_lang.dart';
import 'widgets/animated_background.dart';
import 'services/firebase_service.dart';
import 'services/firebase_auth_service.dart';
import 'widgets/app_drawer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize Firebase and sign in anonymously (best-effort)
  await FirebaseService().init().catchError((_) {});
  try {
    // try anonymous sign-in; ignore failure for local dev
    await FirebaseAuthService().signInAnonymously();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        // Firestore-backed providers for realtime sync (primary)
        ChangeNotifierProvider(create: (_) => ProductsFirestoreProvider()),
        ChangeNotifierProvider(create: (_) => SalesFirestoreProvider()),
      ],
      child: const ShopManagerApp(),
    ),
  );
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
    'exchangeRate': 'Exchange rate',
    'newSale': 'New Sale',
    'products': 'Products',
    'recentSales': 'Recent Sales',
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
    'exchangeRate': 'سعر الصرف',
    'newSale': 'عملية بيع',
    'products': 'المنتجات',
    'recentSales': 'آخر المبيعات',
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
      title: 'Shop Manager',
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
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
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

    final totalUsd = sales.totalUsdAll;
    final totalLbp = totalUsd * exchangeRate;

    final recentTx = sales.recentTransactions;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(T.of(lang, 'dashboard')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: onToggleLang,
            child: Text(
              lang == AppLang.en ? 'AR' : 'EN',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
                _RevenueCard(
                  title: T.of(lang, 'totalRevenue'),
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
                              builder: (_) => ProductsScreen(
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

                // Recent sales title (tap to view full day list)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DailySalesScreen()),
                      );
                    },
                    child: Text(
                      T.of(lang, 'recentSales'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Recent transactions list
                Expanded(
                  child: recentTx.isEmpty
                      ? Center(child: Text(T.of(lang, 'empty')))
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
                                title: Text('Transaction ${i + 1}'),
                                subtitle: Text('$hh:$mm'),
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
