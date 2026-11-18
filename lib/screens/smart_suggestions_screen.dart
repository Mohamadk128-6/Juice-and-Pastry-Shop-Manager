import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sale_transaction.dart';
import '../providers/reliable_sales_provider.dart';
import '../services/local_backup_service.dart';

class SmartSuggestionsScreen extends StatefulWidget {
  const SmartSuggestionsScreen({super.key});

  @override
  State<SmartSuggestionsScreen> createState() => _SmartSuggestionsScreenState();
}

class _SmartSuggestionsScreenState extends State<SmartSuggestionsScreen> {
  Map<String, dynamic>? _aiSuggestion;
  bool _requesting = false;
  String? _requestMessage;

  @override
  void initState() {
    super.initState();
    _aiSuggestion = LocalBackupService.aiSuggestionBackup;
  }

  Future<void> _requestAiSuggestion(_SalesSummary summary) async {
    if (_requesting || summary.totalOrders == 0) return;
    setState(() {
      _requesting = true;
      _requestMessage = 'يتم تحليل المبيعات وتجهيز اقتراح جديد...';
    });

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.5-flash-lite',
        generationConfig: GenerationConfig(maxOutputTokens: 320),
      );
      final response = await model.generateContent([
        Content.text(_aiPrompt(summary)),
      ]).timeout(const Duration(seconds: 35));
      final content = response.text?.trim() ?? '';
      if (content.isEmpty) {
        throw StateError('Gemini returned an empty suggestion');
      }
      final saved = <String, dynamic>{
        'content': content,
        'provider': 'Gemini',
        'generatedAt': DateTime.now().toIso8601String(),
      };
      await LocalBackupService.saveAiSuggestion(saved);
      if (!mounted) return;
      setState(() {
        _aiSuggestion = saved;
        _requesting = false;
        _requestMessage = 'تم إنشاء اقتراح جديد بنجاح.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _requestMessage =
            'استغرق الاتصال وقتاً طويلاً. التحليل المحلي ما زال يعمل.';
      });
    } catch (error, stackTrace) {
      debugPrint('Firebase AI suggestion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _requestMessage =
            'تعذّر تشغيل Gemini الآن. تأكد من تفعيل AI Logic وApp Check؛ التحليل المحلي ما زال يعمل.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions =
        context.watch<SalesFirestoreProvider>().allTransactions;
    final summary = _SalesSummary.fromTransactions(transactions);
    final localSuggestions = summary.localSuggestions;
    final aiText = _aiSuggestion?['content']?.toString().trim() ?? '';
    final provider = _aiSuggestion?['provider']?.toString() ?? '';
    final generatedAt = _date(_aiSuggestion?['generatedAt']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاقتراحات الذكية'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _requestAiSuggestion(summary),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4B942).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF4B942).withValues(alpha: 0.55),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFFB3261E)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'التحليل المحلي فوري ولا يؤثر على سرعة البيع',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(summary: summary),
            const SizedBox(height: 20),
            Text(
              'تحليل فوري من مبيعات آخر 30 يوماً',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (localSuggestions.isEmpty)
              const _SuggestionCard(
                icon: Icons.info_outline,
                title: 'لا توجد بيانات كافية بعد',
                body: 'سجّل بعض الطلبات أولاً لتظهر الاقتراحات.',
              )
            else
              ...localSuggestions.map(
                (item) => _SuggestionCard(
                  icon: item.icon,
                  title: item.title,
                  body: item.body,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الاقتراح السحابي',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (provider.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 17),
                    label: Text(provider),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: aiText.isEmpty
                    ? const Text(
                        'لم يتم إنشاء اقتراح سحابي بعد. الاقتراحات المحلية أعلاه تعمل دون إنترنت.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            aiText,
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'آخر تحديث: ${DateFormat('yyyy/MM/dd – HH:mm').format(generatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
            ),
            if (_requestMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFB3261E)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_requestMessage!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4B942),
                foregroundColor: const Color(0xFF1B160D),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: summary.totalOrders == 0 || _requesting
                  ? null
                  : () => _requestAiSuggestion(summary),
              icon: _requesting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _requesting ? 'يتم تجهيز الاقتراح...' : 'طلب اقتراح ذكي',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يعمل Gemini عبر Firebase AI Logic؛ وعند تعذره تبقى الاقتراحات المحلية متاحة فوراً.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final _SalesSummary summary;

  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'الطلبات',
            value: '${summary.totalOrders}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'المبيعات ل.ل',
            value: formatter.format(summary.totalRevenueLbp.round()),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(body),
          ),
        ),
      );
}

class _LocalSuggestion {
  final IconData icon;
  final String title;
  final String body;

  const _LocalSuggestion(this.icon, this.title, this.body);
}

class _SalesSummary {
  final int periodDays;
  final int totalOrders;
  final double totalRevenueLbp;
  final List<_ProductTotal> topProducts;
  final List<_ProductTotal> weakProducts;
  final List<_PairTotal> commonPairs;
  final int? peakHour;

  const _SalesSummary({
    required this.periodDays,
    required this.totalOrders,
    required this.totalRevenueLbp,
    required this.topProducts,
    required this.weakProducts,
    required this.commonPairs,
    required this.peakHour,
  });

  factory _SalesSummary.fromTransactions(
    List<SaleTransaction> allTransactions,
  ) {
    const periodDays = 30;
    final cutoff = DateTime.now().subtract(const Duration(days: periodDays));
    final transactions = allTransactions
        .where((transaction) => !transaction.createdAt.isBefore(cutoff))
        .toList(growable: false);
    final products = <String, _MutableProductTotal>{};
    final pairs = <String, _MutablePairTotal>{};
    final hours = <int, int>{};

    for (final transaction in transactions) {
      hours.update(transaction.createdAt.hour, (current) => current + 1,
          ifAbsent: () => 1);
      final names = transaction.items
          .map((sale) => sale.productName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      for (final sale in transaction.items) {
        final name = sale.productName.trim();
        if (name.isEmpty) continue;
        final total = products.putIfAbsent(
          name,
          () => _MutableProductTotal(name),
        );
        total.quantity += sale.quantity;
        total.revenueLbp += sale.totalLbp;
      }
      for (var first = 0; first < names.length; first++) {
        for (var second = first + 1; second < names.length; second++) {
          final key = '${names[first]}|${names[second]}';
          final pair = pairs.putIfAbsent(
            key,
            () => _MutablePairTotal(names[first], names[second]),
          );
          pair.count++;
        }
      }
    }

    final rankedProducts = products.values
        .map((item) => _ProductTotal(
              item.name,
              item.quantity,
              item.revenueLbp,
            ))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final weakProducts = List<_ProductTotal>.of(rankedProducts)
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    final rankedPairs = pairs.values
        .map((item) => _PairTotal(item.first, item.second, item.count))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final peakHour = hours.entries.isEmpty
        ? null
        : hours.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _SalesSummary(
      periodDays: periodDays,
      totalOrders: transactions.length,
      totalRevenueLbp: transactions.fold(
        0.0,
        (total, transaction) => total + transaction.totalLbp,
      ),
      topProducts: rankedProducts.take(10).toList(growable: false),
      weakProducts: weakProducts.take(5).toList(growable: false),
      commonPairs: rankedPairs.take(5).toList(growable: false),
      peakHour: peakHour,
    );
  }

  List<_LocalSuggestion> get localSuggestions {
    if (totalOrders == 0 || topProducts.isEmpty) return const [];
    final suggestions = <_LocalSuggestion>[];
    final top = topProducts.first;
    suggestions.add(_LocalSuggestion(
      Icons.trending_up,
      'الأكثر طلباً: ${top.name}',
      'تم بيع ${top.quantity} قطعة خلال آخر $periodDays يوماً. حافظ على توفر مكوناته.',
    ));
    if (commonPairs.isNotEmpty && commonPairs.first.count >= 2) {
      final pair = commonPairs.first;
      suggestions.add(_LocalSuggestion(
        Icons.local_offer_outlined,
        'عرض مقترح',
        '${pair.first} مع ${pair.second} ظهرا معاً في ${pair.count} طلبات. يمكن تجربتهما كعرض واحد.',
      ));
    }
    if (weakProducts.length > 1) {
      final weak = weakProducts.first;
      if (weak.name != top.name) {
        suggestions.add(_LocalSuggestion(
          Icons.lightbulb_outline,
          'منتج يحتاج دعماً: ${weak.name}',
          'مبيعاته ${weak.quantity} فقط. جرّب إبرازه في المنيو أو ضمّه إلى عرض لفترة محدودة.',
        ));
      }
    }
    if (peakHour != null) {
      suggestions.add(_LocalSuggestion(
        Icons.schedule,
        'ساعة الذروة',
        'أكبر عدد من الطلبات كان بين ${_hourLabel(peakHour!)} و${_hourLabel((peakHour! + 1) % 24)}.',
      ));
    }
    return suggestions;
  }

  Map<String, dynamic> toMap() => {
        'periodDays': periodDays,
        'totalOrders': totalOrders,
        'totalRevenueLbp': totalRevenueLbp.round(),
        'topProducts': topProducts
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                })
            .toList(growable: false),
        'weakProducts': weakProducts
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                })
            .toList(growable: false),
        'commonPairs': commonPairs
            .map((item) => {
                  'name': '${item.first} + ${item.second}',
                  'count': item.count,
                })
            .toList(growable: false),
        'peakHour': peakHour == null ? 'غير متوفر' : _hourLabel(peakHour!),
      };
}

