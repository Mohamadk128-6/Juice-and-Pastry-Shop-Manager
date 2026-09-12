import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../providers/sales_firestore_provider.dart';
import '../widgets/animated_background.dart';

class _SaleByProductData {
  final String productName;
  final double totalUsd;
  final int quantity; // total units sold

  _SaleByProductData({
    required this.productName,
    required this.totalUsd,
    required this.quantity,
  });
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesFirestoreProvider>();
    final sales = provider.allSales;

    // Group by product
    final grouped = <String, _SaleByProductData>{};
    for (var sale in sales) {
      if (grouped.containsKey(sale.productName)) {
        grouped[sale.productName] = _SaleByProductData(
          productName: sale.productName,
          totalUsd: grouped[sale.productName]!.totalUsd + sale.totalUsd,
          quantity: grouped[sale.productName]!.quantity + sale.quantity,
        );
      } else {
        grouped[sale.productName] = _SaleByProductData(
          productName: sale.productName,
          totalUsd: sale.totalUsd,
          quantity: sale.quantity,
        );
      }
    }

    final chartData = grouped.values.toList();
    final totalUsd = provider.totalUsdAll;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Statistics'),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary cards
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatCard(
                          label: 'Total Sales (USD)',
                          value: '\$${totalUsd.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _StatCard(
                          label: 'Total Transactions',
                          value: sales.length.toString(),
                        ),
                        const SizedBox(height: 8),
                        _StatCard(
                          label: 'Average Transaction',
                          value: sales.isEmpty
                              ? '\$0.00'
                              : '\$${(totalUsd / sales.length).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pie chart
                if (chartData.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Sales by Product',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          SfCircularChart(
                            series: <CircularSeries>[
                              PieSeries<_SaleByProductData, String>(
                                dataSource: chartData,
                                xValueMapper: (datum, _) => datum.productName,
                                yValueMapper: (datum, _) => datum.totalUsd,
                                dataLabelMapper: (datum, _) =>
                                    '${datum.productName}: \$${datum.totalUsd.toStringAsFixed(2)}',
                                dataLabelSettings:
                                    const DataLabelSettings(isVisible: true),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Column chart: Sales count
                if (chartData.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Units Sold by Product',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          SfCartesianChart(
                            primaryXAxis: const CategoryAxis(),
                            series: <CartesianSeries>[
                              ColumnSeries<_SaleByProductData, String>(
                                dataSource: chartData,
                                xValueMapper: (datum, _) => datum.productName,
                                yValueMapper: (datum, _) => datum.quantity,
                                dataLabelSettings:
                                    const DataLabelSettings(isVisible: true),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Detailed product list
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: chartData.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final item = chartData[i];
                            return ListTile(
                              title: Text(item.productName),
                              subtitle: Text('${item.quantity} sold'),
                              trailing: Text(
                                '\$${item.totalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
