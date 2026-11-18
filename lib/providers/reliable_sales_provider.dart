import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import '../models/sale_transaction.dart';
import '../services/firebase_service.dart';
import '../services/local_backup_service.dart';

class SalesFirestoreProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().firestore;
  final List<SaleTransaction> _transactions = [];
  StreamSubscription? _subscription;

  bool _isLoading = true;
  bool _isFromCache = true;
  bool _hasPendingWrites = false;
  String? _lastError;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  final Set<String> _sendingIds = <String>{};

  SalesFirestoreProvider() {
    _loadLocalData();
    _listen();
    unawaited(retryPendingTransactions());
  }

  bool get isLoading => _isLoading;
  bool get isFromCache => _isFromCache;
  bool get hasPendingWrites => _hasPendingWrites || _pendingCount > 0;
  bool get isSynced => !isLoading && !isFromCache && !hasPendingWrites;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;

  void _loadLocalData() {
    final backup = LocalBackupService.salesBackup;
    for (final data in backup) {
      _transactions.add(_transactionFromMap(
        data['id']?.toString() ?? '',
        data,
      ));
    }
    for (final entry in LocalBackupService.pendingTransactions.entries) {
      if (_transactions.any((transaction) => transaction.id == entry.key)) {
        continue;
      }
      _transactions.insert(0, _transactionFromMap(entry.key, entry.value));
    }
    _pendingCount = LocalBackupService.pendingTransactions.length;
    _isLoading = _transactions.isEmpty;
  }

  void _listen() {
    _subscription = _db
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        _transactions
          ..clear()
          ..addAll(snapshot.docs.map(
            (document) => _transactionFromMap(document.id, document.data()),
          ));
        for (final entry in LocalBackupService.pendingTransactions.entries) {
          if (_transactions.any((transaction) => transaction.id == entry.key)) {
            continue;
          }
          _transactions.insert(0, _transactionFromMap(entry.key, entry.value));
        }
        _isLoading = false;
        _isFromCache = snapshot.metadata.isFromCache;
        _hasPendingWrites = snapshot.metadata.hasPendingWrites;
        _pendingCount = LocalBackupService.pendingTransactions.length;
        _lastError = null;
        if (!_isFromCache && !_hasPendingWrites) {
          _lastSyncedAt = DateTime.now();
          unawaited(LocalBackupService.saveSales(
            _transactions.map(_transactionToMap).toList(growable: false),
          ));
          if (_pendingCount > 0) {
            unawaited(retryPendingTransactions());
          }
        }
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _isFromCache = true;
        _lastError = error.toString();
        notifyListeners();
      },
    );
  }

  List<SaleTransaction> get allTransactions => List.unmodifiable(_transactions);

  List<Sale> get allSales =>
      _transactions.expand((transaction) => transaction.items).toList();

  List<SaleTransaction> get recentTransactions =>
      _transactions.take(20).toList(growable: false);

  List<String> get workerNames {
    final names = _transactions
        .map((transaction) => transaction.workerName)
        .where((name) => name.isNotEmpty && name != 'غير محدد')
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<SaleTransaction> transactionsForWorker(String workerName) =>
      _transactions
          .where((transaction) => transaction.workerName == workerName)
          .toList(growable: false);

  double get totalUsdAll =>
      allSales.fold(0.0, (total, sale) => total + sale.totalUsd);

  double totalUsdForDay(DateTime day) => allSales
      .where((sale) =>
          sale.createdAt.year == day.year &&
          sale.createdAt.month == day.month &&
          sale.createdAt.day == day.day)
      .fold(0.0, (total, sale) => total + sale.totalUsd);

  double totalUsdForMonth(DateTime day) => allSales
      .where((sale) =>
          sale.createdAt.year == day.year && sale.createdAt.month == day.month)
      .fold(0.0, (total, sale) => total + sale.totalUsd);

  Future<String> addTransaction({
    required List<Sale> items,
    required double exchangeRate,
    required String workerName,
    String orderNote = '',
    String? transactionId,
  }) async {
    final now = DateTime.now();
    final id = transactionId ??
        '${now.microsecondsSinceEpoch}-${workerName.hashCode.abs()}';
    final data = <String, dynamic>{
      'id': id,
      'createdAt': now.toIso8601String(),
      'exchangeRate': exchangeRate,
      'workerName': workerName.trim(),
      'orderNote': orderNote.trim(),
      'items': items
          .map((sale) => {
                'id': sale.id,
                'productId': sale.productId,
                'productName': sale.productName,
                'quantity': sale.quantity,
                'unitPriceUsd': sale.unitPriceUsd,
                'exchangeRate': sale.exchangeRate,
                'createdAt': sale.createdAt.toIso8601String(),
              })
          .toList(growable: false),
    };

    await LocalBackupService.queueTransaction(id, data);
    _pendingCount = LocalBackupService.pendingTransactions.length;
    _hasPendingWrites = true;
    if (!_transactions.any((transaction) => transaction.id == id)) {
      _transactions.insert(0, _transactionFromMap(id, data));
    }
    notifyListeners();
    unawaited(_sendQueuedTransaction(id, data));
    return id;
  }

  Future<void> retryPendingTransactions() async {
    _lastError = null;
    final pending = LocalBackupService.pendingTransactions;
    _pendingCount = pending.length;
    notifyListeners();
    for (final entry in pending.entries) {
      unawaited(_sendQueuedTransaction(entry.key, entry.value));
    }
  }

  Future<void> _sendQueuedTransaction(
    String id,
    Map<String, dynamic> queued,
  ) async {
    if (!_sendingIds.add(id)) return;
    try {
      final reference = _db.collection('transactions').doc(id);
      final existing = await reference.get(
        const GetOptions(source: Source.server),
      );
      if (!existing.exists) {
        await reference.set(_firestoreData(queued));
      }
      await LocalBackupService.removePendingTransaction(id);
      _pendingCount = LocalBackupService.pendingTransactions.length;
      _hasPendingWrites = _pendingCount > 0;
      _lastError = null;
      _lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      _pendingCount = LocalBackupService.pendingTransactions.length;
      _isFromCache = true;
      _lastError = error.toString();
      notifyListeners();
    } finally {
      _sendingIds.remove(id);
    }
  }

  Map<String, dynamic> _firestoreData(Map<String, dynamic> queued) => {
        'createdAt': Timestamp.fromDate(_date(queued['createdAt'])),
        'exchangeRate': _double(queued['exchangeRate']),
        'workerName': queued['workerName']?.toString() ?? '',
        'orderNote': queued['orderNote']?.toString() ?? '',
        'items': _mapList(queued['items'])
            .map((item) => {
                  ...item,
                  'createdAt': Timestamp.fromDate(_date(item['createdAt'])),
                })
            .toList(growable: false),
      };

  SaleTransaction _transactionFromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final items = _mapList(data['items'])
        .map((item) => Sale(
              id: item['id']?.toString() ?? '',
              productId: item['productId']?.toString() ?? '',
              productName: item['productName']?.toString() ?? '',
              quantity: _int(item['quantity']),
              unitPriceUsd: _double(item['unitPriceUsd']),
              exchangeRate: _double(item['exchangeRate']),
              createdAt: _date(item['createdAt']),
            ))
        .toList(growable: false);
    return SaleTransaction(
      id: id,
      items: items,
      createdAt: _date(data['createdAt']),
      exchangeRate: _double(data['exchangeRate']),
      workerName: data['workerName']?.toString() ?? 'غير محدد',
      orderNote: data['orderNote']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _transactionToMap(SaleTransaction transaction) => {
        'id': transaction.id,
        'createdAt': transaction.createdAt.toIso8601String(),
        'exchangeRate': transaction.exchangeRate,
        'workerName': transaction.workerName,
        'orderNote': transaction.orderNote,
        'items': transaction.items
            .map((sale) => {
                  'id': sale.id,
                  'productId': sale.productId,
                  'productName': sale.productName,
                  'quantity': sale.quantity,
                  'unitPriceUsd': sale.unitPriceUsd,
                  'exchangeRate': sale.exchangeRate,
                  'createdAt': sale.createdAt.toIso8601String(),
                })
            .toList(growable: false),
      };

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

double _double(dynamic value) => value is num ? value.toDouble() : 0.0;
int _int(dynamic value) => value is num ? value.toInt() : 0;