class _ProductTotal {
  final String name;
  final int quantity;
  final double revenueLbp;

  const _ProductTotal(this.name, this.quantity, this.revenueLbp);
}

class _MutableProductTotal {
  final String name;
  int quantity = 0;
  double revenueLbp = 0;

  _MutableProductTotal(this.name);
}

class _PairTotal {
  final String first;
  final String second;
  final int count;

  const _PairTotal(this.first, this.second, this.count);
}

class _MutablePairTotal {
  final String first;
  final String second;
  int count = 0;

  _MutablePairTotal(this.first, this.second);
}

String _aiPrompt(_SalesSummary summary) => '''
أنت مستشار مبيعات لمحل Sweet Sip في لبنان. حلّل ملخص المبيعات التالي:
${jsonEncode(summary.toMap())}

اكتب اقتراحاً عملياً ومختصراً باللغة العربية. استخدم هذا الترتيب:
1. العرض المقترح.
2. سبب الاقتراح من البيانات.
3. خطوات التطبيق لمدة محدودة.
لا تخترع أسعاراً أو أرقاماً غير موجودة، ولا تتجاوز 120 كلمة.
''';

DateTime _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

String _hourLabel(int hour) {
  final normalized = hour % 24;
  final suffix = normalized < 12 ? 'ص' : 'م';
  final value = normalized % 12 == 0 ? 12 : normalized % 12;
  return '$value $suffix';
}
