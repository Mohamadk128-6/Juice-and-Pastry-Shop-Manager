import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reliable_sales_provider.dart';

class SyncStatusBanner extends StatelessWidget {
  final bool compact;

  const SyncStatusBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesFirestoreProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    late final IconData icon;
    late final Color color;
    late final String text;
    VoidCallback? retry;

    if (sales.lastError != null) {
      icon = Icons.sync_problem;
      color = colorScheme.error;
      text = 'تعذّرت المزامنة • اضغط لإعادة المحاولة';
      retry = sales.retryPendingTransactions;
    } else if (sales.pendingCount > 0 || sales.hasPendingWrites) {
      icon = Icons.cloud_upload_outlined;
      color = Colors.orange.shade800;
      text = sales.pendingCount > 0
          ? '${sales.pendingCount} طلبات بانتظار المزامنة'
          : 'جاري مزامنة التغييرات...';
    } else if (sales.isLoading) {
      icon = Icons.sync;
      color = colorScheme.primary;
      text = 'جاري تحميل البيانات...';
    } else if (sales.isFromCache) {
      icon = Icons.cloud_off_outlined;
      color = Colors.blueGrey;
      text = 'وضع دون إنترنت • ستتم المزامنة تلقائياً';
    } else {
      icon = Icons.cloud_done_outlined;
      color = Colors.green.shade700;
      text = 'تمت المزامنة';
    }

    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.10),
      elevation: 0,
      child: InkWell(
        onTap: retry,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: compact ? 19 : 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
              ),
              if (retry != null) Icon(Icons.refresh, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
