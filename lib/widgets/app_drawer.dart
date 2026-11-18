import 'package:flutter/material.dart';

import '../screens/daily_sales_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/owner_orders_screen.dart';
import '../screens/smart_suggestions_screen.dart';
import '../src/app_lang.dart';
import '../main.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode == 'ar'
        ? AppLang.ar
        : AppLang.en;
    final statsText = T.of(lang, 'statistics');
    final dailyText = T.of(lang, 'dailySales');
    // optionally: final settingsText = lang == AppLang.ar ? 'الإعدادات' : 'Settings';
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              'Sweet Sip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(statsText),
            onTap: () {
              Navigator.pop(context); // close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: Text(lang == AppLang.ar ? 'طلبات الموظفين' : 'Staff Orders'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerOrdersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: Text(dailyText),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailySalesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(
              lang == AppLang.ar ? 'الاقتراحات الذكية' : 'Smart Suggestions',
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SmartSuggestionsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
