import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/sale_transaction.dart';
import '../providers/reliable_sales_provider.dart';
import '../widgets/animated_background.dart';

enum _StatisticsPeriod { today, week, month, all }

class _ProductStatistics {
  final String name;
  double totalUsd = 0;
  int quantity = 0;

  _ProductStatistics({required this.name});
}

class _TrendPoint {
  final String label;
  final double totalUsd;

  const _TrendPoint(this.label, this.totalUsd);
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _StatisticsPeriod _period = _StatisticsPeriod.today;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.watch<SalesFirestoreProvider>();
    final now = DateTime.now();
    final periodStart = _startFor(_period, now);
    final transactions = _filter(provider.allTransactions, periodStart, now);
    final previous = _previousTransactions(
      provider.allTransactions,
      _period,
      periodStart,
    );

    final totalUsd = transactions.fold<double>(
      0,
      (total, transaction) => total + transaction.totalUsd,
    );
    final totalLbp = transactions.fold<double>(
      0,
      (total, transaction) => total + transaction.totalLbp,
    );
    final averageOrder =
        transactions.isEmpty ? 0.0 : totalUsd / transactions.length;
    final previousTotal = previous.fold<double>(
      0,
      (total, transaction) => total + transaction.totalUsd,
    );
    final change = previousTotal <= 0
        ? null
        : ((totalUsd - previousTotal) / previousTotal) * 100;

