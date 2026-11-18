import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    } catch (_) {
      // App Check setup must not prevent offline sales from opening.
    }
    // Enable offline persistence for Firestore
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    _initialized = true;
  }

  FirebaseFirestore get firestore {
    if (!_initialized) {
      throw StateError(
        'FirebaseService.init() must complete before Firestore is used.',
      );
    }
    return FirebaseFirestore.instance;
  }
}
