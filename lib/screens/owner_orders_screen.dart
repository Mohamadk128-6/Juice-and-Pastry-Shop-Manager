import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reliable_sales_provider.dart';
import 'transaction_detail_screen.dart';

/// Real-time view for the shop owner. It reads the same Firestore collection
/// that workers write to, so an order appears here as soon as it is saved.
class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  String _workerFilter = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesFirestoreProvider>();
    final workers = provider.workerNames;
    final transactions = _workerFilter.isEmpty
        ? provider.allTransactions
        : provider.transactionsForWorker(_workerFilter);
    final totalUsd = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.totalUsd,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الموظفين')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _workerFilter,
              decoration: const InputDecoration(
                labelText: 'عرض طلبات العامل',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('كل العاملين')),
                ...workers.map(
                  (name) => DropdownMenuItem(value: name, child: Text(name)),
                ),
              ],
              onChanged: (value) => setState(() => _workerFilter = value ?? ''),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('${transactions.length} طلب'),
                trailing: Text(
                  '\$${totalUsd.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('لا توجد طلبات بعد'))
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final time =
                            TimeOfDay.fromDateTime(transaction.createdAt)
                                .format(context);
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(transaction.workerName),
                            subtitle: Text(
                              '$time • ${transaction.items.length} صنف'
                              '${transaction.orderNote.isEmpty ? '' : '\n${transaction.orderNote}'}',
                            ),
                            isThreeLine: transaction.orderNote.isNotEmpty,
                            trailing: Text(
                              '\$${transaction.totalUsd.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailScreen(
                                  transaction: transaction,
                                ),
                              ),
                            ),
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