    final products = _productStatistics(transactions);
    final topProducts = products.take(5).toList(growable: false);
    final weakestProduct = products.isEmpty
        ? null
        : products.reduce(
            (first, second) =>
                first.quantity <= second.quantity ? first : second,
          );
    final trend = _trendData(transactions, _period, isArabic);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إحصائيات المبيعات' : 'Sales Statistics'),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          RefreshIndicator(
            onRefresh: provider.retryPendingTransactions,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSelector(
                  selected: _period,
                  isArabic: isArabic,
                  onChanged: (value) => setState(() => _period = value),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryCard(
                      icon: Icons.attach_money,
                      label: isArabic ? 'إجمالي المبيعات' : 'Total sales',
                      value: '\$${totalUsd.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                    _SummaryCard(
                      icon: Icons.payments_outlined,
                      label: isArabic ? 'المبيعات بالليرة' : 'Sales in LBP',
                      value: '${NumberFormat('#,##0').format(totalLbp)} L.L',
                      color: Colors.amber.shade800,
                    ),
                    _SummaryCard(
                      icon: Icons.receipt_long_outlined,
                      label: isArabic ? 'عدد الطلبات' : 'Orders',
                      value: transactions.length.toString(),
                      color: Colors.blue,
                    ),
                    _SummaryCard(
                      icon: Icons.analytics_outlined,
                      label: isArabic ? 'متوسط الطلب' : 'Average order',
                      value: '\$${averageOrder.toStringAsFixed(2)}',
                      color: Colors.purple,
                    ),
                  ],
                ),
                if (change != null && _period != _StatisticsPeriod.all) ...[
                  const SizedBox(height: 12),
                  _ComparisonBanner(change: change, isArabic: isArabic),
                ],
                const SizedBox(height: 18),
                if (transactions.isEmpty)
                  _EmptyStatistics(isArabic: isArabic)
                else ...[
                  _ChartCard(
                    title: isArabic
                        ? 'حركة المبيعات خلال الفترة'
                        : 'Sales trend',
                    child: SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: -45,
                        majorGridLines: MajorGridLines(width: 0),
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          symbol: r'$',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries<_TrendPoint, String>>[
                        SplineAreaSeries<_TrendPoint, String>(
                          dataSource: trend,
                          xValueMapper: (point, _) => point.label,
                          yValueMapper: (point, _) => point.totalUsd,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.22),
                          borderColor: Theme.of(context).colorScheme.primary,
                          borderWidth: 3,
                          markerSettings:
                              const MarkerSettings(isVisible: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (topProducts.isNotEmpty)
                    _ChartCard(
                      title: isArabic
                          ? 'أفضل 5 منتجات حسب الكمية'
                          : 'Top 5 products by quantity',
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(
                          labelRotation: -35,
                          majorGridLines: MajorGridLines(width: 0),
                        ),
                        primaryYAxis: const NumericAxis(
                          decimalPlaces: 0,
                          minimum: 0,
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <
                            CartesianSeries<_ProductStatistics, String>>[
                          ColumnSeries<_ProductStatistics, String>(
                            dataSource: topProducts,
                            xValueMapper: (product, _) => product.name,
                            yValueMapper: (product, _) => product.quantity,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
                          ),
                        ],
                      ),
                    ),
                  if (weakestProduct != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.trending_down),
                        ),
                        title: Text(
                          isArabic ? 'الأقل مبيعًا' : 'Lowest-selling product',
                        ),
                        subtitle: Text(weakestProduct.name),
                        trailing: Text(
                          isArabic
                              ? '${weakestProduct.quantity} قطعة'
                              : '${weakestProduct.quantity} units',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ProductDetailsCard(
                    products: products,
                    isArabic: isArabic,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _startFor(_StatisticsPeriod period, DateTime now) {
    switch (period) {
      case _StatisticsPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case _StatisticsPeriod.week:
        final today = DateTime(now.year, now.month, now.day);
        return today.subtract(Duration(days: today.weekday - 1));
      case _StatisticsPeriod.month:
        return DateTime(now.year, now.month);
      case _StatisticsPeriod.all:
        return null;
    }
  }

  List<SaleTransaction> _filter(
    List<SaleTransaction> source,
    DateTime? start,
    DateTime end,
  ) =>
      source
          .where((transaction) =>
              (start == null || !transaction.createdAt.isBefore(start)) &&
              !transaction.createdAt.isAfter(end))
          .toList(growable: false);

  List<SaleTransaction> _previousTransactions(
    List<SaleTransaction> source,
    _StatisticsPeriod period,
    DateTime? currentStart,
  ) {
    if (period == _StatisticsPeriod.all || currentStart == null) return const [];

    late DateTime previousStart;
    late DateTime previousEnd;
    switch (period) {
      case _StatisticsPeriod.today:
        previousStart = currentStart.subtract(const Duration(days: 1));
        previousEnd = currentStart;
      case _StatisticsPeriod.week:
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
      case _StatisticsPeriod.month:
        previousStart = DateTime(currentStart.year, currentStart.month - 1);
        previousEnd = currentStart;
      case _StatisticsPeriod.all:
        return const [];
    }
    return source
        .where((transaction) =>
            !transaction.createdAt.isBefore(previousStart) &&
            transaction.createdAt.isBefore(previousEnd))
        .toList(growable: false);
  }

  List<_ProductStatistics> _productStatistics(
    List<SaleTransaction> transactions,
  ) {
    final grouped = <String, _ProductStatistics>{};
    for (final transaction in transactions) {
      for (final sale in transaction.items) {
        final product = grouped.putIfAbsent(
          sale.productName,
          () => _ProductStatistics(name: sale.productName),
        );
        product.quantity += sale.quantity;
        product.totalUsd += sale.totalUsd;
      }
    }
    final result = grouped.values.toList(growable: false);
    result.sort((a, b) => b.quantity.compareTo(a.quantity));
    return result;
  }

  List<_TrendPoint> _trendData(
    List<SaleTransaction> transactions,
    _StatisticsPeriod period,
    bool isArabic,
  ) {
    final grouped = <DateTime, double>{};
    for (final transaction in transactions) {
      final date = period == _StatisticsPeriod.today
          ? DateTime(
              transaction.createdAt.year,
              transaction.createdAt.month,
              transaction.createdAt.day,
              transaction.createdAt.hour,
            )
          : DateTime(
              transaction.createdAt.year,
              transaction.createdAt.month,
              transaction.createdAt.day,
            );
      grouped.update(
        date,
        (value) => value + transaction.totalUsd,
        ifAbsent: () => transaction.totalUsd,
      );
    }
    final dates = grouped.keys.toList()..sort();
    final locale = isArabic ? 'ar' : 'en';
    return dates
        .map((date) => _TrendPoint(
              period == _StatisticsPeriod.today
                  ? DateFormat('HH:00', locale).format(date)
                  : DateFormat('d MMM', locale).format(date),
              grouped[date]!,
            ))
        .toList(growable: false);
  }
}

class _PeriodSelector extends StatelessWidget {
  final _StatisticsPeriod selected;
  final bool isArabic;
  final ValueChanged<_StatisticsPeriod> onChanged;

  const _PeriodSelector({
    required this.selected,
    required this.isArabic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String label(_StatisticsPeriod period) {
      if (isArabic) {
        return switch (period) {
          _StatisticsPeriod.today => 'اليوم',
          _StatisticsPeriod.week => 'الأسبوع',
          _StatisticsPeriod.month => 'الشهر',
          _StatisticsPeriod.all => 'الكل',
        };
      }
      return switch (period) {
        _StatisticsPeriod.today => 'Today',
        _StatisticsPeriod.week => 'Week',
        _StatisticsPeriod.month => 'Month',
        _StatisticsPeriod.all => 'All',
      };
    }

    return SegmentedButton<_StatisticsPeriod>(
      segments: _StatisticsPeriod.values
          .map((period) => ButtonSegment(
                value: period,
                label: Text(label(period)),
              ))
          .toList(growable: false),
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 42) / 2;
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonBanner extends StatelessWidget {
  final double change;
  final bool isArabic;

  const _ComparisonBanner({required this.change, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final increased = change >= 0;
    final color = increased ? Colors.green : Colors.red;
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(
          increased ? Icons.trending_up : Icons.trending_down,
          color: color,
        ),
        title: Text(
          isArabic
              ? '${increased ? 'ارتفاع' : 'انخفاض'} ${change.abs().toStringAsFixed(1)}% عن الفترة السابقة'
              : '${change.abs().toStringAsFixed(1)}% ${increased ? 'increase' : 'decrease'} from the previous period',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 280, child: child),
            ],
          ),
        ),
      );
}

class _ProductDetailsCard extends StatelessWidget {
  final List<_ProductStatistics> products;
  final bool isArabic;

  const _ProductDetailsCard({
    required this.products,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'تفاصيل المنتجات' : 'Product details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...products.map((product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text(
                      isArabic
                          ? '${product.quantity} قطعة'
                          : '${product.quantity} units',
                    ),
                    trailing: Text(
                      '\$${product.totalUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
            ],
          ),
        ),
      );
}

class _EmptyStatistics extends StatelessWidget {
  final bool isArabic;

  const _EmptyStatistics({required this.isArabic});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.query_stats,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                isArabic
                    ? 'لا توجد مبيعات في هذه الفترة'
                    : 'No sales in this period',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
}
