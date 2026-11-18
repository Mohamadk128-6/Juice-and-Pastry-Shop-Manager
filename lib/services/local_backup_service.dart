import 'package:hive_flutter/hive_flutter.dart';

class LocalBackupService {
  static const boxName = 'sweet_sip_reliability';
  static const _salesKey = 'sales_backup';
  static const _menuKey = 'menu_backup';
  static const _pendingKey = 'pending_transactions';
  static const _aiSuggestionKey = 'ai_suggestion_backup';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) await Hive.openBox(boxName);
  }

  static Box get _box => Hive.box(boxName);

  static List<Map<String, dynamic>> get salesBackup =>
      _mapList(_box.get(_salesKey));

  static Future<void> saveSales(List<Map<String, dynamic>> value) =>
      _box.put(_salesKey, value);

  static Map<String, dynamic>? get menuBackup {
    final value = _box.get(_menuKey);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static Future<void> saveMenu(Map<String, dynamic> value) =>
      _box.put(_menuKey, value);

  static Map<String, dynamic>? get aiSuggestionBackup {
    final value = _box.get(_aiSuggestionKey);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static Future<void> saveAiSuggestion(Map<String, dynamic> value) =>
      _box.put(_aiSuggestionKey, value);

  static Map<String, Map<String, dynamic>> get pendingTransactions {
    final value = _box.get(_pendingKey);
    if (value is! Map) return {};
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        Map<String, dynamic>.from(item as Map),
      ),
    );
  }

  static Future<void> queueTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    final pending = pendingTransactions;
    pending[id] = data;
    await _box.put(_pendingKey, pending);
  }

  static Future<void> removePendingTransaction(String id) async {
    final pending = pendingTransactions..remove(id);
    await _box.put(_pendingKey, pending);
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
