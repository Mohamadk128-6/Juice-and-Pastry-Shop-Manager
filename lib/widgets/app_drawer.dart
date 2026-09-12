import 'package:flutter/material.dart';

import '../screens/daily_sales_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/bank_screen.dart';
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
    final bankText = T.of(lang, 'bank');
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
              'Shop Manager',
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
            leading: const Icon(Icons.inventory_2),
            title: Text(bankText),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BankScreen()),
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
        ],
      ),
    );
  }
}
