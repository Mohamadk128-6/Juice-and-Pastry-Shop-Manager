import 'package:flutter/material.dart';

import '../models/sale_transaction.dart';
import '../src/app_lang.dart';

class TransactionDetailScreen extends StatelessWidget {
  final SaleTransaction transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    // determine current app language from locale
    final lang = Localizations.localeOf(context).languageCode == 'ar'
        ? AppLang.ar
        : AppLang.en;
    final hh = transaction.createdAt.hour.toString().padLeft(2, '0');
    final mm = transaction.createdAt.minute.toString().padLeft(2, '0');

    // ensure content is readable over animated background
    return Scaffold(
      // 0.95 opacity approximated with alpha 242 (255*0.95)
      backgroundColor: Theme.of(context).cardColor.withAlpha(242),
      appBar: AppBar(
        title: Text(lang == AppLang.ar ? 'تفاصيل' : 'Txn @ $hh:$mm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Total: \$${transaction.totalUsd.toStringAsFixed(2)}'),
            Text('LBP ${transaction.totalLbp.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text(lang == AppLang.ar
                ? 'سجله العامل: ${transaction.workerName}'
                : 'Recorded by: ${transaction.workerName}'),
            if (transaction.orderNote.isNotEmpty)
              Text(lang == AppLang.ar
                  ? 'ملاحظة: ${transaction.orderNote}'
                  : 'Note: ${transaction.orderNote}'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: transaction.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final s = transaction.items[i];
                  return ListTile(
                    title: Text(s.productName),
                    subtitle: Text('x${s.quantity} @ \$${s.unitPriceUsd}'),
                    trailing: Text('\$${s.totalUsd.toStringAsFixed(2)}'),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
