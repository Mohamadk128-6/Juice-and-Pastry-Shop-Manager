import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores the name of the staff member using this device.
/// The name is added to every new order so the owner can audit sales.
class WorkerSessionProvider extends ChangeNotifier {
  static const _boxName = 'shop_manager_settings';
  static const _workerNameKey = 'worker_name';

  late final Box _box;
  String _workerName = '';

  WorkerSessionProvider() {
    _box = Hive.box(_boxName);
    _workerName = (_box.get(_workerNameKey, defaultValue: '') as String).trim();
  }

  String get workerName => _workerName;
  bool get hasWorkerName => _workerName.isNotEmpty;

  Future<void> setWorkerName(String value) async {
    _workerName = value.trim();
    await _box.put(_workerNameKey, _workerName);
    notifyListeners();
  }
}
