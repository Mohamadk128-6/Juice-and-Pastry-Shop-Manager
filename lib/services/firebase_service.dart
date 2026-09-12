import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    // Enable offline persistence for Firestore
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    _initialized = true;
  }

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}
