import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/sales_firestore_provider.dart';
import '../src/app_lang.dart';
import 'transaction_detail_screen.dart';

class DailySalesScreen extends StatelessWidget {
  const DailySalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final provider = context.watch<SalesFirestoreProvider>();
    final lang = Localizations.localeOf(context).languageCode == 'ar'
        ? AppLang.ar
        : AppLang.en;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final txs = provider.allTransactions
        .where((t) => sameDay(t.createdAt, today))
        .toList();
    final totalUsd = provider.totalUsdForDay(today);
    final totalLbp = totalUsd * (txs.isNotEmpty ? txs.first.exchangeRate : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == AppLang.ar ? 'مبيعات اليوم' : 'Today\'s Sales'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Total USD: \$${totalUsd.toStringAsFixed(2)}'),
            Text('Total LBP: LBP ${totalLbp.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            Expanded(
              child: txs.isEmpty
                  ? const Center(child: Text('No sales yet'))
                  : ListView.separated(
                      itemCount: txs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final t = txs[i];
                        final hh = t.createdAt.hour.toString().padLeft(2, '0');
                        final mm =
                            t.createdAt.minute.toString().padLeft(2, '0');
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            title: Text('Transaction ${i + 1}'),
                            subtitle: Text('$hh:$mm'),
                            trailing: Text(
                              '\$${t.totalUsd.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                          transaction: t,
                                        )),
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
    );
  }
}
